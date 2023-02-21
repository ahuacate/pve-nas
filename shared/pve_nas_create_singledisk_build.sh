#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_create_singledisk_build.sh
# Description:  Source script for building single ext4 disk storage
# ----------------------------------------------------------------------------------


#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Requires arg 'usb' or 'onboard' to be set in source command
# Sets the validation input type: input_lvm_vgname_val usb
if [ -z "$1" ]
then
  input_tran=""
  input_tran_arg=""
elif [[ "$1" =~ 'usb' ]]
then
  input_tran='(usb)'
  input_tran_arg='usb'
elif [[ "$1" =~ 'onboard' ]]
then
  input_tran='(sata|ata|scsi|nvme)'
  input_tran_arg='onboard'
fi

# Install parted (for partprobe)
if [[ ! $(dpkg -s parted 2>/dev/null) ]]
then
  apt-get install -y parted > /dev/null
fi


#---- Static Variables -------------------------------------------------------------

# Disk Over-Provisioning (value is % of disk)
disk_op_ssd='10'
disk_op_rota='0'

# Basic storage disk label
basic_disklabel='(.*_hba(_[0-9])?|.*_usb(_[0-9])?|.*_onboard(_[0-9])?)$'

#---- Other Variables --------------------------------------------------------------

# USB Disk Storage minimum size (GB)
stor_min='30'

#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequistes

# Check default udev rule exists
if [ -f "/etc/udev/rules.d/80-mount-usb-to-media-by-label.rules" ] && [ "$input_tran_arg" = usb ]
then
  # Remove old udev rule version
  rm -f /etc/udev/rules.d/80-mount-usb-to-media-by-label.rules
  # Re-Activate udev rules
  udevadm control --reload-rules
  sleep 2
fi

# Disable USB autosuspend

display_msg="#### PLEASE READ CAREFULLY - USB POWER MANAGEMENT ####

Proxmox default power management suspends USB disks when they are idle. On restart you may find your NAS storage mount is broken with I/O errors. This is often caused by the USB disk assigning itself a different device id (i.e '/dev/sdd1' to '/dev/sde1') despite the NAS CT bind mount point staying the same. For now the only fix is to disable auto suspend features for USB disks.

Our UDEV Rule performs the USB disk mount and disables power management on the device. This method does NOT always work (when it does its 100% reliable).

If you have any issues or I/O errors read our GitHub guide for any known fixes."

if [ "$input_tran_arg" = usb ]
then
  section "USB Power management & Autosuspend"

  # Display msg
  msg_box "$display_msg"

  # USB menu option
  msg "Make your selection..."
  OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE00")
  OPTIONS_LABELS_INPUT=( "I understand. Continue the install (Recommended)" "Exit this installer" )

  # Run menu selection
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"

  if [ "$RESULTS" = 'TYPE00' ]
  then
    msg "You have chosen not to proceed. Aborting. Bye..."
    echo
    exit 0
  fi
fi


#---- Select a Ext4 build option
section "Select a build option"
# 1=PATH:2=KNAME:3=PKNAME:4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM

while true
do
  # Create fs/disk lists for LVM, ZFS, Basic (onboard & usb)
  source $SHARED_DIR/pve_nas_fs_list.sh

  # Create menu labels
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${basic_option_labels}" \
  | cut -d: -f1,2,4 \
  | sed -e '$a\None. Exit this installer::::' \
  | column -t -s ":" -N "BASIC OPTIONS,DESCRIPTION,SIZE" -T DESCRIPTION -c 150 -d)
  # Create menu values
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${basic_option_values}" \
  | sed -e '$a\TYPE00:0')

  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect SELECTED "$OPTIONS_STRING"

  # Set Build
  BUILD_TYPE=$(echo "$RESULTS" | awk -F':' '{ print $1 }')

  # Create input disk list array
  inputdiskLIST=( "$(echo "$RESULTS" | cut -d: -f2-15)" )


  #---- Destroy Disk
  if [ "$BUILD_TYPE" = TYPE03 ]
  then
    # Create device list
    inputdevLIST=()
    while read pkname
    do
      if [[ "$pkname" =~ ^(sd[a-z]|nvme[0-9]n[0-9]) ]]
      then
        inputdevLIST+=( $(lsblk -n -o path /dev/${pkname}) )
      fi
    done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $3 }' ) # file listing of disks

    # Create print display
    print_DISPLAY=()
    while read dev
    do
      print_DISPLAY+=( "$(lsblk -l -o PATH,FSTYPE,SIZE,MOUNTPOINT $dev)" )
      print_DISPLAY+=( " " )
    done < <( printf '%s\n' "${inputdevLIST[@]}" | grep 'sd[a-z]$\|nvme[0-9]n[0-9]$' ) # dev device listing

    msg_box "#### PLEASE READ CAREFULLY - DESTROYING A DISK  ####\n\nYou have chosen to destroy & wipe a disk. This action will result in permanent data loss of all data stored on the following devices:\n\n$(printf '%s\n' "${print_DISPLAY[@]}" | indent2)\n\nThe disks will be erased and made available for a Basic single disk NAS build."
    echo

    # User confirmation to destroy disk & partitions
    while true
    do
      read -p "Are you sure you want to destroy the disk : [y/n]?" -n 1 -r YN
      echo
      case $YN in
        [Yy]*)
          # Remove any existing mount points
          while read dev
          do
            # Disk uuid
            uuid=$(lsblk -d -n -o uuid $dev 2> /dev/null)
            # Get existing disk label name
            label=$(lsblk -d -n -o label $dev 2> /dev/null)
            # Remove UUID from /etc/fstab
            if [ -n "$uuid" ]
            then
              sed -i "/^UUID=$uuid/d" /etc/fstab
            fi
            # Remove label from /etc/fstab
            if [ -n "$label" ]
            then
              sed -i "/^LABEL=$label/d" /etc/fstab
            fi
            # Remove dev from /etc/fstab
            if [ -n "$dev" ]
            then
              sed -i "\|^${dev}.*|d" /etc/fstab
            fi
            # Check for existing mnt points
            if [[ $(findmnt -n -S $dev) ]]
            then
              # Get existing mount point
              existing_mnt_point=$(lsblk -no mountpoint $dev)
              # Umount dev
              umount -f -q $dev > /dev/null 2>&1 || /bin/true
              # Remove mnt point
              rm -R -f $existing_mnt_point 2> /dev/null
            fi
          done < <( printf '%s\n' "${inputdevLIST[@]}" ) # dev device listing

          # Erase / Wipe disks
          msg "Zapping, Erasing and Wiping disks..."
          while read dev
          do
            # Full device wipeout
            sgdisk --zap $dev >/dev/null 2>&1
            dd if=/dev/zero of=$dev bs=1M status=progress
            wipefs --all --force $dev >/dev/null 2>&1
            info "Zapped, destroyed & wiped device: $dev"
          done < <( printf '%s\n' "${inputdevLIST[@]}" | grep 'sd[a-z]$\|nvme[0-9]n[0-9]$' | uniq ) # file listing of disks to erase

          # Wait for pending udev events
          udevadm settle
          sleep 1

          # Re-read the partition table
          partprobe

          # Update storage list array (function)
          storage_list

          # Create a working list array (function)
          stor_LIST
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
  elif [ "$BUILD_TYPE" = TYPE00 ]
  then
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
if [ "$BUILD_TYPE" = TYPE01 ]
then
  # Set mnt base dir
  if [ "$input_tran_arg" = usb ]
  then
    # Set mnt dir (base dir)
    mnt_base_dir="media"
  else
    # Set mnt dir (base dir)
    mnt_base_dir="mnt"
  fi

  # Disk uuid
  disk_uuid=$(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $11 }')

  # Get existing disk label name
  existing_disk_label=$(blkid -s LABEL -o value /dev/disk/by-uuid/$disk_uuid)

  # Set default mnt point name
  mnt_name="nas_basic_$input_tran_arg"

  # Remove any existing mount points
  while IFS=':' read dev uuid label
  do
    # Remove UUID from /etc/fstab
    if [ -n "$uuid" ]
    then
      sed -i "/^UUID=$uuid/d" /etc/fstab
    fi
    # Remove label from /etc/fstab
    if [ -n "$label" ]
    then
      sed -i "/^LABEL=$label/d" /etc/fstab
    fi
    # Remove dev from /etc/fstab
    if [ -n "$dev" ]
    then
      sed -i "\|^${dev}.*|d" /etc/fstab
    fi
    # Check for existing mnt points
    if [[ $(findmnt -n -S $dev) ]] && [ -n "$dev" ]
    then
      # Get existing mount point
      existing_mnt_point=$(lsblk -no mountpoint $dev)
      # Umount dev
      umount -f -q $dev > /dev/null 2>&1 || /bin/true
      # Remove mnt point
      rm -R -f $existing_mnt_point 2> /dev/null
    fi
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' -v OFS=':' '{ print $1, $11, $13 }' ) # dev device listing

  # Check for existing mnt points
  if [ -d "/$mnt_base_dir/$mnt_name" ] && [[ $(ls -A "/$mnt_base_dir/$mnt_name") ]]
  then
    i=1
    while [ -d "/$mnt_base_dir/${mnt_name}_$i" ] && [[ $(ls -A "/$mnt_base_dir/${mnt_name}_$i") ]]
    do
      # Suffix name by +1
      i=$(( $i + 1 ))
    done
    # Suffix the mnt name
    mnt_name="${mnt_name}_${i}"
  fi

  # New USB disk label
  disk_label="$mnt_name"

  # Erase / Wipe disks
  msg "Zapping, erasing and wiping disks..."
  while read dev
  do
    # Full device wipeout
    sgdisk --zap $dev >/dev/null 2>&1
    dd if=/dev/zero of=$dev bs=1M status=progress
    wipefs -a -f $dev >/dev/null 2>&1
    # Wait for pending udev events
    udevadm settle
    info "Zapped, destroyed & wiped device: $dev"
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $1 }' ) # file listing of disks to erase

  # Create primary partition
  msg "Partitioning, formatting & labelling new disk..."
  # Partition number start
  num=1
  # Create dev list
  inputdevLIST=()
  while read dev
  do
    # Create single partition
    echo 'type=83' | sfdisk $dev
    # Create new partition (part1)
    if [[ "$dev" =~ ^/dev/sd[a-z]$ ]]
    then
      # Format to default ext4
      mkfs.ext4 -Fc $dev$num
      # Wait for pending udev events
      udevadm settle
      # Create disk label
      e2label $dev$num $disk_label
      # Wait for pending udev events
      udevadm settle
      # Set new disk uuid var
      disk_uuid=$(blkid -s UUID -o value $dev$num 2> /dev/null)
      # Create device array
      inputdevLIST+=( "$(echo "$dev$num:$disk_uuid:$disk_label")" )
      info "Ext4 disk partition created: ${YELLOW}$dev$num${NC}"
      echo
    elif [[ $dev =~ ^/dev/nvme[0-9]n[0-9]$ ]]
    then
      # Format to default ext4
      mkfs.ext4 -F ${dev}p$num
      # Wait for pending udev events
      udevadm settle
      # Create disk label
      e2label ${dev}p$num $disk_label
      # Wait for pending udev events
      udevadm settle
      # Set new disk uuid var
      disk_uuid=$(blkid -s UUID -o value ${dev}p$num 2> /dev/null)
      # Create device array
      inputdevLIST+=( "$(echo "${dev}p$num:$disk_uuid:$disk_label")" )
      info "Ext4 disk partition created: ${YELLOW}${dev}p$num${NC}"
      echo
    fi
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $1 }' ) # file listing of disks

  # Disk Over-Provisioning
  msg "Applying over-provisioning factor % to disk..."
  while read dev
  do
    if [ "$(hdparm -I $dev 2> /dev/null | awk -F':' '/Nominal Media Rotation Rate/ { print $2 }' | sed 's/ //g')" = 'SolidStateDevice' ]
    then
      # Set over-provisioning factor %
      tune2fs -m $disk_op_ssd $dev > /dev/null
      # Wait for pending udev events
      udevadm settle
      info "SSD disk reserved block percentage: ${YELLOW}${disk_op_ssd}%${NC}"
      echo
    else
      # Set over-provisioning factor %
      tune2fs -m $disk_op_rota $dev > /dev/null
      # Wait for pending udev events
      udevadm settle
      info "Rotational disk reserved block percentage: ${YELLOW}${disk_op_rota}%${NC}"
      echo
    fi
  done < <( printf '%s\n' "${inputdevLIST[@]}" | awk -F':' '{ print $1 }' ) # file listing of new devs

  # Set SRC mount point
  PVE_SRC_MNT="/$mnt_base_dir/$mnt_name"
fi

#---- TYPE02: Mount existing disk
if [ "$BUILD_TYPE" = TYPE02 ]
then
  # set mnt base dir
  if [ "$input_tran_arg" = usb ]
  then
    # Set mnt dir (base dir)
    mnt_base_dir="media"
  else
    # Set mnt dir (base dir)
    mnt_base_dir="mnt"
  fi

  # Disk uuid
  disk_uuid=$(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $11 }')

  # Get existing disk label name
  existing_disk_label=$(blkid -s LABEL -o value /dev/disk/by-uuid/$disk_uuid)

  # Set default mnt point name
  mnt_name="nas_basic_$input_tran_arg"

  # Remove any existing mount points
  while IFS=':' read dev uuid label
  do
    # Remove UUID from /etc/fstab
    if [ -n "$uuid" ]
    then
      sed -i "/^UUID=$uuid/d" /etc/fstab
    fi
    # Remove label from /etc/fstab
    if [ -n "$label" ]
    then
      sed -i "/^LABEL=$label/d" /etc/fstab
    fi
    # Remove dev from /etc/fstab
    if [ -n "$dev" ]
    then
      sed -i "\|^${dev} |d" /etc/fstab
    fi
    # Check for existing mnt points
    if [[ $(findmnt -n -S $dev) ]] && [ -n "$dev" ]
    then
      # Get existing mount point
      existing_mnt_point=$(lsblk -no mountpoint $dev)
      # Umount dev
      umount -f -q $dev > /dev/null 2>&1 || /bin/true
      # Remove mnt point
      rm -R -f $existing_mnt_point 2> /dev/null
    fi
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' -v OFS=':' '{ print $1, $11, $13 }' ) # dev device listing

  # Check for existing mnt points
  if [ -d "/$mnt_base_dir/$mnt_name" ] && [[ $(ls -A "/$mnt_base_dir/$mnt_name") ]]
  then
    i=1
    while [ -d "/$mnt_base_dir/${mnt_name}_$i" ] && [[ $(ls -A "/$mnt_base_dir/${mnt_name}_$i") ]]
    do
      # Suffix name by +1
      i=$(( $i + 1 ))
    done
    # Suffix the mnt name
    mnt_name="${mnt_name}_${i}"
  fi

  # New USB disk label
  disk_label="$mnt_name"

  # Validate disk label name
  if [ ! "$existing_disk_label" = $disk_label  ]
  then
    # Set disk label
    dev=$(blkid -o device -t UUID="$disk_uuid" | awk 'NR==1{print $1}')
    e2label $dev $disk_label
    # Wait for pending udev events
    udevadm settle
  fi

  # Disk Over-Provisioning
  msg "Applying over-provisioning factor % to disk..."
  while read dev
  do
    if [[ "$(hdparm -I $dev 2> /dev/null | awk -F':' '/Nominal Media Rotation Rate/ { print $2 }' | sed 's/ //g')" == 'SolidStateDevice' ]]
    then
      # Set over-provisioning factor %
      tune2fs -m $disk_op_ssd $dev > /dev/null
      info "SSD disk reserved block percentage: ${YELLOW}${disk_op_ssd}%${NC}"
      echo
    else
      # Set over-provisioning factor %
      tune2fs -m $disk_op_rota $dev > /dev/null
      info "Rotational disk reserved block percentage: ${YELLOW}${disk_op_rota}%${NC}"
      echo
    fi
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $1 }' ) # file listing of new devs

  # Set SRC mount point
  PVE_SRC_MNT="/$mnt_base_dir/$mnt_name"
fi

#---- TYPE04: Destroy, wipe and use partition
if [ "$BUILD_TYPE" = TYPE04 ]
then
  # Set mnt base dir
  if [ "$input_tran_arg" = usb ]
  then
    # Set mnt dir (base dir)
    mnt_base_dir="media"
  else
    # Set mnt dir (base dir)
    mnt_base_dir="mnt"
  fi

  # Disk uuid
  disk_uuid=$(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $11 }')

  # Get existing disk label name
  existing_disk_label=$(blkid -s LABEL -o value /dev/disk/by-uuid/$disk_uuid)

  # Set default mnt point name
  mnt_name="nas_basic_$input_tran_arg"

  # Remove any existing mount points
  while IFS=':' read dev uuid label
  do
    # Remove UUID from /etc/fstab
    if [ -n "$uuid" ]
    then
      sed -i "/^UUID=$uuid/d" /etc/fstab
    fi
    # Remove label from /etc/fstab
    if [ -n "$label" ]
    then
      sed -i "/^LABEL=$label/d" /etc/fstab
    fi
    # Remove dev from /etc/fstab
    if [ -n "$dev" ]
    then
      sed -i "\|^${dev} |d" /etc/fstab
    fi
    # Check for existing mnt points
    if [[ $(findmnt -n -S $dev) ]] && [ -n "$dev" ]
    then
      # Get existing mount point
      existing_mnt_point=$(lsblk -no mountpoint $dev)
      # Umount dev
      umount -f -q $dev > /dev/null 2>&1 || /bin/true
      # Remove mnt point
      rm -R -f $existing_mnt_point 2> /dev/null
    fi
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' -v OFS=':' '{ print $1, $11, $13 }' ) # dev device listing

  # Check for existing mnt points
  if [ -d "/$mnt_base_dir/$mnt_name" ] && [[ $(ls -A "/$mnt_base_dir/$mnt_name") ]]
  then
    i=1
    while [ -d "/$mnt_base_dir/${mnt_name}_$i" ] && [[ $(ls -A "/$mnt_base_dir/${mnt_name}_$i") ]]
    do
      # Suffix name by +1
      i=$(( $i + 1 ))
    done
    # Suffix the mnt name
    mnt_name="${mnt_name}_${i}"
  fi

  # New USB disk label
  disk_label="$mnt_name"

  # Erase / Wipe disks
  msg "Zapping, Erasing and Wiping disks..."
  while read dev
  do
    dd if=/dev/zero of=$dev bs=1M status=progress
    wipefs -a -f $dev >/dev/null 2>&1
    # Wait for pending udev events
    udevadm settle
    info "Zapped, destroyed & wiped device: $dev"
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $1 }' ) # file listing of disks to erase

  # Format existing partition
  msg "Partitioning, formatting & labelling new disk..."
  inputdevLIST=()
  while read dev
  do
    if [[ "$dev" =~ ^/dev/sd[a-z][1-9]$ ]]
    then
      # Format to default ext4
      mkfs.ext4 -Fc $dev
      # Wait for pending udev events
      udevadm settle
      # Create disk label
      e2label $dev $disk_label
      # Wait for pending udev events
      udevadm settle
      # Set new disk uuid var
      disk_uuid=$(blkid -s UUID -o value $dev 2> /dev/null)
      # Create device array
      inputdevLIST+=( "$(echo "$dev:$disk_uuid:$disk_label")" )
      info "Ext4 disk partition created: ${YELLOW}$dev${NC}"
      echo
    elif [[ $dev =~ ^/dev/nvme[0-9]n[0-9]p[0-9]$ ]]
    then
      # Format to default ext4
      mkfs.ext4 -F $dev
      # Wait for pending udev events
      udevadm settle
      # Create disk label
      e2label $dev $disk_label
      # Wait for pending udev events
      udevadm settle
      # Set new disk uuid var
      disk_uuid=$(blkid -s UUID -o value $dev 2> /dev/null)
      # Create device array
      inputdevLIST+=( "$(echo "$dev:$disk_uuid:$disk_label")" )
      info "Ext4 disk partition created: ${YELLOW}$dev${NC}"
      echo
    fi
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $1 }' ) # file listing of disks

  # Disk Over-Provisioning
  msg "Applying over-provisioning factor % to disk..."
  while read dev
  do
    if [ "$(hdparm -I $dev 2> /dev/null | awk -F':' '/Nominal Media Rotation Rate/ { print $2 }' | sed 's/ //g')" = 'SolidStateDevice' ]
    then
      # Set over-provisioning factor %
      tune2fs -m $disk_op_ssd $dev > /dev/null
      # Wait for pending udev events
      udevadm settle
      info "SSD disk reserved block percentage: ${YELLOW}${disk_op_ssd}%${NC}"
      echo
    else
      # Set over-provisioning factor %
      tune2fs -m $disk_op_rota $dev > /dev/null
      # Wait for pending udev events
      udevadm settle
      info "Rotational disk reserved block percentage: ${YELLOW}${disk_op_rota}%${NC}"
      echo
    fi
  done < <( printf '%s\n' "${inputdevLIST[@]}" | awk -F':' '{ print $1 }' ) # file listing of new devs

  # Set SRC mount point
  PVE_SRC_MNT="/$mnt_base_dir/$mnt_name"
fi

#---- PVE disk mount ---------------------------------------------------------------

if [ "$BUILD_TYPE" = TYPE01 ] || [ "$BUILD_TYPE" = TYPE02 ] || [ "$BUILD_TYPE" = TYPE04 ]
then
  if [ "$input_tran_arg" = usb ]
  then
    #---- USB service
    # USB reset
    usb_reset
    # Get the device path associated with the UUID
    device_path=$(blkid -l -o device -t UUID="$disk_uuid")
    # Get the mount point of the device
    mount_point=$(findmnt -n -o TARGET --first-only "$device_path")
    # Remove any old mount (umount)
    if [ -n "$mount_point" ]
    then
      umount -fq $mount_point
    fi
    # Copy latest udev rule version
    cp -f $COMMON_DIR/bash/src/80-mount-usb-to-media-by-label.rules /etc/udev/rules.d/
    # Activate udev rules
    udevadm control --reload-rules
    # Trigger add event for dev
    trig_dev=$(blkid -t UUID=$disk_uuid -o device | awk -F/ '{print $NF}')
    udevadm trigger --action=change --sysname-match=$trig_dev
    # Check udev event usb mnt dir exists
    cnt=10 # Sets attempt number
    for i in $(seq 1 $cnt)
    do
      if [ -d "$PVE_SRC_MNT" ] && [[ $(ls -A "$PVE_SRC_MNT") ]]
      then
        # Print display msg
        info "Disk mount created: ${YELLOW}$PVE_SRC_MNT${NC}\n       (Disk Label: $disk_label)"
        echo
        # Break on success
        break
      else
        sleep 1
        if [ $i -eq $cnt ]
        then
          # Print display msg
          warn "Directory '$PVE_SRC_MNT' does not exist. You have a USB issue to resolve.\nThe system checked ${cnt}x times.\nThe mount action is performed automatically by our udev rule '80-mount-usb-to-media-by-label.rules'. Check you do not have a conflicting udev rule (located in: /etc/udev/rules.d/) or a fstab entry for the particular disk, partition or shared folder being mounted.\n\nAlso try a different USB port and make sure its USB3.0 or later and use a external USB power supply if available.\n\nExiting the installer..."
          echo
          # Exit on fail
          exit 0
        fi
      fi
    done
  else
    #---- Onboard mount
    # Create PVE local disk mount
    mkdir -p "$PVE_SRC_MNT"
    # Create PVE local disk mount /etc/fstab
    echo -e "UUID=$disk_uuid $PVE_SRC_MNT ext4 defaults,nofail,rw,user_xattr,acl 0 0" >> /etc/fstab
    # Run mount command
    mount "$PVE_SRC_MNT"
    # Print display msg
    info "Disk mount created: ${YELLOW}$PVE_SRC_MNT${NC}\n       (Disk UUID: $disk_uuid)"
    echo
  fi
fi
#-----------------------------------------------------------------------------------