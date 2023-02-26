#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_fs_list.sh
# Description:  Create fs list for NAS LVM, ZFS, Basic 
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

# Disk Storage minimum size (GB)
stor_min='30'

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

#---- Create lists

# Create storage list array
storage_list

# Create a working list array
stor_LIST

#---- LVM option list
# 1=PATH:2=KNAME:3=PKNAME:4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM

# LVM options
# build:description:tran:size|action:rota
lvm_option_input=$(printf '%s\n' "${storLIST[@]}" | awk -F':' '$5 != "usb"' | awk -F':' -v stor_min="$stor_min" -v input_tran="$input_tran" -v basic_disklabel="$basic_disklabel" \
'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
# Type01: Mount an existing LV
{if($1 !~ /.*(root|tmeta|tdata|tpool|swap)$/ && $5 ~ input_tran && $9 == "lvm" && $13 !~ basic_disklabel && $15 == 0 && (system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -v 'thin-pool' | grep -q 'thin' > /dev/null") == 0 || system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -v 'thin-pool' | grep -q 'linear' > /dev/null") == 0)) \
{cmd = "lvs " $1 " --noheadings -o lv_name | grep -v 'thinpool' | uniq | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline lv_name; close(cmd); print "Mount existing LV", "LV name - "lv_name, "-", $8, "TYPE01", lv_name }} \
# Type02: Create LV in an existing Thin-pool
{if($1 !~ /.*(root|tmeta|tdata|tpool|swap)$/ && $5 ~ input_tran && $4 == "" && $9 == "lvm" && $13 !~ basic_disklabel && $15 == 0 && system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -q 'thin-pool' > /dev/null") == 0 ) \
{cmd = "lvs " $1 " --noheadings -o lv_name | uniq | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline thinpool_name; close(cmd); print "Create LV in existing Thin-pool", "Thin-pool name - "thinpool_name, "-", $8, "TYPE02", thinpool_name }} \
# Type03: Create LV in an existing VG
{if ($5 ~ input_tran && $4 == "LVM2_member" && $13 !~ basic_disklabel && $15 == 0) \
print "Create LV in an existing VG", "VG name - "$14, "-", $8, "TYPE03", $14 } \
# Type04: Destroy VG
{if ($5 ~ input_tran && $4 == "LVM2_member" && $13 !~ basic_disklabel && $15 == 0) { cmd = "lvs " $14 " --noheadings -o lv_name | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline $16; close(cmd); print "Destroy VG ("$14")", "Destroys LVs/Pools - "$16, "-", "-", "TYPE04", $14 }} \
# Type05: Build a new LVM VG/LV - SSD Disks
{if ($5 ~ input_tran && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= stor_min && $10 == 0 && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) { ssd_count++ }} END { if (ssd_count >= 1) print "Build a new LVM VG/LV - SSD Disks", "Select from "ssd_count"x SSD disks", $5, "-", "TYPE05", "0" } \
# Type06: Build a new LVM VG/LV - HDD Disks
{if ($5 ~ input_tran && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= stor_min && $10 == 1 && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) { hdd_count++ }} END { if (hdd_count >= 1) print "Build a new LVM VG/LV - HDD Disks", "Select from "hdd_count"x HDD disks", $5, "-", "TYPE06", "1" }' \
| sed '/^$/d' \
| sort -t: -s -k 4,4 \
| awk -F':' '!seen[$1$2]++')
# Create selection labels & values
lvm_option_labels=$(printf '%s\n' "$lvm_option_input" | sed '/^$/d' | cut -d: -f1,2,3,4)
lvm_option_values=$(printf '%s\n' "$lvm_option_input" | sed '/^$/d' | cut -d: -f5,6)


#---- ZFS option list
# 1=PATH:2=KNAME:3=PKNAME:4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM

# ZFS options
# build:description:tran:size|action:zpoolname
zfs_option_input=$(printf '%s\n' "${storLIST[@]}" | awk -F':' '$5 != "usb"' | awk -F':' -v stor_min="$stor_min" -v input_tran="$input_tran" -v basic_disklabel="$basic_disklabel" \
'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
# Type01: Use Existing ZPool
{if ($5 ~ input_tran && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $13 !~ basic_disklabel && $14!=/[0-9]+/ && $15 == 0) print "Use Existing ZPool - "$14"", "-", $8, "-", "TYPE01", $14 } \
# Type02: Destroy & Wipe ZPool
{if ($5 ~ input_tran && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $13 !~ basic_disklabel && $14!=/[0-9]+/ && $15 == 0) print "Destroy & Wipe ZPool - "$14"", "-", $8, "-", "TYPE02", $14 } \
# Type03: Create new ZPool - SSD
{if ($5 ~ input_tran && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= stor_min && $10 == 0 && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) { ssd_count++ }} END { if (ssd_count >= 1) print "Create new ZPool - SSD", ssd_count"x SSD disks available", "-", "-", "TYPE03", "0"} \
# Type04: Create new ZPool - HDD
{if ($5 ~ input_tran && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= stor_min && $10 == 1 && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) { hdd_count++ }} END { if (hdd_count >= 1) print "Create new ZPool - HDD", hdd_count"x HDD disks available", "-", "-", "TYPE03", "1"}' \
| sed '/^$/d' \
| awk -F':' '!seen[$1]++')
# Create selection labels & values
zfs_option_labels=$(printf '%s\n' "$zfs_option_input" | sed '/^$/d' | cut -d: -f1,2,3,4)
zfs_option_values=$(printf '%s\n' "$zfs_option_input" | sed '/^$/d' | cut -d: -f5,6)
# Create display
zfs_display=$(printf '%s\n' "$zfs_option_input" | sed '/^$/d' | cut -d: -f1,2,3,4)


#---- Basic option list
# 1=PATH:2=KNAME:3=PKNAME:4=FSTYPE:5=TRAN:6=MODEL:7=SERIAL:8=SIZE:9=TYPE:10=ROTA:11=UUID:12=RM:13=LABEL:14=ZPOOLNAME:15=SYSTEM

# Basic options
# build:description:tran:size|action:all
basic_option_input=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v stor_min="$stor_min" -v input_tran="$input_tran" -v basic_disklabel="$basic_disklabel"  \
'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
# Type01: Basic single disk build
{if ($5 ~ input_tran && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= stor_min && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) print "Basic single disk build", "Format "$1" to ext4", $5, $8, "TYPE01", $0} \
# TYPE02: Mount existing NAS storage disk
{if ($5 ~ input_tran && $3 != 0 && $4 == "ext4" && $9 == "part" && size >= stor_min && $13 ~ basic_disklabel && $14 == 0 && $15 == 0) print "Mount existing NAS storage disk", "Mount "$1" (disk label - "$13")", $5, $8, "TYPE02", $0} \
# TYPE03: Destroy & wipe disk
{if ($5 ~ input_tran && $3 != 0 && $4 == "ext4" && $9 == "part" && size >= stor_min && $13 !~ basic_disklabel && $14 == 0 && $15 == 0) print "Destroy & wipe disk", "Destroy disk /dev/"$3" (disk label - "$13")", $5, $8, "TYPE03", $0} \
# TYPE04: Destroy, wipe and use partition
{if ($5 ~ input_tran && $3 != 0 && ($4 == "ext2" || $4 == "ext3" || $4 == "ext4" || $4 == "btrfs" || $4 == "xfs") && $9 == "part" && size >= stor_min && $14 == 0 && $15 == 0) print "Destroy, wipe & use partition", "Use partition "$1" (disk label - "$13")", $5, $8, "TYPE04", $0}' \
| sed '/^$/d' \
| awk -F':' '!seen[$1$2$3$4]++')
# Create selection labels & values
basic_option_labels=$(printf '%s\n' "$basic_option_input" | sed '/^$/d' | cut -d: -f1,2,3,4)
basic_option_values=$(printf '%s\n' "$basic_option_input" | sed '/^$/d' | cut -d: -f5-)


#---- FS option count

# LVM option count
lvm_option_cnt=$(echo "$lvm_option_labels" | sed '/^$/d' | wc -l)
# ZFS option cnt
zfs_option_cnt=$(echo "$zfs_option_labels" | sed '/^$/d' | wc -l)
# Basic disk count
basic_option_cnt=$(echo "$basic_option_labels" | awk -F':' '$3 != "usb"' | sed '/^$/d' | wc -l)
# USB disk count
usb_option_cnt=$(echo "$basic_option_labels" | awk -F':' '$3 == "usb"' | sed '/^$/d' | wc -l)


#---- Validate available storage to proceed

# Check if any available storage is available (usb and onboard)
# If no disk or storage is available then exits
if [ "$usb_option_cnt" = 0 ] && [ "$lvm_option_cnt" = 0 ] && [ "$zfs_option_cnt" = 0 ] && [ "$basic_option_cnt" = 0 ]
then
  # Exit installer
  warn "We could NOT detect any new available disks, LVs, ZPools or Basic NAS storage disks. New disk(s) might have been wrongly identified as 'system drives' if they contain Linux system or OS partitions. To fix this issue, manually format the disk erasing all data before running this installation again. All USB disks must have a data capacity greater than ${stor_min}G to be detected.
  Exiting the installation script. Bye..."
  echo
  exit 0
fi
#-----------------------------------------------------------------------------------