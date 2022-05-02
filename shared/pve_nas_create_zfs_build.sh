#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_create_zfs_build.sh
# Description:  Source script for building zfs disk storage
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Requires arg 'usb' or 'onboard' to be set in source command
# Sets the validation input type: input_lvm_vgname_val usb
if [ -z "$1" ]; then
  INPUT_TRAN=""
  INPUT_TRAN_ARG=""
elif [[ "$1" =~ 'usb' ]]; then
  INPUT_TRAN='(usb)'
  INPUT_TRAN_ARG='usb'
elif [[ "$1" =~ 'onboard' ]]; then
  INPUT_TRAN='(sata|ata|scsi|nvme)'
  INPUT_TRAN_ARG='onboard'
fi

#---- Static Variables -------------------------------------------------------------

# Basic storage disk label
BASIC_DISKLABEL='(.*_hba|.*_usb|.*_onboard)$'

#---- Other Variables --------------------------------------------------------------

# USB Disk Storage minimum size (GB)
STOR_MIN='30'

# Set SRC mount point
PVE_SRC_MNT="/${POOL}/${ZFS_NAME}"

#---- ZFS variables
# ZFS ashift
ASHIFT_HD='12' # Generally for rotational disks of 4k sectors
ASHIFT_SSD='13' # More modern SSD with 8K sectors

# ZFS compression
ZFS_COMPRESSION='lz4'

#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Wake USB disk
function wake_usb() {
  while IFS= read -r line; do
    dd if=${line} of=/dev/null count=512 status=none
  done < <( lsblk -nbr -o PATH,TRAN | awk '{if ($2 == "usb") print $1 }' )
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

#---- Body -------------------------------------------------------------------------

#---- Select a ZFS build option
section "Select a ZFS build option"
# 1=PATH:2=KNAME:3=PKNAME:4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM
while true; do
msg_box "#### PLEASE READ CAREFULLY - USER OPTIONS FOR ZFS STORAGE ####\n
The User must select from the available ZFS build options.

$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} \
'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
{if ($5 ~ INPUT_TRAN && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $13 !~ BASIC_DISKLABEL && $14!=/[0-9]+/ && $15 == 0) print "Use Existing ZPool", "-", $8, $14,  "TYPE01" } \
{if ($5 ~ INPUT_TRAN && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $13 !~ BASIC_DISKLABEL && $14!=/[0-9]+/ && $15 == 0) print "Destroy & Wipe ZPool", "-", $8, $14, "TYPE02" } \
{if ($5 ~ INPUT_TRAN && $3 == 0 && $4 != "zfs_member" && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { ssd_count++ }} END { if (ssd_count >= 1) print "Create new ZPool - SSD", ssd_count"x SSD disks", "-", "-", "TYPE03" } \
{if ($5 ~ INPUT_TRAN && $3 == 0 && $4 != "zfs_member" && $9 == "disk" && size >= STOR_MIN && $10 == 1 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { hdd_count++ }} END { if (hdd_count >= 1) print "Create new ZPool - HDD", hdd_count"x HDD disks", "-", "-", "TYPE04" }' \
| column -s : -t -N "BUILD OPTIONS,DESCRIPTION,STORAGE SIZE,ZFS POOL,SELECTION" -H "SELECTION" | indent2)

Option A - Use Existing ZPool
Select an existing 'ZPool' to store a new ZFS File System without affecting existing 'ZPool' datasets.

Option B - Destroy & Wipe ZPool
Select and destroy a 'ZPool' and all data stored on all the 'ZPool' member disks. The User can then recreate a ZPool. This will result in 100% loss of all 'ZPool' dataset data.

Option C - Create a new ZPool
The installer has identified free disks available for creating a new ZFS Storage Pool. All data on the selected new member disks will be permanently destroyed."
echo


# Make selection
OPTIONS_VALUES_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} \
'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
# Type01: Use Existing ZPool
{if ($5 ~ INPUT_TRAN && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $13 !~ BASIC_DISKLABEL && $14!=/[0-9]+/ && $15 == 0) print "TYPE01", $14 } \
# Type02: Destroy & Wipe ZPool
{if ($5 ~ INPUT_TRAN && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $13 !~ BASIC_DISKLABEL && $14!=/[0-9]+/ && $15 == 0) print "TYPE02", $14 } \
# Type03: Create new ZPool - SSD
{if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { ssd_count++ }} END { if (ssd_count >= 1) print "TYPE03", "0" } \
# Type04: Create new ZPool - HDD
{if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 1 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { hdd_count++ }} END { if (hdd_count >= 1) print "TYPE03", "1" }' \
| sed -e '$a\TYPE00:0')
OPTIONS_LABELS_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} \
'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
# Type01: Use Existing ZPool
{if ($5 ~ INPUT_TRAN && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $13 !~ BASIC_DISKLABEL && $14!=/[0-9]+/ && $15 == 0) print "Use Existing ZPool - "$14"", $8, "-" } \
# Type02: Destroy & Wipe ZPool
{if ($5 ~ INPUT_TRAN && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $13 !~ BASIC_DISKLABEL && $14!=/[0-9]+/ && $15 == 0) print "Destroy & Wipe ZPool - "$14"", $8, "-" } \
# Type03: Create new ZPool - SSD
{if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { ssd_count++ }} END { if (ssd_count >= 1) print "Create new ZPool - SSD", "-", ssd_count"x SSD disks available" } \
# Type04: Create new ZPool - HDD
{if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 1 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { hdd_count++ }} END { if (hdd_count >= 1) print "Create new ZPool - HDD", "-", hdd_count"x HDD disks available"}' \
| sed -e '$a\None - Exit this installer::' \
| column -t -s :)
makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
singleselect SELECTED "$OPTIONS_STRING"
# Set ZPOOL_BUILD
ZPOOL_BUILD=$(echo ${RESULTS} | awk -F':' '{ print $1 }')
ZPOOL_BUILD_VAR=$(echo ${RESULTS} | awk -F':' '{ print $2 }')

#---- Destroy & Wipe ZPool
if [ ${ZPOOL_BUILD} == 'TYPE02' ]; then
  msg_box "#### PLEASE READ CAREFULLY - DESTROY & WIPE ZPOOL ####\n\nYou have chosen to destroy & wipe ZFS Storage Pool named '${ZPOOL_BUILD_VAR}' on PVE $(echo $(hostname)). This action will result in permanent data loss of all data stored in ZPool '${ZPOOL_BUILD_VAR}'.\n\n$(printf "\tZPool and Datasets selected for destruction")\n$(zfs list | grep "^${ZPOOL_BUILD_VAR}.*" | awk '{ print "\t--  "$1 }')\n\nThe wiped disks will then be available for the creation of a new ZPool."
  echo
  while true; do
    read -p "Are you sure you want to destroy ZPool '${ZPOOL_BUILD_VAR}' and its datasets: [y/n]?" -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        # ZPool DISK UUID member list
        wipediskLIST=( "$(zpool list -v -H ${ZPOOL_BUILD_VAR} | sed '1d' | awk -F'\t' '{ print $2 }')" )

        msg "Destroying ZPool '${ZPOOL_BUILD_VAR}'..."
        # ZPool umount
        while read -r var; do
          zfs -f unmount ${var} &> /dev/null
        done < <( zfs list -r ${POOL} | awk '{ print $1 }' | sed '1d' | sort -r -n )
        # ZPool delete
        zpool destroy -f ${ZPOOL_BUILD_VAR} &> /dev/null
        zpool labelclear -f $(printf '%s\n' "${storLIST[@]}" | awk -F':' -v pool=${ZPOOL_BUILD_VAR} '{if ($14 == pool) { print $1 } }') &> /dev/null
        info "ZPool '${ZPOOL_BUILD_VAR}' status: ${YELLOW}destroyed${NC}"

        # Destroy and wipe disks
        msg "Zapping, Erasing and Wiping disks..."
        while read dev; do
          sgdisk --zap /dev/disk/by-id/${dev} >/dev/null 2>&1
          dd if=/dev/zero of=/dev/disk/by-id/${dev} count=1 bs=512 conv=notrunc 2>/dev/null
          wipefs --all --force /dev/disk/by-id/${dev} >/dev/null 2>&1
          info "Destroyed and wiped disk:\n       /dev/disk/by-id/${dev}"
        done < <( printf '%s\n' "${wipediskLIST[@]}" ) # file listing of disks to erase

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
elif [ ${ZPOOL_BUILD} == 'TYPE00' ]; then
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
if [ ${ZPOOL_BUILD} == 'TYPE03' ]; then
  section "Create new ZPool"
  # 1=PATH:2=KNAME:3=PKNAME:4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM

  # Set Pool name
  input_zfs_name_val POOL

  # Disk count by type
  disk_CNT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v var=${ZPOOL_BUILD_VAR} -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} \
  'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  {if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == var && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { print $0 }}' | wc -l)

  # Select member disks
  if [ "${INPUT_TRAN_ARG}" == 'usb' ]; then
    # USB build
    msg_box "#### PLEASE READ CAREFULLY - SELECT A ZFS POOL DISK ####\n\nThe User has ${disk_CNT}x disk(s) available for a new ZPool. The User can only select one disk. USB NAS builds only support one disk."
    echo
  else
    # Onboard build
    msg_box "#### PLEASE READ CAREFULLY - SELECT ZFS POOL DISKS ####\n\nThe User has ${disk_CNT}x disk(s) available for a new ZPool. When selecting your disks remember ZFS RaidZ will format all disks to the size of the smallest member disk. So its best to select disks of near identical storage sizes. $(if [ ${ZPOOL_BUILD_VAR} == 0 ]; then echo "\nDo NOT select any SSD disks which you intend to use for ZFS Zil or L2ARC cache."; fi)"
    echo
  fi

  #---- Make member disk selection
  msg "The User must now select member disks to create ZFS pool '${POOL}'."
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v var=${ZPOOL_BUILD_VAR} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} \
  'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  {if ($5 ~ INPUT_TRAN && $3 == 0 && $4 != "zfs_member" && $9 == "disk" && size >= STOR_MIN && $10 == var && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { print $0 } }')
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v var=${ZPOOL_BUILD_VAR} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} \
  'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  {if ($5 ~ INPUT_TRAN && $3 == 0 && $4 != "zfs_member" && $9 == "disk" && size >= STOR_MIN && $10 == var && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0)  { sub(/1/,"HDD",$10);sub(/0/,"SSD",$10); print $1, $6, $8, $10 } }' \
  | column -t -s :)
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  if [ "${INPUT_TRAN_ARG}" == 'usb' ]; then
    singleselect_confirm SELECTED "$OPTIONS_STRING"
  else
    multiselect_confirm SELECTED "$OPTIONS_STRING"
  fi
  # Create input disk list array
  unset inputdiskLIST
  for i in "${RESULTS[@]}"; do
    inputdiskLIST+=( $(echo $i) )
  done

  #---- Select ZFS Raid level
  if [ "${INPUT_TRAN_ARG}" == 'usb' ]; then
    # Set Raid level
    inputRAIDLEVEL='raid0'
  else
    # Set Raid level
    section "Select a ZFS Raid level for ZPool '${POOL}'"

    unset raidoptionLIST
    raidoptionLIST+=( "raid0:1:Also called 'striping'. Fast but no redundancy." \
    "raid1:2:Also called 'mirroring'. The resulting capacity is that of a single disk." \
    "raid10:4:A combination of RAID0 and RAID1. Minimum 4 disks (even unit number only)." \
    "raidZ1:3:A variation on RAID-5, single parity. Minimum 3 disks." \
    "raidZ2:4:A variation on RAID-5, double parity. Minimum 4 disks." \
    "raidZ3:5:A variation on RAID-5, triple parity. Minimum 5 disks." )

    # Select RaidZ level
    msg "The User must now select a ZFS RaidZ level based on your ${#inputdiskLIST[@]}x disk selection..."
    OPTIONS_VALUES_INPUT=$(printf '%s\n' "${raidoptionLIST[@]}" | awk -F':' -v INPUT_CNT=${#inputdiskLIST[@]} 'BEGIN{OFS=FS} \
    {if ($2 <= INPUT_CNT) { print $1} }')
    OPTIONS_LABELS_INPUT=$(printf '%s\n' "${raidoptionLIST[@]}" | awk -F':' -v INPUT_CNT=${#inputdiskLIST[@]} 'BEGIN{OFS=FS} \
    {if ($2 <= INPUT_CNT) { print toupper($1) " | " $3} }')
    makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
    singleselect_confirm SELECTED "$OPTIONS_STRING"
    # Selected RaidZ level
    inputRAIDLEVEL=${RESULTS}
  fi


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
  if [ ${ZPOOL_BUILD_VAR} == '0' ]; then
    ASHIFT=${ASHIFT_SSD}
  elif [ ${ZPOOL_BUILD_VAR} == '1' ]; then
    ASHIFT=${ASHIFT_HD}
  fi

  # Determine disk cnt parity ( prune smallest disk if odd cnt for Raid10 )
  if [ ! $((number%${#inputdiskLIST[@]})) == '0' ] && [ ${inputRAIDLEVEL} == "raid10" ]; then
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
  if [ "${INPUT_TRAN_ARG}" == 'usb' ]; then
    msg "Creating Zpool '${POOL}'..."
    info "ZPool '${POOL}' status: ${YELLOW}${inputRAIDLEVEL^^}${NC} - ${#inputdiskLIST[@]}x member disk"
    zpool create -f -o ashift=${ASHIFT} ${POOL} $(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $1 }')
    sleep 1
    zpool export $POOL
    zpool import -d /dev/disk/by-id $POOL
    storage_list && stor_LIST # Update storage list array
    echo
  else
    msg "Creating Zpool '${POOL}'..."
    if [ ${inputRAIDLEVEL} == "raid0" ]; then
      # Raid 0
      zfs_ARG=$(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print "/dev/disk/by-id/"$5 "-" $6 "_" $7 }' | xargs)
      zfs_DISPLAY="ZPool '${POOL}' status: ${YELLOW}${inputRAIDLEVEL^^}${NC} - ${#inputdiskLIST[@]}x member disks"
    elif [ ${inputRAIDLEVEL} == "raid1" ]; then
      # Raid 1
      zfs_ARG=$(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print "/dev/disk/by-id/"$5 "-" $6 "_" $7 }' | xargs | sed 's/^/mirror /')  
      zfs_DISPLAY="ZPool '${POOL}' status: ${YELLOW}${inputRAIDLEVEL^^}${NC} - ${#inputdiskLIST[@]}x member disks"
    elif [ ${inputRAIDLEVEL} == "raid10" ]; then
      # Raid 10
      zfs_ARG=$(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print "/dev/disk/by-id/"$5 "-" $6 "_" $7 }' | xargs | sed '-es/ / mirror /'{1000..1..2} | sed 's/^/mirror /')
      zfs_DISPLAY="ZPool '${POOL}' status: ${YELLOW}${inputRAIDLEVEL^^}${NC} - ${#inputdiskLIST[@]}x member disks\n$(if [ ${inputdiskLISTPARITY} = 1 ]; then msg "Disk '$(printf '%s\n' "${deleteDISK[@]}" | awk -F':' '{ print $5 "-" $6 "_" $7 }')' was NOT INCLUDED in ZPool '${POOL}'. Raid 10 requires a even number of member disks so it was removed. You can manually configure this disk as a hot spare."; fi)"
    elif [ ${inputRAIDLEVEL} == "raidz1" ]; then
      # RaidZ1
      zfs_ARG="raidz1 $(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print "/dev/disk/by-id/"$5 "-" $6 "_" $7 }' | xargs)"
      zfs_DISPLAY="Creating ZPool '${POOL}': ${YELLOW}${inputRAIDLEVEL^^}${NC} - ${#inputdiskLIST[@]}x member disks"
    elif [ ${inputRAIDLEVEL} == "raidz2" ]; then
      # RaidZ2
      zfs_ARG="raidz2 $(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print "/dev/disk/by-id/"$5 "-" $6 "_" $7 }' | xargs)"
      zfs_DISPLAY="Creating ZPool '${POOL}': ${YELLOW}${inputRAIDLEVEL^^}${NC} - ${#inputdiskLIST[@]}x member disks"
    elif [ ${inputRAIDLEVEL} == "raidz3" ]; then
      # Raid Z3
      zfs_ARG="raidz3 $(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print "/dev/disk/by-id/"$5 "-" $6 "_" $7 }' | xargs)"
      zfs_DISPLAY="Creating ZPool '${POOL}': ${YELLOW}${inputRAIDLEVEL^^}${NC} - ${#inputdiskLIST[@]}x member disks"
    fi
    # Create ZFS Pool
    zpool create -f -o ashift=${ASHIFT} ${POOL} ${zfs_ARG}
    info "${zfs_DISPLAY}"
    info "ZFS Storage Pool status: ${YELLOW}$(zpool status -x $POOL)${NC}"
    echo
  fi
fi # End of Create new ZPOOL ( TYPE02 action )


#---- Reconnect to ZPool
if [ ${ZPOOL_BUILD} == 'TYPE01' ]; then
  section "Reconnect to existing ZPool"

  # Wake USB disk
  if [ "${INPUT_TRAN_ARG}" == 'usb' ]; then
    wake_usb
  fi

  # Set ZPOOL if TYPE01
  if [ ${ZPOOL_BUILD} == 'TYPE01' ]; then
    POOL=${ZPOOL_BUILD_VAR}
  fi

  # Reconnect to ZPool
  msg "Reconnecting to existing ZFS '$POOL'..."
  zpool export $POOL
  zpool import -d /dev/disk/by-id $POOL
  info "ZFS Storage Pool status: ${YELLOW}$(zpool status -x $POOL)${NC}"
  echo
fi


#---- Create PVE ZFS File System
if [ ${ZPOOL_BUILD} == 'TYPE01' ] || [ ${ZPOOL_BUILD} == 'TYPE03' ]; then
  section "Create ZFS file system"

  # Wake USB disk
  if [ "${INPUT_TRAN_ARG}" == 'usb' ]; then
    wake_usb
  fi

  # Set ZPOOL if TYPE01
  if [ ${ZPOOL_BUILD} == 'TYPE01' ]; then
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

# Update storage list array
storage_list
stor_LIST

# Set SRC mount point
PVE_SRC_MNT="/${POOL}/${ZFS_NAME}"
