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

# Download external scripts

# Command to run script
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_version_updater_ct_20.sh)"


# Setting Variables


#### Update & Upgrade ####
section "$SECTION_HEAD - Upgrade your System OS and software packages."

box_out '#### PLEASE READ CAREFULLY ####' '' 'This program will fully update and upgrade your PVE ZFS NAS container.' 'User input is required. The program may create, edit and/or change system' 'files on your PVE ZFS NAS. When an optional default setting is provided' 'you may accept the default by pressing ENTER on your keyboard or' 'change it to your preferred value.'
echo
read -p "Proceed with upgrading ${WHITE}$(echo ${HOSTNAME^^})${NC} OS and software packages [y/n]? " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    OS_UPDATE=0
    info "Proceeding with installing updates."
    echo
    msg "Performing $(echo ${HOSTNAME^^}) package update..."
    sudo apt -y update > /dev/null 2>&1
    msg "Performing $(echo ${HOSTNAME^^}) upgrade..."
    sudo apt -y upgrade > /dev/null 2>&1
    msg "Performing $(echo ${HOSTNAME^^}) clean..."
    sudo apt -y clean > /dev/null 2>&1
    msg "Performing $(echo ${HOSTNAME^^}) autoremove..."
    sudo apt -y autoremove > /dev/null 2>&1
    msg "Your current $(echo ${HOSTNAME^^}) OS release details are:"
    echo
    indent lsb_release -idc
    echo
else
    OS_UPDATE=1
    info "You have chosen to skip this step. Aborting program."
fi


#### Full System Release Upgrade ####
if [ $(do-release-upgrade -c > /dev/null; echo $?) = 0 ] && [ $OS_UPDATE = 0 ]; then
section "$SECTION_HEAD - Perform a full Ubuntu OS release upgrade."
    msg "Checking for a new Ubuntu OS release..."
    info "$(do-release-upgrade -c | sed '$d' | sed '1d') (Current Vers: $(lsb_release -d | awk -F'\t' '{print $2}'))"
    echo
    box_out '#### PLEASE READ CAREFULLY ####' '' 'A Ubuntu OS release upgrade is available. This is a major upgrade.' 'It is recommended you perform a PVE CT backup before performing this upgrade.' '' 'User input is required. The update will create, edit and/or change system' 'files on your PVE ZFS NAS CT. When an optional default setting is provided' 'you may accept the default by pressing ENTER on your keyboard or' 'change it to your preferred value.'
    echo
    read -p "Proceed with upgrading ${WHITE}$(echo ${HOSTNAME^^})${NC} Ubuntu OS [y/n]? " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        RELEASE_UPDATE=0
        msg "Performing release upgrade..."
        sudo apt -y update > /dev/null 2>&1
        sudo do-release-upgrade -f DistUpgradeViewNonInteractive
        info "$SECTION_HEAD CT has been upgraded to: ${YELLOW}$(lsb_release -d | awk -F'\t' '{print $2}')${NC}"
        echo
    else
        RELEASE_UPDATE=1
        info "You have chosen to skip this step. Aborting program."
        echo
    fi
else
    RELEASE_UPDATE=1
fi


#### Finish ####
section "$SECTION_HEAD - Completion Status."

if [ $OS_UPDATE = 0 ] && [ $RELEASE_UPDATE = 0 ]; then
    msg "${WHITE}Success.${NC}\nThe following upgrade tasks have been performed on $SECTION_HEAD:\n  --  updated the package lists\n  --  installed latest versions of the packages\n  --  upgraded to the latest Ubuntu release ( New Version:  $(lsb_release -d | awk -F'\t' '{print $2}') )"
    echo
elif [ $OS_UPDATE = 0 ] && [ $RELEASE_UPDATE = 1 ]; then
    msg "${WHITE}Success.${NC}\nThe following upgrade tasks have been performed on $SECTION_HEAD:\n  --  updated the package lists\n  --  installed latest versions of the packages"
    echo
fi

sleep 3
# Cleanup
cleanup