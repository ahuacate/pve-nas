#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_create_storagediskbuild.sh
# Description:  Source script for NAS internal SATA or Nvme or USB disk setup
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

#---- Source local Git
# /mnt/pve/nas-01-git/ahuacate/pve-nas/shared/pve_nas_create_usbdiskbuild.sh

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

# Clean out inactive /etc/fstab mounts
while read target; do
  if [[ ! $(findmnt ${target} -n -o source) ]]; then
    msg "Deleting inactive mount point..."
    sed -i "\|${target}|d" /etc/fstab
    info "Deleted inactive mount point: ${YELLOW}${target}${NC}"
    echo
  fi
done < <( cat /etc/fstab | awk '$2 ~ /^\/mnt\/.*/ {print $2}' ) # /mnt mount point listing

# Install PVE USB auto mount
function install_usbautomount () {
  PVE_VERS=$(pveversion -v | grep 'proxmox-ve:*' | awk '{ print $2 }' | sed 's/\..*$//')
  if [ ${PVE_VERS} = 6 ]; then
    # Remove old version
    if [ $(dpkg -l pve[0-9]-usb-automount >/dev/null 2>&1; echo $?) = 0 ] && [ $(dpkg -l pve6-usb-automount >/dev/null 2>&1; echo $?) != 0 ]; then
      apt-get remove --purge pve[0-9]-usb-automount -y > /dev/null
    fi
    # Install new version
    if [ $(dpkg -l pve6-usb-automount >/dev/null 2>&1; echo $?) != 0 ]; then
      msg "Installing PVE USB automount..."
      apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 2FAB19E7CCB7F415 &> /dev/null
      echo "deb https://apt.iteas.at/iteas buster main" > /etc/apt/sources.list.d/iteas.list
      apt-get -qq update > /dev/null
      apt-get install pve6-usb-automount -y > /dev/null
      if [ $(dpkg -l pve6-usb-automount >/dev/null 2>&1; echo $?) = 0 ]; then
        info "PVE USB Automount status: ${GREEN}ok${NC} ( fully installed )"
        echo
      else
        warn "There are problems with the installation. Manual intervention is required.\nExiting installation in 3 second. Bye..."
        sleep 3
        echo
        trap cleanup EXIT
      fi
    fi
  elif [ ${PVE_VERS} = 7 ]; then
    # Remove old version
    if [ $(dpkg -l pve[0-9]-usb-automount >/dev/null 2>&1; echo $?) = 0 ] && [ $(dpkg -l pve7-usb-automount >/dev/null 2>&1; echo $?) != 0 ]; then
      apt-get remove --purge pve[0-9]-usb-automount -y > /dev/null
    fi
    # Install new version
    if [ $(dpkg -l pve7-usb-automount >/dev/null 2>&1; echo $?) != 0 ]; then
      msg "Installing PVE USB automount..."
      apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 2FAB19E7CCB7F415 &> /dev/null
      echo "deb https://apt.iteas.at/iteas bullseye main" > /etc/apt/sources.list.d/iteas.list
      apt-get -qq update > /dev/null
      apt-get install pve7-usb-automount -y > /dev/null
      if [ $(dpkg -l pve7-usb-automount >/dev/null 2>&1; echo $?) = 0 ]; then
        info "PVE USB Automount status: ${GREEN}ok${NC} ( fully installed )"
        echo
      else
        warn "There are problems with the installation. Manual intervention is required.\nExiting installation in 3 second. Bye..."
        sleep 3
        echo
        trap cleanup EXIT
      fi
    fi
  elif [ ${PVE_VERS} -lt 6 ]; then
    warn "There are problems with the installation:\n\n      1. This installation requires Proxmox version 6 or later. To continue you must first upgrade your Proxmox host.\n\n      Exiting installation in 3 second. Bye..."
    sleep 2
    echo
    trap cleanup EXIT
  fi
}

# Storage Array List
function reset_usb() {
  msg "Resetting USB devices..."
  # USB 3.1 Only
  for port in $(lspci | grep xHCI | cut -d' ' -f1); do
    echo -n "0000:${port}"| tee /sys/bus/pci/drivers/xhci_hcd/unbind > /dev/null
    sleep 5
    echo -n "0000:${port}" | tee /sys/bus/pci/drivers/xhci_hcd/bind > /dev/null
    sleep 5
  done
  # All USB
  for port in $(lspci | grep USB | cut -d' ' -f1); do
    echo -n "0000:${port}"| tee /sys/bus/pci/drivers/xhci_hcd/unbind > /dev/null
    sleep 5
    echo -n "0000:${port}" | tee /sys/bus/pci/drivers/xhci_hcd/bind > /dev/null
    sleep 5
  done
  echo
}


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
    elif [ "$var14" == 'pve' ]; then
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

# Wake USB disk
function wake_usb() {
  while IFS= read -r line; do
    dd if=${line} of=/dev/null count=512 status=none
  done < <( lsblk -nbr -o PATH,TRAN | awk '{if ($2 == "usb") print $1 }' )
}


#---- Static Variables -------------------------------------------------------------

# Basic storage disk label
BASIC_DISKLABEL='(.*_hba|.*_usb|.*_onboard)$'

#---- Other Variables --------------------------------------------------------------

# USB Disk Storage minimum size (GB)
STOR_MIN='5'

#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Wakeup USB disks
wake_usb

# Create storage list array
storage_list

# Create a working list array
stor_LIST


# Set installer trans selection (check for USB devices)
if [ $(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} '{size=0.0+$8; if ($5 == "usb" && $15 == 0 && $14 != "pve" && ($9 == "disk" && size >= STOR_MIN || $9 == "part" || $9 == 'lvm')) { print $0 } }' | wc -l) -gt 0 ]; then
  # Set installer trans selection
  msg "The installer has detected available USB devices. The User must select a storage option..."
  OPTIONS_VALUES_INPUT=( "onboard" "usb" )
  OPTIONS_LABELS_INPUT=( "Onboard SAS/SATA/NVMe/HBA storage" "USB disk storage")
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"
  # Set installer Trans option
  if [[ "${RESULTS}" =~ 'usb' ]]; then
    INPUT_TRAN='(usb)'
    INPUT_TRAN_ARG='usb'
  elif [[ "${RESULTS}" =~ 'onboard' ]]; then
    INPUT_TRAN='(sata|ata|scsi|nvme)'
    INPUT_TRAN_ARG='onboard'
  fi
else
  # Set for onboard only
  INPUT_TRAN='(sata|ata|scsi|nvme)'
  INPUT_TRAN_ARG='onboard'
fi


# Check if any available storage is available
if [ $(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} '{size=0.0+$8; if ($5 ~ INPUT_TRAN && $15 == 0 && $14 != "pve" && ($9 == "disk" && size >= STOR_MIN || $9 == "part" || $9 == 'lvm')) { print $0 } }' | wc -l) == 0 ]; then
  msg "We could NOT detect any new available disks, LVs, ZPools or Basic NAS storage disks. New disk(s) might have been wrongly identified as 'system drives' if they contain Linux system or OS partitions. To fix this issue, manually format the disk erasing all data before running this installation again. All USB disks must have a data capacity greater than ${STOR_MIN}G to be detected.
  Exiting the installation script. Bye..."
  echo
  exit 0
fi

#---- Select USB Disk format type
section "Select a File Storage type"

# lvm_options=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} \
# 'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
# # Type01: Mount an existing LV
# {if($1 !~ /.*(root|tmeta|tdata|tpool|swap)$/ && $5 ~ INPUT_TRAN && $9 == "lvm" && $13 !~ BASIC_DISKLABEL && $15 == 0 && (system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -v 'thin-pool' | grep -q 'thin' > /dev/null") == 0 || system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -v 'thin-pool' | grep -q 'linear' > /dev/null") == 0)) \
# {cmd = "lvs " $14 " --noheadings -o lv_name | grep -v 'thinpool' | uniq | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline lv_list; close(cmd); print "Mount an existing LV", "Available LVs - "lv_list, $8, $14, "TYPE01"}} \
# # Type02: Create LV in an existing Thin-pool
# {if($1 !~ /.*(root|tmeta|tdata|tpool|swap)$/ && $5 ~ INPUT_TRAN && $4 == "" && $9 == "lvm" && $13 !~ BASIC_DISKLABEL && $15 == 0 && system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -q 'thin-pool' > /dev/null") == 0 ) \
# {cmd = "lvs " $14 " --noheadings -o pool_lv | uniq | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline thin_list; close(cmd); print "Create LV in an existing Thin-pool", "Available pools - "thin_list, $8, $14, "TYPE02"}} \
# # Type03: Create LV in an existing VG
# {if ($5 ~ INPUT_TRAN && $4 == "LVM2_member" && $13 !~ BASIC_DISKLABEL && $15 == 0) \
# print "Create LV in an existing VG", "VG name - "$14, $8, $14, "TYPE03" } \
# # Type04: Destroy VG
# {if ($5 ~ INPUT_TRAN && $4 == "LVM2_member" && $13 !~ BASIC_DISKLABEL && $15 == 0) { cmd = "lvs " $14 " --noheadings -o lv_name | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline $16; close(cmd); print "Destroy VG ("$14")", "Destroys LVs/Pools - "$16, $8, $14, "TYPE04" }} \
# # Type05: Build a new LVM VG/LV - SSD Disks
# {if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { ssd_count++ }} END { if (ssd_count >= 1) print "Build a new LVM VG/LV - SSD Disks", "Select from "ssd_count"x SSD disks", "-", "-", "TYPE05" } \
# # Type05: Build a new LVM VG/LV - HDD Disks
# {if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 1 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { hdd_count++ }} END { if (hdd_count >= 1) print "Build a new LVM VG/LV - HDD Disks", "Select from "hdd_count"x HDD disks", "-", "-", "TYPE06" }' | sort -t: -us -k 1,1 -k 2,2 -k 4,4 \
# | column -s : -t -N "LVM OPTIONS,DESCRIPTION,SIZE,VG NAME,SELECTION" -H "SELECTION,SIZE" -W DESCRIPTION -c 120 | indent2)

# zfs_options=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} 'BEGIN{OFS=FS} $8 ~ /G$/ \
# {if ($5 ~ INPUT_TRAN && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $13 !~ BASIC_DISKLABEL && $14!=/[0-9]+/ && $15 == 0) print "Use Existing ZPool", "-", $8, $14,  "TYPE01" } \
# {if ($5 ~ INPUT_TRAN && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $13 !~ BASIC_DISKLABEL && $14!=/[0-9]+/ && $15 == 0) print "Destroy & Wipe ZPool", "-", $8, $14, "TYPE02" } \
# {size=0.0+$8; if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { ssd_count++ }} END { if (ssd_count >= 1) print "Create new ZPool - SSD", ssd_count"x SSD disks", "-", "-", "TYPE03" } \
# {size=0.0+$8; if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 1 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { hdd_count++ }} END { if (hdd_count >= 1) print "Create new ZPool - HDD", hdd_count"x HDD disks", "-", "-", "TYPE04" }' \
# | column -s : -t -N "ZFS OPTIONS,DESCRIPTION,SIZE,ZFS POOL,SELECTION" -H "SELECTION" | indent2)

# basic_options=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL}  \
# 'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
# {if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print "Basic single disk build", "Format "$1" only", $8, "TYPE07" } \
# # TYPE08: Mount existing NAS storage disk
# {if ($5 ~ INPUT_TRAN && $3 != 0 && $4 == "ext4" && $9 == "part" && size >= STOR_MIN && $13 ~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print "Mount existing NAS storage disk", "Mount "$1" (disk label - "$13")", $8, "TYPE08" }' \
# | column -s : -t -N "BASIC OPTIONS,DESCRIPTION,SIZE,SELECTION" -H "SELECTION" | indent2)

lvm_options=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} \
'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
# Type01: Mount an existing LV
{if($1 !~ /.*(root|tmeta|tdata|tpool|swap)$/ && $5 ~ INPUT_TRAN && $9 == "lvm" && $13 !~ BASIC_DISKLABEL && $15 == 0 && (system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -v 'thin-pool' | grep -q 'thin' > /dev/null") == 0 || system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -v 'thin-pool' | grep -q 'linear' > /dev/null") == 0)) \
{cmd = "lvs " $14 " --noheadings -o lv_name | grep -v 'thinpool' | uniq | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline lv_list; close(cmd); print "Mount an existing LV", "Available LVs - "lv_list, $8, $14, "TYPE01"}} \
# Type02: Create LV in an existing Thin-pool
{if($1 !~ /.*(root|tmeta|tdata|tpool|swap)$/ && $5 ~ INPUT_TRAN && $4 == "" && $9 == "lvm" && $13 !~ BASIC_DISKLABEL && $15 == 0 && system("lvs " $1 " --quiet --noheadings --segments -o type 2> /dev/null | grep -q 'thin-pool' > /dev/null") == 0 ) \
{cmd = "lvs " $14 " --noheadings -o pool_lv | uniq | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline thin_list; close(cmd); print "Create LV in an existing Thin-pool", "Available pools - "thin_list, $8, $14, "TYPE02"}} \
# Type03: Create LV in an existing VG
{if ($5 ~ INPUT_TRAN && $4 == "LVM2_member" && $13 !~ BASIC_DISKLABEL && $15 == 0) \
print "Create LV in an existing VG", "VG name - "$14, $8, $14, "TYPE03" } \
# Type04: Destroy VG
{if ($5 ~ INPUT_TRAN && $4 == "LVM2_member" && $13 !~ BASIC_DISKLABEL && $15 == 0) { cmd = "lvs " $14 " --noheadings -o lv_name | xargs | sed -r 's/[[:space:]]/,/g'"; cmd | getline $16; close(cmd); print "Destroy VG ("$14")", "Destroys LVs/Pools - "$16, $8, $14, "TYPE04" }} \
# Type05: Build a new LVM VG/LV - SSD
{if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { ssd_count++ }} END { if (ssd_count >= 1) print "Build a new LVM VG/LV - SSD", ssd_count"x SSD disks", "-", "-", "TYPE05" } \
# Type05: Build a new LVM VG/LV - HDD
{if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 1 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { hdd_count++ }} END { if (hdd_count >= 1) print "Build a new LVM VG/LV - HDD", hdd_count"x HDD disks", "-", "-", "TYPE06" }' | sort -t: -us -k 1,1 -k 2,2 -k 4,4 \
| sed '1 i\LVM OPTIONS:DESCRIPTION:SIZE:VG NAME:SELECTION')

zfs_options=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL} 'BEGIN{OFS=FS} $8 ~ /G$/ \
{if ($5 ~ INPUT_TRAN && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $13 !~ BASIC_DISKLABEL && $14!=/[0-9]+/ && $15 == 0) print "Use Existing ZPool", "-", $8, $14,  "TYPE01" } \
{if ($5 ~ INPUT_TRAN && $3 != 0 && $4 == "zfs_member" && $9 == "part" && $13 !~ BASIC_DISKLABEL && $14!=/[0-9]+/ && $15 == 0) print "Destroy & Wipe ZPool", "-", $8, $14, "TYPE02" } \
{size=0.0+$8; if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 0 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { ssd_count++ }} END { if (ssd_count >= 1) print "Create new ZPool - SSD", ssd_count"x SSD disks", "-", "-", "TYPE03" } \
{size=0.0+$8; if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $10 == 1 && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) { hdd_count++ }} END { if (hdd_count >= 1) print "Create new ZPool - HDD", hdd_count"x HDD disks", "-", "-", "TYPE04" }' \
| sed '1 i\ZFS OPTIONS:DESCRIPTION:SIZE:ZFS POOL:SELECTION')

basic_options=$(printf '%s\n' "${storLIST[@]}" | awk -F':' -v STOR_MIN=${STOR_MIN} -v INPUT_TRAN=${INPUT_TRAN} -v BASIC_DISKLABEL=${BASIC_DISKLABEL}  \
'BEGIN{OFS=FS} {$8 ~ /G$/} {size=0.0+$8} \
{if ($5 ~ INPUT_TRAN && $3 == 0 && ($4 != "LVM2_member" || $4 != "zfs_member") && $9 == "disk" && size >= STOR_MIN && $13 !~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print "Basic single disk build", "Format "$1" only", $8, "-", "TYPE07" } \
# TYPE08: Mount existing NAS storage disk
{if ($5 ~ INPUT_TRAN && $3 != 0 && $4 == "ext4" && $9 == "part" && size >= STOR_MIN && $13 ~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print "Mount existing NAS storage disk", "Mount "$1" (disk label - "$13")", $8, "-", "TYPE08" } \
{if ($5 ~ INPUT_TRAN && $3 != 0 && $4 == "ext4" && $9 == "part" && size >= STOR_MIN && $13 ~ BASIC_DISKLABEL && $14 == 0 && $15 == 0) print "Destroy & wipe disk", "Destroy disk /dev/"$3" (disk label - "$13")", $8, "-", "TYPE09" }' \
| sed '1 i\BASIC OPTIONS:DESCRIPTION:SIZE::SELECTION')


msg_box "#### PLEASE READ CAREFULLY - STORAGE OPTIONS ####\n
The User must choose either ZFS Raid, LVM Raid or a Basic single disk storage for their NAS build. The basic single disk storage is recommended for USB disk storage devices.

If an option to create new storage is missing its because the disk(s) may have been wrongly identified as 'system disks' or the disk contains a working ZFS, LVM or Basic NAS file system. To fix this issue, exit the installation and use Proxmox PVE WebGUI to:

  --  destroy a ZFS ZPool or LVM VG (which resides on the missing disk)
  --  run PVE disk wipe tool on all the 'missing' disk devices

The above operations will result in permanent loss of data. Re-run the installation and the disks should be available for selection."

# Display options
unset display_LIST
unset OPTIONS_VALUES_INPUT
unset OPTIONS_LABELS_INPUT
echo
if [ $(echo "${lvm_options}" | sed '/^$/d' | wc -l) -gt '0' ]; then
  display_LIST+=( "$(printf '%s\n' "${lvm_options}" | sed '/^$/d')" )
  display_LIST+=( ":" )
  OPTIONS_VALUES_INPUT+=("STORAGE_LVM")
  OPTIONS_LABELS_INPUT+=("LVM Raid filesystem")
fi
if [ $(echo "${zfs_options}" | sed '/^$/d' | wc -l) -gt '0' ]; then
  display_LIST+=( "$(printf '%s\n' "${zfs_options}" | sed '/^$/d')" )
  display_LIST+=( ":" )
  OPTIONS_VALUES_INPUT+=( "STORAGE_ZFS" )
  OPTIONS_LABELS_INPUT+=( "ZFS Raid filesystem" )
fi
if [ $(echo "${basic_options}" | sed '/^$/d' | wc -l) -gt '0' ]; then
  display_LIST+=( "$(printf '%s\n' "${basic_options}" | sed '/^$/d')" )
  display_LIST+=( ":" )
  OPTIONS_VALUES_INPUT+=( "STORAGE_BASIC" )
  OPTIONS_LABELS_INPUT+=( "Basic single disk only" )
fi
# Add Exit option
OPTIONS_VALUES_INPUT+=( "STORAGE_EXIT" )
OPTIONS_LABELS_INPUT+=( "None - Exit this installer" )
# Print available option list
printf '%s\n' "${display_LIST[@]}" | column -s : -t -N "1,2,3,4,5" -H "5" -d -W 2 -c 120 | indent2

makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"
# Set installer type
STORAGE_TYPE=${RESULTS}


#---- Exit selection ---------------------------------------------------------------
if [ ${STORAGE_TYPE} == 'STORAGE_EXIT' ]; then
  msg "You have chosen not to proceed. Aborting. Bye..."
  echo
  exit 0
fi

#---- Basic EXT4 STORAGE -----------------------------------------------------------
if [ ${STORAGE_TYPE} == 'STORAGE_BASIC' ]; then
  # Format disk
  source ${SHARED_DIR}/pve_nas_create_singledisk_build.sh ${INPUT_TRAN_ARG}
fi


#---- LVM STORAGE ------------------------------------------------------------------
if [ ${STORAGE_TYPE} == 'STORAGE_LVM' ]; then
  # Create LVM
  source ${SHARED_DIR}/pve_nas_create_lvm_build.sh ${INPUT_TRAN_ARG}
fi


#---- ZFS STORAGE ------------------------------------------------------------------
if [ ${STORAGE_TYPE} == 'STORAGE_ZFS' ]; then
  # Create ZFS
  source ${SHARED_DIR}/pve_nas_create_zfs_build.sh ${INPUT_TRAN_ARG}
fi