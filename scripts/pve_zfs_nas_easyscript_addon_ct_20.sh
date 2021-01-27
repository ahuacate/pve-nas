#!/usr/bin/env bash

set -Eeuo pipefail
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
trap cleanup EXIT

function info() {
  local REASON="$1"
  local FLAG="\e[36m[INFO]\e[39m"
  msg "$FLAG $REASON"
}
function msg() {
  local TEXT="$1"
  echo -e "$TEXT"
}
function warn() {
  local REASON="\e[97m$1\e[39m"
  local FLAG="\e[93m[WARNING]\e[39m"
  msg "$FLAG $REASON"
}
function section() {
  local REASON="  \e[97m$1\e[37m"
  printf -- '-%.0s' {1..100}; echo ""
  msg "$REASON"
  printf -- '-%.0s' {1..100}; echo ""
  echo
}
function pushd () {
  command pushd "$@" &> /dev/null
}
function popd () {
  command popd "$@" &> /dev/null
}
function cleanup() {
  popd
  rm -rf $TEMP_DIR
  unset TEMP_DIR
}
function box_out() {
  set +u
  local s=("$@") b w
  for l in "${s[@]}"; do
	((w<${#l})) && { b="$l"; w="${#l}"; }
  done
  tput setaf 3
  echo " -${b//?/-}-
| ${b//?/ } |"
  for l in "${s[@]}"; do
	printf '| %s%*s%s |\n' "$(tput setaf 7)" "-$w" "$l" "$(tput setaf 3)"
  done
  echo "| ${b//?/ } |
 -${b//?/-}-"
  tput sgr 0
  set -u
}
function indent() {
    eval "$@" |& sed "s/^/\t/"
    return "$PIPESTATUS"
}
function pct_list_fix() {
    pct list | perl -lne '
        if ($. == 1) {
            @head = ( /(\S+\s*)/g );
            pop @head;
            $patt = "^";
            $patt .= "(.{" . length($_) . "})" for @head;
            $patt .= "(.*)\$";
        }
        print join ",", map {s/"/""/g; s/\s+$//; qq($_)} (/$patt/o);
    '
}
function select_running_ctid() {
  while true; do
    msg "We need to identify and set the ${WHITE}VMID/CTID${NC} used by your $SECTION_HEAD.\n\nYou can accept Easy Script default values by pressing ENTER on your\nkeyboard at each prompt. Or overwrite the default value by typing in your own\nvalue and press ENTER to accept/continue."
    echo
    if [[ $(pct list | grep 'nas-[0-9]' | awk '{print $1}') ]]; then
      CTID_VAR=$(pct list | grep 'nas-[0-9]' | awk 'NR==1{print $1}')
    else
      CTID_VAR=110
    fi
    pct_list_fix | awk -F',' '{print "\033[1;37m"$1"\033[0m",$4,$2}' | column -t
    echo
    read -p "Enter your $SECTION_HEAD VMID/CTID : " -e -i $CTID_VAR CTID
    CTID_NAME=$(pct_list_fix | grep -w $CTID | awk -F',' '{print $4}')
    if ! [[ "$CTID" =~ ^[0-9]+$ ]]; then
      warn "Sorry integers only.\nTry again..."
      sleep 1
    elif [[ "$CTID" =~ ^[0-9]+$ ]] && [ "$(pct list | awk '{print $1}' | grep -w $CTID > /dev/null; echo $?)" != 0 ]; then
      warn "The CTID ${RED}$CTID${NC} is not valid.\nThere is no CT with a CTID of $CTID. Try again..."
      sleep 1
    elif [[ "$CTID" =~ ^[0-9]+$ ]] && [ "$(pct list | awk '{print $1}' | grep -w $CTID > /dev/null; echo $?)" = 0 ] && [ "$(pct list | grep -w $CTID | awk '{print $2}')" = "stopped" ]; then
      msg "${CTID_NAME^} CT ${WHITE}$CTID${NC} is valid but the CT status is: ${RED}stopped${NC} (not running)"
      read -p "Do you want to restart ${CTID_NAME^} CT $CTID [y/n]? " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        msg "Starting ${CTID_NAME^} CT $CTID..."
        pct start $CTID 2> /dev/null
        # Restart CT - watch and wait
        attempt_counter=0
        max_attempts=5
        until [ "$(pct status $CTID | awk '{print $2}' | grep 'running' >/dev/null; echo $?)" = 0 ]; do
            attempt_counter=$(($attempt_counter+1))
            if [ ${attempt_counter} -ln ${max_attempts} ];then
                msg "Waiting for ${CTID_NAME^} CT $CTID to restart. This is the "$attempt_counter"x attempt..."
            fi
            if [ ${attempt_counter} -eq ${max_attempts} ];then
                warn "${CTID_NAME^} CT $CTID failed to start.\nAttempted "$attempt_counter"x times. Maximum attempts reached.\nUser intervention is required. Fix your ${CTID_NAME^} CT $CTID, start it and try again.\nAborting this installation program.."
                exit 1
            fi
        done
        if [ "$(pct status $CTID | awk '{print $2}')" = "running" ]; then
          info "Success. ${CTID_NAME^} CT $CTID status: ${GREEN}running${NC}\n$SECTION_HEAD CTID is set: ${YELLOW}$CTID${NC}"
          break
        fi
      else
        info "You have chosen to skip this step. Aborting this installation program."
        exit 0
      fi
    elif [[ "$CTID" =~ ^[0-9]+$ ]] && [ "$(pct list | awk '{print $1}' | grep -w $CTID > /dev/null; echo $?)" = 0 ] && [ "$(pct status $CTID | awk '{print $2}')" = "running" ]; then
      info "$SECTION_HEAD CTID is set: ${YELLOW}$CTID${NC}"
      break
    fi
    echo
  done
}

# Colour
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
WHITE=$'\033[1;37m'
NC=$'\033[0m'

# Resize Terminal
printf '\033[8;40;120t'

# Script Variables
SECTION_HEAD="PVE ZFS NAS"

# Set Temp Folder
if [ -z "${TEMP_DIR+x}" ]; then
    TEMP_DIR=$(mktemp -d)
    pushd $TEMP_DIR >/dev/null
else
    if [ $(pwd -P) != $TEMP_DIR ]; then
    cd $TEMP_DIR >/dev/null
    fi
fi

# Checking for Internet connectivity
msg "Checking for internet connectivity..."
if nc -zw1 google.com 443; then
  info "Internet connectivity status: ${GREEN}Active${NC}"
  echo
else
  warn "Internet connectivity status: ${RED}Down${NC}\n          Cannot proceed without a internet connection.\n          Fix your PVE hosts internet connection and try again..."
  echo
  cleanup
  exit 0
fi

# Download external scripts

# Command to run script
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_easyscript_addon_ct_20.sh)"

# Setting Variables


#### Action a PVE ZFS NAS Addon Task ####
section "$SECTION_HEAD -  Action a Add-on Task"

# Input list. Add add-on actions or services here. (adhere to the 4 fields - TYPE|LABEL|DESCRIPTION|URL)
cat <<-EOF > input_list
Addon|Jailed User Account|a Home folder jailed user (chroot user)|https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_add_jailuser_ct_20.sh
Addon|Power User Account|member of medialab, homelab or privatelab|https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_add_poweruser_ct_20.sh
Addon|Kodi Rsync User Account|special user for Kodi player data rsync|https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_nfs_nas_add_rsyncuser_ct_20.sh
Addon|SSMTP Server| email server for sending PVE email alerts|https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_install_ssmtp_ct_20.sh
Addon|ProFTPd Server|a sFTP server for Power & Jailed user accounts|https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_install_proftpd_ct_20.sh
Addon|PVE ZFS NAS OS Version Release Updater|backup critical data first|https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_version_updater_ct_20.sh
New CT|Medialab-Rsync|create a new PVE Medialab-Rsync CT server|https://test
EOF

# Create options list from input list
unset options i
while read line; do
    options[i++]="$(echo $line | awk -F'|' '{ print $1,"-","\033[1;33m"$2"\033[0m","-",$3 }')"
done < input_list

# Menu Selection
PS3="Select the task you want to perform (entering numeric) : "
msg "Your available options are:"
select menu in "${options[@]}" "None ${YELLOW}Exit/Abort${NC} - exit this program."; do
  case $menu in
    "Addon"*)
        info "You have selected a $SECTION_HEAD add-on:\n    $(echo $menu | sed 's/^Addon - //')"
        echo
        # Processing
        section "$SECTION_HEAD - Setting the PVE VMID/CTID."
        select_running_ctid
        section "$SECTION_HEAD - Running the Task."
        sleep 1
        wget -qL $(cat input_list | grep "^$(echo $menu | sed 's/ - /|/g' | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g")" | awk -F'|' '{print $4}')
        PROGRAM_NAME=$(cat input_list | grep "^$(echo $menu | sed 's/ - /|/g' | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g")" | awk -F'|' '{print $4}' | rev | cut -d / -f 1 | rev)
        pct push $CTID $PROGRAM_NAME /tmp/$PROGRAM_NAME 
        pct push $CTID $PROGRAM_NAME $PROGRAM_NAME -perms 755
        pct exec $CTID -- bash -c "/$PROGRAM_NAME"
        break
        ;;
    "New CT"*)
        info "You have chosen to create a new PVE CT:\n    $(echo $menu | sed 's/^New CT - //')"
        echo
        # Processing
        section "$SECTION_HEAD - Running the Task."
        sleep 1
        wget -qL $(cat input_list | grep "^$(echo $menu | sed 's/ - /|/g' | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g")" | awk -F'|' '{print $4}')
        PROGRAM_NAME=$(cat input_list | grep "^$(echo $menu | sed 's/ - /|/g' | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g")" | awk -F'|' '{print $4}' | rev | cut -d / -f 1 | rev)
        chmod +x $PROGRAM_NAME
        ./$PROGRAM_NAME
        break
        ;;
    "None ${YELLOW}Exit/Abort${NC} - exit this program.")
        msg "You have chosen to exit this program..."
        read -p "Are you sure you want to exit (abort)? [y/n]?" -n 1 -r
        echo    # (optional) move to a new line
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Exiting now..."
            sleep 1
            exit 0
        else
            msg "Okay. Try again..."
            echo
        fi
        ;;
    *)
        echo "This is not a valid number. Try again..."
        ;;
  esac
done


#### Finish ####
section "$SECTION_HEAD - Completion Status."

msg "${WHITE}Success.${NC}\nExiting program in 3 seconds."

sleep 3
# Cleanup
cleanup