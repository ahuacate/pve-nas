#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_select_fs_build.sh
# Description:  Select storage fs for NAS internal SATA or Nvme or USB disk setup
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# PVE NAS bash utility
source $COMMON_DIR/nas/src/nas_bash_utility.sh

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
basic_disklabel='(.*_hba(_[0-9])?|.*_usb(_[0-9])?|.*_onboard(_[0-9])?)$'

#---- Other Variables --------------------------------------------------------------

# USB Disk Storage minimum size (GB)
stor_min='5'

#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Clean out inactive/dormant /etc/fstab mounts
while read target
do
  if [[ ! $(findmnt $target -n -o source) ]]
  then
    msg "Deleting inactive mount point..."
    sed -i "\|$target|d" /etc/fstab
    info "Deleted inactive mount point: ${YELLOW}$target${NC}"
    echo
  fi
done < <( cat /etc/fstab | awk '$2 ~ /^\/mnt\/.*/ {print $2}' ) # /mnt mount point listing

# Wakeup USB disks
wake_usb

# Create storage list array
storage_list

# Create a working list array
stor_LIST

#---- Create fs/disk lists by type (lvm,zfs,basic)

# Create fs/disk lists for LVM, ZFS, Basic (onboard & usb)
source $SHARED_DIR/pve_nas_fs_list.sh


# # LVM options
# lvm_options=$(printf '%s\n' "${storLIST[@]}" | awk -F':' '$5 != "usb"' | awk -F':' -v stor_min="$stor_min" -v input_tran="$input_tran" -v basic_disklabel="$basic_disklabel" \
# 'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8}  \
# # Type01: Mount an existing LV
# {if($1 !~ /.*(root|tmeta|tdata|tpool|swap)$/ && $5 ~ input_tran && $9 == "lvm" && $13 !~ basic_disklabel && $15 == 0 && (system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -v 'thin-pool' | grep -q 'thin' > /dev/null") == 0 || system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -v 'thin-pool' | grep -q 'linear' > /dev/null") == 0)) \
# {cmd = "lvs " $14 " --noheadings -o lv_name | grep -v 'thinpool' | uniq | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline lv_list; close(cmd); print "Mount an existing LV", "Available LVs - "lv_list, "-", $8, $14, "TYPE01"}} \
# # Type02: Create LV in an existing Thin-pool
# {if($1 !~ /.*(root|tmeta|tdata|tpool|swap)$/ && $5 ~ input_tran && $4 == "" && $9 == "lvm" && $13 !~ basic_disklabel && $15 == 0 && system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -q 'thin-pool' > /dev/null") == 0 ) \
# {cmd = "lvs " $14 " --noheadings -o pool_lv | uniq | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline thin_list; close(cmd); print "Create LV in an existing Thin-pool", "Available pools - "thin_list, "-", $8, $14, "TYPE02"}} \
# # Type03: Create LV in an existing VG
# {if ($5 ~ input_tran && $4 == "LVM2_member" && $13 !~ basic_disklabel && $15 == 0) \
# print "Create LV in an existing VG", "VG name - "$14, "-", $8, $14, "TYPE03" } \
# # Type04: Destroy VG
# {if ($5 ~ input_tran && $4 == "LVM2_member" && $13 !~ basic_disklabel && $15 == 0) { cmd = "lvs " $14 " --noheadings -o lv_name | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline $16; close(cmd); print "Destroy VG ("$14")", "Destroys LVs/Pools - "$16, "-", $8, $14, "TYPE04" }} \
# # Type05: Build a new LVM VG/LV - SSD
# {if ($5 ~ input_tran && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= stor_min && $10 == 0 && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) { ssd_count++ }} END { if (ssd_count >= 1) print "Build a new LVM VG/LV - SSD", ssd_count"x SSD disks", $5, "-", "-", "TYPE05" } \
# # Type05: Build a new LVM VG/LV - HDD
# {if ($5 ~ input_tran && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= stor_min && $10 == 1 && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) { hdd_count++ }} END { if (hdd_count >= 1) print "Build a new LVM VG/LV - HDD", hdd_count"x HDD disks", $5, "-", "-", "TYPE06" }' | sort -t: -us -k 1,1 -k 2,2 -k 5,5 \
# | awk -F':' '!seen[$1$2$4$5]++' \
# | sed '1 i\LVM OPTIONS:DESCRIPTION::SIZE:VG NAME:SELECTION')
# # ZFS options
# zfs_options=$(printf '%s\n' "${storLIST[@]}" | awk -F':' '$5 != "usb"' | awk -F':' -v stor_min="$stor_min" -v input_tran="$input_tran" -v basic_disklabel="$basic_disklabel" 'BEGIN{OFS=FS} $8 ~ /G$/ {size=0.0+$8} \
# # Use existing ZPool
# {if ($5 ~ input_tran && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $13 !~ basic_disklabel && $14!=/[0-9]+/ && $15 == 0) print "Use Existing ZPool", "-", "-", $8, $14, "TYPE01" } \
# # Destroy & Wipe ZPool
# {if ($5 ~ input_tran && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $13 !~ basic_disklabel && $14!=/[0-9]+/ && $15 == 0) print "Destroy & Wipe ZPool", "-", "-", $8, $14, "TYPE02" } \
# # Create new ZPool - SSD
# {size=0.0+$8; if ($5 ~ input_tran && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= stor_min && $10 == 0 && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) { ssd_count++ }} END { if (ssd_count >= 1) print "Create new ZPool - SSD", ssd_count"x SSD disks", "-", "-", "-", "TYPE03" } \
# # Create new ZPool - HDD
# {size=0.0+$8; if ($5 ~ input_tran && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= stor_min && $10 == 1 && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) { hdd_count++ }} END { if (hdd_count >= 1) print "Create new ZPool - HDD", hdd_count"x HDD disks", "-", "-", "-", "TYPE04" }' \
# | awk -F':' '!seen[$1$5]++' \
# | sed '1 i\ZFS OPTIONS:DESCRIPTION::SIZE:ZFS POOL:SELECTION')

# # basic_options=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v stor_min="$stor_min" -v input_tran="$input_tran" -v basic_disklabel="$basic_disklabel"  \
# # 'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
# # # TYPE07: Basic single disk build
# # {if ($5 ~ input_tran && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= stor_min && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) print "Basic single disk build", "Format "$1" only", $8, "-", "TYPE07" } \
# # # TYPE08: Mount existing NAS storage disk
# # {if ($5 ~ input_tran && $3 != 0 && $4 == "ext4" && $9 == "part" && size >= stor_min && $13 ~ basic_disklabel && $14 == 0 && $15 == 0) print "Mount existing NAS storage disk", "Mount "$1" (disk label - "$13")", $8, "-", "TYPE08" } \
# # # TYPE09: Destroy and Wipe disk
# # {if ($5 ~ input_tran && $3 != 0 && $4 == "ext4" && $9 == "part" && size >= stor_min && $13 ~ basic_disklabel && $14 == 0 && $15 == 0) print "Destroy & wipe disk", "Destroy disk /dev/"$3" (disk label - "$13")", $8, "-", "TYPE09" }' \
# # | awk -F':' '!seen[$1$2$3$4]++' \
# # | sed '1 i\BASIC OPTIONS:DESCRIPTION:SIZE::SELECTION')

# # Basic single disk option
# basic_options=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v stor_min="$stor_min" -v input_tran="$input_tran" -v basic_disklabel="$basic_disklabel"  \
# 'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
# # TYPE07: Basic single disk build
# {if ($5 ~ input_tran && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= stor_min && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) print "Basic single disk build", "Format "$1" only", $5, $8, "-", "TYPE07" } \
# # TYPE08: Mount existing NAS storage disk
# {if ($5 ~ input_tran && $3 != 0 && $4 == "ext4" && $9 == "part" && size >= stor_min && $13 ~ basic_disklabel && $14 == 0 && $15 == 0) print "Mount existing NAS storage disk", "Mount "$1" (disk label - "$13")", $5, $8, "-", "TYPE08" } \
# # TYPE09: Destroy and Wipe disk
# {if ($5 ~ input_tran && $3 != 0 && $4 == "ext4" && $9 == "part" && size >= stor_min && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) print "Destroy & wipe disk", "Destroy disk /dev/"$3" (disk label - "$13")", $5, $8, "-", "TYPE09" } \
# # TYPE10: Destroy, wipe and use partition
# {if ($5 ~ input_tran && $3 != 0 && ($4 == "ext2" || $4 == "ext3" || $4 == "ext4" || $4 == "btrfs" || $4 == "xfs") && $9 == "part" && size >= stor_min && $14 == 0 && $15 == 0) print "Destroy, wipe & use partition", "Use partition "$1" (disk label - "$13")", $5, $8, "-", "TYPE10" }' \
# | awk -F':' '!seen[$1$2$3$4]++' \
# | sed '1 i\BASIC OPTIONS:DESCRIPTION::SIZE::SELECTION')

# # LVM option count
# lvm_option_cnt=$(echo "$lvm_options" | sed '/^$/d' | sed '1d' | wc -l)
# # ZFS option cnt
# zfs_option_cnt=$(echo "$zfs_options" | sed '/^$/d' | sed '1d' | wc -l)
# # Basic disk count
# basic_option_cnt=$(echo "$basic_options" | sed '/^$/d' | sed '1d' | awk -F':' '$3 != "usb"' | wc -l)
# # USB disk count
# usb_option_cnt=$(echo "$basic_options" | sed '/^$/d'| sed '1d' | awk -F':' '$3 == "usb"' | wc -l)

# # Check if any available storage is available (usb and onboard)
# # If no disk or storage is available then exits
# if [ "$usb_option_cnt" = 0 ] && [ "$lvm_option_cnt" = 0 ] && [ "$zfs_option_cnt" = 0 ] && [ "$basic_option_cnt" = 0 ]
# then
#   # Exit installer
#   warn "We could NOT detect any new available disks, LVs, ZPools or Basic NAS storage disks. New disk(s) might have been wrongly identified as 'system drives' if they contain Linux system or OS partitions. To fix this issue, manually format the disk erasing all data before running this installation again. All USB disks must have a data capacity greater than ${stor_min}G to be detected.
#   Exiting the installation script. Bye..."
#   echo
#   exit 0
# fi


#----- Set installer trans selection (check for USB devices)

# Sets trans (usb or onboard) if usb exist. If no usb then defaults to onboard
if [ ! "$usb_option_cnt" = 0 ]
then
  # Set installer trans selection
  msg "The installer has detected available USB devices. The User must select a storage option location..."

  # Create menu options
  OPTIONS_VALUES_INPUT=()
  OPTIONS_LABELS_INPUT=()
  # Onboard menu option
  if [ ! "$lvm_option_cnt" = 0 ] || [ ! "$zfs_option_cnt" = 0 ] || [ ! "$basic_option_cnt" = 0 ] 
  then
    OPTIONS_VALUES_INPUT+=( "onboard" )
    OPTIONS_LABELS_INPUT+=( "Onboard SAS/SATA/NVMe/HBA storage (internal)" )
  fi
  # USB menu option
  if [ ! "$usb_option_cnt" = 0 ]
  then
    OPTIONS_VALUES_INPUT+=( "usb" )
    OPTIONS_LABELS_INPUT+=( "USB disk storage (external)" )
  fi

  # Run menu selection
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"

  # Set installer Trans option
  if [ "$RESULTS" = 'usb' ]
  then
    # Set for usb only
    input_tran='(usb)'
    input_tran_arg='usb'
    # Wakeup USB disks
    wake_usb
    # Create storage list array
    storage_list
    # Create a working list array
    stor_LIST
  elif [ "$RESULTS" = 'onboard' ]
  then
    # Set for onboard only
    input_tran='(sata|ata|scsi|nvme)'
    input_tran_arg='onboard'
    # Create storage list array
    storage_list
    # Create a working list array
    stor_LIST
  fi
else
  # Set for onboard only
  input_tran='(sata|ata|scsi|nvme)'
  input_tran_arg='onboard'
fi


#---- Make selection (onboard)
if [ "$input_tran_arg" = 'onboard' ]
then
  display_msg="#### PLEASE READ CAREFULLY - STORAGE OPTIONS ####\n
  Depending on your available options you must choose either ZFS Raid or LVM Raid or a Basic single disk storage for your NAS build. Basic single disk storage uses a ext4 file system and is default for USB disk storage devices.

  If an option to create new storage is missing its because the disk(s) may have been wrongly identified as 'system disks' or the disk contains a working ZFS, LVM or Basic NAS file system. To fix this issue, exit the installation and use Proxmox PVE WebGUI to:

    --  destroy a ZFS ZPool or LVM VG (which resides on the missing disk)
    --  run PVE disk wipe tool on all the 'missing' disk devices

  The above operations will result in permanent loss of data so make sure you select the correct disk. Re-run the installation and the disks should be available for selection."

  # Display options
  display_LIST=()
  OPTIONS_VALUES_INPUT=()
  OPTIONS_LABELS_INPUT=()
  echo

  # LVM build
  if [ ! "$lvm_option_cnt" = 0 ] && [ "$input_tran_arg" = 'onboard' ]
  then
    display_LIST+=( "$(printf '%s\n' "${lvm_option_labels}" | sort -t: -us -k 1,1 -k 2,2 -k 5,5 | sed '1 i\LVM OPTIONS:DESCRIPTION::SIZE:VG NAME:SELECTION')" )
    display_LIST+=( ":" )
    OPTIONS_VALUES_INPUT+=("STORAGE_LVM")
    OPTIONS_LABELS_INPUT+=("LVM Raid filesystem")
  fi

  # ZFS build
  if [ ! "$zfs_option_cnt" = 0 ] && [ "$input_tran_arg" = 'onboard' ]
  then
    display_LIST+=( "$(printf '%s\n' "${zfs_option_labels}" | sed '1 i\ZFS OPTIONS:DESCRIPTION::SIZE:ZFS POOL:SELECTION')" )
    display_LIST+=( ":" )
    OPTIONS_VALUES_INPUT+=( "STORAGE_ZFS" )
    OPTIONS_LABELS_INPUT+=( "ZFS Raid filesystem" )
  fi

  # Basic build (onboard)
  if [ ! "$basic_option_cnt" = 0 ] && [ "$input_tran_arg" = 'onboard' ]
  then
    display_LIST+=( "$(printf '%s\n' "${basic_option_labels}" | awk -F':' '$3 != "usb"' | sed '1 i\BASIC OPTIONS:DESCRIPTION::SIZE::SELECTION')" )
    display_LIST+=( ":" )
    OPTIONS_VALUES_INPUT+=( "STORAGE_BASIC" )
    OPTIONS_LABELS_INPUT+=( "Basic single disk filesystem" )
  fi

  # Add Exit option
  OPTIONS_VALUES_INPUT+=( "STORAGE_EXIT" )
  OPTIONS_LABELS_INPUT+=( "None - Exit this installer" )

  # Display msg
  msg_box "$display_msg"

  # Print available option list
  printf '%s\n' "${display_LIST[@]}" | cut -d: -f1,2,4 | column -s : -t -N "1,2,3" -d -W 2 -c 120 | indent2

  # Menu selection for onboard device
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"
fi

#---- Make selection (usb)
if [ "$input_tran_arg" = 'usb' ]
then
  # Manual set Results var to usb
  RESULTS='STORAGE_BASIC'
fi

#---- Run selection ----------------------------------------------------------------

#---- Exit selection
if [ "$RESULTS" = 'STORAGE_EXIT' ]
then
  msg "You have chosen not to proceed. Aborting. Bye..."
  echo
  exit 0
fi

#---- Basic EXT4 STORAGE (onboard and usb)
if [ "$RESULTS" = 'STORAGE_BASIC' ]
then
  # Format disk
  source $SHARED_DIR/pve_nas_create_singledisk_build.sh "$input_tran_arg"
fi


#---- LVM STORAGE
if [ "$RESULTS" = 'STORAGE_LVM' ]
then
  # Create LVM
  source $SHARED_DIR/pve_nas_create_lvm_build.sh "$input_tran_arg"
fi


#---- ZFS STORAGE
if [ "$RESULTS" = 'STORAGE_ZFS' ]
then
  # Create ZFS
  source $SHARED_DIR/pve_nas_create_zfs_build.sh "$input_tran_arg"
fi
#-----------------------------------------------------------------------------------