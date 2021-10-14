#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_create_internaldiskbuild.sh
# Description:  Source script for NAS internal SATA or Nvme disk ZFS raid storage
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Creating the ZPOOL Tank
section "Setting up Zpool storage."

# Set ZFS pool name
msg "Setting up your ZPool storage devices..."
while true; do
  if [ $(zpool list | grep -iv '^rpool' | sed '1d' | wc -l) = 0 ]; then
    msg "A common ZFS pool name is 'tank'. We recommended you use pool name 'tank' whenever you can."
  elif [ $(zpool list | grep -iv '^rpool' | sed '1d' | wc -l) -ge 0 ]; then
    msg "A common ZFS pool name is 'tank'. We recommended you use pool name 'tank' whenever you can. Your current ZFS pools and datasets are listed below. ${RED}[WARNING]${NC} If you ${UNDERLINE}choose to destroy any ZFS pool${NC} its associated datasets will also be ${UNDERLINE}permanently destroyed resulting in permanent loss${NC} of all dataset data. \n"
    echo "$(zpool list -o name,size | grep -iv '^rpool'| column -t | indent2)"
    echo
  fi
  read -p "Enter your desired ZFS pool name (i.e default is tank): " -e -i tank POOL
  POOL=${POOL,,}
  echo
  if [ $POOL = "rpool" ]; then
    warn "ZFS pool name '$POOL' is your default ZFS root pool. You cannot use this.\nTry again..."
    echo
  elif [ $(zpool list -v -H -P $POOL | grep dev | awk '{print $1}' | grep -E '(/usb-*)' >/dev/null; echo $?) = 0 ]; then
    warn "ZFS pool name '$POOL' is an existing USB ZFS pool.\nYou cannot use this name. Try again..."
    echo
  elif [ $(zfs list | grep -w "^$POOL " >/dev/null; echo $?) = 1 ]; then
    ZPOOL_TYPE=0
    info "ZFS pool name is set: ${YELLOW}$POOL${NC}"
    break
  elif [ $(zpool list -v -H -P $POOL | grep dev | awk '{print $1}' | grep -E '(/ata-*|/nvme-*|/scsi-*)' >/dev/null; echo $?) = 0 ]; then
    warn "A ZFS pool named '$POOL' already exists:"
    zfs list | grep -e "NAME\|^$POOL"| fold | awk '{ print $1,$2,$3 }' | column -t | sed "s/^/    /g"
    echo
    TYPE01="${YELLOW}Destroy & Rebuild${NC} - destroy ZFS pool '$POOL' & create a new ZFS pool '$POOL'."
    TYPE02="${YELLOW}Use Existing${NC} - use the existing ZFS pool '$POOL' storage."
    TYPE03="${YELLOW}Destroy & Exit${NC} - destroy ZFS pool '$POOL' and exit installation."
    TYPE04="${YELLOW}None. Try again${NC} - try another ZFS pool name."
    PS3="Select the action type you want to do (entering numeric) : "
    msg "Your available options are:"
    options=("$TYPE01" "$TYPE02" "$TYPE03" "$TYPE04")
    select menu in "${options[@]}"; do
      case $menu in
        "$TYPE01")
          echo
          warn "You have chosen to destroy ZFS pool '$POOL' on PVE $(echo $(hostname)). This action will result in ${UNDERLINE}permanent data loss${NC} ${WHITE}of all data stored in the existing ZFS pool '$POOL'. A clean new ZFS pool '$POOL' with then be re-created.${NC}\n"
          while true; do
            read -p "Are you sure you want to destroy ZFS pool '$POOL' and datasets: [y/n]?" -n 1 -r YN
            echo
            case $YN in
              [Yy]*)
                ZPOOL_TYPE=0
                msg "Destroying ZFS pool '$POOL'..."
                while read -r var; do
                  zfs unmount $var &> /dev/null
                done < <( zfs list -r $POOL | awk '{ print $1 }' | sed '1d' | sort -r -n )
                zpool destroy -f $POOL &> /dev/null
                info "ZFS pool '$POOL' status: ${YELLOW}destroyed${NC}"
                echo
                break 2
                ;;
              [Nn]*)
                echo
                msg "You have chosen not to proceed with destroying ZFS pool '$POOL'.\nTry again..."
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
          ;;
        "$TYPE02")
          echo
          ZPOOL_TYPE=1
          info "You have chosen to use the existing ZFS pool '$POOL'.\nNo new ZFS pool will be created.\nZFS pool name is set: ${YELLOW}$POOL${NC} (existing ZFS pool)"
          echo
          break 2
          ;;
        "$TYPE03")
          echo
          msg "You have chosen to destroy ZFS pool '$POOL'. This action will result in ${UNDERLINE}permanent data loss${NC} of all data stored in the existing ZFS pool '$POOL'. After ZFS pool '$POOL' is destroyed this installation script with exit."
          echo
          while true; do
            read -p "Are you sure to destroy ZFS pool '$POOL': [y/n]?" -n 1 -r YN
            echo
            case $YN in
              [Yy]*)
                msg "Destroying ZFS pool '$POOL'..."
                while read -r var; do
                  zfs unmount $var &> /dev/null
                done < <( zfs list -r $POOL | awk '{ print $1 }' | sed '1d' | sort -r -n )
                zpool destroy -f $POOL &> /dev/null
                echo
                exit 0
                ;;
              [Nn]*)
                echo
                msg "You have chosen not to proceed with destroying ZFS pool '$POOL'.\nTry again..."
                sleep 1
                echo
                break 2
                ;;
              *)
                warn "Error! Entry must be 'y' or 'n'. Try again..."
                echo
                ;;
            esac
          done
          ;;
        "$TYPE04")
          echo
          msg "No problem. Try again..."
          echo
          break
          # done
          ;;
        *) warn "Invalid entry. Try again.." >&2
      esac
    done
  fi
  if ! [ -z "${ZPOOL_TYPE+x}" ]; then
    break
  fi
done


# Identifying PVE Boot Disks
if [ $ZPOOL_TYPE = 0 ]; then
msg "Identifying Proxmox PVE, OS and Boot hard disk ID..."
# boot disks
fdisk -l 2>/dev/null | grep -E '(BIOS boot|EFI System)' | awk '{ print $1 }' | sort > boot_disklist_var01
# Identify disk type (sda or nvme)
if [ $(cat boot_disklist_var01 | grep -E "^/dev/sd.*" > /dev/null; echo $?) = 0 ]; then
  cat boot_disklist_var01 | sed 's/[0-9]\+$//g' | awk '!seen[$0]++' > boot_disklist_tmp01
  BOOT_DEVICE_TYPE=sata
elif [ $(cat boot_disklist_var01 | grep -E "^/dev/nvme.*" > /dev/null; echo $?) = 0 ]; then
  cat boot_disklist_var01 | sed 's/[p][0-9]\+$//g' | awk '!seen[$0]++' > boot_disklist_tmp01
  BOOT_DEVICE_TYPE=nvme
fi
for f in $(cat boot_disklist_tmp01 | sed 's|/dev/||')
  do read dev
    echo "$(fdisk -l /dev/"$f" | grep -E 'Solaris /usr & Apple ZFS' | awk '{print $1}')" >> boot_disklist_var01
done < boot_disklist_tmp01
# Create raw whole device /dev/(sd?/nvme?)
if grep -Fq "$(cat boot_disklist_var01 | sed 's/[0-9]\+$//' | sed 's/p$//' | awk '!seen[$0]++')" boot_disklist_var01; then
  cat boot_disklist_var01 | sed 's/[0-9]\+$//' | sed 's/p$//' | awk '!seen[$0]++' >> boot_disklist_var01
fi
# Sort the list
sort -o boot_disklist_var01 boot_disklist_var01
# Add Linux by-id to column 2 & Disk Size to column 3,4 & Disk Type to column 5
for f in $(cat boot_disklist_var01 | awk '{ print $1 }' | sed 's|/dev/||')
  do read dev
    echo "$dev" "$(ls -l /dev/disk/by-id | grep -E '(ata-*|nvme-*|scsi-*)' | grep -w "$f" | awk '{ print $9 }' | sed 's|/dev/disk/by-id/||')" "$(fdisk -l /dev/"$f" | grep -w "Disk /dev/"$f"" | awk '{print $3,$4}' | sed 's|,||')" "$(if [ $(cat /sys/block/"$(echo $f | sed 's/[0-9]\+$//' | sed 's/p$//')"/queue/rotational) == 0 ];then echo "ssd"; else echo "harddisk";fi)" >> boot_disklist
done < boot_disklist_var01
echo

# Confirm Root File System Partitioned Cache & Log Disks
set +Eeuo pipefail
if [ $(fdisk -l $(fdisk -l 2>/dev/null | grep -E 'BIOS boot|EFI System'| awk '{ print $1 }' | sort | sed 's/[0-9]*//g' | awk '!seen[$0]++') | grep -Ev 'BIOS boot|EFI System|Solaris /usr & Apple ZFS' | grep -E 'Linux filesystem' | awk '{ print $1 }' | wc -l)  -ge 2 ]; then
  msg "Confirming Proxmox Root File System partitions for ZFS ARC or L2ARC Cache & ZIL (logs) on $HOSTNAME ..."
  echo
  while true; do
    read -p "Have you ${UNDERLINE}already partitioned${NC} $HOSTNAME root filesystem disk(s) for ARC or L2ARC Cache and ZIL: [y/n]?" -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        fdisk -l $(fdisk -l 2>/dev/null | grep -E '(BIOS boot|EFI System)'| awk '{ print $1 }' | sort | sed 's/[0-9]\+$//' | sed 's/p$//' | awk '!seen[$0]++') | grep -Ev '(BIOS boot|EFI System|Solaris /usr & Apple ZFS)' | grep -E 'Linux filesystem' | awk '{ print $1 }' > zfs_rootcachezil_disklist_var01
        for f in $(cat zfs_rootcachezil_disklist_var01 | awk '{ print $1 }' | sed 's|/dev/||')
          do read dev
            echo "$dev" "$(ls -l /dev/disk/by-id | grep -E '(ata-*|nvme-*|scsi-*)' | grep -w "$f" | awk '{ print $9 }' | sed 's|/dev/disk/by-id/||')" "$(fdisk -l /dev/"$f" | grep -w "Disk /dev/"$f"" | awk '{print $3, $4}' | sed 's|,||')" "$(if [ $(cat /sys/block/"$(echo $f | sed 's/[0-9]\+$//' | sed 's/p$//')"/queue/rotational) == 0 ];then echo "ssd"; else echo "harddisk";fi)" >> zfs_rootcachezil_disklist_var02
        done < zfs_rootcachezil_disklist_var01
        msg "There are two different SSD caches that a ZFS pool can make use of:\n  1.  ZFS Intent Log, or ZIL, to buffer WRITE operations.\n  2.  ARC and L2ARC cache which are meant for READ operations.\nIn the next steps you will asked to select ZIL and ARC or L2ARC Cache disks.\nRemember ARC or L2ARC disks will be larger (default 64GiB) than ZIL disks (default 8GiB).\n\nSelect the disk, or two matching disks if you are configured for raid, to be used for: ${YELLOW}ARC or L2ARC Cache${NC} (excluding ZIL disks)."
        menu() {
          echo "Available options:"
          for i in "${!options[@]}"; do 
              printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
          done
          if [[ "$msg" ]]; then echo "$msg"; fi
        }
        mapfile -t options < zfs_rootcachezil_disklist_var02
        prompt="Check an option to select ARC or L2ARC cache\ndisk partitions (again to uncheck, ENTER when done): "
        while menu && read -rp "$prompt" num && [[ "$num" ]]; do
          [[ "$num" != *[![:digit:]]* ]] &&
          (( num > 0 && num <= ${#options[@]} )) ||
          { msg="Invalid option: $num"; continue; }
          ((num--)); msg="${options[num]} was ${choices[num]:+un}checked"
          [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
        done
        echo
        printf "Your selected ARC or L2ARC cache disk partitions are:\n"; msg=" nothing"
        for i in ${!options[@]}; do
          [[ "${choices[i]}" ]] && { printf "${YELLOW}Disk ID:${NC}  %s\n" "${options[i]}"; msg=""; } && echo $({ printf "%s" "${options[i]}"; msg=""; }) >> zpool_rootcache_disklist
        done
        unset choices
        echo
        awk -F " "  'NR==FNR {a[$1];next}!($1 in a) {print $0}' zpool_rootcache_disklist zfs_rootcachezil_disklist_var02 | awk '!seen[$0]++' | sort > zfs_rootzil_disklist_var01
        msg "Now select the disk, or two matching disks if you are configured for raid, to be used for: ${YELLOW}ZIL Cache${NC}."
        menu() {
          echo "Available options:"
          for i in ${!options[@]}; do 
              printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
          done
          if [[ "$msg" ]]; then echo "$msg"; fi
        }
        mapfile -t options < zfs_rootzil_disklist_var01
        prompt="Check an option to select SSD disks (again to uncheck, ENTER when done): "
        while menu && read -rp "$prompt" num && [[ "$num" ]]; do
          [[ "$num" != *[![:digit:]]* ]] &&
          (( num > 0 && num <= ${#options[@]} )) ||
          { msg="Invalid option: $num"; continue; }
          ((num--)); msg="${options[num]} was ${choices[num]:+un}checked"
          [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
        done
        echo
        printf "Your selected ZIL cache disk partitions are:\n"; msg=" nothing"
        for i in ${!options[@]}; do
          [[ "${choices[i]}" ]] && { printf "${YELLOW}Disk ID:${NC}  %s\n" "${options[i]}"; msg=""; } && echo $({ printf "%s" "${options[i]}"; msg=""; }) >> zpool_rootzil_disklist
        done
        unset choices
      echo
      echo
      if [ -s zpool_rootcache_disklist ]; then
        msg "${YELLOW}You selected the following disks for ARC or L2ARC Cache:${NC}\n${WHITE}$(cat zpool_rootcache_disklist 2>/dev/null)${NC}"
      else
        msg "${YELLOW}You selected the following disks for ARC or L2ARC Cache:\n${WHITE}None. You have NOT selected any disks!${NC}"
      fi
      echo
      if [ -s zpool_rootzil_disklist ]; then
        msg "${YELLOW}You selected the following disks for ZIL:${NC}\n${WHITE}$(cat zpool_rootzil_disklist 2>/dev/null)${NC}"
      else
        msg "${YELLOW}You selected the following disks for ZIL:\n${WHITE}None. You have NOT selected any disks!${NC}"
      fi
      echo
      while true; do
        read -p "Confirm your ARC or L2ARC Cache and ZIL disk selection is correct: [y/n]?" -n 1 -r YN
        echo
        case $YN in
          [Yy]*)
            info "Success. Moving on."
            ZFS_ROOTCACHE_READY=0
            echo
            break 2
            ;;
          [Nn]*)
            echo
            warn "No good. No problem. Try again."
            rm {zfs_rootcachezil_disklist_var01,zfs_rootcachezil_disklist_var02,zfs_rootzil_disklist_var01,zpool_rootcache_disklist,zpool_rootzil_disklist} 2>/dev/null
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
        ;;
      [Nn]*)
        info "You have chosen not to set ARC or L2ARC Cache or ZIL on $HOSTNAME Proxmox OS root drives. You may choose to use dedicated SSD's for ZFS caching in the coming steps."
        ZFS_ROOTCACHE_READY=1
        fdisk -l $(fdisk -l 2>/dev/null | grep -E '(BIOS boot|EFI System)' | awk '{ print $1 }' | sort | sed 's/[0-9]\+$//' | sed 's/p$//' | awk '!seen[$0]++') | grep -Ev '(BIOS boot|EFI System|Solaris /usr & Apple ZFS)' | grep -E 'Linux filesystem' | awk '{ print $1 }' > zpool_rootcacheall_disklist_var01
        for f in $(cat zpool_rootcacheall_disklist_var01 | awk '{ print $1 }' | sed 's|/dev/||')
        do read dev
          echo "$dev" "$(ls -l /dev/disk/by-id | grep -E '(ata-*|nvme-*|scsi-*)' | grep -w "$f" | awk '{ print $9 }' | sed 's|/dev/disk/by-id/||')" "$(fdisk -l /dev/"$f" | grep -w "Disk /dev/"$f"" | awk '{print $3, $4}' | sed 's|,||')" "$(if [ $(cat /sys/block/"$(echo $f | sed 's/[0-9]\+$//' | sed 's/p$//')"/queue/rotational) == 0 ];then echo "ssd"; else echo "harddisk";fi)" >> zpool_rootcacheall_disklist
        done < zpool_rootcacheall_disklist_var01
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
else
  ZFS_ROOTCACHE_READY=1
  set +Eeuo pipefail
  fdisk -l $(fdisk -l 2>/dev/null | grep -E '(BIOS boot|EFI System)'| awk '{ print $1 }' | sort | sed 's/[0-9]\+$//' | sed 's/p$//' | awk '!seen[$0]++') | grep -Ev '(BIOS boot|EFI System|Solaris /usr & Apple ZFS)' | grep -E 'Linux filesystem' | awk '{ print $1 }' > zpool_rootcacheall_disklist_var01
  set -Eeuo pipefail
  for f in $(cat zpool_rootcacheall_disklist_var01 | awk '{ print $1 }' | sed 's|/dev/||')
  do read dev
    echo "$dev" "$(ls -l /dev/disk/by-id | grep -E '(ata-*|nvme-*|scsi-*)' | grep -w "$f" | awk '{ print $9 }' | sed 's|/dev/disk/by-id/||')" "$(fdisk -l /dev/"$f" | grep -w "Disk /dev/"$f"" | awk '{print $3, $4}' | sed 's|,||')" "$(if [ $(cat /sys/block/"$(echo $f | sed 's/[0-9]\+$//' | sed 's/p$//')"/queue/rotational) == 0 ];then echo "ssd"; else echo "harddisk";fi)" >> zpool_rootcacheall_disklist
  done < zpool_rootcacheall_disklist_var01
fi
set -Eeuo pipefail

# Create disk list for new ZFS pool
msg "Creating disk list for zpool '$POOL' ..."
# Create list of all disks
ls -l /dev/disk/by-id | grep -E '(ata-*|nvme-*|scsi-*)' | awk '{ print $11}'  | sed 's|../../|/dev/|' | sort > zfs_disklist_var01
# Add unformatted / unused disks
lsblk -r --output NAME,MOUNTPOINT | awk -F \/ '/sd/||/nvme/ { dsk=substr($1,1,3);dsks[dsk]+=1 } END { for ( i in dsks ) { if (dsks[i]==1) print "/dev/"i } }' >> zfs_disklist_var01
# Remove all OS & boot disks, Cache disks
if [ -f boot_disklist ]; then
  cat boot_disklist | awk '!seen[$0]++' > temp_var01
fi
if [ -f zpool_rootzil_disklist ]; then
  cat zpool_rootzil_disklist | awk '!seen[$0]++' >> temp_var01
fi
if [ -f zpool_rootcache_disklist ]; then
  cat zpool_rootcache_disklist | awk '!seen[$0]++' >> temp_var01
fi
if [ -f zpool_rootcacheall_disklist ]; then
  cat zpool_rootcacheall_disklist | awk '!seen[$0]++' >> temp_var01
fi
awk -F " " 'NR==FNR {a[$1];next}!($1 in a) {print $0}' temp_var01 zfs_disklist_var01 | awk '!seen[$0]++' | sort > zfs_disklist_var02
# Add Linux by-id to column 2 & Disk Size to column 3,4 & Disk Type to column 5
for f in $(cat zfs_disklist_var02 | awk '{ print $1 }' | sed 's|/dev/||')
  do read dev
    echo "$dev" "$(ls -l /dev/disk/by-id | grep -E '(ata-*|nvme-*|scsi-*)' | grep -w "$f" | awk '{ print $9 }' | sed 's|/dev/disk/by-id/||')" "$(fdisk -l /dev/"$f" | grep -w "Disk /dev/"$f"" | awk '{print $3, $4}' | sed 's|,||')" "$(if [ $(cat /sys/block/"$(echo $f | sed 's/[0-9]\+$//' | sed 's/p$//')"/queue/rotational) == 0 ];then echo "ssd"; else echo "harddisk";fi)" >> zfs_disklist_var03
done < zfs_disklist_var02
# Remove any partition disks
if [ $(cat zfs_disklist_var03 | awk '{ print $1 }' | grep -c 'sd[a-z][0-9]\+$\|nvme[0-9]n[0-9]p[0-9]\+$' 2> /dev/null) -gt 0 ]; then
  msg "The following disks contain existing disk partitions (partitions in red):\n\n$(cat zfs_disklist_var03 | awk '$1 ~ /sd[a-z]$/ {print $1, $3, $4, "(Disk Type: " $5")"}' | sed '/^$/d')\n$(cat zfs_disklist_var03 | awk '$1 ~ /sd[a-z][0-9]$/ {print "\033[0;31m"$1"\033[0m", $3, $4, "(Disk Type: " $5")"}')\n$(cat zfs_disklist_var03 | awk '$1 ~ /nvme[0-9]n[0-9]$/ {print $1, $3, $4, "(Disk Type: " $5")"}')\n$(cat zfs_disklist_var03 | awk '$1 ~ /nvme[0-9]n[0-9]p[0-9]$/ {print "\033[0;31m"$1"\033[0m", $3, $4, "(Disk Type: " $5")"}' | sed '/^$/d')Your options are:\n  1.  Zap, Erase & Wipe the disk partitions (Recommended).\n      (Note: This results in 100% destruction of all data on the disk.)\n  2.  Select which disk partition to use."
  while true; do
    read -p "Proceed to Zap, Erase and Wipe disks: [y/n]?" -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        cat zfs_disklist_var03 | grep -v 'sd[a-z][0-9]\|nvme[0-9]n[0-9]p[0-9]' | awk '!seen[$0]++' 2>/dev/null > zfs_disklist
        info "Good choice. Using whole disk in your zpool '$POOL' $SECTION_HEAD."
        echo
        break
        ;;
      [Nn]*)
        cat zfs_disklist_var03 | awk '!seen[$0]++' 2>/dev/null > zfs_disklist
        info "You have chosen to use disk partitions in your zpool '$POOL' $SECTION_HEAD."
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
else
  cat zfs_disklist_var03 | grep -v 'sd[a-z][0-9]\|nvme[0-9]n[0-9]p[0-9]' | awk '!seen[$0]++' 2>/dev/null > zfs_disklist
fi

# Checking for ZFS pool /tank 
msg "Checking for ZFS pool '$POOL'..." 
if [ $(zpool list $POOL > /dev/null 2>&1; echo $?) == 0 ] && [ $(cat zfs_disklist | wc -l) -ge 1 ]; then
  info "ZFS pool '$POOL' already exists, skipping creating ZFS pool '$POOL'."
  ZPOOL_TANK=0
elif [ $(zpool list $POOL > /dev/null 2>&1; echo $?) != 0 ] && [ $(cat zfs_disklist | wc -l) -ge 1 ]; then
  info "ZFS pool '$POOL' does NOT exist on PVE host: ${YELLOW}$HOSTNAME${NC}." msg "We identified $(cat zfs_disklist | awk '$5~"harddisk"' | wc -l)x rotational hard drives and $(cat zfs_disklist | awk '$5~"ssd"' | wc -l)x SSD drives suitable for creating ZFS pool: '$POOL'. If you choose to create ZFS pool '$POOL' these $(cat zfs_disklist | wc -l)x drives will be ${UNDERLINE}erased, formatted and all existing data on the drives lost forever${NC}."
  echo
  while true; do
    read -p "Proceed to create ZFS pool '$POOL': [y/n]?" -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        ZFSPOOL_TANK_CREATE=0
        info "You have chosen to create ZFS pool '$POOL'."
        echo
        break
        ;;
      [Nn]*)
        info "You have chosen to NOT create ZFS pool '$POOL'. Skipping this step."
        ZFSPOOL_TANK_CREATE=1
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
  ZPOOL_TANK=1
fi

# Building ZFS pool disk type options list
if [ "$ZPOOL_TANK" = 1 ] && [ "$ZFSPOOL_TANK_CREATE" = 0 ]; then
  while true
  do
    msg "You have $(cat zfs_disklist | awk '$5~"harddisk"' | wc -l)x rotational disks and $(cat zfs_disklist | awk '$5~"ssd"' | wc -l)x SSD disks available for your new ZFS pool '$POOL'. $(if [ $(cat zfs_disklist | awk '$5~"harddisk"' | wc -l) -ge 1 ] && [ $(cat zfs_disklist | awk '$5~"ssd"' | wc -l) -ge 1 ]; then echo "You ${UNDERLINE}cannot combine both types of drives${NC} in the same ZFS pool. "; fi)You now must decide on your ZFS pool setup."
    TYPE01="${YELLOW}TYPE01${NC} - $(cat zfs_disklist | awk '$5~"harddisk"' | wc -l)x disk ZFS pool only (No ZFS cache)." >/dev/null
    TYPE02="${YELLOW}TYPE02${NC} - $(cat zfs_disklist | awk '$5~"harddisk"' | wc -l)x disk ZFS pool WITH ZFS root cache." >/dev/null
    TYPE03="${YELLOW}TYPE03${NC} - $(cat zfs_disklist | awk '$5~"harddisk"' | wc -l)x disk ZFS pool AND up to $(cat zfs_disklist | awk '$5~"ssd"' | wc -l)x SSD disk ZFS cache." >/dev/null
    TYPE04="${YELLOW}TYPE04${NC} - $(cat zfs_disklist | awk '$5~"ssd"' | wc -l)x SSD ZFS pool only (No ZFS cache)." >/dev/null
    TYPE05="${YELLOW}TYPE05${NC} - $(cat zfs_disklist | awk '$5~"ssd"' | wc -l)x SSD ZFS pool WITH ZFS root cache." >/dev/null
    TYPE06="${YELLOW}TYPE06${NC} - $(cat zfs_disklist | awk '$5~"ssd"' | wc -l)x SSD ZFS pool AND SSD disk ZFS cache." >/dev/null
    if [ $(cat zfs_disklist | awk '$5~"harddisk"' | wc -l) -ge 1 ] && [ $(cat zfs_disklist | awk '$5~"ssd"' | wc -l) == 0 ] && [ $ZFS_ROOTCACHE_READY == 1 ];then
      msg "Now select your ZFS pool setup for $(cat zfs_disklist | awk '$5~"harddisk"' | wc -l)x rotational disks."
      PS3="Select from the following options (entering numeric) : "
      echo
      select zpool_type in "$TYPE01"
      do
      info "You have selected: $zpool_type"
      ZPOOL_OPTIONS_TYPE=$(echo $zpool_type | sed 's/\s.*$//' | sed 's/\x1b\[[0-9;]*m//g' | sed -e 's/\(.*\)/\L\1/')
      echo
      break
      done
    elif [ $(cat zfs_disklist | awk '$5~"harddisk"' | wc -l) -ge 1 ] && [ $(cat zfs_disklist | awk '$5~"ssd"' | wc -l) == 0 ] && [ $ZFS_ROOTCACHE_READY == 0 ];then
      msg "Now select your ZFS pool setup for $(cat zfs_disklist | awk '$5~"harddisk"' | wc -l)x rotational disks."
      PS3="Select from the following options (entering numeric) : "
      echo
      select zpool_type in "$TYPE02"
      do
      info "You have selected: $zpool_type"
      ZPOOL_OPTIONS_TYPE=$(echo $zpool_type | sed 's/\s.*$//' | sed 's/\x1b\[[0-9;]*m//g' | sed -e 's/\(.*\)/\L\1/')
      echo
      break
      done
    elif [ $(cat zfs_disklist | awk '$5~"harddisk"' | wc -l) -ge 1 ] && [ $(cat zfs_disklist | awk '$5~"ssd"' | wc -l) -ge 1 ] && [ $ZFS_ROOTCACHE_READY == 1 ];then
      msg "Now select your ZFS pool setup for $(cat zfs_disklist | awk '$5~"harddisk"' | wc -l)x rotational disks and $(cat zfs_disklist | awk '$5~"ssd"' | wc -l)x SSD disks.\nRecommend: Create a ZFS Cache to boost rotational disk read & write performance: i.e TYPE03"
      PS3="Select from the following options (entering numeric) : "
      echo
      select zpool_type in "$TYPE01" "$TYPE03"
      do
      info "You have selected: $zpool_type"
      ZPOOL_OPTIONS_TYPE=$(echo $zpool_type | sed 's/\s.*$//' | sed 's/\x1b\[[0-9;]*m//g' | sed -e 's/\(.*\)/\L\1/')
      echo
      break
      done
    elif [ $(cat zfs_disklist | awk '$5~"harddisk"' | wc -l) == 0 ] && [ $(cat zfs_disklist | awk '$5~"ssd"' | wc -l) == 1 ] && [ $ZFS_ROOTCACHE_READY == 1 ];then
      msg "Now select your ZFS pool setup for $(cat zfs_disklist | awk '$5~"ssd"' | wc -l)x SSD disks."
      PS3="Select from the following options (entering numeric) : "
      echo
      select zpool_type in "$TYPE04"
      do
      info "You have selected: $zpool_type"
      ZPOOL_OPTIONS_TYPE=$(echo $zpool_type | sed 's/\s.*$//' | sed 's/\x1b\[[0-9;]*m//g' | sed -e 's/\(.*\)/\L\1/')
      echo
      break
      done
    elif [ $(cat zfs_disklist | awk '$5~"harddisk"' | wc -l) == 0 ] && [ $(cat zfs_disklist | awk '$5~"ssd"' | wc -l) == 1 ] && [ $ZFS_ROOTCACHE_READY = 0 ];then
      msg "Now select your ZFS pool setup for $(cat zfs_disklist | awk '$5~"ssd"' | wc -l)x SSD disks."
      PS3="Select from the following options (entering numeric) : "
      echo
      select zpool_type in "$TYPE05"
      do
      info "You have selected: $zpool_type"
      ZPOOL_OPTIONS_TYPE=$(echo $zpool_type | sed 's/\s.*$//' | sed 's/\x1b\[[0-9;]*m//g' | sed -e 's/\(.*\)/\L\1/')
      echo
      break
      done
    elif [ $(cat zfs_disklist | awk '$5~"harddisk"' | wc -l) == 0 ] && [ $(cat zfs_disklist | awk '$5~"ssd"' | wc -l) -ge 2 ] && [ $ZFS_ROOTCACHE_READY == 1 ];then
      msg "Now select your ZFS pool setup for $(cat zfs_disklist | awk '$5~"ssd"' | wc -l)x SSD disks.\nRecommend: Create a ZFS Cache to boost disk read & write performance: i.e TYPE06"
      PS3="Select from the following options (entering numeric) : "
      echo
      select zpool_type in "$TYPE04" "$TYPE06"
      do
      info "You have selected: $zpool_type"
      ZPOOL_OPTIONS_TYPE=$(echo $zpool_type | sed 's/\s.*$//' | sed 's/\x1b\[[0-9;]*m//g' | sed -e 's/\(.*\)/\L\1/')
      echo
      break
      done
    elif [ $(cat zfs_disklist | awk '$5~"harddisk"' | wc -l) == 0 ] && [ $(cat zfs_disklist | awk '$5~"ssd"' | wc -l) -ge 2 ] && [ $ZFS_ROOTCACHE_READY == 0 ];then
      msg "Now select your ZFS pool setup for $(cat zfs_disklist | awk '$5~"ssd"' | wc -l)x SSD disks."
      PS3="Select from the following options (entering numeric) : "
      echo
      select zpool_type in "$TYPE05"
      do
      info "You have selected: $zpool_type"
      ZPOOL_OPTIONS_TYPE=$(echo $zpool_type | sed 's/\s.*$//' | sed 's/\x1b\[[0-9;]*m//g' | sed -e 's/\(.*\)/\L\1/')
      echo
      break
      done
    fi
    while true; do
      read -p "Confirm your selection is correct: [y/n]?" -n 1 -r YN
      echo
      case $YN in
        [Yy]*)
          echo
          break 2
          ;;
        [Nn]*)
          msg "No good. No problem. Try again..."
          break
          sleep 1
          echo
          ;;
        *)
          warn "Error! Entry must be 'y' or 'n'. Try again..."
          echo
          ;;
      esac
    done
  done
fi


# Create ZFS Pool disk lists
set +Eeuo pipefail
if [ "$ZPOOL_TANK" = 1 ] && [ "$ZFSPOOL_TANK_CREATE" = 0 ]; then
while true; do
  if [[ $ZPOOL_OPTIONS_TYPE == "type01" || $ZPOOL_OPTIONS_TYPE == "type02" ]]; then
    msg "Creating a list of available disks for ZFS pool '$POOL'..."
    cat zfs_disklist | awk '$5~"harddisk"' 2>/dev/null > zpool_harddisk_disklist_var01
    msg "Please select the disks to be used in ZFS pool: ${WHITE}$POOL${NC}"
    menu() {
      echo "Available options:"
      for i in ${!options[@]}; do
          printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
      done
      if [[ "$msg" ]]; then echo "$msg"; fi
    }
    mapfile -t options < zpool_harddisk_disklist_var01
    prompt="Check an option to select disk(s) (type numeric, again to uncheck, ENTER when done): "
    while menu && read -rp "$prompt" num && [[ "$num" ]]; do
      [[ "$num" != *[![:digit:]]* ]] &&
      (( num > 0 && num <= ${#options[@]} )) ||
      { msg="Invalid option: $num"; continue; }
      ((num--)); msg="${options[num]} was ${choices[num]:+un}checked"
      [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
    done
    echo
    printf "Your selected disks are:\n"; msg=" nothing"
    for i in ${!options[@]}; do
      [[ "${choices[i]}" ]] && { printf "${YELLOW}Disk ID:${NC}  %s\n" "${options[i]}"; msg=""; } && echo $({ printf "%s" "${options[i]}"; msg=""; }) >> zpool_harddisk_disklist
    done
    unset choices
  elif [ $ZPOOL_OPTIONS_TYPE == "type03" ]; then
    msg "Creating a list of available disks for ZFS pool '$POOL'..."
    cat zfs_disklist | awk '$5~"harddisk"' 2>/dev/null > zpool_harddisk_disklist_var01  
    cat zfs_disklist | awk '$5~"ssd"' 2>/dev/null > zpool_cache_disklist_var01    
    msg "Please select the disks to be used in ZFS pool: ${WHITE}$POOL${NC}"
    menu() {
      echo "Available options:"
      for i in ${!options[@]}; do 
          printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
      done
      if [[ "$msg" ]]; then echo "$msg"; fi
    }
    mapfile -t options < zpool_harddisk_disklist_var01
    prompt="Check an option to select disk(s) (type numeric, again to uncheck, ENTER when done): "
    while menu && read -rp "$prompt" num && [[ "$num" ]]; do
      [[ "$num" != *[![:digit:]]* ]] &&
      (( num > 0 && num <= ${#options[@]} )) ||
      { msg="Invalid option: $num"; continue; }
      ((num--)); msg="${options[num]} was ${choices[num]:+un}checked"
      [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
    done
    echo
    printf "Your selected disk disks are:\n"; msg=" nothing"
    for i in ${!options[@]}; do
      [[ "${choices[i]}" ]] && { printf "${YELLOW}Disk ID:${NC}  %s\n" "${options[i]}"; msg=""; } && echo $({ printf "%s" "${options[i]}"; msg=""; }) >> zpool_harddisk_disklist
    done
    unset choices
    echo   
    if [ $(cat zpool_cache_disklist_var01 | wc -l) -ge 1 ] && [ $ZFS_ROOTCACHE_READY = 1 ]; then
      msg "Creating a list of available SSD disks for ARC or L2ARC cache and ZIL..."
      msg "There are two different SSD caches that a ZFS pool can make use of:\n  1.  ZFS Intent Log, or ZIL, to buffer WRITE operations.\n  2.  ARC and L2ARC cache which are meant for READ operations.\nIn the next steps you will asked to select disks which will be partitioned for ZIL and ARC or L2ARC cache.\nThese disks will be erased and wiped of all data.\n\nYou have 2x or more SSD disks available for ARC or L2ARC cache and ZIL. Your options are: \n1)  ${YELLOW}Standard Cache${NC}: Select 1x SSD cache disk only. No ARC, L2ARC or ZIL disk redundancy.\n2)  ${YELLOW}Accelerated Cache${NC}: Select 2x SSD cache disks. ARC or L2ARC cache set to Raid0 (stripe) and ZIL set to Raid1 (mirror).\nThere is no need to select more than 2x SSD disks!"
      msg "Please select the SSD disks to be used for ARC or L2ARC cache and ZIL:"
      menu() {
        echo "Available options:"
        for i in ${!options[@]}; do 
            printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
        done
        if [[ "$msg" ]]; then echo "$msg"; fi
      }
      mapfile -t options < zpool_cache_disklist_var01
      set +Eeuo pipefail
      prompt="Check an option to select SSD disks (again to uncheck, ENTER when done): "
      while menu && read -rp "$prompt" num && [[ "$num" ]]; do
        [[ "$num" != *[![:digit:]]* ]] &&
        (( num > 0 && num <= ${#options[@]} )) ||
        { msg="Invalid option: $num"; continue; }
        ((num--)); msg="${options[num]} was ${choices[num]:+un}checked"
        [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
      done
      echo
      printf "Your selected SSD cache disks are:\n"; msg=" nothing"
      for i in ${!options[@]}; do
        [[ "${choices[i]}" ]] && { printf "${YELLOW}Disk ID:${NC}  %s\n" "${options[i]}"; msg=""; } && echo $({ printf "%s" "${options[i]}"; msg=""; }) >> zpool_cache_disklist
      done
      unset choices
    elif [ $ZFS_ROOTCACHE_READY = 0 ]; then
      msg "You have already selected Root File System partitions for ARC or L2ARC Cache:\n${WHITE}$(cat zpool_rootcache_disklist 2>/dev/null)${NC}"
      msg "You have already selected Root File System partitions for ZIL:\n${WHITE}$(cat zpool_rootzil_disklist 2>/dev/null)${NC}"
    fi
  elif [[ $ZPOOL_OPTIONS_TYPE == "type04" || $ZPOOL_OPTIONS_TYPE == "type05" ]];then
    msg "Creating a list of available SSD disks for ZFS pool '$POOL'..."
    cat zfs_disklist | awk '$5~"ssd"' 2>/dev/null > zpool_ssd_disklist_var01
    msg "Please select the SSD disks to be used in ZFS pool: ${WHITE}$POOL${NC}."
    menu() {
      echo "Available options:"
      for i in ${!options[@]}; do 
          printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
      done
      if [[ "$msg" ]]; then echo "$msg"; fi
    }
    mapfile -t options < zpool_ssd_disklist_var01
    prompt="Check an option to select SSD disks (again to uncheck, ENTER when done): "
    while menu && read -rp "$prompt" num && [[ "$num" ]]; do
      [[ "$num" != *[![:digit:]]* ]] &&
      (( num > 0 && num <= ${#options[@]} )) ||
      { msg="Invalid option: $num"; continue; }
      ((num--)); msg="${options[num]} was ${choices[num]:+un}checked"
      [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
    done
    echo
    printf "Your selected SSD disks are:\n"; msg=" nothing"
    for i in ${!options[@]}; do
      [[ "${choices[i]}" ]] && { printf "${YELLOW}Disk ID:${NC}  %s\n" "${options[i]}"; msg=""; } && echo $({ printf "%s" "${options[i]}"; msg=""; }) >> zpool_ssd_disklist
    done
    unset choices
  elif [ $ZPOOL_OPTIONS_TYPE == "type06" ];then
    msg "Creating a list of available SSD disks for ZFS pool $POOL..."
    cat zfs_disklist | awk '$5~"ssd"' > zpool_ssd_disklist_var01
    if [ $ZFS_ROOTCACHE_READY = 1 ]; then
      msg "Please select the SSD disks to be used in ZFS pool: ${WHITE}$POOL${NC}.
      Do not select all SSD disks. Leave one or two SSD disks unselected for ZFS cache."
    elif [ $ZFS_ROOTCACHE_READY = 0 ]; then
      msg "Please select the SSD disks to be used in ZFS pool: ${WHITE}$POOL${NC}."
    fi
    menu() {
      echo "Available options:"
      for i in ${!options[@]}; do 
          printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
      done
      if [[ "$msg" ]]; then echo "$msg"; fi
    }
    mapfile -t options < zpool_ssd_disklist_var01
    prompt="Check an option to select SSD disks (again to uncheck, ENTER when done): "
    while menu && read -rp "$prompt" num && [[ "$num" ]]; do
      [[ "$num" != *[![:digit:]]* ]] &&
      (( num > 0 && num <= ${#options[@]} )) ||
      { msg="Invalid option: $num"; continue; }
      ((num--)); msg="${options[num]} was ${choices[num]:+un}checked"
      [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
    done
    echo
    printf "Your selected SSD disks are:\n"; msg=" nothing"
    for i in ${!options[@]}; do
      [[ "${choices[i]}" ]] && { printf "${YELLOW}Disk ID:${NC}  %s\n" "${options[i]}"; msg=""; } && echo $({ printf "%s" "${options[i]}"; msg=""; }) >> zpool_ssd_disklist
    done
    unset choices
    echo
    if [ $(cat zpool_cache_disklist_var01 | wc -l) -ge 1 ] && [ $ZFS_ROOTCACHE_READY = 1 ]; then
      awk -F " "  'NR==FNR {a[$1];next}!($1 in a) {print $0}' zpool_ssd_disklist zpool_ssd_disklist_var01 | awk '!seen[$0]++' | sort > zpool_cache_disklist_var01
      msg "Creating a list of available SSD disks for ARC or L2ARC cache and ZIL..."
      msg "There are two different SSD caches that a ZFS pool can make use of:\n  1.  ZFS Intent Log, or ZIL, to buffer WRITE operations.\n  2.  ARC and L2ARC cache which are meant for READ operations.\nIn the next steps you will asked to select disks which will be partitioned for ZIL and ARC or L2ARC cache.\nThese disks will be erased and wiped of all data.\n\n
      You have 2x or more SSD disks available for ARC or L2ARC cache and ZIL. Your options are: \n1)  ${YELLOW}Standard Cache${NC}: Select 1x SSD cache disk only. No ARC,L2ARC or ZIL disk redundancy.\n2)  ${YELLOW}Accelerated Cache${NC}: Select 2x SSD cache disks. ARC or L2ARC cache set to Raid0 (stripe) and ZIL set to Raid1 (mirror).\n
      No need to select more than 2x SSD disks!"
      msg "Please select the SSD disks to be used for ARC or L2ARC cache and ZIL:"
    menu() {
      echo "Available options:"
      for i in ${!options[@]}; do 
          printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
      done
      if [[ "$msg" ]]; then echo "$msg"; fi
    }
    mapfile -t options < zpool_cache_disklist_var01
    prompt="Check an option to select SSD disks (again to uncheck, ENTER when done): "
    while menu && read -rp "$prompt" num && [[ "$num" ]]; do
      [[ "$num" != *[![:digit:]]* ]] &&
      (( num > 0 && num <= ${#options[@]} )) ||
      { msg="Invalid option: $num"; continue; }
      ((num--)); msg="${options[num]} was ${choices[num]:+un}checked"
      [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
    done
    echo
    printf "Your selected SSD cache disks are:\n"; msg=" nothing"
    for i in ${!options[@]}; do
      [[ "${choices[i]}" ]] && { printf "${YELLOW}Disk ID:${NC}  %s\n" "${options[i]}"; msg=""; } && echo $({ printf "%s" "${options[i]}"; msg=""; }) >> zpool_cache_disklist
    done
    unset choices
    elif [ $ZFS_ROOTCACHE_READY = 0 ]; then
      msg "You have already selected Root File System partitions for ARC or L2ARC Cache:\n${WHITE}$(cat zpool_rootcache_disklist 2>/dev/null)${NC}"
      msg "You have already selected Root File System partitions for ZIL:\n${WHITE}$(cat zpool_rootzil_disklist 2>/dev/null)${NC}"
    fi
  fi
  echo
  if [ -s zpool_harddisk_disklist ] || [ -s zpool_ssd_disklist ]; then
    info "Your ZFS Pool disk selection is:"
    msg "  ${UNDERLINE}ZFS Pool Disk ID${NC}"
    i=0
    while read line; do 
      i=$((i+1))
      msg "  ${i})  $line"
    done < <(cat zpool_harddisk_disklist zpool_ssd_disklist 2>/dev/null)
  else
    info "Your final ZFS Pool disk selection is:"
    msg "  ${UNDERLINE}ZFS Pool Disk ID${NC}"
    msg "  ${WHITE}You have NOT selected any disks!${NC}"
  fi
  if [ -s zpool_cache_disklist ]; then
    echo
    info "Your ZFS cache setup is:"
    msg "  ${UNDERLINE}ARC, L2ARC and ZIL SSD Cache Disk ID${NC} (whole disks)"
    i=0
    while read line; do 
      i=$((i+1))
      msg "  ${i})  $line"
    done < <(cat zpool_cache_disklist 2>/dev/null)
  fi
  if [ $ZFS_ROOTCACHE_READY = 0 ]; then
    echo
    info "Your ZFS cache setup is:"
    msg "  ${UNDERLINE}Root File System Partitioned for ARC or L2ARC${NC} (Disk ID)"
    i=0
    while read line; do 
      i=$((i+1))
      msg "  ${i})  $line"
    done < <(cat zpool_rootcache_disklist 2>/dev/null)
    msg "  ${UNDERLINE}Root File System Partitioned for ZIL${NC} (Disk ID)"
    i=0
    while read line; do 
      i=$((i+1))
      msg "  ${i})  $line"
    done < <(cat zpool_rootzil_disklist 2>/dev/null)
  fi
  echo
  while true; do
    read -p "Confirm your zpool disk selection is correct: [y/n]?" -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        echo
        break 2
        ;;
      [Nn]*)
        msg "No good. No problem. Try again..."
        rm {zpool_harddisk_disklist_var01,zpool_harddisk_disklist,zpool_ssd_disklist_var01,zpool_ssd_disklist,zpool_cache_disklist_var01,zpool_cache_disklist} 2>/dev/null
        sleep 1
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
  done
fi
set -Eeuo pipefail


# Checking for ZFS pool /tank Raid level options
if [ "$ZPOOL_TANK" = 1 ] && [ "$ZFSPOOL_TANK_CREATE" = 0 ]; then
while true; do
  msg "Checking available Raid level options for your ZFS pool '$POOL'..."
  echo
  RAID0="${YELLOW}RAID0${NC} - Also called “striping”. No redundancy, so the failure of a single drive makes the volume unusable." >/dev/null
  RAID1="${YELLOW}RAID1${NC} - Also called “mirroring”. Data is written identically to all disks. The resulting capacity is that of a single disk." >/dev/null
  RAID10="${YELLOW}RAID10${NC} - A combination of RAID0 and RAID1. Requires at least 4 disks." >/dev/null
  RAIDZ1="${YELLOW}RAIDZ1${NC} - A variation on RAID-5, single parity. Requires at least 3 disks." >/dev/null
  RAIDZ2="${YELLOW}RAIDZ2${NC} - A variation on RAID-5, double parity. Requires at least 4 disks." >/dev/null
  RAIDZ3="${YELLOW}RAIDZ3${NC} - A variation on RAID-5, triple parity. Requires at least 5 disks." >/dev/null
  if [ $(cat zpool_harddisk_disklist 2>/dev/null | wc -l) = 1 ] || [ $(cat zpool_ssd_disklist 2>/dev/null | wc -l) = 1 ]; then
    msg "Raid type options for ${WHITE}$(( $(cat zpool_harddisk_disklist 2>/dev/null | wc -l) + $(cat zpool_ssd_disklist 2>/dev/null | wc -l) ))x${NC} disks are:"
    PS3="Select a Raid type for your ZFS pool '$POOL' (entering numeric) : "
    echo
    select raid_type in "$RAID0"
    do
    echo
    info "You have selected: $(echo $raid_type | sed 's/\s.*$//')"
    ZPOOL_RAID_TYPE=$(echo $raid_type | sed 's/\s.*$//' | sed 's/\x1b\[[0-9;]*m//g' | sed -e 's/\(.*\)/\L\1/')
    echo
    break
    done
  elif [ $(cat zpool_harddisk_disklist 2>/dev/null | wc -l) = 2 ] || [ $(cat zpool_ssd_disklist 2>/dev/null | wc -l) = 2 ]; then
    msg "Raid type options for ${WHITE}$(( $(cat zpool_harddisk_disklist 2>/dev/null | wc -l) + $(cat zpool_ssd_disklist 2>/dev/null | wc -l) ))x${NC} disks are (Recommend RAID1):"
    PS3="Select the Raid type for your ZFS pool '$POOL' (entering numeric) : "
    echo
    select raid_type in "$RAID0" "$RAID1"
    do
    echo
    info "You have selected: $(echo $raid_type | sed 's/\s.*$//')"
    ZPOOL_RAID_TYPE=$(echo $raid_type | sed 's/\s.*$//' | sed 's/\x1b\[[0-9;]*m//g' | sed -e 's/\(.*\)/\L\1/')
    echo
    break
    done
  elif [ $(cat zpool_harddisk_disklist 2>/dev/null | wc -l) = 3 ] || [ $(cat zpool_ssd_disklist 2>/dev/null | wc -l) = 3 ]; then
    msg "Raid type options for ${WHITE}$(( $(cat zpool_harddisk_disklist 2>/dev/null | wc -l) + $(cat zpool_ssd_disklist 2>/dev/null | wc -l) ))x${NC} disks are(Recommend RAIDZ1):"
    PS3="Select the Raid type for your ZFS pool '$POOL' (entering numeric) : "
    echo
    select raid_type in "$RAID0" "$RAID1" "$RAIDZ1"
    do
    echo
    info "You have selected: $(echo $raid_type | sed 's/\s.*$//')"
    ZPOOL_RAID_TYPE=$(echo $raid_type | sed 's/\s.*$//' | sed 's/\x1b\[[0-9;]*m//g' | sed -e 's/\(.*\)/\L\1/')
    echo
    break
    done
  elif [ $(cat zpool_harddisk_disklist 2>/dev/null | wc -l) = 4 ] || [ $(cat zpool_ssd_disklist 2>/dev/null | wc -l) = 4 ]; then
    msg "Raid type options for ${WHITE}$(( $(cat zpool_harddisk_disklist 2>/dev/null | wc -l) + $(cat zpool_ssd_disklist 2>/dev/null | wc -l) ))x${NC} disks are (Recommend RAIDZ1):"
    PS3="Select the Raid type for your ZFS pool '$POOL' (entering numeric) : "
    echo
    select raid_type in "$RAID0" "$RAID1" "$RAID10" "$RAIDZ1" "$RAIDZ2"
    do
    echo
    info "You have selected: $(echo $raid_type | sed 's/\s.*$//')"
    ZPOOL_RAID_TYPE=$(echo $raid_type | sed 's/\s.*$//' | sed 's/\x1b\[[0-9;]*m//g' | sed -e 's/\(.*\)/\L\1/')
    echo
    break
    done
  elif [ $(cat zpool_harddisk_disklist 2>/dev/null | wc -l) -ge 5 ] || [ $(cat zpool_ssd_disklist 2>/dev/null | wc -l) -ge 5 ]; then
    msg "Raid type options for ${WHITE}$(( $(cat zpool_harddisk_disklist 2>/dev/null | wc -l) + $(cat zpool_ssd_disklist 2>/dev/null | wc -l) ))x${NC} disks are (Recommend RAIDZ2):"
    PS3="Select the Raid type for your ZFS pool '$POOL' (entering numeric) : "
    echo
    select raid_type in "$RAID0" "$RAID1" "$RAID10" "$RAIDZ1" "$RAIDZ2" "$RAIDZ3"
    do
    echo
    info "You have selected: $(echo $raid_type | sed 's/\s.*$//')"
    ZPOOL_RAID_TYPE=$(echo $raid_type | sed 's/\s.*$//' | sed 's/\x1b\[[0-9;]*m//g' | sed -e 's/\(.*\)/\L\1/')
    echo
    break
    done
  fi
  while true; do
    read -p "Confirm your ZFS pool raid type is correct: [y/n]?" -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        echo
        break 2
        ;;
      [Nn]*)
        msg "No good. No problem. Try again..."
        sleep 1
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
done
fi

    
# Erase / Wipe ZFS pool disks
if [ "$ZPOOL_TANK" = 1 ] && [ "$ZFSPOOL_TANK_CREATE" = 0 ]; then
  msg "Zapping, Erasing and Wiping ZFS pool disks..."
  if [ -f zpool_harddisk_disklist ]; then
    cat zpool_harddisk_disklist 2>/dev/null | awk '{print $1}' >> zpool_disklist_erase_input
  fi
  if [ -f zpool_ssd_disklist ]; then
    cat zpool_ssd_disklist 2>/dev/null | awk '{print $1}' >> zpool_disklist_erase_input
  fi
  if [ -f zpool_harddisk_disklist ]; then
    cat zpool_harddisk_disklist 2>/dev/null | awk '{print $1}' >> zpool_disklist_erase_input
  fi
  while read SELECTED_DEVICE; do
    sgdisk --zap $SELECTED_DEVICE >/dev/null 2>&1
    info "SGDISK - zapped (destroyed) the GPT data structures on device: $SELECTED_DEVICE"
    dd if=/dev/zero of=$SELECTED_DEVICE count=1 bs=512 conv=notrunc 2>/dev/null
    info "DD - cleaned & wiped device: $SELECTED_DEVICE"
    wipefs --all --force $SELECTED_DEVICE  >/dev/null 2>&1
    info "wipefs - wiped device: $SELECTED_DEVICE"
  done < zpool_disklist_erase_input # file listing of disks to erase
  echo
fi


# Create ZFS Pool Tank
if [ "$ZPOOL_TANK" = 1 ] && [ "$ZFSPOOL_TANK_CREATE" = 0 ]; then
  if [ $ZPOOL_RAID_TYPE == "raid0" ]; then
    msg "Creating ZFS pool '$POOL'. Raid type: Raid-0..."
    zpool create -f -o ashift=12 $POOL $(cat zpool_harddisk_disklist zpool_ssd_disklist 2>/dev/null | awk '{print $2}' ORS=' ' | sed 's/ *$//')
  elif [ $ZPOOL_RAID_TYPE == "raid1" ]; then
    msg "Creating ZFS pool '$POOL'. Raid type: Raid-1..."
    zpool create -f -o ashift=12 $POOL $(cat zpool_harddisk_disklist zpool_ssd_disklist 2>/dev/null | awk '{print $2}' ORS=' ' | sed 's/ *$//' | sed 's/^/mirror /')   
  elif [ $ZPOOL_RAID_TYPE == "raid10" ]; then
    msg "Creating ZFS pool '$POOL'. Raid type: Raid-10..."
    zpool create -f -o ashift=12 $POOL $(cat zpool_harddisk_disklist zpool_ssd_disklist 2>/dev/null | awk '{print $2}' ORS=' ' | sed 's/ *$//' | sed '-es/ / mirror /'{1000..1..2} | sed 's/^/mirror /')   
  elif [ $ZPOOL_RAID_TYPE == "raidz1" ]; then
    msg "Creating ZFS pool '$POOL'. Raid type: Raid-Z1..."
    zpool create -f -o ashift=12 $POOL raidz1 $(cat zpool_harddisk_disklist zpool_ssd_disklist 2>/dev/null | awk '{print $2}' ORS=' ' | sed 's/ *$//')
  elif [ $ZPOOL_RAID_TYPE == "raidz2" ]; then
    msg "Creating  ZFS pool '$POOL'. Raid type: Raid-Z2..."
    zpool create -f -o ashift=12 $POOL raidz2 $(cat zpool_harddisk_disklist zpool_ssd_disklist 2>/dev/null | awk '{print $2}' ORS=' ' | sed 's/ *$//')
  fi
fi
echo


# Create ZFS Root Cache
if [ $ZFS_ROOTCACHE_READY = 0 ] && [ -s zpool_rootcache_disklist ] && [ -s zpool_rootzil_disklist ]; then
  msg "Creating ZFS pool cache..."
  cat zpool_rootzil_disklist | awk '{ print $2 }' | sed 's/^/\/dev\/disk\/by-id\//' | awk '{print}' ORS=' ' | sed '$s/.$//' | sed 's/^/mirror /' > zpool_cache_zil_partitioned_disklist
  zpool add $POOL log $(cat zpool_cache_zil_partitioned_disklist)
  info "ZIL cache completed:\n  1.  $(cat zpool_rootzil_disklist | wc -l)x disks Raid1 (mirror)."
  cat zpool_rootcache_disklist | awk '{ print $2 }' | sed 's/^/\/dev\/disk\/by-id\//' | awk '{print}' ORS=' ' | sed '$s/.$//' > zpool_cache_arc_partitioned_disklist
  zpool add $POOL cache $(cat zpool_cache_arc_partitioned_disklist)
  info "ARC cache completed:\n  1.  $(cat zpool_rootcache_disklist | wc -l)x disks Raid0 (stripe)."
  echo
fi


# Create ZFS Pool Cache - whole disk
if [ "$ZPOOL_TANK" = 1 ] && [ "$ZFSPOOL_TANK_CREATE" = 0 ] && [ -s zpool_cache_disklist ] && [ "$ZFS_ROOTCACHE_READY" = 1 ] && [[ "$ZPOOL_OPTIONS_TYPE" = "type02" || "$ZPOOL_OPTIONS_TYPE" =  "type04" ]]; then
  msg "Calculating ARC or L2ARC cache and ZIL disk partition sizes..."
  msg "You have allocated $(cat zpool_cache_disklist 2>/dev/null | wc -l)x SSD disk for ZFS cache partitioning.\nThe maximum size of a ZIL log device should be about half the size of your hosts ${YELLOW}$(grep MemTotal /proc/meminfo | awk '{printf "%.0fGB\n", $2/1024/1024}')${NC} installed physical RAM memory BUT not less than our ${YELLOW}default 8GB${NC}.\nThe size of ARC or L2ARC cache should be not less than our ${YELLOW}default 64GB${NC} but could be the remaining size of your ZFS cache disk.\n\nYou have allocated the following $(cat zpool_cache_disklist 2>/dev/null | wc -l)x SSD disks for cache:\n${WHITE}$(cat zpool_cache_disklist 2>/dev/null)${NC}\n\nThe system will automatically calculate the best partition sizes for you. You can accept the suggested values by pressing ENTER on your keyboard.\nOr overwrite the suggested value by typing in your own value and press ENTER to accept/continue."
  echo
  if [ $(grep MemTotal /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024/2}') -le 8 ]; then
    ZIL_VAR_01=8
  else
    ZIL_VAR_01="$(grep MemTotal /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024/2}')"
  fi
  while true; do
    read -p "Enter the ZIL partition size (GB): " -e -i $ZIL_VAR_01 ZIL_VAR_02
    if [ $ZIL_VAR_02 -le $(( $(grep MemTotal /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024}') / 2 )) ] && [ $ZIL_VAR_02 -ge 8 ]; then
      info "Good ZIL Sizing. ZIL partition size is set: ${YELLOW}"$ZIL_VAR_02"GB${NC}."
      echo
      break
    elif [ $ZIL_VAR_02 -lt $(( $(grep MemTotal /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024}') / 2  )) ] && [ $ZIL_VAR_02 -lt 8 ]; then
      warn "There are problems with your input:
      1. A "$ZIL_VAR_02"GB partition size is less than 50% of your $(grep MemTotal /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024}')GB RAM.
      2. A "$ZIL_VAR_02"GB partition size is smaller than the default 8GB minimum."
      while true; do
        read -p "Do you want to accept a non-standard "$ZIL_VAR_02"GB partition size: [y/n]?" -n 1 -r YN
        echo
        case $YN in
          [Yy]*)
            echo
            info "ZIL partition size is set: ${YELLOW}"$ZIL_VAR_02"GB${NC}."
            echo
            break 2
            ;;
          [Nn]*)
            echo
            warn "No good. No problem. Try again..."
            echo
            break
            ;;
          *)
            warn "Error! Entry must be 'y' or 'n'. Try again..."
            echo
            ;;
        esac
      done
    elif [ $ZIL_VAR_02 -gt $(( $(grep MemTotal /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024}') / 2  )) ] && [ $ZIL_VAR_02 -lt $(( $(grep MemTotal /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024}')  )) ] && [ $ZIL_VAR_02 -gt 8 ]; then
      warn "There are problems with your input:
      1. Your "$ZIL_VAR_02"GB partition size input exceeds 50% of your installed $(grep MemTotal /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024}')GB of RAM memory.
      2. Your "$ZIL_VAR_02"GB partition size input is unnecessarily larger than the default 8GB minimum."
      while true; do
        read -p "Do you want to accept a non-standard "$ZIL_VAR_02"GB partition size: [y/n]?" -n 1 -r YN
        echo
        case $YN in
          [Yy]*)
            echo
            info "ZIL partition size is set: ${YELLOW}"$ZIL_VAR_02"GB${NC}."
            echo
            break 2
            ;;
          [Nn]*)
            echo
            warn "No good. No problem. Try again..."
            echo
            break
            ;;
          *)
            warn "Error! Entry must be 'y' or 'n'. Try again..."
            echo
            ;;
        esac
      done
    elif [ $ZIL_VAR_02 -gt $(( $(grep MemTotal /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024}') )) ] && [ $ZIL_VAR_02 -gt 8 ]; then
      warn "There are problems with your input:
      1. This is a BAD idea! A "$ZIL_VAR_02"GB partition size exceeds your total installed $(grep MemTotal /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024}')GB of RAM.
      2. And a "$ZIL_VAR_02"GB partition size is much larger than the default 8GB minimum."
      while true; do
        read -p "Do you want to accept a non-standard "$ZIL_VAR_02"GB partition size: [y/n]?" -n 1 -r YN
        echo
        case $YN in
          [Yy]*)
            echo
            info "ZIL partition size is set: ${YELLOW}"$ZIL_VAR_02"GB${NC}."
            echo
            break 2
            ;;
          [Nn]*)
            echo
            warn "No good. No problem. Try again..."
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
  done
  if [ 64 -le $(( $(cat zpool_cache_disklist | sort -k 3 | awk 'NR==1{print $3}' | awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}') * 9/10 - $ZIL_VAR_02 )) ]; then
    ARC_VAR_01=64
  else
    ARC_VAR_01=$(( $(cat zpool_cache_disklist | sort -k 3 | awk 'NR==1{print $3}' | awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}') * 9/10 - $ZIL_VAR_02 ))
  fi
  while true; do
    read -p "Enter the ARC or L2ARC partition size (GB): " -e -i $ARC_VAR_01 ARC_VAR_02
    if [ $ARC_VAR_02 -le $(( $(cat zpool_cache_disklist | sort -k 3 | awk 'NR==1{print $3}' | awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}') * 9/10 - $ZIL_VAR_01 )) ] && [ $ARC_VAR_02 -ge 64 ]; then
      info "ARC or L2ARC partition size is set: ${YELLOW}"$ARC_VAR_02"GB${NC}."
      echo
      break
    elif [ $ARC_VAR_02 -gt $(( $(cat zpool_cache_disklist | sort -k 3 | awk 'NR==1{print $3}' | awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}') * 9/10 - $ZIL_VAR_01 )) ]; then
      warn "There are problems with your input:
      1)  Your "$ARC_VAR_02"GB partition size exceeds available SSD disk space.
      Try again..."
      echo
    elif [ $ARC_VAR_02 -lt 64 ]; then
      warn "There are problems with your input:
      1) Your "$ARC_VAR_02"GB partition size is smaller than the default 64GB minimum. You have "$(( $(cat zpool_cache_disklist | sort -k 3 | awk 'NR==1{print $3}' | awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}') * 9/10 - $ZIL_VAR_02 ))"GB of free disk space available for this task."
      while true; do
        read -p "Do you want to accept a non-standard "$ARC_VAR_02"GB partition size: [y/n]?" -n 1 -r YN
        echo
        case $YN in
          [Yy]*)
            echo
            info "ARC or L2ARC partition size is set: ${YELLOW}"$ARC_VAR_02"GB${NC}."
            echo
            break 2
            ;;
          [Nn]*)
            echo
            warn "No good. No problem. Try again..."
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
  done
  ZIL_SIZE="$(( ($ZIL_VAR_02 * 1073741824)/512 ))"
  ARC_SIZE="$(( ($ARC_VAR_02 * 1073741824)/512 ))"
  # Partitioning ZFS cache disks
  msg "Partitioning the ZFS cache disks..."
  cat zpool_cache_disklist 2>/dev/null | awk '{print $1}' > zpool_cache_disklist_partition_input
  while read SELECTED_DEVICE; do
    echo 'label: gpt' | sfdisk $SELECTED_DEVICE
    info "GPT labelled: $SELECTED_DEVICE"
    sfdisk --quiet --wipe=always --force $SELECTED_DEVICE <<-EOF
    ,$ZIL_SIZE
    ,$ARC_SIZE
EOF
    info "Partitioning complete for: $SELECTED_DEVICE"
  done < zpool_cache_disklist_partition_input # file listing of disks to erase
  echo
  # Creating ZFS Cache
  msg "Creating ZFS pool cache..."
  for f in $(cat zpool_cache_disklist_partition_input | awk '{ print $1 }' | sed 's|/dev/||')
    do read
      echo "$(fdisk -l /dev/"$f" | grep '^/dev' | cut -d' ' -f1)" >> zpool_cache_partitioned_disklist_var01
  done < zpool_cache_disklist_partition_input
  for f in $(cat zpool_cache_partitioned_disklist_var01 | awk '{ print $1 }' | sed 's|/dev/||')
    do read dev
      echo "$dev" "$(ls -l /dev/disk/by-id | grep -E '(ata-*|nvme-*|scsi-*)' | grep -w "$f" | awk '{ print $9 }' | sed 's|/dev/disk/by-id/||')" "$(fdisk -l /dev/"$f" | grep -w "Disk /dev/"$f"" | awk '{print $3, $4}' | sed 's|,||')" "$(if [ $(cat /sys/block/"$(echo $f | sed 's/[0-9]\+$//' | sed 's/p$//')"/queue/rotational) == 0 ];then echo "ssd"; else echo "harddisk";fi)" >> zpool_cache_partitioned_disklist_var02
  done < zpool_cache_partitioned_disklist_var01
  if [ $(cat zpool_cache_partitioned_disklist_var02 | grep -w "$ZIL_VAR_02 GiB" | wc -l) -le 3 ]; then
    cat zpool_cache_partitioned_disklist_var02 | grep -w "$ZIL_VAR_02 GiB" | awk '{ print $2 }' | sed 's/^/\/dev\/disk\/by-id\//' | awk '{print}' ORS=' ' | sed '$s/.$//' | sed 's/^/mirror /' > zpool_cache_zil_partitioned_disklist
    zpool add $POOL log $(cat zpool_cache_zil_partitioned_disklist)
    info "ZIL cache completed:\n  1.  $(cat zpool_cache_zil_partitioned_disklist | wc -l)x disk Raid1 (mirror only)."
    echo
  elif [ $(cat zpool_cache_partitioned_disklist_var02 | grep -w "$ZIL_VAR_02 GiB" | wc -l) -ge 4 ]; then
    count=$(cat zpool_cache_partitioned_disklist_var02 | grep -w "$ZIL_VAR_02 GiB" | wc -l)
    if [ "$((count% 2))" -eq 0 ]; then
      cat zpool_cache_partitioned_disklist_var02 | grep -w "$ZIL_VAR_02 GiB" | awk '{ print $2 }' | sed 's/^/\/dev\/disk\/by-id\//' | awk '{print}' ORS=' ' | sed '$s/.$//' | sed '-es/ / mirror /'{1000..1..2} | sed 's/^/mirror /' > zpool_cache_zil_partitioned_disklist
      zpool add $POOL log $(cat zpool_cache_zil_partitioned_disklist)
      info "ZIL cache completed:\n  1.  $(( $(cat zpool_cache_zil_partitioned_disklist | wc -l) / 2 ))x disk Raid0 (stripe).\n  2.  $(( $(cat zpool_cache_zil_partitioned_disklist | wc -l) / 2 ))x disk Raid1 (mirror)."
      echo
    else
      cat zpool_cache_partitioned_disklist_var02 | grep -w "$ZIL_VAR_02 GiB" | sed '$ d' | awk '{ print $2 }' | sed 's/^/\/dev\/disk\/by-id\//' | awk '{print}' ORS=' ' | sed '$s/.$//' | sed '-es/ / mirror /'{1000..1..2} | sed 's/^/mirror /' > zpool_cache_zil_partitioned_disklist
      zpool add $POOL log $(cat zpool_cache_zil_partitioned_disklist)
      info "ZIL cache completed:\n  1.  $(( $(cat zpool_cache_zil_partitioned_disklist | wc -l) / 2 ))x disk Raid0 (stripe).\n  1.  $(( $(cat zpool_cache_zil_partitioned_disklist | wc -l) / 2 ))x disk Raid1 (mirror)."
      echo
    fi
  fi
  if [ $(cat zpool_cache_partitioned_disklist_var02 | grep -w "$ARC_VAR_02 GiB" | wc -l) -le 3 ]; then
    cat zpool_cache_partitioned_disklist_var02 | grep -w "$ARC_VAR_02 GiB" | awk '{ print $2 }' | sed 's/^/\/dev\/disk\/by-id\//' | awk '{print}' ORS=' ' | sed '$s/.$//' > zpool_cache_arc_partitioned_disklist
    zpool add $POOL cache $(cat zpool_cache_arc_partitioned_disklist)
    info "ARC cache completed:\n  1.  $(cat zpool_cache_arc_partitioned_disklist | wc -l)x disk Raid0 (stripe only)."
    echo
  elif [ $(cat zpool_cache_partitioned_disklist_var02 | grep -w "$ARC_VAR_02 GiB" | wc -l) -ge 4 ]; then
    count=$(cat zpool_cache_partitioned_disklist_var02 | grep -w "$ARC_VAR_02 GiB" | wc -l)
    if [ "$((count% 2))" -eq 0 ]; then
      cat zpool_cache_partitioned_disklist_var02 | grep -w "$ARC_VAR_02 GiB" | awk '{ print $2 }' | sed 's/^/\/dev\/disk\/by-id\//' | awk '{print}' ORS=' ' | sed '$s/.$//' | sed '-es/ / mirror /'{1000..1..2} | sed 's/^/mirror /' > zpool_cache_arc_partitioned_disklist
      zpool add $POOL cache $(cat zpool_cache_zil_partitioned_disklist)
      info "ARC cache completed:\n  1.  $(( $(cat zpool_cache_arc_partitioned_disklist | wc -l) / 2 ))x disk Raid0 (stripe).\n  2.  $(( $(cat zpool_cache_arc_partitioned_disklist | wc -l) / 2 ))x disk Raid1 (mirror)."
      echo
    else
      cat zpool_cache_partitioned_disklist_var02 | grep -w "$ARC_VAR_02 GiB" | sed '$ d' | awk '{ print $2 }' | sed 's/^/\/dev\/disk\/by-id\//' | awk '{print}' ORS=' ' | sed '$s/.$//' | sed '-es/ / mirror /'{1000..1..2} | sed 's/^/mirror /' > zpool_cache_arc_partitioned_disklist
      zpool add $POOL cache $(cat zpool_cache_arc_partitioned_disklist)
      info "ARC cache completed:\n  1.  $(( $(cat zpool_cache_arc_partitioned_disklist | wc -l) / 2 ))x disk Raid0 (stripe).\n  1.  $(( $(cat zpool_cache_arc_partitioned_disklist | wc -l) / 2 ))x disk Raid1 (mirror)."
      echo
    fi
  fi
fi
fi
# fi # End for ZPOOL_TYPE = 0

#---- Create PVE ZFS File System
section "Create ZFS file system."

# Create PVE ZFS 
if [ $ZPOOL_TYPE = 0 ]; then
  msg "Creating ZFS file system $POOL/$CT_HOSTNAME..."
  zfs create -o compression=lz4 $POOL/$CT_HOSTNAME >/dev/null
  zfs set acltype=posixacl aclinherit=passthrough xattr=sa $POOL/$CT_HOSTNAME >/dev/null
  zfs set xattr=sa dnodesize=auto $POOL >/dev/null
  info "ZFS file system settings:\n    --  Compresssion: ${YELLOW}lz4${NC}\n    --  Posix ACL type: ${YELLOW}posixacl${NC}\n    --  ACL inheritance: ${YELLOW}passthrough${NC}\n    --  LXC with ACL on ZFS: ${YELLOW}auto${NC}"
  echo
elif [ $ZPOOL_TYPE = 1 ] && [ -d "/$POOL/$CT_HOSTNAME" ]; then  
  msg "Modifying existing ZFS file system settings /$POOL/$CT_HOSTNAME..."
  zfs set compression=lz4 $POOL/$CT_HOSTNAME
  zfs set acltype=posixacl aclinherit=passthrough xattr=sa $POOL/$CT_HOSTNAME >/dev/null
  zfs set xattr=sa dnodesize=auto $POOL >/dev/null
  info "Changes to existing ZFS file system settings ( $POOL/$CT_HOSTNAME ):\n  --  Compresssion: ${YELLOW}lz4${NC}\n  --  Posix ACL type: ${YELLOW}posixacl${NC}\n  --  ACL inheritance: ${YELLOW}passthrough${NC}\n  --  LXC with ACL on ZFS: ${YELLOW}auto${NC}\nCompression will only be performed on new stored data."
  echo
elif [ $ZPOOL_TYPE = 1 ] && [ ! -d "/$POOL/$CT_HOSTNAME" ]; then  
  msg "Creating ZFS file system $POOL/$CT_HOSTNAME..."
  zfs create -o compression=lz4 $POOL/$CT_HOSTNAME >/dev/null
  zfs set acltype=posixacl aclinherit=passthrough xattr=sa $POOL/$CT_HOSTNAME >/dev/null
  zfs set xattr=sa dnodesize=auto $POOL >/dev/null
  info "ZFS file system settings:\n    --  Compresssion: ${YELLOW}lz4${NC}\n    --  Posix ACL type: ${YELLOW}posixacl${NC}\n    --  ACL inheritance: ${YELLOW}passthrough${NC}\n    --  LXC with ACL on ZFS: ${YELLOW}auto${NC}"
  echo
fi


# #### Create LXC Mount Points ####
# section "Create LXC CT mount point to Zpool."
# # Add LXC mount points
# #lxc.mount.entry: /tank/data srv/data none bind,create=dir,optional 0 0
# msg "Creating LXC mount points..." 
# pct set $CTID -mp0 /$POOL/$CT_HOSTNAME,mp=/srv/$CT_HOSTNAME,acl=1 >/dev/null
# info "CT $CTID mount point created: ${YELLOW}/srv/$CT_HOSTNAME${NC}"
# echo