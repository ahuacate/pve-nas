#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_create_lvm_build.sh
# Description:  Source script for building lvm disk storage
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

#---- LVM variables
# LVM Thin Pool auto extend values
AUTOEXTEND_THRESHOLD='70'
AUTOEXTEND_PERCENT='20'

# LV Thinpool extents
LV_THINPOOL_EXTENTS='50%'

# VG metadatasize
VG_METADATASIZE='1024M'

# LV Thin Pool name
LV_THIN_POOLNAME='thinpool'

# LV Thin Pool poolmetadatasize
LV_THIN_POOLMETADATASIZE='1024M'

# LV Thin stripesize
LV_THIN_STRIPESIZE='128k'

# LV stripesize
LV_STRIPESIZE='128k'

# LV Thin Pool chunksize
LV_THIN_CHUNKSIZE='128k'

# LV Thin Pool size
LV_THIN_SIZE='200M'

# LV Thin Volume virtualsize
LV_THINVOL_VIRTUALSIZE='200M'

# LV Name ( Use CT/VM hostname )
LV_NAME=$(echo $HOSTNAME | sed 's/-/_/g') # Hostname mod (change any '-' to '_')
if [ $(lvs | grep "^\s*${LV_NAME}" &>/dev/null; echo $?) == '0' ] || [[ $(ls -A /mnt/${LV_NAME}) ]]; then
    i=1
    while [ $(lvs | grep "^\s*${LV_NAME}_${i}" &>/dev/null; echo $?) == '0' ] || [[ $(ls -A /mnt/${LV_NAME}_${i}) ]]; do
      i=$(( $i + 1 ))
    done
    LV_NAME=${LV_NAME}_${i}
fi

# Set SRC mount point
PVE_SRC_MNT="/mnt/${LV_NAME}"

# /etc/fstab mount options
unset fstab_options_LIST
fstab_options_LIST=()
while IFS= read -r line; do
  [[ "$line" =~ ^\#.*$ ]] && continue
  fstab_options_LIST+=( "$line" )
done << EOF
# Example
# Each mount option MUST be on a new line
defaults
rw
user_xattr
acl
EOF

#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# LVM VG name create
function create_lvm_vgname_val(){
  local option=$1
  # Sets the validation input type: input_lvm_vgname_val usb
  if [ -z "$option" ]; then
    vgname_var='_'
  elif [[ ${option,,} =~ 'usb' ]]; then
    vgname_var='_usb_'
  fi
  # Hostname mod (change any '-' to '_')
  hostname_var=$(echo $(hostname -s) | sed 's/-/_/g')
  # Set new name
  VG_NAME="vg${vgname_var}${hostname_var}"
  if [ $(vgs ${VG_NAME} &>/dev/null; echo $?) == '0' ]; then
      i=1
      while [ $(vgs ${VG_NAME}_${i} &>/dev/null; echo $?) == '0' ]; do
        i=$(( $i + 1 ))
      done
      VG_NAME=${VG_NAME}_${i}
  fi
}

# # LVM VG name create
# function create_lvm_vgname_val(){
#   local option=$1
#   # Sets the validation input type: input_lvm_vgname_val usb or input_lvm_vgname_val "${INPUT_TRAN}"
#   if [ -z "$option" ]; then
#     vgname_var='_'
#   elif [[ ${option,,} =~ 'usb' ]]; then
#     vgname_var='_usb_'
#   elif [[ ${option,,} =~ '(usb)' ]]; then
#     vgname_var='_usb_'
#   else
#     vgname_var='_'
#   fi
#   # Hostname mod (change any '-' to '_')
#   hostname_var=$(echo $(hostname -s) | sed 's/-/_/g')
#   # Set new name
#   VG_NAME="vg${vgname_var}${hostname_var}"
#   if [ $(vgs ${VG_NAME} &>/dev/null; echo $?) == '0' ]; then
#       i=1
#       while [ $(vgs ${VG_NAME}_${i} &>/dev/null; echo $?) == '0' ]; do
#         i=$(( $i + 1 ))
#       done
#       VG_NAME=${VG_NAME}_${i}
#   fi
# }

# Wake USB disk
function wake_usb() {
  while IFS= read -r line; do
    dd if=${line} of=/dev/null count=512 status=none
  done < <( lsblk -nbr -o PATH,TRAN | awk '{if ($2 == "usb") print $1 }' )
}

#---- Body -------------------------------------------------------------------------

#---- Create LVM thin pool autoextend profile
lvmconfig --file /etc/lvm/profile/autoextend.profile --withcomments --config "activation/thin_pool_autoextend_threshold=${AUTOEXTEND_THRESHOLD} activation/thin_pool_autoextend_percent=${AUTOEXTEND_PERCENT}"

#---- Select a LVM build option
section "Select a LVM build option"
# 1=PATH:2=KNAME:3=PKNAME:4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM

while true; do
  # Make selection
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} \
  'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  # Type01: Mount an existing LV
  {if($1 !~ /.*(root|tmeta|tdata|tpool|swap)$/ && $5 ~ INPUT_TRAN && $9 == "lvm" && $13 !~ BASIC_DISKLABEL && $15 == 0 && (system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -v 'thin-pool' | grep -q 'thin' > /dev/null") == 0 || system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -v 'thin-pool' | grep -q 'linear' > /dev/null") == 0)) \
  {cmd = "lvs " $1 " --noheadings -o lv_name | grep -v 'thinpool' | uniq | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline lv_name; close(cmd); print "Mount existing LV", "LV name - "lv_name, $8, "TYPE01" }} \
  # Type02: Create LV in an existing Thin-pool
  {if($1 !~ /.*(root|tmeta|tdata|tpool|swap)$/ && $5 ~ INPUT_TRAN && $4 == "" && $9 == "lvm" && $13 !~ BASIC_DISKLABEL && $15 == 0 && system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -q 'thin-pool' > /dev/null") == 0 ) \
  {cmd = "lvs " $1 " --noheadings -o lv_name | uniq | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline thinpool_name; close(cmd); print "Create LV in existing Thin-pool", "Thin-pool name - "thinpool_name, $8, "TYPE02" }} \
  # Type03: Create LV in an existing VG
  {if ($5 ~ INPUT_TRAN && $4 == "LVM2_member" && $13 !~ BASIC_DISKLABEL && $15 == 0) \
  print "Create LV in an existing VG", "VG name - "$14, $8, "TYPE03" } \
  # Type04: Destroy VG
  {if ($5 ~ INPUT_TRAN && $4 == "LVM2_member" && $13 !~ BASIC_DISKLABEL && $15 == 0) { cmd = "lvs " $14 " --noheadings -o lv_name | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline $16; close(cmd); print "Destroy VG ("$14")", "Destroys LVs/Pools - "$16, "-", "TYPE04" }} \
  # Type05: Build a new LVM VG/LV - SSD Disks
  {if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { ssd_count++ }} END { if (ssd_count >= 1) print "Build a new LVM VG/LV - SSD Disks", "Select from "ssd_count"x SSD disks", "-", "TYPE05" } \
  # Type06: Build a new LVM VG/LV - HDD Disks
  {if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 1 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { hdd_count++ }} END { if (hdd_count >= 1) print "Build a new LVM VG/LV - HDD Disks", "Select from "hdd_count"x HDD disks", "-", "TYPE06" }' \
  | sort -t: -s -k 4,4 \
  | sed -e '$a\None. Exit this installer:::TYPE00' \
  | column -t -s ":" -N "LVM OPTIONS,DESCRIPTION,SIZE,TYPE" -H TYPE -T DESCRIPTION -c 150 -d)

  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} \
  'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  # Type01: Mount an existing LV
  {if($1 !~ /.*(root|tmeta|tdata|tpool|swap)$/ && $5 ~ INPUT_TRAN && $9 == "lvm" && $13 !~ BASIC_DISKLABEL && $15 == 0 && (system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -v 'thin-pool' | grep -q 'thin' > /dev/null") == 0 || system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -v 'thin-pool' | grep -q 'linear' > /dev/null") == 0)) \
  {cmd = "lvs " $1 " --noheadings -o lv_name | grep -v 'thinpool' | uniq | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline lv_name; close(cmd); print "TYPE01", lv_name }} \
  # Type02: Create LV in an existing Thin-pool
  {if($1 !~ /.*(root|tmeta|tdata|tpool|swap)$/ && $5 ~ INPUT_TRAN && $4 == "" && $9 == "lvm" && $13 !~ BASIC_DISKLABEL && $15 == 0 && system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -q 'thin-pool' > /dev/null") == 0 ) \
  {cmd = "lvs " $1 " --noheadings -o lv_name | uniq | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline thinpool_name; close(cmd); print "TYPE02", thinpool_name }} \
  # Type03: Create LV in an existing VG
  {if ($5 ~ INPUT_TRAN && $4 == "LVM2_member" && $13 !~ BASIC_DISKLABEL && $15 == 0) \
  print "TYPE03", $14 } \
  # Type04: Destroy VG
  {if ($5 ~ INPUT_TRAN && $4 == "LVM2_member" && $13 !~ BASIC_DISKLABEL && $15 == 0) { cmd = "lvs " $14 " --noheadings -o lv_name | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline $16; close(cmd); print "TYPE04", $14 }} \
  # Type05: Build a new LVM VG/LV - SSD Disks
  {if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { ssd_count++ }} END { if (ssd_count >= 1) print "TYPE05","0" } \
  # Type06: Build a new LVM VG/LV - HDD Disks
  {if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 1 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { hdd_count++ }} END { if (hdd_count >= 1) print "TYPE06","1" }' \
  | sort -t: -s -k 1,1 \
  | sed -e '$a\TYPE00:0')

  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect SELECTED "$OPTIONS_STRING"
  # Set ZPOOL_BUILD
  LVM_BUILD=$(echo ${RESULTS} | awk -F':' '{ print $1 }')
  LVM_BUILD_VAR=$(echo ${RESULTS} | awk -F':' '{ print $2 }')

  #---- Destroy LVM
  if [ ${LVM_BUILD} == 'TYPE04' ]; then
    # Destroy VG
    VG_NAME=${LVM_BUILD_VAR}
    unset pve_disk_LIST
    pve_disk_LIST+=( "$(pvdisplay -S vgname=${VG_NAME} -C -o pv_name --noheadings | sed 's/ //g')" )

    # Print display
    if [ ! $(lvs ${LVM_BUILD_VAR} --noheadings -a -o lv_name | wc -l) == '0' ]; then
      unset print_DISPLAY
      print_DISPLAY+=( "$(printf "\t-- VG to be destroyed: ${LVM_BUILD_VAR}")" )
      print_DISPLAY+=( "$(printf "\t-- LV(s) to be destroyed: $(lvs ${LVM_BUILD_VAR} --noheadings -a -o lv_name | sed 's/ //g' | xargs | sed -e 's/ /, /g')")" )
    else
      unset print_DISPLAY
      print_DISPLAY+=( "$(printf "\t-- VG to be destroyed: ${LVM_BUILD_VAR}")" )
    fi

    msg_box "#### PLEASE READ CAREFULLY - DESTROY A LVM VOLUME GROUP  ####\n\nYou have chosen to destroy LVM VG '${LVM_BUILD_VAR}' on PVE $(echo $(hostname)). This action will result in permanent data loss of all data stored in LVM VG '${LVM_BUILD_VAR}'.\n\n$(printf '%s\n' "${print_DISPLAY[@]}")\n\nThe disks will be erased and made available for a new LVM build."
    echo
    while true; do
      read -p "Are you sure you want to destroy VG '${LVM_BUILD_VAR}' : [y/n]?" -n 1 -r YN
      echo
      case $YN in
        [Yy]*)
          msg "Destroying VG '${LVM_BUILD_VAR}'..."
          # Umount LVs & delete FSTAB mount entry
          while read lv; do
            if mountpoint -q "$lv"; then
              # Umount
              umount -q /dev/${LVM_BUILD_VAR}/${lv}
              # Delete fstab entry
              sed -i.bak "\@^/dev/${LVM_BUILD_VAR}/${lv}@d" /etc/fstab
            fi
          done< <( lvs ${LVM_BUILD_VAR} --noheadings -a -o lv_name | sed 's/ //g' )
          # Destroy LVs
          while read lv; do
            lvremove /dev/${LVM_BUILD_VAR}/${lv} -y > /dev/null
          done< <( lvs ${LVM_BUILD_VAR} --noheadings -a -o lv_name | sed 's/ //g' )
          # Destroy VG
          vgremove ${VG_NAME} -y > /dev/null
          # Destroy PV
          while read pv; do
            pvremove ${pv} -y > /dev/null
          done< <( printf '%s\n' "${pve_disk_LIST[@]}" )
          info "VG '${LVM_BUILD_VAR}' status: ${YELLOW}destroyed${NC}"
          storage_list # Update storage list array
          stor_LIST # Create a working list array
          echo
          break
          ;;
        [Nn]*)
          echo
          msg "You have chosen not to proceed with destroying VG '${LVM_BUILD_VAR}'.\nTry again..."
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
  elif [ ${LVM_BUILD} == 'TYPE00' ]; then
    # Exit installer
    msg "You have chosen not to proceed. Aborting. Bye..."
    echo
    exit 0
  else
    # Proceed with build option
    break
  fi
done


#---- Type01: Mount an existing LV
if [ ${LVM_BUILD} == 'TYPE01' ]; then
  section "Mount an existing LV LVM"

  # Set LV Name
  LV_NAME=${LVM_BUILD_VAR}

  # Set VG Name
  VG_NAME=$(lvs --noheadings -o vg_name -S lv_name=${LV_NAME} | sed 's/ //g')

  # Validate & set PVE mount point
  PVE_SRC_MNT="/mnt/${LV_NAME}"
  if [[ $(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=${LV_NAME})) ]]; then
    if [ $(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=${LV_NAME} | sed 's/ //g') -o target) == ${PVE_SRC_MNT} ]; then
      # Mount pre-exists
      NEW_LV_MNT='1'
    elif [ ! $(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=${LV_NAME} | sed 's/ //g') -o target) == ${PVE_SRC_MNT} ]; then
      # Modify existing target mount point
      PVE_SRC_MNT=$(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=${LV_NAME} | sed 's/ //g') -o target)
      NEW_LV_MNT='1'
    fi
  else
    if [[ $(mountpoint -q ${PVE_SRC_MNT}) ]]; then
      # Target mount point conflict
      msg "The target mount point '${PVE_SRC_MNT}' is in use by another target volume ( $(findmnt ${PVE_SRC_MNT} -n -o source) ). A new target mount point path has been created..."
      i=1
      while [[ -d "${PVE_SRC_MNT}_${i}" ]] && [[ $(findmnt -n "${PVE_SRC_MNT}_${i}") ]]; do
        i=$(( $i + 1 ))
      done
      PVE_SRC_MNT=${PVE_SRC_MNT}_${i}
      NEW_LV_MNT='0'
      info "New target mount point: ${YELLOW}${PVE_SRC_MNT}${NC}"
      echo
    else
      NEW_LV_MNT='0'
    fi
  fi
fi


#---- Type02: Create LV in an existing Thin-pool
if [ ${LVM_BUILD} == 'TYPE02' ]; then
  section "Create LV in an existing Thin-pool"

  # Set Thin-pool name
  LV_THIN_POOLNAME=${LVM_BUILD_VAR}

  # Set VG Name
  VG_NAME=$(lvs --noheadings -o vg_name -S lv_name=${LV_THIN_POOLNAME} | sed 's/ //g')

  # Set mount status
  NEW_LV_MNT='0'
fi


#---- Type03: Create LV in an existing VG
if [ ${LVM_BUILD} == 'TYPE03' ]; then
  section "Create LV in an existing VG"

  # Set VG name
  VG_NAME=${LVM_BUILD_VAR}

  # Set mount status
  NEW_LV_MNT='0'

  # Create input disk list array
  unset inputdiskLIST
  while read -r line; do
    inputdiskLIST+=( $(printf '%s\n' "${storLIST[@]}" | grep "^${line}:" 2> /dev/null) )
  done < <( pvdisplay -C --noheadings -o pv_name -S vgname=${VG_NAME} | sed 's/ //g' 2> /dev/null )
fi


#---- TYPE05/06: Build a new LVM VG/LV (SSD and HDD)
if [ ${LVM_BUILD} == 'TYPE05' ] || [ ${LVM_BUILD} == 'TYPE06' ]; then
  section "Select disks for new LVM"
  # 1=PATH:2=KNAME:3=PKNAME:4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM

  # Set mount status
  NEW_LV_MNT='0'

  # Disk count by type
  disk_CNT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN="${STOR_MIN}" -v INPUT_TRAN=${INPUT_TRAN} -v var="${LVM_BUILD_VAR}" -v BASIC_DISKLABEL=${BASIC_DISKLABEL} \ 'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  {if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10=var && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { print $0 }}' | wc -l)

  # Select member disks
  msg_box "#### PLEASE READ CAREFULLY - SELECT LVM DISKS ####\n\nThe User has ${disk_CNT}x disk(s) available for their new LVM storage. If selecting for a USB NAS build the User can only select a single disk."
  echo

  # Make disk selection
  msg "The User must now select all member disk(s)."
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v ROTA=${LVM_BUILD_VAR} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} \
  'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  {if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 = ROTA && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { print $0 } }')
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v ROTA=${LVM_BUILD_VAR} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} \
  'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  {if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == ROTA && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0)  { sub(/1/,"HDD",$10);sub(/0/,"SSD",$10); print $1, $6, $8, $10 } }' \
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

  # Set LVM VG name (arg 'usb' prefixes name with 'vg-usb_etc')
  create_lvm_vgname_val ${INPUT_TRAN_ARG}
    
  # Erase / Wipe disks
  msg "Zapping, Erasing and Wiping disks..."
  while read dev; do
    sgdisk --zap $dev >/dev/null 2>&1
    info "SGDISK - zapped (destroyed) the GPT data structures on device: $dev"
    dd if=/dev/zero of=$dev count=1 bs=512 conv=notrunc 2>/dev/null
    info "DD - cleaned & wiped device: $dev"
    wipefs --all --force $dev  >/dev/null 2>&1
    info "wipefs - wiped device: $dev"
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $1 }' ) # file listing of disks to erase
  echo

  # Create primary partition
  num=1
  unset inputdevLIST
  while read dev; do
    # Create single partition
    echo 'type=83' | sfdisk $dev
    # Create new dev list
    if [[ $dev =~ ^/dev/sd[a-z]$ ]]; then
      inputdevLIST+=( "$(echo "${dev}${num}")" )
    elif [[ $dev =~ ^/dev/nvme[0-9]n[0-9]$ ]]; then
      inputdevLIST+=( "$(echo "${dev}p${num}")" )
    fi
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $1 }' ) # file listing of disks

  # Create PV
  while read dev; do
    pvcreate --metadatasize ${VG_METADATASIZE} -y -ff $dev
  done < <( printf '%s\n' "${inputdevLIST[@]}" ) # file listing of devs

  # Create VG
  vgcreate ${VG_NAME} $(printf '%s\n' "${inputdevLIST[@]}" | xargs | sed 's/ *$//g')
fi

#---- Create Thin-Pool
if [ ${LVM_BUILD} == 'TYPE03' ] || [ ${LVM_BUILD} == 'TYPE05' ] || [ ${LVM_BUILD} == 'TYPE06' ]; then
  # Select LVM RAID level
  unset raidoptionLIST
  raidoptionLIST+=( "raid0:1:Also called 'striping'. Fast but no redundancy." \
  "raid1:2:Also called 'mirroring'. The resulting capacity is that of a single disk." \
  "raid5:3:Striping with single parity. Minimum 3 disks." \
  "raid6:5:Striping with double parity. Minimum 5 disks." \
  "raid10:4:A combination of RAID0 and RAID1. Minimum 4 disks (even unit number only)." )

  msg "The User must now select a LVM RAID level based on your $(echo "${#inputdiskLIST[@]}")x disk selection..."
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${raidoptionLIST[@]}" | awk -F':' -v INPUT_CNT=$(echo "${#inputdiskLIST[@]}") 'BEGIN{OFS=FS} \
  {if ($2 <= INPUT_CNT) { print $1} }')
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${raidoptionLIST[@]}" | awk -F':' -v INPUT_CNT=$(echo "${#inputdiskLIST[@]}") 'BEGIN{OFS=FS} \
  {if ($2 <= INPUT_CNT) { print toupper($1) " | " $3} }')
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect_confirm SELECTED "$OPTIONS_STRING"
  # Selected RaidZ level
  inputRAIDLEVEL=${RESULTS}

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
  
  # Create LVM RAID Thin Pool
  msg "Creating LVM RAID Thin Pool '${LV_THIN_POOLNAME}'..."
  if [ ${inputRAIDLEVEL} == 'raid0' ]; then
    # RAID 0
    if [ ${#inputdevLIST[@]} == '1' ]; then
      # Create LV thinpool
      lvcreate \
      --thin ${VG_NAME}/${LV_THIN_POOLNAME} \
      --chunksize ${LV_THIN_CHUNKSIZE} \
      --poolmetadatasize ${LV_THIN_POOLMETADATASIZE} \
      --extents ${LV_THINPOOL_EXTENTS}VG
      # Set thin autoextend
      lvchange --metadataprofile autoextend ${VG_NAME}/${LV_THIN_POOLNAME}
      lvchange --monitor y ${VG_NAME}/${LV_THIN_POOLNAME}
    else
      # Create LV thinpool
      lvcreate \
      --thin ${VG_NAME}/${LV_THIN_POOLNAME} \
      --chunksize ${LV_THIN_CHUNKSIZE} \
      --poolmetadatasize ${LV_THIN_POOLMETADATASIZE} \
      --stripes ${#inputdiskLIST[@]} \
      --stripesize ${LV_THIN_STRIPESIZE} \
      --extents ${LV_THINPOOL_EXTENTS}VG
      # Set thin autoextend
      lvchange --metadataprofile autoextend ${VG_NAME}/${LV_THIN_POOLNAME}
      lvchange --monitor y ${VG_NAME}/${LV_THIN_POOLNAME}
    fi
  elif [ ${inputRAIDLEVEL} == 'raid1' ]; then
    # RAID 1
    # Create LV thinpool
    lvcreate \
    --mirrors 1 \
    --type raid1 \
    --extents ${LV_THINPOOL_EXTENTS}VG \
    --name ${LV_THIN_POOLNAME} ${VG_NAME}
    lvcreate \
    --mirrors 1 \
    --type raid1 \
    --size ${LV_THIN_POOLMETADATASIZE} \
    --name thin_meta ${VG_NAME}
    lvconvert -y \
    --thinpool ${VG_NAME}/${LV_THIN_POOLNAME} \
    --poolmetadata ${VG_NAME}/thin_meta \
    --chunksize ${LV_THIN_CHUNKSIZE}
    # Set thin autoextend
    lvchange --metadataprofile autoextend ${VG_NAME}/${LV_THIN_POOLNAME}
    lvchange --monitor y ${VG_NAME}/${LV_THIN_POOLNAME}
  elif [ ${inputRAIDLEVEL} == 'raid5' ]; then
    # RAID 5
    STRIPECNT=$(( ${#inputdevLIST[@]} - 1 ))
    # Create LV thinpool
    lvcreate \
    --type raid5 \
    --stripes ${STRIPECNT} \
    --stripesize ${LV_STRIPESIZE} \
    --extents ${LV_THINPOOL_EXTENTS}VG \
    --name ${LV_THIN_POOLNAME} ${VG_NAME}
    lvcreate \
    --type raid5 \
    --stripes ${STRIPECNT} \
    --stripesize ${LV_STRIPESIZE} \
    --size ${LV_THIN_POOLMETADATASIZE} \
    --name thin_meta ${VG_NAME}
    lvconvert -y \
    --thinpool ${VG_NAME}/${LV_THIN_POOLNAME} \
    --poolmetadata ${VG_NAME}/thin_meta \
    --chunksize ${LV_THIN_CHUNKSIZE}
    # Set thin autoextend
    lvchange --metadataprofile autoextend ${VG_NAME}/${LV_THIN_POOLNAME}
    lvchange --monitor y ${VG_NAME}/${LV_THIN_POOLNAME}
  elif [ ${inputRAIDLEVEL} == 'raid6' ]; then
    # RAID 6
    STRIPECNT=$(( ${#inputdevLIST[@]} - 2 ))
    # Create LV thinpool
    lvcreate \
    --type raid6 \
    --stripes ${STRIPECNT} \
    --stripesize ${LV_STRIPESIZE} \
    --extents ${LV_THINPOOL_EXTENTS}VG \
    --name ${LV_THIN_POOLNAME} ${VG_NAME}
    lvcreate \
    --type raid6 \
    --stripes ${STRIPECNT} \
    --stripesize ${LV_STRIPESIZE} \
    --size ${LV_THIN_POOLMETADATASIZE} \
    --name thin_meta ${VG_NAME}
    lvconvert -y \
    --thinpool ${VG_NAME}/${LV_THIN_POOLNAME} \
    --poolmetadata ${VG_NAME}/thin_meta \
    --chunksize ${LV_THIN_CHUNKSIZE}
    # Set thin autoextend
    lvchange --metadataprofile autoextend ${VG_NAME}/${LV_THIN_POOLNAME}
    lvchange --monitor y ${VG_NAME}/${LV_THIN_POOLNAME}
  elif [ ${inputRAIDLEVEL} == 'raid10' ]; then
    # RAID 10
    # Create LV thinpool
    lvcreate \
    --mirrors 1 \
    --type raid10 \
    --extents ${LV_THINPOOL_EXTENTS}VG \
    --stripesize ${LV_STRIPESIZE} \
    --name ${LV_THIN_POOLNAME} ${VG_NAME}
    lvcreate \
    --mirrors 1 \
    --type raid10 \
    --size ${LV_THIN_POOLMETADATASIZE} \
    --stripesize ${LV_STRIPESIZE} \
    --name thin_meta ${VG_NAME}
    lvconvert -y \
    --thinpool ${VG_NAME}/${LV_THIN_POOLNAME} \
    --poolmetadata ${VG_NAME}/thin_meta \
    --chunksize ${LV_THIN_CHUNKSIZE}
    # Set thin autoextend
    lvchange --metadataprofile autoextend ${VG_NAME}/${LV_THIN_POOLNAME}
    lvchange --monitor y ${VG_NAME}/${LV_THIN_POOLNAME}
  fi
  info "Thin-pool created: ${YELLOW}${LV_THIN_POOLNAME}${NC}"
  echo
fi


#---- Create LV
if [ ${LVM_BUILD} == 'TYPE02' ] || [ ${LVM_BUILD} == 'TYPE03' ] || [ ${LVM_BUILD} == 'TYPE05' ] || [ ${LVM_BUILD} == 'TYPE06' ]; then
  msg "Creating LV '${LV_NAME}'..."
  # Create thin volume
  lvcreate \
  --virtualsize 2G \
  --thin ${VG_NAME}/${LV_THIN_POOLNAME} \
  --name ${LV_NAME}
  # Extend volume to VG max
  lvextend --extents 100%VG ${VG_NAME}/${LV_NAME}
  info "LV created: ${YELLOW}${LV_NAME}${NC}"
  echo
fi


#---- Set FS Type
if [[ $(blkid $(lvs --noheadings -o lv_path -S lv_name=${LV_NAME} | sed 's/ //g') -s TYPE -o value) =~ "" ]]; then
  msg "The installer has detected LV '${LV_NAME}' has no detectable Linux File System. In the next step the User can select a Linux File System. Formatting will permanently destroy all existing data stored on LV '${LV_NAME}'. The User has been warned..."
  echo
  # Menu options
  OPTIONS_VALUES_INPUT=( "ext4" "ext3" "btrfs" "xfs" "TYPE00" )
  OPTIONS_LABELS_INPUT=( "Linux File Systems - ext4 ( Recommended )" "Linux File Systems - ext3" "Linux File Systems - btrfs" "Linux File Systems - xfs" "None - Exit this installer" )
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"
  # Exit action
  if [ ${RESULTS} == 'TYPE00' ]; then
    msg "You have chosen not to proceed. Aborting. Bye..."
    echo
    exit 0
  fi
  LV_FSTYPE=${RESULTS}
  echo
else
  LV_FSTYPE=$(blkid $(lvs --noheadings -o lv_path -S lv_name=${LV_NAME} | sed 's/ //g') -s TYPE -o value)
fi


#---- Set /etc/fstab options & mkfs arg
if [ ${LV_FSTYPE} == 'ext4' ]; then
  # Options for EXT4
  mkfs_arg='-F'
  if [ ${NEW_LV_MNT} == '0' ]; then
    fstab_options=( "defaults" "rw" "user_xattr" "acl" ) # Edit options here
    fstab_options=$(printf '%s\n' ${fstab_options[@]} | uniq | xargs | sed -r 's/[[:space:]]/,/g')
  elif [ ${NEW_LV_MNT} == '1' ]; then
    fstab_options=( "defaults" "rw" "user_xattr" "acl" ) # Edit options here
    fstab_options+=( $(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=${LV_NAME}) -o options | sed 's/,/\n/g') )
    fstab_options=$(printf '%s\n' ${fstab_options[@]} | uniq | xargs | sed -r 's/[[:space:]]/,/g')
  fi
elif [ ${LV_FSTYPE} == 'ext3' ]; then
  # Options for EXT3
  mkfs_arg='-F'
  if [ ${NEW_LV_MNT} == '0' ]; then
    fstab_options=( "defaults" "rw" "user_xattr" "acl" ) # Edit options here
    fstab_options=$(printf '%s\n' ${fstab_options[@]} | uniq | xargs | sed -r 's/[[:space:]]/,/g')
  elif [ ${NEW_LV_MNT} == '1' ]; then
    fstab_options=( "defaults" "rw" "user_xattr" "acl" ) # Edit options here
    fstab_options+=( $(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=${LV_NAME}) -o options | sed 's/,/\n/g') )
    fstab_options=$(printf '%s\n' ${fstab_options[@]} | uniq | xargs | sed -r 's/[[:space:]]/,/g')
  fi
elif [ ${LV_FSTYPE} == 'btrfs' ]; then
  # Options for BTRFS
  mkfs_arg='-f'
  if [ ${NEW_LV_MNT} == '0' ]; then
    fstab_options=( "defaults" "rw" ) # Edit options here
    fstab_options=$(printf '%s\n' ${fstab_options[@]} | uniq | xargs | sed -r 's/[[:space:]]/,/g')
  elif [ ${NEW_LV_MNT} == '1' ]; then
    fstab_options=( "defaults" "rw" ) # Edit options here
    fstab_options+=( $(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=${LV_NAME}) -o options | sed 's/,/\n/g') )
    fstab_options=$(printf '%s\n' ${fstab_options[@]} | uniq | xargs | sed -r 's/[[:space:]]/,/g')
  fi
elif [ ${LV_FSTYPE} == 'xfs' ]; then
  # Options for XFS
  mkfs_arg='-f'
  if [ ${NEW_LV_MNT} == '0' ]; then
    fstab_options=( "defaults" "rw" ) # Edit options here
    fstab_options=$(printf '%s\n' ${fstab_options[@]} | uniq | xargs | sed -r 's/[[:space:]]/,/g')
  elif [ ${NEW_LV_MNT} == '1' ]; then
    fstab_options=( "defaults" "rw" ) # Edit options here
    fstab_options+=( $(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=${LV_NAME}) -o options | sed 's/,/\n/g') )
    fstab_options=$(printf '%s\n' ${fstab_options[@]} | uniq | xargs | sed -r 's/[[:space:]]/,/g')
  fi
fi

# Format LV volume
mkfs.${LV_FSTYPE} ${mkfs_arg} /dev/mapper/${VG_NAME}-${LV_NAME}

#---- Complete LVM build
if [ ${NEW_LV_MNT} == '0' ]; then
  # Umount any existing mount point
  umount -q $(lvs --noheadings -o lv_path -S lv_name=${LV_NAME} | sed 's/ //g')
  umount -q /dev/mapper/${VG_NAME}-${LV_NAME}
  umount -q ${PVE_SRC_MNT}
  # Clean /etc/fstab of any conflicts
  sed -i "\|^$(lvs --noheadings -o lv_path -S lv_name=${LV_NAME} | sed 's/ //g')|d" /etc/fstab
  sed -i "\|^/dev/mapper/${VG_NAME}-${LV_NAME}|d" /etc/fstab
  sed -i "\|${PVE_SRC_MNT}|d" /etc/fstab
  # Format LV volume
  mkfs.${LV_FSTYPE} ${mkfs_arg} /dev/mapper/${VG_NAME}-${LV_NAME}
  # Create mount point
  if [ ${INPUT_TRAN_ARG} == "" ] || [ ${INPUT_TRAN_ARG} == 'onboard' ]; then
    echo "/dev/mapper/${VG_NAME}-${LV_NAME} ${PVE_SRC_MNT} ${LV_FSTYPE} ${fstab_options} 0 0" >> /etc/fstab
    mount ${PVE_SRC_MNT}
    info "LV mount created: ${YELLOW}${PVE_SRC_MNT}${NC}"
  elif [ ${INPUT_TRAN_ARG} == 'usb' ]; then
    mkdir -p ${PVE_SRC_MNT}
    LV_UUID=$(lvs --noheadings -o uuid -S lv_name=${LV_NAME} | sed 's/ //g' 2> /dev/null)
    echo -e "UUID=${LV_UUID} ${PVE_SRC_MNT} ${LV_FSTYPE} ${fstab_options} 0 0" >> /etc/fstab
    mount ${PVE_SRC_MNT}
    info "LV mount created: ${YELLOW}${PVE_SRC_MNT}${NC}\n       (LV UUID: ${LV_UUID})"
  fi
elif [ ${NEW_LV_MNT} == '1' ]; then
  # Umount any existing mount point
  umount -q $(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=${LV_NAME}) -o target)
  # Clean /etc/fstab of any conflicts
  sed -i "\|^$(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=${LV_NAME}) -o target)|d" /etc/fstab
  sed -i "\|^/dev/mapper/${VG_NAME}-${LV_NAME}|d" /etc/fstab
  sed -i "\|${PVE_SRC_MNT}|d" /etc/fstab
  # Create mount point
  if [ ${INPUT_TRAN_ARG} == "" ] || [ ${INPUT_TRAN_ARG} == 'onboard' ]; then
    echo "/dev/mapper/${VG_NAME}-${LV_NAME} ${PVE_SRC_MNT} ${LV_FSTYPE} ${fstab_options} 0 0" >> /etc/fstab
    mount ${PVE_SRC_MNT}
    info "LV mount created: ${YELLOW}${PVE_SRC_MNT}${NC}"
  elif [ ${INPUT_TRAN_ARG} == 'usb' ]; then
    mkdir -p ${PVE_SRC_MNT}
    LV_UUID=$(lvs --noheadings -o uuid -S lv_name=${LV_NAME} | sed 's/ //g' 2> /dev/null)
    echo -e "UUID=${LV_UUID} ${PVE_SRC_MNT} ${LV_FSTYPE} ${fstab_options} 0 0" >> /etc/fstab
    mount ${PVE_SRC_MNT}
    info "LV mount created: ${YELLOW}${PVE_SRC_MNT}${NC}\n       (LV UUID: ${LV_UUID})"
  fi
fi