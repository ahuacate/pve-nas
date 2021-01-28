#!/usr/bin/env bash

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

# Colour
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
WHITE=$'\033[1;37m'
NC=$'\033[0m'

# Resize Terminal
printf '\033[8;40;120t'

# Script Variables
SECTION_HEAD="Proxmox ZFS NAS"

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
wget -qL https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/proftpd_settings/sftp.conf


# Command to run script
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_add_rsyncuser_ct.sh)"


# Setting Variables


# Install ProFTP Prerequisites
section "$SECTION_HEAD - Installing ProDTPd Prerequisites."
msg "Checking ProFTPd status..."
if [ $(dpkg -s proftpd-basic >/dev/null 2>&1; echo $?) = 0 ]; then
  info "ProFTPd status: ${GREEN}active (running).${NC}"
else
  msg "Installing ProFTPd..."
  sudo apt-get -y update >/dev/null 2>&1
  sudo apt-get install -y proftpd >/dev/null
  sleep 1
  if [ $(dpkg -s proftpd-basic >/dev/null 2>&1; echo $?) = 0 ]; then
    info "ProFTPd status: ${GREEN}active (running).${NC}"
  else
    warn "ProFTPd status: ${RED}inactive or cannot install (dead).${NC}.\nYour intervention is required.\nExiting installation script in 3 second."
    sleep 3
    exit 0
  fi
fi
echo


# Creating sftp Configuration
section "$SECTION_HEAD - Modifying ProFTPd sFTP Settings."
msg "Checking sftp configuration..."
echo
if [ -f /etc/proftpd/conf.d/sftp.conf ]; then
  box_out '#### PLEASE READ CAREFULLY - SFTP CONFIGURATION ####' '' 'An existing ProFTPd sftp settings file has been found. Updating will' 'overwrite your existing sftp settings file:' '' '  --  /etc/proftpd/conf.d/sftp.conf' '' 'If you have made custom changes to your sftp settings file DO NOT' 'proceed to update this file. Otherwise we RECOMMEND you update (overwrite)' 'your sftp settings file to our latest version.'
  echo
  read -p "Update your proftpd sftp settings file (Recommended) [y/n]?: " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    msg "Updating ProFTPd sftp settings file..."
    sudo systemctl stop proftpd 2>/dev/null
    cat sftp.conf > /etc/proftpd/conf.d/sftp.conf
    info "sFTP settings file status: ${YELLOW}Updated${NC}"
  else
    info "You have chosen to skip this step."
  fi
else
  msg "Creating ProFTPd sftp settings file..."
  sudo systemctl stop proftpd 2>/dev/null
  cat sftp.conf > /etc/proftpd/conf.d/sftp.conf
  info "sFTP settings file status: ${YELLOW}Updated${NC}"
fi
echo


# Modifying ProFTPd Defaults
section "$SECTION_HEAD - Modifying ProFTPd Default Settings."
msg "Editing ProFTP defaults..."
sudo systemctl stop proftpd 2>/dev/null
sudo sed -i 's|# DefaultRoot			~|DefaultRoot			~|g' /etc/proftpd/proftpd.conf
sudo sed -i 's|ServerName.*|ServerName                      "'$(echo ${HOSTNAME^^})'"|g' /etc/proftpd/proftpd.conf
sudo sed -i 's|UseIPv6.*|UseIPv6                         off|g' /etc/proftpd/proftpd.conf
info "ProFTPd settings file status: ${YELLOW}Updated${NC}"
echo

#ProFTPd Statussection "ProFTPd - sFTP Settings."
section "$SECTION_HEAD - ProFTPd Status Check."
msg "Checking ProFTP status..."
sudo systemctl restart proftpd 2>/dev/null
sleep 1
if [ "$(systemctl is-active --quiet proftpd; echo $?) -eq 0" ]; then
  info "Proftpd status: ${GREEN}active (running).${NC}"
  echo
elif [ "$(systemctl is-active --quiet proftpd; echo $?) -eq 3" ]; then
  info "Proftpd status: ${RED}inactive (dead).${NC}. Your intervention is required."
  echo
fi


#### Finish ####
section "$SECTION_HEAD - ProFTPd Completion Status."

echo
msg "${WHITE}Success.${NC}"
sleep 3

# Cleanup
if [ -z ${PARENT_EXEC_INSTALL_PROFTPD+x} ]; then
  cleanup
fi
