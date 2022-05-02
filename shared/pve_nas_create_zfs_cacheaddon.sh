#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_create_zfs_cacheaddon.sh
# Description:  Source script for adding ZFS Cache to a existing ZFS raid storage
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Sets the validation input type
INPUT_TRAN='(sata|ata|scsi|nvme)'
INPUT_TRAN_ARG='onboard'

# Basic storage disk label
BASIC_DISKLABEL='(.*_hba|.*_usb|.*_onboard)$'

# Disk Over-Provisioning (value is % of disk)
DISK_OP_SSD='10'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

# USB Disk Storage minimum size (GB)
STOR_MIN='5'

#---- Functions --------------------------------------------------------------------

# Storage Array List
function storage_list() {
  # 1=PATH:2=KNAME:3=PKNAME (or part cnt.):4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM
  # PVE All Disk array
  # Output printf '%s\n' "${allSTORAGE[@]}"
  unset allSTORAGE
  # Suppress warnings
  export LVM_SUPPRESS_FD_WARNINGS=1
  while read -r line; do
    #---- Set dev
    dev=$(echo $line | awk -F':' '{ print $1 }')

    #---- Set variables
    # Partition Cnt (Col 3)
    if ! [[ $(echo $line | awk -F':' '{ print $3 }') ]] && [[ "$(echo "$line" | awk -F':' '{ if ($1 ~ /^\/dev\/sd[a-z]$/ || $1 ~ /^\/dev\/nvme[0-9]n[0-9]$/) { print "0" } }')" ]]; then
      # var3=$(partx -g ${dev} | wc -l)
      if [[ $(lsblk ${dev} | grep part) ]]; then
        var3=$(lsblk ${dev} | grep part | wc -l)
      else
        var3='0'
      fi
    else
      var3=$(echo $line | awk -F':' '{ print $3 }')
    fi

    #---- ZFS_Members (Col 4)
    if ! [[ $(echo $line | awk -F':' '{ print $4 }') ]] && [ "$(lsblk -nbr -o FSTYPE ${dev})" = "zfs_member" ] || [ "$(blkid -o value -s TYPE ${dev})" = "zfs_member" ]; then
      var4='zfs_member'
    else
      var4=$(echo $line | awk -F':' '{ print $4 }')
    fi

    # Tran (Col 5)
    if ! [[ $(echo $line | awk -F':' '{ print $5 }') ]] && [[ ${dev} =~ ^/dev/(sd[a-z]|nvme[0-9]n[0-9]) ]]; then
      var5=$(lsblk -nbr -o TRAN /dev/"$(lsblk -nbr -o PKNAME ${dev} | grep 'sd[a-z]$\|nvme[0-9]n[0-9]$' | uniq | sed '/^$/d')" | uniq | sed '/^$/d')
    elif [[ ${dev} =~ ^/dev/mapper ]] && [ $(lvs $dev &> /dev/null; echo $?) == '0' ]; then
      vg_var="$(lvs $dev --noheadings -o vg_name | sed 's/ //g')"
      device_var=$(pvs --noheadings -o pv_name,vg_name | sed  's/^[t ]*//g' | grep "$vg_var" | awk '{ print $1 }')
      if [[ ${device_var} =~ ^/dev/(sd[a-z]$|nvme[0-9]n[0-9]$) ]]; then
        device=$device_var
      else
        device="/dev/$(lsblk -nbr -o PKNAME $device_var | grep 'sd[a-z]$\|nvme[0-9]n[0-9]$' | sed '/^$/d' | uniq)"
      fi
      var5=$(lsblk -nbr -o TRAN $device | sed '/^$/d')
    else
      var5=$(echo $line | awk -F':' '{ print $5 }')
    fi

    # Size (Col 8)
    var8=$(lsblk -nbrd -o SIZE ${dev} | awk '{ $1=sprintf("%.0f",$1/(1024^3))"G" } {print $0}')
    # Rota (Col 10)
    if [[ $(hdparm -I ${dev} 2> /dev/null | awk -F':' '/Nominal Media Rotation Rate/ { print $2 }' | sed 's/ //g') == 'SolidStateDevice' ]]; then
      var10='0'
    else
      var10='1'
    fi

    # Zpool/LVM VG Name or Cnt (Col 14)
    if [[ $(lsblk ${dev} -dnbr -o TYPE) == 'disk' ]] && [ ! "$(blkid -o value -s TYPE ${dev})" == 'LVM2_member' ]; then
      cnt=0
      var14=0
      while read -r dev_line; do
        if [ ! "$(blkid -o value -s TYPE ${dev_line})" == 'zfs_member' ] && [ ! "$(blkid -o value -s TYPE ${dev_line})" == 'LVM2_member' ]; then
          continue
        fi
        cnt=$((cnt+1))
        var14=$cnt
      done < <(lsblk -nbr ${dev} -o PATH)
    elif [ $(lsblk ${dev} -dnbr -o TYPE) == 'part' ] && [ "$(blkid -o value -s TYPE ${dev})" == 'zfs_member' ]; then
      var14=$(blkid -o value -s LABEL ${dev})
    elif [[ $(lsblk ${dev} -dnbr -o TYPE) =~ (disk|part) ]] && [ "$(blkid -o value -s TYPE ${dev})" == 'LVM2_member' ]; then
      var14=$(pvs --noheadings -o pv_name,vg_name | sed "s/^[ \t]*//" | grep $dev | awk '{ print $2 }')
    elif [[ ${dev} =~ ^/dev/mapper ]] && [[ ! ${dev} =~ ^/dev/mapper/pve- ]] && [ $(lvs $dev &> /dev/null; echo $?) == '0' ]; then
      var14=$(lvs $dev --noheadings -a -o vg_name | sed 's/ //g')
    elif [[ ${dev} =~ ^/dev/mapper/pve- ]]; then
      var14=$(echo $dev | awk -F'/' '{print $NF}' | sed 's/\-.*$//')
    else
      var14='0'
    fi

    # System (Col 15)
    if [[ $(df -hT | grep /$ | grep -w '^rpool/.*') ]]; then
      # ONLINE=$(zpool status rpool | grep -Po "\S*(?=\s*ONLINE)")
      ONLINE=$(zpool status rpool 2> /dev/null | grep -Po "\S*(?=\s*ONLINE|\s*DEGRADED)")
      unset ROOT_DEV
      while read -r pool; do
        if ! [ -b "/dev/disk/by-id/${pool}" ]; then
          continue
        fi
        ROOT_DEV+=( $(readlink -f /dev/disk/by-id/${pool}) )
      done <<< "$ONLINE"
    elif [[ $(df -hT | grep /$ | grep -w '^/dev/.*') ]]; then
      ROOT_DEV+=( $(df -hT | grep /$) )
    fi
    if [[ $(fdisk -l ${dev} 2>/dev/null | grep -E '(BIOS boot|EFI System|Linux swap|Linux LVM)' | awk '{ print $1 }') ]] || [[ "${ROOT_DEV[*]}" =~ "${dev}" ]]; then
      var15='1'
    elif [[ ${dev} =~ ^/dev/mapper/(pve-root|pve-data.*|pve-vm.*|pve-swap.*) ]]; then
      var15='1'
    elif [ $var14 == 'pve' ]; then
      var15='1'
    else
      var15='0'
    fi

    #---- Finished Output
    allSTORAGE+=( "$(echo $line | awk -F':' -v var3=${var3} -v var4=${var4} -v var5=${var5} -v var8=${var8} -v var10=${var10} -v var14=${var14} -v var15=${var15} 'BEGIN {OFS = FS}{ $3 = var3 } { $4 = var4 } {if ($5 == "") {$5 = var5;}} { $8 = var8 } { $10 = var10 } { $14 = var14 } { $15 = var15 } { print $0 }')" )

  done < <( lsblk -nbr -o PATH,KNAME,PKNAME,FSTYPE,TRAN,MODEL,SERIAL,SIZE,TYPE,ROTA,UUID,RM,LABEL | sed 's/ /:/g' | sed 's/$/:/' | sed 's/$/:0/' | sed '/^$/d' | awk '!a[$0]++' 2> /dev/null )
}

# Working output Storage Array List
function stor_LIST() {
  unset storLIST
  for i in "${allSTORAGE[@]}"; do
    storLIST+=( $(echo $i) )
  done
}

#---- Body -------------------------------------------------------------------------

#---- Prerequisites
# Create storage list array
storage_list

# Create a working list array
stor_LIST

# Disk count by type
disk_CNT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN="${STOR_MIN}" -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} \
'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
{if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { print $0 }}' | wc -l)

# Available ZPool list
unset zpoolLIST
while read zpool; do
  # Check if ZPool is already configured for ZFS cache
  if [[ ! $(zpool status ${zpool} | grep -w 'logs\|cache') ]]; then
    zpoolLIST+=( "${zpool}" )
  fi
done < <( zpool list -H -o name | sed '/^rpool/d' ) # file listing of zpools

# Check SSD/NVMe storage is available
if [[ ${disk_CNT} == '0' ]]; then
  msg "We could NOT detect any new available SSD or NVMe storage devices. New disk(s) might have been wrongly identified as 'system drives' if they contain Linux system or OS partitions. To fix this issue, manually format the disk erasing all data before running this installation again. USB disks cannot be used for ZFS cache. Bye..."
  echo
  return
fi

# Check for existing ZPools
if [ ${#zpoolLIST[@]} == '0' ]; then
  msg "We could NOT detect any existing ZPools to add ZFS Cache. First create a ZPool and try again. Bye..."
  echo
  return
fi

#---- Select ZFS Cache devices
section "Select ZFS Cache devices"
# 1=PATH:2=KNAME:3=PKNAME:4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM

# Select member disks
TYPE_SSD='(^/dev/sd[a-z])'
TYPE_NVME='(^/dev/nvme[0-9]n[0-9])'
while true; do
  msg_box "#### PLEASE READ CAREFULLY - ZFS CACHE SETUP ####\n\nThere are ${disk_CNT}x available device(s) for ZFS Cache. Do not co-mingle SSD and NVMe cache devices together.\n\n$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} -v TYPE_SSD=${TYPE_SSD} -v TYPE_NVME=${TYPE_NVME} \
  'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  {if ($1 ~ TYPE_SSD && $5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print $1, $6, "SSD", $8 } \
  {if ($1 ~ TYPE_NVME && $5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print $1, $6, "NVMe", $8 }' \
  | column -s : -t -N "DEVICE PATH,DESCRIPTION,TYPE,SIZE" | indent2)\n\nIn the next steps the User must select their ZFS cache devices (recommend a maximum of 2x devices). The devices will be erased and wiped of all data and partitioned ready for ZIL and ARC or L2ARC cache.\n\nThe ARC or L2ARC and ZIL cache build options are:\n\n1.  Standard Cache: Select 1x device only. No ARC,L2ARC or ZIL disk redundancy.\n2.  Accelerated Cache: Select 2x devices. ARC or L2ARC cache set to Raid0 (stripe) and ZIL set to Raid1 (mirror)."

  # Make selection
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} -v TYPE_SSD=${TYPE_SSD} -v TYPE_NVME=${TYPE_NVME} \
  'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  # Select SSD
  {if ($1 ~ TYPE_SSD && $5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print "TYPE01", $0 } \
  # Select NVMe
  {if ($1 ~ TYPE_NVME && $5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print "TYPE02", $0 }')
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} -v TYPE_SSD=${TYPE_SSD} -v TYPE_NVME=${TYPE_NVME} \
  'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  # TYPE01: Select SSD
  {if ($1 ~ TYPE_SSD && $5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print $1, $6, "SSD", $8 } \
  # TYPE02: Select NVMe
  {if ($1 ~ TYPE_NVME && $5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print $1, $6, "NVMe", $8 }' \
  | column -t -s :)
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  multiselect_confirm SELECTED "$OPTIONS_STRING"

  # Create input disk list array
  unset inputcachediskLIST
  for i in "${RESULTS[@]}"; do
    inputcachediskLIST+=( $(echo $i) )
  done

  # Check device number and co-mingling status of selected devices
  if [ "${#inputcachediskLIST[@]}" == '0' ] || [[ "${inputcachediskLIST[*]}" =~ ^TYPE01 ]] && [[ "${inputcachediskLIST[*]}" =~ ^TYPE02 ]]; then
    msg "The User selected ${#inputcachediskLIST[@]}x devices. The requirement is:\n  --  Minimum of '1x' device\n  --  A recommended maximum of '2x' devices\n  --  Cannot co-mingled SSD and NVMe devices together\nTry again..."
  elif [ "${#inputcachediskLIST[@]}" -ge '1' ]; then
    break
  fi
done


#---- Set ZFS cache partition sizes
section "Set ZFS cache partition sizes"

msg_box "#### Set ARC or L2ARC cache and ZIL disk partition sizes ####\n\nYou have allocated '${#inputcachediskLIST[@]}x' device(s) for ZFS cache partitioning.\nThe maximum size of a ZIL log should be about half the size of your hosts $(grep MemTotal /proc/meminfo | awk '{printf "%.0fGB\n", $2/1024/1024}') installed physical RAM memory BUT not less than 8GB.\n\nThe ARC or L2ARC cache size should not be less than 64GB but will be sized to use the whole ZFS cache device.\n\nThe system will automatically calculate the best partition sizes for you. A device over-provisioning factor of ${DISK_OP_SSD}% will be applied."
echo

# Set ZIL partition size
if [ $(grep MemTotal /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024}') -le 16 ]; then
  # Set ZIL partition size to default minimum
  ZIL_SIZE_VAR=8
  msg "PVE host $(grep MemTotal /proc/meminfo | awk '{printf "%.0fGB\n", $2/1024/1024}') of RAM is below the minimum threshold. Setting ZIL size to the default minimum..."
  info "ZIL size: ${YELLOW}${ZIL_SIZE_VAR}GB${NC} (default minimum)"
  echo
elif [ $(grep MemTotal /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024}') -gt 16 ]; then
  # Set ZIL partition size
  if [ $(grep MemTotal /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024}') -lt 24 ]; then
    ZIL_SEQ_SIZE='1'
  else
    ZIL_SEQ_SIZE='4'
  fi
  msg "The User must select a ZIL size. The available options are based on your PVE hosts installed $(grep MemTotal /proc/meminfo | awk '{printf "%.0fGB\n", $2/1024/1024}') RAM in ${ZIL_SEQ_SIZE}GB increments. Now select your ZIL size..."

  OPTIONS_VALUES_INPUT=$(seq $(grep MemTotal /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024/2}') -${ZIL_SEQ_SIZE} 8)
  OPTIONS_LABELS_INPUT=$(seq $(grep MemTotal /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024/2}') -${ZIL_SEQ_SIZE} 8 | sed 's/$/GB/' | sed '1 s/$/ (Recommended)/')
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect SELECTED "$OPTIONS_STRING"
  # Set ZIL size
  ZIL_SIZE_VAR=${RESULTS}
fi

# Set ARC partition size (based on smallest device)
ARC_SIZE_VAR=$(( $(printf '%s\n' "${inputcachediskLIST[@]}" | sort -t ':' -k 9 | awk -F':' 'NR==1{print $9}' | sed 's/[[:alpha:]]//' | awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}') * ( 100 - ${DISK_OP_SSD} ) / 100 - ${ZIL_SIZE_VAR} ))

# Set final ZIL and ARC variables into bytes
ZIL_SIZE="$(( (${ZIL_SIZE_VAR} * 1073741824)/512 ))"
ARC_SIZE="$(( (${ARC_SIZE_VAR} * 1073741824)/512 ))"

# GPT label & wipe devices
msg "GPT label & wipe ZFS cache devices..."
while read dev; do
  echo 'label: gpt' | sfdisk --quiet --wipe=always --force ${dev}
  info "GPT labelled: ${dev}"
done < <( printf '%s\n' "${inputcachediskLIST[@]}" | awk -F':' '{ print $2 }' ) # file listing of disks
echo

# Partition ZFS cache device(s)
msg "Partition ZFS cache device(s)..."
part_LIST=( " " )
part_LIST+=( ",${ZIL_SIZE}" ) 
part_LIST+=( ",${ARC_SIZE}" )
unset inputcachedevLIST
while read dev; do
  i=1
  sfdisk --quiet --force ${dev} <<<$(printf '%s\n' "${part_LIST[@]}")
  info "ZIL cache partition created: ${dev}${i}"
  # Get part by-id
  part_ID=$(ls -l /dev/disk/by-id | grep -E "${INPUT_TRAN}" | grep -w "$(echo ${dev}${i} | sed 's|^.*/||')" | awk '{ print $9 }')
  inputcachedevLIST+=( "${dev}${i}:${part_ID}:zil" )
  i=$(( $i + 1 ))
  info "ARC cache partition created: ${dev}${i}"
  # Get part by-id
  part_ID=$(ls -l /dev/disk/by-id | grep -E "${INPUT_TRAN}" | grep -w "$(echo ${dev}${i} | sed 's|^.*/||')" | awk '{ print $9 }')
  inputcachedevLIST+=( "${dev}${i}:${part_ID}:arc" )
done < <( printf '%s\n' "${inputcachediskLIST[@]}" | awk -F':' '{ print $2 }' ) # file listing of disks
echo

# Create ZFS ZIL arg
if [ $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l) == '1' ]; then
  zil_ARG=$(printf '%s\n' "${inputcachedevLIST[@]}" | awk -F':' 'BEGIN{OFS=FS} { if ($3 == "zil") print "/dev/disk/by-id/"$2 }')
  zil_DISPLAY="ZIL cache set:\n  1.  $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l)x disk Raid0 (single only)"
elif [ $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l) -gt '1' -a $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l) -le '3' ]; then
  zil_ARG=$(printf '%s\n' "${inputcachedevLIST[@]}" | awk -F':' 'BEGIN{OFS=FS} { if ($3 == "zil") print "/dev/disk/by-id/"$2 }' | xargs | sed 's/^/mirror /')
  zil_DISPLAY="ZIL cache set:\n  1.  $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l)x disk Raid1 (mirror only)"
elif [ $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l) -ge '4' ]; then
  count=$(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l)
  if [ "$((count% 2))" -eq 0 ]; then
    # Even cnt
    zil_ARG=$(printf '%s\n' "${inputcachedevLIST[@]}" | awk -F':' 'BEGIN{OFS=FS} { if ($3 == "zil") print "/dev/disk/by-id/"$2 }' | xargs | sed '-es/ / mirror /'{1000..1..2} | sed 's/^/mirror /')
    zil_DISPLAY="ZIL cache set:\n  1.  $(( $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l) / 2 ))x disk Raid0 (stripe).\n  2.  $(( $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l) / 2 ))x disk Raid1 (mirror)"
  else
    # Odd cnt (fix)
    zil_ARG=$(printf '%s\n' "${inputcachedevLIST[@]}" | awk -F':' 'BEGIN{OFS=FS} { if ($3 == "zil") print "/dev/disk/by-id/"$2 }' | sed '$ d' | xargs | sed '-es/ / mirror /'{1000..1..2} | sed 's/^/mirror /')
    zil_DISPLAY="ZIL cache set:\n  1.  $(( $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l) / 2 ))x disk Raid0 (stripe).\n  2.  $(( $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "zil" | wc -l) / 2 ))x disk Raid1 (mirror)"
  fi
fi

# Create ZFS ARC arg
if [ $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "arc" | wc -l) -le '3' ]; then
  arc_ARG=$(printf '%s\n' "${inputcachedevLIST[@]}" | awk -F':' 'BEGIN{OFS=FS} { if ($3 == "arc") print "/dev/disk/by-id/"$2 }' | xargs)
  arc_DISPLAY="ARC cache set:\n  1.  $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "arc" | wc -l)x disk Raid0 (stripe only)"
elif [ $(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "arc" | wc -l) -ge '4' ]; then
  count=$(printf '%s\n' "${inputcachedevLIST[@]}" | grep -w "arc" | wc -l)
  if [ "$((count% 2))" -eq 0 ]; then
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

# Select a ZPool
if [[ -z ${POOL} ]]; then
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${zpoolLIST[@]}" | sed -e '$a\TYPE00')
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${zpoolLIST[@]}" | sed -e '$a\None. Exit this ZFS Cache installer')
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect SELECTED "$OPTIONS_STRING"
  if [ ${RESULTS} == 'TYPE00' ]; then
    # Exit installer
    msg "You have chosen not to proceed. Bye..."
    echo
    return
  else
    # Set ZPOOL
    POOL=${RESULTS}
  fi
fi

# Add ZFS Cache to ZPool
msg "Creating ZIL Cache..."
zpool add -f ${POOL} log ${zil_ARG}
info "${zil_DISPLAY}"
echo

msg "Creating ARC Cache..."
zpool add -f ${POOL} cache ${arc_ARG}
info "${arc_DISPLAY}"
echo

#---- Finish Line ------------------------------------------------------------------