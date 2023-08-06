#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_create_lvm_build.sh
# Description:  Source script for building lvm disk storage
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Requires '/shared/pve_nas_bash_utility.sh'
# Loaded from parent 'pve_nas_create_storagediskbuild.sh'

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

#---- Static Variables -------------------------------------------------------------

# Basic storage disk label
basic_disklabel='(.*_hba|.*_usb|.*_onboard)$'

#---- Other Variables --------------------------------------------------------------

# USB Disk Storage minimum size (GB)
stor_min='30'

#---- LVM variables
# LVM Thin Pool auto extend values
autoextend_threshold='70'
autoextend_percent='20'

# LV Thinpool extents
lv_thinpool_extents='50%'

# VG metadatasize
vg_metadatasize='1024M'

# LV Thin Pool name
lv_thin_poolname='thinpool'

# LV Thin Pool poolmetadatasize
lv_thin_poolmetadatasize='1024M'

# LV Thin stripesize
lv_thin_stripesize='128k'

# LV stripesize
lv_stripesize='128k'

# LV Thin Pool chunksize
lv_thin_chunksize='128k'

# LV Thin Pool size
lv_thin_size='200M'

# LV Thin Volume virtualsize
lv_thinvol_virtualsize='200M'

# LV Name ( Use CT/VM hostname )
LV_NAME=$(echo "$HOSTNAME" | sed 's/-/_/g') # Hostname mod (change any '-' to '_')
if [[ $(lvs | grep "^\s*$LV_NAME") ]] || [[ $(ls -A /mnt/$LV_NAME 2> /dev/null) ]]
then
  i=1
  while [[ $(lvs | grep "^\s*${LV_NAME}_${i}") ]] || [[ $(ls -A /mnt/${LV_NAME}_${i} 2> /dev/null) ]]
  do
    i=$(( $i + 1 ))
  done
  LV_NAME=${LV_NAME}_$i
fi


# Set SRC mount point
PVE_SRC_MNT="/mnt/$LV_NAME"

# /etc/fstab mount options
fstab_options_LIST=()
while IFS= read -r line
do
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
#---- Body -------------------------------------------------------------------------

#---- Create LVM thin pool autoextend profile
lvmconfig --file /etc/lvm/profile/autoextend.profile --withcomments --config "activation/thin_pool_autoextend_threshold=$autoextend_threshold activation/thin_pool_autoextend_percent=$autoextend_percent"

#---- Select a LVM build option

section "Select a LVM build option"

while true
do
  # Create fs/disk lists for LVM, ZFS, Basic (onboard & usb)
  source $SHARED_DIR/pve_nas_fs_list.sh

  # Create labels
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${lvm_option_labels}" \
  | sed -e '$a\None. Exit this installer:::TYPE00' \
  | column -t -s ":" -N "LVM OPTIONS,DESCRIPTION,SIZE,TYPE" -H TYPE -T DESCRIPTION -c 150 -d)

  # Create values
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${lvm_option_values}" \
  | sed -e '$a\TYPE00:0')

  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect SELECTED "$OPTIONS_STRING"
  # Set LVM_BUILD
  LVM_BUILD=$(echo "$RESULTS" | awk -F':' '{ print $1 }')
  LVM_BUILD_VAR=$(echo "$RESULTS" | awk -F':' '{ print $2 }')

  #---- Destroy LVM
  if [ "$LVM_BUILD" = TYPE04 ]
  then
    # Set VG name
    VG_NAME="$LVM_BUILD_VAR"

    pve_disk_LIST=()
    pve_disk_LIST+=( "$(pvdisplay -S vgname=$VG_NAME -C -o pv_name --noheadings | sed 's/ //g')" )

    # Print display
    if [ ! "$(lvs $VG_NAME --noheadings -a -o lv_name | wc -l)" = 0 ]
    then
      print_DISPLAY=()
      print_DISPLAY+=( "$(printf "\t-- VG to be destroyed: $VG_NAME")" )
      print_DISPLAY+=( "$(printf "\t-- LV(s) to be destroyed: $(lvs $VG_NAME --noheadings -a -o lv_name | sed 's/ //g' | xargs | sed -e 's/ /, /g')")" )
    else
      print_DISPLAY=()
      print_DISPLAY+=( "$(printf "\t-- VG to be destroyed: $VG_NAME")" )
    fi

    msg_box "#### PLEASE READ CAREFULLY - DESTROY A LVM VOLUME GROUP  ####\n\nYou have chosen to destroy LVM VG '$VG_NAME' on PVE $(echo $(hostname)). This action will result in permanent data loss of all data stored in LVM VG '$VG_NAME'.\n\n$(printf '%s\n' "${print_DISPLAY[@]}")\n\nThe LVM VG '$VG_NAME' member disks including partitions will be permanently erased and made available for a new LVM build."
    echo
    while true
    do
      read -p "Do you want to destroy LVM VG '$VG_NAME' including member disks : [y/n]?" -n 1 -r YN
      echo
      case $YN in
        [Yy]*)
          msg "Destroying VG '$VG_NAME'..."
          # Umount LVs & delete FSTAB mount entry
          while read lv
          do
            # Check if lv mnt exists
            lv_mnt=$(mount | awk '{print $1}' | egrep ^.*-$lv$)
            if [ -n "${lv_mnt}" ]
            then
              # Umount
              umount -q "$lv_mnt"
              # Delete fstab entry
              sed -i.bak "\@^$lv_mnt@d" /etc/fstab
            fi
          done < <( lvs $VG_NAME --noheadings -o lv_name | sed 's/ //g' )

          # Destroy LVs
          while read lv
          do
            lvremove $VG_NAME/$lv -y 2> /dev/null
            if [ ! $? = 0 ]
            then
              warn "LVM logical volume '$VG_NAME/$lv' appears to be in use and cannot be deleted. Try another option or exit this installer and manually fix the problem ($VG_NAME/$lv may be in use by a existing VM or LXC)."
              echo
              break 2
            fi
          done < <( lvs $VG_NAME --noheadings -o lv_name | sed 's/ //g' )

          # Destroy VG
          # vg devs
          vg_dev_LIST=( $(pvdisplay -C --separator ':' -o pv_name,vg_name | egrep ^.*$VG_NAME$ | awk -F: '{gsub(/^[ \t]+/, "", $1); print $1}') )
          # Delete VG
          vgremove -f $VG_NAME -y 2> /dev/null
          # Delete partition
          while read dev
          do
            device=${dev%[0-9]}
            wipefs --all --force $device >/dev/null 2>&1
            dd if=/dev/urandom of=$device count=1 bs=1M conv=notrunc 2> /dev/null
          done < <( printf '%s\n' "${vg_dev_LIST[@]}" )

          # Destroy PV
          while read pv
          do
            pvremove $pv -y 2> /dev/null
          done < <( printf '%s\n' "${pve_disk_LIST[@]}" )

          info "VG '$VG_NAME' status: ${YELLOW}destroyed${NC}"
          storage_list # Update storage list array
          stor_LIST # Create a working list array
          echo
          break
          ;;
        [Nn]*)
          echo
          msg "You have chosen not to proceed with destroying VG '$VG_NAME'.\nTry again..."
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
  elif [ "$LVM_BUILD" = TYPE00 ]
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


#---- Type01: Mount an existing LV
if [ "$LVM_BUILD" = TYPE01 ]
then
  section "Mount an existing LV LVM"

  # Set LV Name
  LV_NAME="$LVM_BUILD_VAR"

  # Set VG Name
  VG_NAME=$(lvs --noheadings -o vg_name -S lv_name=$LV_NAME | sed 's/ //g')

  # Validate & set PVE mount point
  PVE_SRC_MNT="/mnt/$LV_NAME"
  if [[ $(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=$LV_NAME)) ]]
  then
    if [ "$(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=$LV_NAME | sed 's/ //g') -o target)" = $PVE_SRC_MNT ]
    then
      # Mount pre-exists ('1' pre-exists, '0' not exist)
      lv_mnt_status=1
    elif [ ! "$(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=$LV_NAME | sed 's/ //g') -o target)" = $PVE_SRC_MNT ]
    then
      # Modify existing target mount point
      PVE_SRC_MNT=$(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=$LV_NAME | sed 's/ //g') -o target)
      # Mount pre-exists ('1' pre-exists, '0' not exist)
      lv_mnt_status=1
    fi
  else
    if [[ $(mountpoint -q $PVE_SRC_MNT) ]]
    then
      # Target mount point conflict
      msg "The target mount point '$PVE_SRC_MNT' is in use by another target volume ( $(findmnt $PVE_SRC_MNT -n -o source) ). A new target mount point path has been created..."
      i=1
      while [[ -d "${PVE_SRC_MNT}_${i}" ]] && [[ $(findmnt -n "${PVE_SRC_MNT}_${i}") ]];
      do
        i=$(( $i + 1 ))
      done
      PVE_SRC_MNT=${PVE_SRC_MNT}_${i}
      # Mount pre-exists ('1' pre-exists, '0' not exist)
      lv_mnt_status=0
      info "New target mount point: ${YELLOW}$PVE_SRC_MNT${NC}"
      echo
    else
      # Mount pre-exists ('1' pre-exists, '0' not exist)
      lv_mnt_status='0'
    fi
  fi
fi


#---- Type02: Create LV in an existing Thin-pool
if [ "$LVM_BUILD" = TYPE02 ]
then
  section "Create LV in an existing Thin-pool"

  # Set Thin-pool name
  lv_thin_poolname="$LVM_BUILD_VAR"

  # Set VG Name
  VG_NAME=$(lvs --noheadings -o vg_name -S lv_name=$lv_thin_poolname | sed 's/ //g')

  # Mount pre-exists ('1' pre-exists, '0' not exist)
  lv_mnt_status='0'
fi


#---- Type03: Create LV in an existing VG
if [ "$LVM_BUILD" = TYPE03 ]
then
  section "Create LV in an existing VG"

  # Set VG name
  VG_NAME="$LVM_BUILD_VAR"

  # Mount pre-exists ('1' pre-exists, '0' not exist)
  lv_mnt_status=0

  # Create input disk list array
  inputdiskLIST=()
  while read -r line
  do
    inputdiskLIST+=( $(printf '%s\n' "${storLIST[@]}" | grep "^${line}:" 2> /dev/null) )
  done < <( pvdisplay -C --noheadings -o pv_name -S vgname=$VG_NAME | sed 's/ //g' 2> /dev/null )
fi


#---- TYPE05/06: Build a new LVM VG/LV (SSD and HDD)
if [ "$LVM_BUILD" = TYPE05 ] || [ "$LVM_BUILD" = TYPE06 ]
then
  section "Select disks for new LVM"
  # 1=PATH:2=KNAME:3=PKNAME:4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM

  # Mount pre-exists ('1' pre-exists, '0' not exist)
  lv_mnt_status=0

  # Disk count by type
  disk_CNT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v stor_min="$stor_min" -v input_tran="$input_tran" -v var="$LVM_BUILD_VAR" -v basic_disklabel="$basic_disklabel" \ 'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  {if ($5 ~ input_tran && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= stor_min && $10=var && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) { print $0 }}' | wc -l)

  # Select member disks
  msg_box "#### PLEASE READ CAREFULLY - SELECT LVM DISKS ####\n\nThe User has ${disk_CNT}x disk(s) available for their new LVM storage. If selecting for a USB NAS build the User can only select a single disk."
  echo

  # Make disk selection
  msg "The User must now select all member disk(s)."
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v stor_min="$stor_min" -v input_tran="$input_tran" -v ROTA="$LVM_BUILD_VAR" -v basic_disklabel="$basic_disklabel" \
  'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  {if ($5 ~ input_tran && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= stor_min && $10 == ROTA && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) { print $0 } }')
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v stor_min="$stor_min" -v input_tran="$input_tran" -v ROTA="$LVM_BUILD_VAR" -v basic_disklabel="$basic_disklabel" \
  'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
  {if ($5 ~ input_tran && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= stor_min && $10 == ROTA && $13 !~ basic_disklabel && $14 == 0 && $15 == 0)  { sub(/1/,"HDD",$10);sub(/0/,"SSD",$10); print $1, $6, $8, $10 } }' \
  | column -t -s :)
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  if [ "$input_tran_arg" = usb ]
  then
    singleselect_confirm SELECTED "$OPTIONS_STRING"
  else
    multiselect_confirm SELECTED "$OPTIONS_STRING"
  fi
  # Create input disk list array
  unset inputdiskLIST
  for i in "${RESULTS[@]}"
  do
    inputdiskLIST+=( $(echo $i) )
  done

  # Set LVM VG name (arg 'usb' prefixes name with 'vg-usb_etc')
  create_lvm_vgname_val "$input_tran_arg"
    
  # Erase / Wipe disks
  msg "Erasing disks..."
  while read dev
  do
    # Full device erase
    sgdisk --zap /dev/disk/by-id/$dev >/dev/null 2>&1
    #dd if=/dev/urandom of=/dev/disk/by-id/$dev bs=1M count=1 conv=notrunc 2>/dev/null
    wipefs --all --force /dev/disk/by-id/$dev >/dev/null 2>&1
    # Wait for pending udev events
    udevadm settle
    info "Erased device: $dev"
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $1 }' ) # file listing of disks to erase
  echo

  # Create primary partition
  num=1
  inputdevLIST=()
  while read dev
  do
    # Create single partition
    echo 'type=83' | sfdisk $dev
    # Create new dev list
    if [[ "$dev" =~ ^/dev/sd[a-z]$ ]]
    then
      inputdevLIST+=( "$(echo "${dev}${num}")" )
    elif [[ "$dev" =~ ^/dev/nvme[0-9]n[0-9]$ ]]
    then
      inputdevLIST+=( "$(echo "${dev}p${num}")" )
    fi
  done < <( printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' '{ print $1 }' ) # file listing of disks

  # Create PV
  while read dev
  do
    pvcreate --metadatasize $vg_metadatasize -y -ff $dev
  done < <( printf '%s\n' "${inputdevLIST[@]}" ) # file listing of devs

  # Create VG
  vgcreate $VG_NAME $(printf '%s\n' "${inputdevLIST[@]}" | xargs | sed 's/ *$//g')
fi

#---- Create Thin-Pool
if [ "$LVM_BUILD" = TYPE03 ] || [ "$LVM_BUILD" = TYPE05 ] || [ "$LVM_BUILD" = TYPE06 ]
then
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
  inputRAIDLEVEL="$RESULTS"

  # Determine disk cnt parity ( prune smallest disk if odd cnt for Raid10 )
  if [ ! $((number%${#inputdiskLIST[@]})) = 0 ] && [ "$inputRAIDLEVEL" = "raid10" ]
  then
    # Set smallest member disk for removal for Raid10 build
    inputdiskLISTPARITY=1
    deleteDISK=( $(printf '%s\n' "${inputdiskLIST[@]}" | awk -F':' 'NR == 1 {line = $0; min = $8} \
    NR > 1 && $3 < min {line = $0; min = $8} \
    END{print line}') )
    for target in "${deleteDISK[@]}"
    do
      for i in "${!inputdiskLIST[@]}"
      do
        if [[ ${inputdiskLIST[i]} = $target ]]
        then
          unset 'inputdiskLIST[i]'
        fi
      done
    done
  else
    inputdiskLISTPARITY=0
  fi
  
  # Create LVM RAID Thin Pool
  msg "Creating LVM RAID Thin Pool '$lv_thin_poolname'..."
  if [ "$inputRAIDLEVEL" = 'raid0' ]
  then
    # RAID 0
    if [ ${#inputdevLIST[@]} = 1 ]
    then
      # Create LV thinpool
      lvcreate \
      --thin $VG_NAME/$lv_thin_poolname \
      --chunksize $lv_thin_chunksize \
      --poolmetadatasize $lv_thin_poolmetadatasize \
      --extents ${lv_thinpool_extents}VG
      # Set thin autoextend
      lvchange --metadataprofile autoextend $VG_NAME/$lv_thin_poolname
      lvchange --monitor y $VG_NAME/$lv_thin_poolname
    else
      # Create LV thinpool
      lvcreate \
      --thin $VG_NAME/$lv_thin_poolname \
      --chunksize $lv_thin_chunksize \
      --poolmetadatasize $lv_thin_poolmetadatasize \
      --stripes ${#inputdiskLIST[@]} \
      --stripesize $lv_thin_stripesize \
      --extents ${lv_thinpool_extents}VG
      # Set thin autoextend
      lvchange --metadataprofile autoextend $VG_NAME/$lv_thin_poolname
      lvchange --monitor y $VG_NAME/$lv_thin_poolname
    fi
  elif [ "$inputRAIDLEVEL" = 'raid1' ]
  then
    # RAID 1
    # Create LV thinpool
    lvcreate \
    --mirrors 1 \
    --type raid1 \
    --extents ${lv_thinpool_extents}VG \
    --name $lv_thin_poolname $VG_NAME
    lvcreate \
    --mirrors 1 \
    --type raid1 \
    --size $lv_thin_poolmetadatasize \
    --name thin_meta $VG_NAME
    lvconvert -y \
    --thinpool $VG_NAME/$lv_thin_poolname \
    --poolmetadata $VG_NAME/thin_meta \
    --chunksize $lv_thin_chunksize
    # Set thin autoextend
    lvchange --metadataprofile autoextend $VG_NAME/$lv_thin_poolname
    lvchange --monitor y $VG_NAME/$lv_thin_poolname
  elif [ "$inputRAIDLEVEL" = 'raid5' ]
  then
    # RAID 5
    STRIPECNT=$(( ${#inputdevLIST[@]} - 1 ))
    # Create LV thinpool
    lvcreate \
    --type raid5 \
    --stripes $STRIPECNT \
    --stripesize $lv_stripesize \
    --extents ${lv_thinpool_extents}VG \
    --name $lv_thin_poolname $VG_NAME
    lvcreate \
    --type raid5 \
    --stripes $STRIPECNT \
    --stripesize $lv_stripesize \
    --size $lv_thin_poolmetadatasize \
    --name thin_meta $VG_NAME
    lvconvert -y \
    --thinpool $VG_NAME/$lv_thin_poolname \
    --poolmetadata $VG_NAME/thin_meta \
    --chunksize $lv_thin_chunksize
    # Set thin autoextend
    lvchange --metadataprofile autoextend $VG_NAME/$lv_thin_poolname
    lvchange --monitor y $VG_NAME/$lv_thin_poolname
  elif [ "$inputRAIDLEVEL" = 'raid6' ]
  then
    # RAID 6
    STRIPECNT=$(( ${#inputdevLIST[@]} - 2 ))
    # Create LV thinpool
    lvcreate \
    --type raid6 \
    --stripes ${STRIPECNT} \
    --stripesize $lv_stripesize \
    --extents ${lv_thinpool_extents}VG \
    --name $lv_thin_poolname $VG_NAME
    lvcreate \
    --type raid6 \
    --stripes ${STRIPECNT} \
    --stripesize $lv_stripesize \
    --size $lv_thin_poolmetadatasize \
    --name thin_meta $VG_NAME
    lvconvert -y \
    --thinpool $VG_NAME/$lv_thin_poolname \
    --poolmetadata ${VG_NAME}/thin_meta \
    --chunksize ${lv_thin_chunksize}
    # Set thin autoextend
    lvchange --metadataprofile autoextend $VG_NAME/$lv_thin_poolname
    lvchange --monitor y $VG_NAME/$lv_thin_poolname
  elif [ "$inputRAIDLEVEL" = 'raid10' ]
  then
    # RAID 10
    # Create LV thinpool
    lvcreate \
    --mirrors 1 \
    --type raid10 \
    --extents ${lv_thinpool_extents}VG \
    --stripesize $lv_stripesize \
    --name $lv_thin_poolname $VG_NAME
    lvcreate \
    --mirrors 1 \
    --type raid10 \
    --size $lv_thin_poolmetadatasize \
    --stripesize $lv_stripesize \
    --name thin_meta $VG_NAME
    lvconvert -y \
    --thinpool $VG_NAME/$lv_thin_poolname \
    --poolmetadata $VG_NAME/thin_meta \
    --chunksize $lv_thin_chunksize
    # Set thin autoextend
    lvchange --metadataprofile autoextend $VG_NAME/$lv_thin_poolname
    lvchange --monitor y $VG_NAME/$lv_thin_poolname
  fi
  info "Thin-pool created: ${YELLOW}$lv_thin_poolname${NC}"
  echo
fi


#---- Create LV
if [ "$LVM_BUILD" = TYPE02 ] || [ "$LVM_BUILD" = TYPE03 ] || [ "$LVM_BUILD" = TYPE05 ] || [ "$LVM_BUILD" = TYPE06 ]
then
  msg "Creating LV '$LV_NAME'..."
  # Create thin volume
  lvcreate \
  --virtualsize 2G \
  --thin $VG_NAME/$lv_thin_poolname \
  --name $LV_NAME
  # Extend volume to VG max
  lvextend --extents 100%VG $VG_NAME/$LV_NAME
  info "LV created: ${YELLOW}$LV_NAME${NC}"
  echo
fi

#---- Set FS Type
if [[ ! $(lsblk --noheadings -o fstype /dev/$VG_NAME/$LV_NAME) =~ (ext4|ext3|btrfs|xfs) ]]
then
  msg "The installer has detected LV '$LV_NAME' has no detectable Linux File System. In the next step the User can select a Linux File System. Formatting will permanently destroy all existing data stored on LV '$LV_NAME'. The User has been warned..."
  echo
  # Menu options
  OPTIONS_VALUES_INPUT=( "ext4" "ext3" "btrfs" "xfs" "TYPE00" )
  OPTIONS_LABELS_INPUT=( "Linux File Systems - ext4 ( Recommended )" "Linux File Systems - ext3" "Linux File Systems - btrfs" "Linux File Systems - xfs" "None - Exit this installer" )
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"
  # Exit action
  if [ "$RESULTS" = 'TYPE00' ]
  then
    msg "You have chosen not to proceed. Aborting. Bye..."
    echo
    exit 0
  fi
  LV_FSTYPE="$RESULTS"
  echo
else
  LV_FSTYPE=$(lsblk --noheadings -o fstype /dev/$VG_NAME/$LV_NAME)
fi


#---- Set /etc/fstab options & mkfs arg
if [ "$LV_FSTYPE" = 'ext4' ]
then
  # Options for EXT4
  mkfs_arg='-F'
  if [ "$lv_mnt_status" = 0 ]
  then
    fstab_options=( "defaults" "rw" "user_xattr" "acl" ) # Edit options here
    fstab_options=$(printf '%s\n' ${fstab_options[@]} | uniq | xargs | sed -r 's/[[:space:]]/,/g')
  elif [ "$lv_mnt_status" = 1 ]
  then
    fstab_options=( "defaults" "rw" "user_xattr" "acl" ) # Edit options here
    fstab_options+=( $(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=$LV_NAME) -o options | sed 's/,/\n/g') )
    fstab_options=$(printf '%s\n' ${fstab_options[@]} | uniq | xargs | sed -r 's/[[:space:]]/,/g')
  fi
elif [ "$LV_FSTYPE" = 'ext3' ]
then
  # Options for EXT3
  mkfs_arg='-F'
  if [ "$lv_mnt_status" = 0 ]
  then
    fstab_options=( "defaults" "rw" "user_xattr" "acl" ) # Edit options here
    fstab_options=$(printf '%s\n' ${fstab_options[@]} | uniq | xargs | sed -r 's/[[:space:]]/,/g')
  elif [ "$lv_mnt_status" = 1 ]
  then
    fstab_options=( "defaults" "rw" "user_xattr" "acl" ) # Edit options here
    fstab_options+=( $(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=$LV_NAME) -o options | sed 's/,/\n/g') )
    fstab_options=$(printf '%s\n' ${fstab_options[@]} | uniq | xargs | sed -r 's/[[:space:]]/,/g')
  fi
elif [ "$LV_FSTYPE" = 'btrfs' ]
then
  # Options for BTRFS
  mkfs_arg='-f'
  if [ "$lv_mnt_status" = 0 ]
  then
    fstab_options=( "defaults" "rw" ) # Edit options here
    fstab_options=$(printf '%s\n' ${fstab_options[@]} | uniq | xargs | sed -r 's/[[:space:]]/,/g')
  elif [ "$lv_mnt_status" = 1 ]
  then
    fstab_options=( "defaults" "rw" ) # Edit options here
    fstab_options+=( $(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=$LV_NAME) -o options | sed 's/,/\n/g') )
    fstab_options=$(printf '%s\n' ${fstab_options[@]} | uniq | xargs | sed -r 's/[[:space:]]/,/g')
  fi
elif [ "$LV_FSTYPE" = 'xfs' ]
then
  # Options for XFS
  mkfs_arg='-f'
  if [ "$lv_mnt_status" = 0 ]
  then
    fstab_options=( "defaults" "rw" ) # Edit options here
    fstab_options=$(printf '%s\n' ${fstab_options[@]} | uniq | xargs | sed -r 's/[[:space:]]/,/g')
  elif [ "$lv_mnt_status" = 1 ]
  then
    fstab_options=( "defaults" "rw" ) # Edit options here
    fstab_options+=( $(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=$LV_NAME) -o options | sed 's/,/\n/g') )
    fstab_options=$(printf '%s\n' ${fstab_options[@]} | uniq | xargs | sed -r 's/[[:space:]]/,/g')
  fi
fi

# # Format LV volume
# mkfs.$LV_FSTYPE $mkfs_arg /dev/mapper/$VG_NAME-$LV_NAME

#---- Complete LVM build
if [ "$lv_mnt_status" = 0 ]
then
  # Umount any existing mount point
  umount -q $(lvs --noheadings -o lv_path -S lv_name=$LV_NAME | sed 's/ //g')
  umount -q /dev/mapper/$VG_NAME-$LV_NAME
  umount -q $PVE_SRC_MNT 2> /dev/null
  # Clean /etc/fstab of any conflicts
  sed -i "\|^$(lvs --noheadings -o lv_path -S lv_name=$LV_NAME | sed 's/ //g')|d" /etc/fstab
  sed -i "\|^/dev/mapper/$VG_NAME-$LV_NAME|d" /etc/fstab
  sed -i "\|$PVE_SRC_MNT|d" /etc/fstab
  # Format LV volume
  mkfs.$LV_FSTYPE $mkfs_arg /dev/mapper/$VG_NAME-$LV_NAME
  # Create mount point
  if [ "$input_tran_arg" = "" ] || [ "$input_tran_arg" = 'onboard' ]
  then
    echo "/dev/mapper/$VG_NAME-$LV_NAME $PVE_SRC_MNT $LV_FSTYPE $fstab_options 0 0" >> /etc/fstab
    mkdir -p $PVE_SRC_MNT
    mount $PVE_SRC_MNT
    info "LV mount created: ${YELLOW}$PVE_SRC_MNT${NC}"
  elif [ "$input_tran_arg" = 'usb' ]
  then
    mkdir -p $PVE_SRC_MNT
    LV_UUID=$(lvs --noheadings -o uuid -S lv_name=$LV_NAME | sed 's/ //g' 2> /dev/null)
    echo -e "UUID=$LV_UUID $PVE_SRC_MNT $LV_FSTYPE $fstab_options 0 0" >> /etc/fstab
    mount $PVE_SRC_MNT
    info "LV mount created: ${YELLOW}$PVE_SRC_MNT${NC}\n       (LV UUID: $LV_UUID)"
  fi
elif [ "$lv_mnt_status" = '1' ]
then
  # Umount any existing mount point
  umount -q $(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=$LV_NAME) -o target)
  # Clean /etc/fstab of any conflicts
  sed -i "\|^$(findmnt -n $(lvs --noheadings -o lv_path -S lv_name=$LV_NAME) -o target)|d" /etc/fstab
  sed -i "\|^/dev/mapper/$VG_NAME-$LV_NAME|d" /etc/fstab
  sed -i "\|$PVE_SRC_MNT|d" /etc/fstab
  # Create mount point
  if [ "$input_tran_arg" = "" ] || [ "$input_tran_arg" = 'onboard' ]
  then
    echo "/dev/mapper/$VG_NAME-$LV_NAME $PVE_SRC_MNT $LV_FSTYPE $fstab_options 0 0" >> /etc/fstab
    mkdir -p $PVE_SRC_MNT
    mount $PVE_SRC_MNT
    info "LV mount created: ${YELLOW}$PVE_SRC_MNT${NC}"
  elif [ "$input_tran_arg" = 'usb' ]
  then
    mkdir -p $PVE_SRC_MNT
    LV_UUID=$(lvs --noheadings -o uuid -S lv_name=$LV_NAME | sed 's/ //g' 2> /dev/null)
    echo -e "UUID=$LV_UUID $PVE_SRC_MNT $LV_FSTYPE $fstab_options 0 0" >> /etc/fstab
    mount $PVE_SRC_MNT
    info "LV mount created: ${YELLOW}$PVE_SRC_MNT${NC}\n       (LV UUID: $LV_UUID)"
  fi
fi
#-----------------------------------------------------------------------------------