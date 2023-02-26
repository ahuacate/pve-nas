#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_create_zfs_cacheaddon.sh
# Description:  Source script for adding ZFS Cache to a existing ZFS raid storage
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

# NAS bash utility
source $COMMON_DIR/nas/src/nas_bash_utility.sh

#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Sets the validation input type
input_tran='(sata|ata|scsi|nvme)'
input_tran_arg='onboard'

# Basic storage disk label
basic_disklabel='(.*_hba|.*_usb|.*_onboard)$'

# Disk Over-Provisioning (value is % of disk)
disk_op_ssd=10

# Disk device regex
type_ssd='(^/dev/sd[a-z])'
type_nvme='(^/dev/nvme[0-9]n[0-9])'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

# USB Disk Storage minimum size (GB)
stor_min=5

#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Create storage list array
storage_list

# Create a working list array
stor_LIST

# Create ZPool list
zpool_LIST=()
while read zpool
do
  # Check if ZPool is already configured for ZFS cache
  if [[ ! $(zpool status $zpool | grep -w 'logs\|cache') ]]
  then
    zpool_LIST+=( "$zpool" )
  fi
done < <( zpool list -H -o name | sed '/^rpool/d' ) # file listing of zpools

# Check for existing ZPools
if [ ${#zpool_LIST[@]} = 0 ]
then
  msg "We could NOT detect any existing ZPools to add ZFS Cache. First create a ZPool and try again. Bye..."
  echo
  return
fi


#---- ZFS cache disk list
# 1=PATH:2=KNAME:3=PKNAME:4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM
# build:description:tran:size|action:all

zfs_cache_option_input=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v stor_min="$stor_min" -v input_tran="$input_tran" -v basic_disklabel="$basic_disklabel" -v type_ssd="$type_ssd" -v type_nvme="$type_nvme" \
'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
# TYPE01: Select SSD
{if ($1 ~ type_ssd && $5 ~ input_tran && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= stor_min && $10 == 0 && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) print "TYPE01", "SSD", $0 } \
# TYPE02: Select NVMe
{if ($1 ~ type_nvme && $5 ~ input_tran && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= stor_min && $10 == 0 && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) print "TYPE02", "NVMe", $0 }')

# Create selection labels & values
zfs_cache_option_labels=$(printf '%s\n' "$zfs_cache_option_input" | sed '/^$/d' | awk 'BEGIN{FS=OFS=":"} { print $3, $8, $2, $10 }')
zfs_cache_option_values=$(printf '%s\n' "$zfs_cache_option_input" | sed '/^$/d' | cut -d: -f1,3-)

# ZFS option cnt
zfs_cache_option_cnt=$(echo "$zfs_cache_option_values" | sed '/^$/d' | wc -l)

# Create display
zfs_cache_option_display=$(printf '%s\n' "$zfs_cache_option_input" | sed '/^$/d' | awk 'BEGIN{FS=OFS=":"} { print $3, $8, $2, $10 }' | column -s : -t -N "DEVICE PATH,DESCRIPTION,TYPE,SIZE" | indent2)

# Check SSD/NVMe storage is available
if [ "$zfs_cache_option_cnt" = 0 ]
then
  msg "We could NOT detect any unused available SSD or NVMe storage devices. Unused disk(s) might have been wrongly identified as 'system drives' if they contain Linux system or OS partitions. To fix this issue, manually format the disk erasing all data before running this installation again. USB disks cannot be used for ZFS cache. Bye..."
  echo
  return
fi


#---- Select ZFS Cache devices

section "Select ZFS Cache devices"
# 1=PATH:2=KNAME:3=PKNAME:4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM

# Select cache member disks
while true
do
  # Create labels
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "$zfs_cache_option_labels" | column -t -s :)

  # Create values
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "$zfs_cache_option_values")

  # Display msg
  msg_box "#### PLEASE READ CAREFULLY - ZFS CACHE SETUP ####\n\nThere are ${zfs_cache_option_cnt}x available device(s) for ZFS Cache. Do not co-mingle SSD and NVMe cache devices together.\n\n$(printf '%s\n' "$zfs_cache_option_display")\n\nIn the next steps the User must select their ZFS cache devices (recommend a maximum of 2x devices). The devices will be erased and wiped of all data and partitioned ready for ZIL and ARC or L2ARC cache.\n\nThe ARC or L2ARC and ZIL cache build options are:\n\n1.  Standard Cache: Select 1x device only. No ARC,L2ARC or ZIL disk redundancy.\n2.  Accelerated Cache: Select 2x devices. ARC or L2ARC cache set to Raid0 (stripe) and ZIL set to Raid1 (mirror)."

  # Make selection
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  multiselect_confirm SELECTED "$OPTIONS_STRING"

  # Create input disk list array
  inputcachedisk_LIST=()
  for i in "${RESULTS[@]}"
  do
    inputcachedisk_LIST+=( $(echo $i) )
  done

  # Check device number and co-mingling status of selected devices
  if [ "${#inputcachedisk_LIST[@]}" = 0 ] || [[ "${inputcachedisk_LIST[*]}" =~ ^TYPE01 ]] && [[ "${inputcachedisk_LIST[*]}" =~ ^TYPE02 ]]
  then
    msg "The User selected ${#inputcachedisk_LIST[@]}x devices. The requirement is:\n  --  Minimum of '1x' device\n  --  A recommended maximum of '2x' devices\n  --  Cannot co-mingled SSD and NVMe devices together\nTry again..."
  elif [ "${#inputcachedisk_LIST[@]}" -ge 1 ]
  then
    break
  fi
done


#---- Set ZFS cache partition sizes

section "Set ZFS cache partition sizes"

msg_box "#### Set ARC or L2ARC cache and ZIL disk partition sizes ####

You have allocated ${#inputcachedisk_LIST[@]}x device(s) for ZFS cache partitioning.

The maximum size of a ZIL log should be about half the size of your hosts $(grep MemTotal /proc/meminfo | awk '{printf "%.0fGB\n", $2/1024/1024}') installed physical RAM memory BUT not less than 8GB.

The ARC or L2ARC cache size should not be less than 64GB but will be sized to use the whole ZFS cache device.

The system will automatically calculate the best partition sizes for you. A device over-provisioning factor of ${disk_op_ssd}% will be applied."
echo

# Set ZIL partition size
if [ $(free -g | awk '/^Mem:/ {print $2}') -le 16 ]
then
  # Set ZIL partition size to default minimum
  zil_size_var=8
  msg "PVE host $(grep MemTotal /proc/meminfo | awk '{printf "%.0fGB\n", $2/1024/1024}') of RAM is below the minimum threshold. Setting ZIL size to the default minimum..."
  info "ZIL size: ${YELLOW}${zil_size_var}GB${NC} (default minimum)"
  echo
elif [ $(free -g | awk '/^Mem:/ {print $2}') -gt 16 ]
then
  # Set ZIL partition size
  if [ $(free -g | awk '/^Mem:/ {print $2}') -lt 24 ]
  then
    zil_seq_size=1
  else
    zil_seq_size=4
  fi
  msg "The User must select a ZIL size. The available options are based on your PVE hosts installed $(grep MemTotal /proc/meminfo | awk '{printf "%.0fGB\n", $2/1024/1024}') RAM in ${zil_seq_size}GB increments. Now select your ZIL size..."

  OPTIONS_VALUES_INPUT=$(seq $(grep MemTotal /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024/2}') -${zil_seq_size} 8)
  OPTIONS_LABELS_INPUT=$(seq $(grep MemTotal /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024/2}') -${zil_seq_size} 8 | sed 's/$/GB/' | sed '1 s/$/ (Recommended)/')
  # Make selection
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect SELECTED "$OPTIONS_STRING"
  # Set ZIL size
  zil_size_var="$RESULTS"
fi

# Set ARC partition size (based on smallest device)
arc_size_var=$(( $(printf '%s\n' "${inputcachedisk_LIST[@]}" | sort -t ':' -k 9 | awk -F':' 'NR==1{print $9}' | sed 's/[[:alpha:]]//' | awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}') * ( 100 - $disk_op_ssd ) / 100 - $zil_size_var ))

# Set final ZIL and ARC variables into bytes
zil_size="$(( ($zil_size_var * 1073741824)/512 ))"
arc_size="$(( ($arc_size_var * 1073741824)/512 ))"

# GPT label & wipe devices
msg "GPT label & wipe ZFS cache devices..."
while read dev
do
  # Full device wipeout
  dd if=/dev/urandom of=$dev count=1 bs=1M conv=notrunc 2>/dev/null
  # Label device
  echo 'label: gpt' | sfdisk --quiet --wipe=always --force $dev
  info "GPT labelled: $dev"
done < <( printf '%s\n' "${inputcachedisk_LIST[@]}" | awk -F':' '{ print $2 }' ) # file listing of disks
echo

# Partition ZFS cache device(s)
msg "Partition ZFS cache device(s)..."
part_LIST=()
part_LIST+=( ",$zil_size,L" ) 
part_LIST+=( ",$arc_size,L" )
inputcachedevLIST=()
while read dev
do
  #---- Create disk partitions
  sfdisk --quiet --force $dev <<<$(printf '%s\n' "${part_LIST[@]}")
  udevadm settle

  #---- Zil cache
  i=1
  # Remove the "/dev/" prefix from the device name
  dev_name=$(echo "$dev$i" | sed 's/\/dev\///g')
  # Get the by-id name for the specified device
  by_id_name="$(ls -l /dev/disk/by-id | grep -v "wwn-" | grep "$dev_name" | awk '{print $9}')"
  # Create cache disk input list
  inputcachedevLIST+=( "$dev${i}:$by_id_name:zil" )
  info "ZIL cache partition created: $dev${i}"

  #---- Arc cache
  i=$(( $i + 1 ))
  # Remove the "/dev/" prefix from the device name
  dev_name=$(echo "$dev$i" | sed 's/\/dev\///g')
  # Get the by-id name for the specified device
  by_id_name=$(ls -l /dev/disk/by-id | grep -v "wwn-" | grep "$dev_name" | awk '{print $9}')
  # Create cache disk input list
  inputcachedevLIST+=( "$dev${i}:$by_id_name:arc" )
  info "ARC cache partition created: $dev${i}"
done < <( printf '%s\n' "${inputcachedisk_LIST[@]}" | awk -F':' '{ print $2 }' ) # file listing of disks


# Create ZFS ZIL arg
if [ "$(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l)" = 1 ]
then
  zil_ARG=$(printf '%s\n' "${inputcachedevLIST[@]}" | awk -F':' 'BEGIN{OFS=FS} { if ($3 == "zil") print "/dev/disk/by-id/"$2 }')
  zil_DISPLAY="ZIL cache set:\n  1.  "$(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l)"x disk Raid0 (single only)"
elif [ "$(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l)" -gt 1 ] && [ "$(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l)" -le 3 ]
then
  zil_ARG=$(printf '%s\n' "${inputcachedevLIST[@]}" | awk -F':' 'BEGIN{OFS=FS} { if ($3 == "zil") print "/dev/disk/by-id/"$2 }' | xargs | sed 's/^/mirror /')
  zil_DISPLAY="ZIL cache set:\n  1.  "$(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l)"x disk Raid1 (mirror only)"
elif [ "$(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l)" -ge 4 ]
then
  count="$(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l)"
  if [ "$((count% 2))" -eq 0 ]
  then
    # Even cnt
    zil_ARG=$(printf '%s\n' "${inputcachedevLIST[@]}" | awk -F':' 'BEGIN{OFS=FS} { if ($3 == "zil") print "/dev/disk/by-id/"$2 }' | xargs | sed '-es/ / mirror /'{1000..1..2} | sed 's/^/mirror /')
    zil_DISPLAY="ZIL cache set:\n  1.  $(( "$(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l)" / 2 ))x disk Raid0 (stripe).\n  2.  $(( "$(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l)" / 2 ))x disk Raid1 (mirror)"
  else
    # Odd cnt (fix)
    zil_ARG=$(printf '%s\n' "${inputcachedevLIST[@]}" | awk -F':' 'BEGIN{OFS=FS} { if ($3 == "zil") print "/dev/disk/by-id/"$2 }' | sed '$ d' | xargs | sed '-es/ / mirror /'{1000..1..2} | sed 's/^/mirror /')
    zil_DISPLAY="ZIL cache set:\n  1.  $(( "$(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l)" / 2 ))x disk Raid0 (stripe).\n  2.  $(( "$(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l)" / 2 ))x disk Raid1 (mirror)"
  fi
fi

# Create ZFS ARC arg
if [ $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "arc" | wc -l) -le 3 ]
then
  arc_ARG=$(printf '%s\n' "${inputcachedevLIST[@]}" | awk -F':' 'BEGIN{OFS=FS} { if ($3 == "arc") print "/dev/disk/by-id/"$2 }' | xargs)
  arc_DISPLAY="ARC cache set:\n  1.  $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "arc" | wc -l)x disk Raid0 (stripe only)"
elif [ $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "arc" | wc -l) -ge 4 ]
then
  count=$(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "arc" | wc -l)
  if [ "$((count% 2))" -eq 0 ]
  then
    # Even cnt
    arc_ARG=$(printf '%s\n' "${inputcachedevLIST[@]}" | awk -F':' 'BEGIN{OFS=FS} { if ($3 == "arc") print "/dev/disk/by-id/"$2 }' | xargs | sed '-es/ / mirror /'{1000..1..2} | sed 's/^/mirror /')
    arc_DISPLAY="ARC cache set:\n  1.  $(( $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "arc" | wc -l) / 2 ))x disk Raid0 (stripe)\n  2.  $(( $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "arc" | wc -l) / 2 ))x disk Raid1 (mirror)"
  else
    # Odd cnt (fix)
    arc_ARG=$(printf '%s\n' "${inputcachedevLIST[@]}" | awk -F':' 'BEGIN{OFS=FS} { if ($3 == "arc") print "/dev/disk/by-id/"$2 }' | sed '$ d' | xargs | sed '-es/ / mirror /'{1000..1..2} | sed 's/^/mirror /')
    arc_DISPLAY="ARC cache set:\n  1.  $(( $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "arc" | wc -l) / 2 ))x disk Raid0 (stripe)\n  2.  $(( $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "arc" | wc -l) / 2 ))x disk Raid1 (mirror)"
  fi
fi

#---- Apply ZFS Cache to ZPool

section "Apply ZFS Cache to an existing ZPool"

# Select a ZPool to add cache to
if [[ -z "$POOL" ]]
then
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${zpool_LIST[@]}" | sed -e '$a\TYPE00')
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${zpool_LIST[@]}" | sed -e '$a\None. Exit this ZFS Cache installer')
  # Make selection
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect SELECTED "$OPTIONS_STRING"
  if [ "$RESULTS" = TYPE00 ]
  then
    # Exit installer
    msg "You have chosen not to proceed. Bye..."
    echo
    return
  else
    # Set ZPOOL
    POOL="$RESULTS"
  fi
fi

# Add ZFS Cache to ZPool
msg "Creating ZIL Cache..."
zpool add -f $POOL log $zil_ARG
info "$zil_DISPLAY"
echo

msg "Creating ARC Cache..."
zpool add -f $POOL cache $arc_ARG
info "$arc_DISPLAY"
echo
#-----------------------------------------------------------------------------------