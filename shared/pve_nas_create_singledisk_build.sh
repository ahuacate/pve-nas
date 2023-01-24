#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_create_singlediskext4_build.sh
# Description:  Source script for building single ext4 disk storage
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

# Install Parted (for partprobe)
if [ $(dpkg -s parted >/dev/null 2>&1; echo $?) != 0 ]; then
  apt-get install -y parted > /dev/null
fi


#---- Static Variables -------------------------------------------------------------

# Disk Over-Provisioning (value is % of disk)
DISK_OP_SSD='10'
DISK_OP_ROTA='0'

# Basic storage disk label
BASIC_DISKLABEL='(.*_hba|.*_usb|.*_onboard)$'

#---- Other Variables --------------------------------------------------------------

# USB Disk Storage minimum size (GB)
STOR_MIN='30'

#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Wake USB disk
function wake_usb() {
  while IFS= read -r line; do
    dd if=${line} of=/dev/null count=512 status=none
  done < <( lsblk -nbr -o PATH,TRAN | awk '{if ($2 == "usb") print $1 }' )
}

#---- Body -------------------------------------------------------------------------

#---- Select a Ext4 build option
section "Select a build option"
# 1=PATH:2=KNAME:3=PKNAME:4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM

while true; do
  # Make selection
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} \
  'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  {if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print "TYPE01", $0 } \
  {if ($5 ~ INPUT_TRAN && $3 != 0 && $4 == "ext4" && $9 == "part" && size >= STOR_MIN && $13 ~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print "TYPE02", $0 } \
  {if ($5 ~ INPUT_TRAN && $3 != 0 && $4 == "ext4" && $9 == "part" && size >= STOR_MIN && $13 ~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print "TYPE03", $0 }' \
  | sed -e '$a\TYPE00:0')
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL}  \
  'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  # Type01: Basic single disk build
  {if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print "Basic single disk build", "Format "$1" to ext4", $8} \
  # TYPE02: Mount existing NAS storage disk
  {if ($5 ~ INPUT_TRAN && $3 != 0 && $4 == "ext4" && $9 == "part" && size >= STOR_MIN && $13 ~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print "Mount existing NAS storage disk", "Mount "$1" (disk label - "$13")", $8} \
  # TYPE03: Destroy & wipe disk
  {if ($5 ~ INPUT_TRAN && $3 != 0 && $4 == "ext4" && $9 == "part" && size >= STOR_MIN && $13 ~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print "Destroy & wipe disk", "Destroy disk /dev/"$3" (disk label - "$13")", $8}' \
  | sed -e '$a\None. Exit this installer:' \
  | column -t -s ":")

  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect SELECTED "$OPTIONS_STRING"

  # Set USB Build
  BUILD_TYPE=$(echo ${RESULTS} | awk -F':' '{ print $1 }')

  # Create input disk list array
  inputdiskLIST=( "$(echo ${RESULTS} | cut -d: -f2-15)" )


  #---- Destroy Disk
  if [ ${BUILD_TYPE} == 'TYPE03' ]; then
    # Create device list
    unset inputdevLIST
    while read pkname; do
      if [[ ${pkname} =~ ^(sd[a-z]|nvme[0-9]n[0-9]) ]]; then
        inputdevLIST+=( "$(lsblk -n -o path /dev/${pkname})" )
      fi
    done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $3 }' ) # file listing of disks

    unset print_DISPLAY
    while read dev; do
      print_DISPLAY+=( "$(lsblk -l -o PATH,FSTYPE,SIZE,MOUNTPOINT $dev)" )
      print_DISPLAY+=( " " )
    done < <( printf '%s\n' "${inputdevLIST[@]}" | grep 'sd[a-z]$\|nvme[0-9]n[0-9]$' ) # dev device listing

    msg_box "#### PLEASE READ CAREFULLY - DESTROYING A DISK  ####\n\nYou have chosen to destroy & wipe a disk. This action will result in permanent data loss of all data stored on the following devices:\n\n$(printf '%s\n' "${print_DISPLAY[@]}" | indent2)\n\nThe disks will be erased and made available for a Basic single disk NAS build."
    echo
    while true; do
      read -p "Are you sure you want to destroy the disk : [y/n]?" -n 1 -r YN
      echo
      case $YN in
        [Yy]*)
          # Remove any existing mount points
          while read dev; do
            # Umount dev
            umount -q ${dev} > /dev/null 2>&1 || /bin/true
            # Remove any /etc/fstab mount points
            sed -i "\|^${dev}|d" /etc/fstab
            if [[ $(blkid -s UUID -o value ${dev}) ]]; then
              DISK_UUID=$(blkid -s UUID -o value ${dev} 2> /dev/null)
              sed -i "\|${DISK_UUID}|d" /etc/fstab
            fi
          done < <( printf '%s\n' "${inputdevLIST[@]}" | awk -F':' '{ print $1 }' ) # dev device listing
          # Erase / Wipe disks
          msg "Zapping, Erasing and Wiping disks..."
          while read dev; do
            sgdisk --zap ${dev} >/dev/null 2>&1
            info "SGDISK - zapped (destroyed) the GPT data structures on device: ${dev}"
            dd if=/dev/zero of=${dev} count=1 bs=512 conv=notrunc 2>/dev/null
            info "DD - cleaned & wiped device: ${dev}"
            wipefs --all --force ${dev} >/dev/null 2>&1
            info "wipefs - wiped device: ${dev}"
          done < <( printf '%s\n' "${inputdevLIST[@]}" | grep 'sd[a-z]$\|nvme[0-9]n[0-9]$' ) # file listing of disks to erase
          sleep 1
          partprobe
          storage_list # Update storage list array
          stor_LIST # Create a working list array
          echo
          break 
          ;;
        [Nn]*)
          echo
          msg "You have chosen not to proceed with destroying a disk.\nTry again..."
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
  elif [ ${BUILD_TYPE} == 'TYPE00' ]; then
    # Exit installer
    msg "You have chosen not to proceed. Aborting. Bye..."
    echo
    exit 0
  else
    # Proceed with build option
    break
  fi
done


#---- TYPE01: Basic Storage Build
if [ ${BUILD_TYPE} == 'TYPE01' ]; then
  # Remove any existing mount points
  while read dev; do
    # Umount dev
    umount -q ${dev} > /dev/null 2>&1 || /bin/true
    # Remove any /etc/fstab mount points
    sed -i "\|^${dev}.*|d" /etc/fstab
    if [[ $(blkid -s UUID -o value ${dev}) ]]; then
      DISK_UUID=$(blkid -s UUID -o value ${dev} 2> /dev/null)
      sed -i "\|${DISK_UUID}|d" /etc/fstab
    fi
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $1 }' ) # dev device listing

  # Mount point name ( Use CT/VM hostname )
  MNT_NAME=$(echo $HOSTNAME | sed 's/-/_/g') # Hostname mod (change any '-' to '_')
  if [ -d /mnt/${MNT_NAME} ] && [[ $(ls -A /mnt/${MNT_NAME}) ]]; then
    i=1
    while [ $(lvs | grep "^\s*${MNT_NAME}_${i}" &>/dev/null; echo $?) == '0' ] || [ $(vgs ${MNT_NAME}_${i} &>/dev/null; echo $?) == '0' ]; do
      i=$(( $i + 1 ))
    done
    MNT_NAME=${MNT_NAME}_${i}
  fi

  # Set SRC mount point
  PVE_SRC_MNT="/mnt/${MNT_NAME}"

  # New USB disk label
  DISK_LABEL="${MNT_NAME}_${INPUT_TRAN_ARG}"

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

  # Create primary partition
  msg "Partitioning, formatting & labelling new disk..."
  num='1'
  unset inputdevLIST
  while read dev; do
    # Create single partition
    echo 'type=83' | sfdisk $dev
    # Create new dev list
    if [[ $dev =~ ^/dev/sd[a-z]$ ]]; then
      # Format to ext4
      mkfs.ext4 ${dev}${num}
      e2label ${dev}${num} ${DISK_LABEL}
      DISK_UUID=$(blkid -s UUID -o value ${dev}${num} 2> /dev/null)
      inputdevLIST+=( "$(echo "${dev}${num}:${DISK_UUID}")" )
      info "Ext4 disk partition created: ${YELLOW}${dev}${num}${NC}"
    elif [[ $dev =~ ^/dev/nvme[0-9]n[0-9]$ ]]; then
      # Format to ext4
      mkfs.ext4 ${dev}p${num}
      e2label ${dev}p${num} ${DISK_LABEL}
      DISK_UUID=$(blkid -s UUID -o value ${dev}p${num} 2> /dev/null)
      inputdevLIST+=( "$(echo "${dev}p${num}:${DISK_UUID}")" )
      info "Ext4 disk partition created: ${YELLOW}${dev}p${num}${NC}"
    fi
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $1 }' ) # file listing of disks
  echo

  # Disk Over-Provisioning
  msg "Applying over-provisioning factor % to disk..."
  while read dev; do
    if [[ "$(hdparm -I $dev 2> /dev/null | awk -F':' '/Nominal Media Rotation Rate/ { print $2 }' | sed 's/ //g')" == 'SolidStateDevice' ]]; then
      tune2fs -m ${DISK_OP_SSD} $dev > /dev/null
      info "SSD disk reserved block percentage: ${YELLOW}${DISK_OP_SSD}%${NC}"
      echo
    else
      tune2fs -m ${DISK_OP_ROTA} $dev > /dev/null
      info "Rotational disk reserved block percentage: ${YELLOW}${DISK_OP_ROTA}%${NC}"
      echo
    fi
  done < <( printf '%s\n' "${inputdevLIST[@]}" | awk -F':' '{ print $1 }' ) # file listing of new devs

  # PVE local disk mount
  mkdir -p ${PVE_SRC_MNT}
  echo -e "UUID=${DISK_UUID} ${PVE_SRC_MNT} ext4 defaults,rw,user_xattr,acl 0 0" >> /etc/fstab
  mount ${PVE_SRC_MNT}
  info "Disk mount created: ${YELLOW}${PVE_SRC_MNT}${NC}\n       (Disk UUID: ${DISK_UUID})"
  echo
fi


#---- TYPE02: Mount existing disk
if [ ${BUILD_TYPE} == 'TYPE02' ]; then

  # Get disk UUID
  while read dev; do
    DISK_UUID=$(blkid -s UUID -o value ${dev} 2> /dev/null)
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $1 }' ) # file listing of disks

  # Remove any existing mount points
  while read dev; do
    # Umount dev
    umount -q ${dev} > /dev/null 2>&1 || /bin/true
    # Remove any fstab dev mount points
    sed -i "\|^${dev}.*|d" /etc/fstab
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $1 }' ) # dev device listing
  # Remove UUID from /etc/fstab
  sed -i "\|${DISK_UUID}|d" /etc/fstab

  # Disk Over-Provisioning
  msg "Applying over-provisioning factor % to disk..."
  while read dev; do
    if [[ "$(hdparm -I $dev 2> /dev/null | awk -F':' '/Nominal Media Rotation Rate/ { print $2 }' | sed 's/ //g')" == 'SolidStateDevice' ]]; then
      tune2fs -m ${DISK_OP_SSD} $dev > /dev/null
      info "SSD disk reserved block percentage: ${YELLOW}${DISK_OP_SSD}%${NC}"
      echo
    else
      tune2fs -m ${DISK_OP_ROTA} $dev > /dev/null
      info "Rotational disk reserved block percentage: ${YELLOW}${DISK_OP_ROTA}%${NC}"
      echo
    fi
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $1 }' ) # file listing of new devs

  # Mount point name ( Use CT/VM hostname )
  MNT_NAME=$(echo $HOSTNAME | sed 's/-/_/g') # Hostname mod (change any '-' to '_')
  if [ -d /mnt/${MNT_NAME} ] && [[ $(ls -A /mnt/${MNT_NAME}) ]]; then
    i=1
    while [ $(lvs | grep "^\s*${MNT_NAME}_${i}" &>/dev/null; echo $?) == '0' ] || [ $(vgs ${MNT_NAME}_${i} &>/dev/null; echo $?) == '0' ]; do
      i=$(( $i + 1 ))
    done
    MNT_NAME=${MNT_NAME}_${i}
  fi

  # Set SRC mount point
  PVE_SRC_MNT="/mnt/${MNT_NAME}"

  # PVE local disk mount
  mkdir -p ${PVE_SRC_MNT}
  echo -e "UUID=${DISK_UUID} ${PVE_SRC_MNT} ext4 defaults,rw,user_xattr,acl 0 0" >> /etc/fstab
  mount ${PVE_SRC_MNT}
  info "Disk mount created: ${YELLOW}${PVE_SRC_MNT}${NC}\n       (Disk UUID: ${DISK_UUID})"
  echo
fi