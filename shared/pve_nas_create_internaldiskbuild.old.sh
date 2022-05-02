#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_create_internaldiskbuild.sh
# Description:  Source script for NAS internal SATA or Nvme disk ZFS raid storage
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

#---- Source local Git
# /mnt/pve/nas-01-git/ahuacate/pve-nas/shared/pve_nas_create_internaldiskbuild.sh

#---- Dependencies -----------------------------------------------------------------

# Storage Array List
function storage_list() {
  # 1=PATH:2=KNAME:3=PKNAME (or part cnt.):4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM
  # PVE All Disk array
  # Output printf '%s\n' "${allSTORAGE[@]}"
  unset allSTORAGE
  while read -r line; do
    #---- Set dev
    dev=$(echo $line | awk -F':' '{ print $1 }')

    #---- Set variables
    # Partition Cnt (Col 3)
    if ! [[ $(echo $line | awk -F':' '{ print $3 }') ]] && [[ "$(echo "$line" | awk -F':' '{ if ($1 ~ /^\/dev\/sd[a-z]$/ || $1 ~ /^\/dev\/nvme[0-9]n[0-9]$/) { print "0" } }')" ]]; then
      # var3=$(partx -g ${dev} | wc -l)
      if [[ $(lsblk ${dev} | grep -q part) ]]; then
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
    if ! [[ $(echo $line | awk -F':' '{ print $5 }') ]]; then
      var5=$(lsblk -nbr -o TRAN /dev/"$(lsblk -nbr -o PKNAME ${dev} | uniq | sed '/^$/d')" | uniq | sed '/^$/d')
    else
      var5=$(echo $line | awk -F':' '{ print $5 }')
    fi

    # Size (Col 8)
    var8=$(lsblk -nbrd -o SIZE ${dev} | awk '{ $1=sprintf("%.0f",$1/(1024^3))"G" } {print $0}')

    # Zpool Name or Cnt (Col 14)
    if [[ $(lsblk ${dev} -dnbr -o TYPE) == 'disk' ]]; then
      cnt=0
      var14=0
      while read -r dev_line; do
        if ! [ "$(blkid -o value -s TYPE ${dev_line})" == 'zfs_member' ]; then
          continue
        fi
        cnt=$((cnt+1))
        var14=$cnt
      done < <(lsblk -nbr ${dev} -o PATH)
    elif [[ $(lsblk ${dev} -dnbr -o TYPE) == 'part' ]] && [ "$(blkid -o value -s TYPE ${dev})" == 'zfs_member' ]; then
      var14=$(blkid -o value -s LABEL ${dev})
    else
      var14='0'
    fi

    # System (Col 15)
    if [[ $(df -hT | grep /$ | grep -w '^rpool/.*') ]]; then
      # ONLINE=$(zpool status rpool | grep -Po "\S*(?=\s*ONLINE)")
      ONLINE=$(zpool status rpool | grep -Po "\S*(?=\s*ONLINE|\s*DEGRADED)")
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
    else
      var15='0'
    fi

    #---- Finished Output
    allSTORAGE+=( "$(echo $line | awk -F':' -v var3=${var3} -v var4=${var4} -v var5=${var5} -v var8=${var8} -v var14=${var14} -v var15=${var15} 'BEGIN {OFS = FS}{ $3 = var3 } { $4 = var4 } {if ($5 == "") {$5 = var5;}} { $8 = var8 } { $14 = var14 } { $15 = var15 } { print $0 }')" )

  done < <( lsblk -nbr -o PATH,KNAME,PKNAME,FSTYPE,TRAN,MODEL,SERIAL,SIZE,TYPE,ROTA,UUID,RM,LABEL | sed 's/ /:/g' | sed 's/$/:/' | sed 's/$/:0/' | sed '/^$/d' 2> /dev/null )
}

# Working output Storage Array List
function stor_LIST() {
  unset storLIST
  for i in "${allSTORAGE[@]}"; do
    storLIST+=( $(echo $i) )
  done
}

# ZFS file system name validate
function input_zfs_name_val(){
  INPUT_NAME_VAR="$1" # Sets the validation input type: input_zfs_name_val POOL. Types: 'POOL' for ZPool name or 'ZFS_NAME' for ZFS File System name.
  INPUT_NAME_VAR=${INPUT_NAME_VAR^^}
  # Set msg_box text output variable
  if [ ${INPUT_NAME_VAR} == POOL ]; then
    msg_box "#### PLEASE READ CAREFULLY - SET A ZPOOL NAME ####\n\nWe could not detect a preset name for the new ZPool. A recommended ZPool name would be 'tank' ( use 'usbtank' for USB connected disks ). You can input any name so long as it meets some basic Linux ZFS component constraints."
  elif [ ${INPUT_NAME_VAR} == ZFS_NAME ]; then
    msg_box "#### PLEASE READ CAREFULLY - SET A ZFS FILE SYSTEM NAME ####\n\nWe could not detect a preset name for the new ZFS File System: /ZPool/?. A recommended ZFS file system name for a PVE CT NAS server would be the NAS hostname ( i.e /Zpool/'nas-01' or /ZPool/'nas-02'). You can input any name so long as it meets some basic Linux ZFS component constraints.$(zfs list -r -H | awk '{ print $1 }' | grep -v "^rpool.*" | grep '.*/.*' | awk '{print "\n\n\tExisting ZFS Storage Systems\n\t--  "$0 }'; echo)"
  fi
  # Set new name
  while true
  do
    read -p "Enter a ZFS component name : " NAME
    NAME=${NAME,,} # Force to lowercase
    if [[ ${NAME} = [Rr][Pp][Oo][Oo][Ll] ]]; then
      warn "The name '${NAME}' is your default root ZFS Storage Pool.\nYou cannot use this. Try again..."
      echo
    elif [ $(zpool list | grep -w "^${NAME}$" >/dev/null; echo $?) == 0 ]; then
      warn "The name '${NAME}' is an existing ZPool.\nYou cannot use this name. Try again..."
      echo
    elif [ $(zfs list | grep -w ".*/${NAME}.*" >/dev/null; echo $?) == 0 ]; then
      if [ ${INPUT_NAME_VAR} == POOL ]; then
        info "The name '${NAME}' is an existing ZFS file system.\nYou cannot use this name. Try again..."
        echo
      elif [ ${INPUT_NAME_VAR} == ZFS_NAME ]; then
        while true; do
          info "The name '${NAME}' is an existing ZFS file system dataset..."
          read -p "Are you sure you want to use '${NAME}' datasets: [y/n]?" -n 1 -r YN
          echo
          case $YN in
            [Yy]*)
              ZFS_NAME=$NAME
              info "ZFS Storage System name is set : ${YELLOW}${NAME}${NC}"
              echo
              break 2
              ;;
            [Nn]*)
              echo
              msg "You have chosen not to proceed with '${NAME}'.\nTry again..."
              sleep 2
              echo
              break
              ;;
            *)
              warn "Error! Entry must be 'y' or 'n'. Try again..."
              echo
              ;;
          esac
        done
      fi
    elif [[ ! $NAME =~ ^([a-z]{1})([^%])([_]?[-]?[:]?[.]?[a-z0-9]){1,14}$ ]] || [[ $(echo $NAME | egrep '^c[0-9]$|^log$|^spare$|^root$|^rpool$|^mirror$|^raidz[0-9]?') ]]; then
      msg "The ZFS component name is not valid. A valid name is when all of the following constraints are satisfied:
        --  it contains only lowercase characters
        --  it begins with at least 1 alphabet character
        --  it contains at least 2 characters and at most is 10 characters long
        --  it may include numerics, underscore (_), hyphen (-), colon (:), period but not start or end with them
        --  it doesn't contain any other special characters [!#$&%*+]
        --  it doesn't contain any white space
        --  beginning sequence 'c[0-9]' is not allowed
        --  a name that begins with root, rpool, log, mirror, raid, raidz, raidz(0-9) or spare is not allowed because these names are reserved.

      Try again..."
      echo
    elif [[ $NAME =~ ^([a-z]{1})([^%])([_]?[-]?[:]?[.]?[a-z0-9]){1,14}$ ]] && [[ $(echo $NAME | egrep -v '^c[0-9]$|^log$|^spare$|^root$|^rpool$|^mirror$|^raidz[0-9]?') ]]; then
      if [ ${INPUT_NAME_VAR} == POOL ]; then
        POOL=$NAME
        info "ZPool name is set : ${YELLOW}${NAME}${NC}"
        echo
      elif [ ${INPUT_NAME_VAR} == ZFS_NAME ]; then
        ZFS_NAME=$NAME
        info "ZFS Storage System name is set : ${YELLOW}${NAME}${NC}"
        echo
      fi
      break
    fi
  done
}

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------

# USB Disk Storage minimum size (GB)
STOR_MIN='30'

# ZFS ashift
ASHIFT_HD='12' # Generally for rotational disks of 4k sectors
ASHIFT_SSD='13' # More modern SSD with 8K sectors

# ZFS compression
ZFS_COMPRESSION='lz4'

#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites
# Create storage list array
storage_list

# Create a working list array
stor_LIST

# Check if any available SATA, NVme disks available
if [ $(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} '{size=0.0+$8; if (($5 == "sata" || $5 == "ata" || $5 == "scsi" || $5 == "nvme") && $15 == 0 && ($9 == "disk" && size >= STOR_MIN || $9 == "part")) { print $0 } }' | wc -l) == 0 ]; then
  msg "We could NOT detect any available SATA disks. New disk(s) might have been wrongly identified as 'system drives' if they contain Linux system or OS partitions. To fix this issue, manually format the disk erasing all data before running this installation again.
  Exiting the installation script. Bye..."
  echo
  exit 0
fi


#---- Select a ZFS build option
section "Select a ZFS build option"
# 1=PATH:2=KNAME:3=PKNAME:4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM
while true; do
msg_box "#### PLEASE READ CAREFULLY - USER OPTIONS FOR ZFS STORAGE ####\n
The User must select an existing ZFS Storage Pool ( ZPool ) or create a new ZPool using any of the build options listed below. If an option to create a new ZPool from recently installed disks is missing its because the new disks have been wrongly identified as 'system disks' because they contain Linux system partitions. To fix this issue, exit this installation and manually format the disk erasing all data and partitions before running this installation again.

$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} 'BEGIN{OFS=FS} $8 ~ /G$/ \
{if (($5 == "sata" || $5 == "ata" || $5 == "scsi" || $5 == "nvme") && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $14!=/[0-9]+/ && $15 == 0) print "Use Existing ZPool", "-", $8, $14,  "TYPE01" } \
{if (($5 == "sata" || $5 == "ata" || $5 == "scsi" || $5 == "nvme") && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $14!=/[0-9]+/ && $15 == 0) print "Destroy & Wipe ZPool", "-", $8, $14, "TYPE02" } \
{size=0.0+$8; if (($5 == "sata" || $5 == "ata" || $5 == "scsi" || $5 == "nvme") && $3 == 0 && $4 != "zfs_member" && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $14 == 0 && $15 == 0) { ssd_count++; ssd_sum+=$8 }} END { if (ssd_count >= 1) print "Create new ZPool - SSD", ssd_count"x SSD disks", ssd_sum"G (max.)", "-", "TYPE03" } \
{size=0.0+$8; if (($5 == "sata" || $5 == "ata" || $5 == "scsi" || $5 == "nvme") && $3 == 0 && $4 != "zfs_member" && $9 == "disk" && size >= STOR_MIN && $10 == 1 && $14 == 0 && $15 == 0) { hdd_count++; hdd_sum+=$8 }} END { if (hdd_count >= 1) print "Create new ZPool - HDD", hdd_count"x HDD disks", hdd_sum"G (max.)", "-", "TYPE04" }' \
| column -s : -t -N "BUILD OPTIONS,DESCRIPTION,STORAGE SIZE,ZFS POOL,SELECTION" -H "SELECTION" | indent2)

Note: Storage size shown for 'Create new ZPool' is combined total of all available disks ( equiv. to striped ). Final storage size with be determined by the Raid level selected by the User.

Option A - Use Existing ZPool
The User can use a existing 'ZPool' to store a new ZFS File System without affecting any existing 'ZPool' datasets.

Option B - Destroy & Wipe ZPool
The User can select a 'ZPool' and destroy and wipe all 'ZPool' member disks. The User can then recreate a ZPool. This will result in 100% loss of all 'ZPool' dataset data.

Option C - Create a new ZPool
The installer has identified free disks available for creating a new ZFS Storage Pool. ZFS cannot combine SSD and HDD (rotational) disks in the same ZFS pool. All data on the selected new member disks will be permanently destroyed."
echo

# Make selection
OPTIONS_VALUES_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} 'BEGIN{OFS=FS} $8 ~ /G$/ \
{if (($5 == "sata" || $5 == "ata" || $5 == "scsi" || $5 == "nvme") && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $14!=/[0-9]+/ && $15 == 0) print "TYPE01", $14 } \
{if (($5 == "sata" || $5 == "ata" || $5 == "scsi" || $5 == "nvme") && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $14!=/[0-9]+/ && $15 == 0) print "TYPE02", $14 } \
{size=0.0+$8; if (($5 == "sata" || $5 == "ata" || $5 == "scsi" || $5 == "nvme") && $3 == 0 && $4 != "zfs_member" && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $14 == 0 && $15 == 0) { ssd_count++; ssd_sum+=$8 }} END { if (ssd_count >= 1) print "TYPE03", "0" } \
{size=0.0+$8; if (($5 == "sata" || $5 == "ata" || $5 == "scsi" || $5 == "nvme") && $3 == 0 && $4 != "zfs_member" && $9 == "disk" && size >= STOR_MIN && $10 == 1 && $14 == 0 && $15 == 0) { hdd_count++; hdd_sum+=$8 }} END { if (hdd_count >= 1) print "TYPE03", "1" }' \
| sed -e '$a\TYPE04:0')
OPTIONS_LABELS_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} 'BEGIN{OFS=FS} $8 ~ /G$/ \
{if (($5 == "sata" || $5 == "ata" || $5 == "scsi" || $5 == "nvme") && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $14!=/[0-9]+/ && $15 == 0) print "Use Existing ZPool - "$14"", $8, "-" } \
{if (($5 == "sata" || $5 == "ata" || $5 == "scsi" || $5 == "nvme") && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $14!=/[0-9]+/ && $15 == 0) print "Destroy & Wipe ZPool - "$14"", $8, "-" } \
{size=0.0+$8; if (($5 == "sata" || $5 == "ata" || $5 == "scsi" || $5 == "nvme") && $3 == 0 && $4 != "zfs_member" && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $14 == 0 && $15 == 0) { ssd_count++; ssd_sum+=$8 }} END { if (ssd_count >= 1) print "Create new ZPool - SSD", ssd_sum"G (max.)", ssd_count"x SSD disks" } \
{size=0.0+$8; if (($5 == "sata" || $5 == "ata" || $5 == "scsi" || $5 == "nvme") && $3 == 0 && $4 != "zfs_member" && $9 == "disk" && size >= STOR_MIN && $10 == 1 && $14 == 0 && $15 == 0) { hdd_count++; hdd_sum+=$8 }} END { if (hdd_count >= 1) print "Create new ZPool - HDD", hdd_sum"G (max.)", hdd_count"x HDD disks"}' \
| sed -e '$a\None - Exit this installer::' \
| column -t -s :)
makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
singleselect SELECTED "$OPTIONS_STRING"
# Set ZPOOL_BUILD
ZPOOL_BUILD=$(echo ${RESULTS} | awk -F':' '{ print $1 }')
ZPOOL_BUILD_VAR=$(echo ${RESULTS} | awk -F':' '{ print $2 }')


if [ ${ZPOOL_BUILD} == TYPE02 ]; then
  # Destroy & Wipe ZPool
  msg_box "#### PLEASE READ CAREFULLY - DESTROY & WIPE ZPOOL ####\n\nYou have chosen to destroy & wipe ZFS Storage Pool '${ZPOOL_BUILD_VAR}' on PVE $(echo $(hostname)). This action will result in permanent data loss of all data stored in ZPool '${ZPOOL_BUILD_VAR}'.\n\n$(printf "\tZPool and Datasets selected for destruction")\n$(zfs list | grep "^${ZPOOL_BUILD_VAR}.*" | awk '{ print "\t--  "$1 }')\n\nThe wiped disks will then be available for the creation of a new ZPool."
  echo
  while true; do
    read -p "Are you sure you want to destroy ZPool '${ZPOOL_BUILD_VAR}' and its datasets: [y/n]?" -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        msg "Destroying ZPool '${ZPOOL_BUILD_VAR}'..."
        # while read -r var; do
        #   zfs unmount $var &> /dev/null
        # done < <( zfs list -r ${POOL} | awk '{ print $1 }' | sed '1d' | sort -r -n )
        zpool destroy -f ${ZPOOL_BUILD_VAR} &> /dev/null
        zpool labelclear -f $(printf '%s\n' "${storLIST[@]}" | awk -F':' -v pool=${ZPOOL_BUILD_VAR} '{if ($14 == pool) { print $1 } }') &> /dev/null
        info "ZPool '${ZPOOL_BUILD_VAR}' status: ${YELLOW}destroyed${NC}"
        storage_list # Update storage list array
        stor_LIST # Create a working list array
        echo
        break
        ;;
      [Nn]*)
        echo
        msg "You have chosen not to proceed with destroying ZFS Storage Pool '${ZPOOL_BUILD_VAR}'.\nTry again..."
        sleep 2
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
elif [ ${ZPOOL_BUILD} == TYPE04 ]; then
  # Exit installer
  msg "You have chosen not to proceed. Aborting. Bye..."
  echo
  exit 0
else
  # Proceed with build option
  break
fi
done


#---- Create new ZPOOL (SSD and HDD)
if [ ${ZPOOL_BUILD} == TYPE03 ]; then
  section "Create new ZPool"
  # 1=PATH:2=KNAME:3=PKNAME:4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM

  # Set Pool name
  input_zfs_name_val POOL

  # Disk count by type
  disk_CNT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN="${STOR_MIN}" -v var="${ZPOOL_BUILD_VAR}" 'BEGIN{OFS=FS} $8 ~ /G$/ \
  {size=0.0+$8; if (($5 == "sata" || $5 == "ata" || $5 == "scsi" || $5 == "nvme") && $3 == 0 && $4 != "zfs_member" && $9 == "disk" && size >= STOR_MIN && $10=var && $14 == 0 && $15 == 0) { print $0 }}' | wc -l)

  # Select member disks
  msg_box "#### PLEASE READ CAREFULLY - SELECT ZFS POOL DISKS ####\n\nThe User has ${disk_CNT}x disk(s) available for a new ZPool. When selecting your disks remember ZFS RaidZ will format all disks to the size of the smallest member disk. So its best to select disks of near identical storage sizes. $(if [ ${ZPOOL_BUILD_VAR} == 0 ]; then echo "\nDo NOT select any SSD disks which you intend to use for ZFS Zil or L2ARC cache."; fi)"
  echo

  # Make disk selection
  msg "The User must now select all member disks to create ZFS pool '${POOL}'."
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v var=${ZPOOL_BUILD_VAR} 'BEGIN{OFS=FS} $8 ~ /G$/ \
  {size=0.0+$8; if (($5 == "sata" || $5 == "ata" || $5 == "scsi" || $5 == "nvme") && $3 == 0 && $4 != "zfs_member" && $9 == "disk" && size >= STOR_MIN && $10=var && $14 == 0 && $15 == 0) { print $0 } }')
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v var=${ZPOOL_BUILD_VAR} 'BEGIN{OFS=FS} $8 ~ /G$/ \
  {size=0.0+$8; if (($5 == "sata" || $5 == "ata" || $5 == "scsi" || $5 == "nvme") && $3 == 0 && $4 != "zfs_member" && $9 == "disk" && size >= STOR_MIN && $10=var && $14 == 0 && $15 == 0)  { sub(/1/,"HDD",$10);sub(/0/,"SSD",$10); print $1, $6, $8, $10 } }' \
  | column -t -s :)
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  multiselect_confirm SELECTED "$OPTIONS_STRING"
  # Create input disk list array
  unset inputdiskLIST
  for i in "${RESULTS[@]}"; do
    inputdiskLIST+=( $(echo $i) )
  done

  #---- Select ZFS Raid level
  section "Select a ZFS Raid level for ZPool '${POOL}'"

  unset raidoptionLIST
  raidoptionLIST+=( "raid0:1:Also called 'striping'. Fast but no redundancy." \
  "raid1:2:Also called 'mirroring'. The resulting capacity is that of a single disk." \
  "raid10:4:A combination of RAID0 and RAID1. Minimum 4 disks (even unit number only)." \
  "raidZ1:3:A variation on RAID-5, single parity. Minimum 3 disks." \
  "raidZ2:4:A variation on RAID-5, double parity. Minimum 4 disks." \
  "raidZ3:5:A variation on RAID-5, triple parity. Minimum 5 disks." )

  # Select RaidZ level
  msg "The User must now select a ZFS RaidZ level based on your $(echo "${#inputdiskLIST[@]}")x disk selection..."
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${raidoptionLIST[@]}" | awk -F':' -v INPUT_CNT=$(echo "${#inputdiskLIST[@]}") 'BEGIN{OFS=FS} \
  {if ($2 <= INPUT_CNT) { print $1} }')
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${raidoptionLIST[@]}" | awk -F':' -v INPUT_CNT=$(echo "${#inputdiskLIST[@]}") 'BEGIN{OFS=FS} \
  {if ($2 <= INPUT_CNT) { print toupper($1) " | " $3} }')
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect_confirm SELECTED "$OPTIONS_STRING"
  # Selected RaidZ level
  inputRAIDLEVEL=${RESULTS}

  #---- Create new ZPool
  section "Create new ZFS Pool '${POOL^}'"
    
  # Erase / Wipe ZFS pool disks
  msg "Zapping, Erasing and Wiping ZFS pool disks..."
  while read dev; do
    sgdisk --zap $dev >/dev/null 2>&1
    info "SGDISK - zapped (destroyed) the GPT data structures on device: $dev"
    dd if=/dev/zero of=$dev count=1 bs=512 conv=notrunc 2>/dev/null
    info "DD - cleaned & wiped device: $dev"
    wipefs --all --force $dev  >/dev/null 2>&1
    info "wipefs - wiped device: $dev"
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $1 }' ) # file listing of disks to erase
  echo

  # Set ZFS ashift
  if [ ${ZPOOL_BUILD_VAR} == 0 ]; then
    ASHIFT=${ASHIFT_SSD}
  elif [ ${ZPOOL_BUILD_VAR} == 1 ]; then
    ASHIFT=${ASHIFT_HD}
  fi

  # Determine disk cnt parity ( prune smallest disk if odd cnt for Raid10 )
  if [ ! $((number%${#inputdiskLIST[@]})) == 0 ] && [ ${inputRAIDLEVEL} == "raid10" ]; then
    # Set smallest member disk for removal for Raid10 build
    inputdiskLISTPARITY=1
    deleteDISK=( $(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' 'NR == 1 {line = $0; min = $8} \
    NR > 1 && $3 < min {line = $0; min = $8} \
    END{print line}') )
    for target in "${deleteDISK[@]}"; do
      for i in "${!inputdiskLIST[@]}"; do
        if [[ ${inputdiskLIST[i]} = $target ]]; then
          unset 'inputdiskLIST[i]'
        fi
      done
    done
  else
    inputdiskLISTPARITY=0
  fi

  # Create ZFS Pool Tank
  msg "Creating Zpool '${POOL}'..."
  if [ ${inputRAIDLEVEL} == "raid0" ]; then
    info "ZPool '${POOL}' status: ${YELLOW}${inputRAIDLEVEL^^}${NC} - $(echo "${#inputdiskLIST[@]}")x member disks"
    echo
    zpool create -f -o ashift=${ASHIFT} ${POOL} $(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $5 "-" $6 "_" $7 }' ORS=' ' 2>/dev/null | sed 's/ *$//')
  elif [ ${inputRAIDLEVEL} == "raid1" ]; then
    info "ZPool '${POOL}' status: ${YELLOW}${inputRAIDLEVEL^^}${NC} - $(echo "${#inputdiskLIST[@]}")x member disks"
    echo
    zpool create -f -o ashift=${ASHIFT} ${POOL} $(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $5 "-" $6 "_" $7 }' ORS=' ' 2>/dev/null | sed 's/ *$//' | sed 's/^/mirror /')   
  elif [ ${inputRAIDLEVEL} == "raid10" ]; then
    info "ZPool '${POOL}' status: ${YELLOW}${inputRAIDLEVEL^^}${NC} - $(echo "${#inputdiskLIST[@]}")x member disks"
    if [ ${inputdiskLISTPARITY} == 1 ]; then
      msg "( Disk '$(printf '%s\n' "${deleteDISK[@]}" | awk -F':' '{ print $5 "-" $6 "_" $7 }')' was NOT INCLUDED in ZPool '${POOL}'. Raid 10 requires a even number of member disks so it was removed. You can manually configure this disk as a hot spare. )"
    fi
    echo
    zpool create -f -o ashift=${ASHIFT} ${POOL} $(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $5 "-" $6 "_" $7 }' ORS=' ' 2>/dev/null | sed 's/ *$//' | sed '-es/ / mirror /'{1000..1..2} | sed 's/^/mirror /')   
  elif [ ${inputRAIDLEVEL} == "raidz1" ]; then
    msg "Creating ZPool '${POOL}': ${YELLOW}${inputRAIDLEVEL^^}${NC} - $(echo "${#inputdiskLIST[@]}")x member disks"
    echo
    zpool create -f -o ashift=${ASHIFT} ${POOL} raidz1 $(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $5 "-" $6 "_" $7 }' ORS=' ' 2>/dev/null | sed 's/ *$//')
  elif [ ${inputRAIDLEVEL} == "raidz2" ]; then
    msg "Creating ZPool '${POOL}': ${YELLOW}${inputRAIDLEVEL^^}${NC} - $(echo "${#inputdiskLIST[@]}")x member disks"
    echo
    zpool create -f -o ashift=${ASHIFT} ${POOL} raidz2 $(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $5 "-" $6 "_" $7 }' ORS=' ' 2>/dev/null | sed 's/ *$//')
  elif [ ${inputRAIDLEVEL} == "raidz3" ]; then
    msg "Creating ZPool '${POOL}': ${YELLOW}${inputRAIDLEVEL^^}${NC} - $(echo "${#inputdiskLIST[@]}")x member disks"
    echo
    zpool create -f -o ashift=${ASHIFT} ${POOL} raidz3 $(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $5 "-" $6 "_" $7 }' ORS=' ' 2>/dev/null | sed 's/ *$//')
  fi
fi # End of Create new ZPOOL ( TYPE02 action )


#---- Create PVE ZFS File System
if [ ${ZPOOL_BUILD} == TYPE01 ] || [ ${ZPOOL_BUILD} == TYPE03 ]; then
  section "Create ZFS file system"

  # Set ZPOOL if TYPE01
  if [ ${ZPOOL_BUILD} == TYPE01 ]; then
    POOL=${ZPOOL_BUILD_VAR}
  fi

  # Check if ZFS file system name is set
  if [ -z ${HOSTNAME+x} ]; then
    input_zfs_name_val ZFS_NAME
  else
    ZFS_NAME=${HOSTNAME,,} 
  fi

  # Create PVE ZFS 
  if [ ! -d "/${POOL}/${ZFS_NAME}" ]; then  
    msg "Creating ZFS file system ${POOL}/${ZFS_NAME}..."
    zfs create -o compression=${ZFS_COMPRESSION} ${POOL}/${ZFS_NAME} >/dev/null
    zfs set acltype=posixacl aclinherit=passthrough xattr=sa ${POOL}/${ZFS_NAME} >/dev/null
    zfs set xattr=sa dnodesize=auto ${POOL} >/dev/null
    info "ZFS file system settings:\n    --  Compresssion: ${YELLOW}${ZFS_COMPRESSION}${NC}\n    --  Posix ACL type: ${YELLOW}posixacl${NC}\n    --  ACL inheritance: ${YELLOW}passthrough${NC}\n    --  LXC with ACL on ZFS: ${YELLOW}auto${NC}"
    echo
  elif [ -d "/${POOL}/${ZFS_NAME}" ]; then
    msg "Modifying existing ZFS file system settings /${POOL}/${ZFS_NAME}..."
    zfs set compression=${ZFS_COMPRESSION} ${POOL}/${ZFS_NAME}
    zfs set acltype=posixacl aclinherit=passthrough xattr=sa ${POOL}/${ZFS_NAME} >/dev/null
    zfs set xattr=sa dnodesize=auto ${POOL} >/dev/null
    info "Changes to existing ZFS file system settings ( ${POOL}/${ZFS_NAME} ):\n  --  Compresssion: ${YELLOW}${ZFS_COMPRESSION}${NC}\n  --  Posix ACL type: ${YELLOW}posixacl${NC}\n  --  ACL inheritance: ${YELLOW}passthrough${NC}\n  --  LXC with ACL on ZFS: ${YELLOW}auto${NC}\nCompression will only be performed on new stored data."
    echo
  fi
fi