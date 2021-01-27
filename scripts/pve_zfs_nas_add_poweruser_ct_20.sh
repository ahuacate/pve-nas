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

# Command to run script
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_add_poweruser_ct_20.sh)"


#### Create New Power User Accounts ####
if [ -z "${NEW_POWER_USER+x}" ] && [ -z "${PARENT_EXEC_NEW_POWER_USER+x}" ]; then
  section "$SECTION_HEAD - Create New Power User Accounts"

  echo
  box_out '#### PLEASE READ CAREFULLY - CREATING POWER USER ACCOUNTS ####' '' 'Power Users are trusted persons with privileged access to data and application' 'resources hosted on your PVE ZFS NAS. Power Users are NOT standard users!' 'Standard users are added at a later stage.' '' 'Each new Power Users security permissions are controlled by Linux groups.' 'Group security permission levels are as follows:' '' '  --  GROUP NAME    -- PERMISSIONS' '  --  "medialab"    -- Everything to do with media (i.e movies, TV and music)' '  --  "homelab"     -- Everything to do with a smart home including "medialab"' '  --  "privatelab"  -- Private storage including "medialab" & "homelab" rights' '' 'A Personal Home Folder will be created for each new user. The folder name is' 'the users name. You can access Personal Home Folders and other shares' 'via CIFS/Samba and NFS.' '' 'Remember your PVE ZFS NAS is also pre-configured with user names' 'specifically tasked for running hosted applications (i.e Proxmox LXC,CT,VM).' 'These application users names are as follows:' '' '  --  GROUP NAME    -- USER NAME' '  --  "medialab"    -- /srv/CT_HOSTNAME/homes/"media"' '  --  "homelab"     -- /srv/CT_HOSTNAME/homes/"home"' '  --  "privatelab"  -- /srv/CT_HOSTNAME/homes/"private"'
  echo
  read -p "Create new power user accounts on your $SECTION_HEAD [y/n]? " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    NEW_POWER_USER=0 >/dev/null
  else
    NEW_POWER_USER=1 >/dev/null
    info "You have chosen to skip this step."
    exit 0
  fi
  echo
fi
while [[ "$REPLY" != ^[Nn]$ ]] && [ "$NEW_POWER_USER" = 0 ]; do
  read -p "Enter new username you want to create : " username
  echo
  msg "Choose your new user's group permissions."
  GRP01="Medialab - Everything to do with media (i.e movies, TV and music)." >/dev/null
  GRP02="Homelab - Everything to do with a smart home including medialab." >/dev/null
  GRP03="Privatelab - Private storage including medialab & homelab rights." >/dev/null
  PS3="Select your new users group permission rights level (entering numeric) : "
  echo
  select grp_type in "$GRP01" "$GRP02" "$GRP03"
  do
  echo
  info "You have selected: $grp_type"
  echo
  break
  done
  if [ "$grp_type" = "$GRP01" ]; then
    usergrp="medialab"
  elif [ "$grp_type" = "$GRP02" ]; then
    usergrp="homelab -G medialab"
  elif [ "$grp_type" = "$GRP03" ]; then
    usergrp="privatelab -G medialab,homelab"
  fi
  while true; do
    read -s -p "Now Enter a Password for $jail_username: " jail_password
    echo
    read -s -p "Re-enter the Password (again): " jail_password2
    echo
    [ "$password" = "$password2" ] && echo "$username $password $usergrp" >> usersfile.txt && break
    warn "Passwords do not match. Please try again."
  done
  echo
  read -p "Do you want to create another new jailed user account [y/n]? " -n 1 -r
  if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo
    break
  fi
  echo
done

if [ $(id -u) -eq 0 ] && [ "$NEW_POWER_USER" = 0 ]; then
  NEW_USERS=usersfile.txt
  HOME_BASE="/srv/$HOSTNAME/homes/"
  cat ${NEW_USERS} | while read USER PASSWORD GROUP USERMOD
  do
  pass=$(perl -e 'print crypt($ARGV[0], 'password')' $PASSWORD)
  if [ $(egrep "^$USER[0]" /etc/passwd > /dev/null; echo $?) = 0 ]; then USER_EXISTS=0; else USER_EXISTS=1; fi
  if [ -d "${HOME_BASE}${USER}" ]; then USER_DIR_EXISTS=0; else USER_DIR_EXISTS=1; fi
  if [ $USER_EXISTS = 0 ]; then
    warn "User $USER exists!"
    echo
    exit 1
  elif [ $USER_EXISTS = 1 ] && [ $USER_DIR_EXISTS = 0 ]; then
    msg "Creating new user ${USER}..."
    useradd -g ${GROUP} -p ${pass} ${USERMOD} -m -d ${HOME_BASE}${USER} -s /bin/bash ${USER}
    msg "Creating SSH folder and authorised keys file for user ${USER}..."
    sudo mkdir -p /srv/$HOSTNAME/homes/${USER}/.ssh
    sudo touch /srv/$HOSTNAME/homes/${USER}/.ssh/authorized_keys
    sudo chmod -R 0700 /srv/$HOSTNAME/homes/${USER}
    sudo chown -R ${USER}:${GROUP} /srv/$HOSTNAME/homes/${USER}
    sudo ssh-keygen -o -q -t ed25519 -a 100 -f /srv/$HOSTNAME/homes/${USER}/.ssh/id_${USER,,}_ed25519 -N ""
    cat /srv/$HOSTNAME/homes/${USER}/.ssh/id_${USER,,}_ed25519.pub >> /srv/$HOSTNAME/homes/${USER}/.ssh/authorized_keys
    # Create ppk key for Putty or Filezilla
    msg "Creating a private PPK key..."
    sudo puttygen /srv/$HOSTNAME/homes/${USER}/.ssh/id_${USER,,}_ed25519 -o /srv/$HOSTNAME/homes/${USER}/.ssh/id_${USER,,}_ed25519.ppk
    msg "Backing up ${USER} latest SSH keys..."
    sudo mkdir -p /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)
    sudo chown -R root:privatelab /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)
    sudo chmod 0750 /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)
    sudo cp /srv/$HOSTNAME/homes/${USER}/.ssh/id_${USER,,}_ed25519* /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)/
    msg "Creating ${USER} smb account..."
    (echo ${PASSWORD}; echo ${PASSWORD} ) | smbpasswd -s -a ${USER}
    info "User $USER has been added to the system. Existing home folder found.\nUsing existing home folder."
    echo
  else
    msg "Creating new user ${USER}..."
    useradd -g ${GROUP} -p ${pass} ${USERMOD} -m -d ${HOME_BASE}${USER} -s /bin/bash ${USER}
    msg "Creating default home folders (xdg-user-dirs-update)..."
    sudo -iu ${USER} xdg-user-dirs-update
    msg "Creating SSH folder and authorised keys file for user ${USER}..."
    sudo mkdir -p /srv/$HOSTNAME/homes/${USER}/.ssh
    sudo touch /srv/$HOSTNAME/homes/${USER}/.ssh/authorized_keys
    sudo chmod -R 0700 /srv/$HOSTNAME/homes/${USER}
    sudo chown -R ${USER}:${GROUP} /srv/$HOSTNAME/homes/${USER}
    sudo ssh-keygen -o -q -t ed25519 -a 100 -f /srv/$HOSTNAME/homes/${USER}/.ssh/id_${USER,,}_ed25519 -N ""
    cat /srv/$HOSTNAME/homes/${USER}/.ssh/id_${USER,,}_ed25519.pub >> /srv/$HOSTNAME/homes/${USER}/.ssh/authorized_keys
    # Create ppk key for Putty or Filezilla
    msg "Creating a private PPK key..."
    sudo puttygen /srv/$HOSTNAME/homes/${USER}/.ssh/id_${USER,,}_ed25519 -o /srv/$HOSTNAME/homes/${USER}/.ssh/id_${USER,,}_ed25519.ppk
    msg "Creating ${USER} smb account..."
    (echo ${PASSWORD}; echo ${PASSWORD} ) | smbpasswd -s -a ${USER}
    [ $USER_EXISTS = 1 ] && info "User $USER has been added to the system." || warn "Failed adding user $USER!"
    echo
  fi
  done
fi


#### Email User SSH Keys ####
if [ $(dpkg -s ssmtp >/dev/null 2>&1; echo $?) = 0 ] && [ $(grep -qs "^root:*" /etc/ssmtp/revaliases >/dev/null; echo $?) = 0 ]; then
  section "$SECTION_HEAD - Email User Credentials & SSH keys"
  echo
  box_out '#### PLEASE READ CAREFULLY - EMAIL NEW USER CREDENTIALS ####' '' 'You can email each new users login credentials and ssh keys to the' 'system administrator. The system administrator may then forward the email(s)' 'to each new user.' '' 'Each email will include the following information and attachments:' '' '  --  Username' '  --  Password' '  --  User Group' '  --  Folder Permission Level' '  --  Private SSH Key (Standard)' '  --  Private SSH Key (PPK Version)' '  --  PVE ZFS NAS IP Address' '  --  SMB Status'
  echo
  read -p "Email new users Credentials & SSH key to your system’s administrator. [y/n]?: " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    cat ${NEW_USERS} | while read USER PASSWORD GROUP USERMOD
    do
    msg "Sending $USER SSH key to $(grep -r "root=.*" /etc/ssmtp/ssmtp.conf | grep -v "#" | sed -e 's/root=//g')..."
    echo -e "Subject: Login Credentials for $USER.\n\n==========   LOGIN CREDENTIALS FOR USERNAME : ${USER^^}   ==========\n \n \nThe users private SSH keys are attached. SSH keys should never be accessible to anyone other than the person who will be using them.\n \nThe users ($USER) login credentials details are:\n    Username: $USER\n    Password: $PASSWORD\n    Primary User Group: $GROUP\n    Supplementary User Group: $(echo -e $USERMOD | sed 's/^...//' | sed 's/,/, /')\n    Private SSH Key (Standard): id_${USER,,}_ed25519\n    Private SSH Key (PPK version): id_${USER,,}_ed25519.ppk\n    PVS ZFS NAS IP Address: $(hostname -I)\n    SMB Status: Enabled" | (cat - && uuencode /srv/$HOSTNAME/homes/${USER}/.ssh/id_${USER,,}_ed25519 id_${USER,,}_ed25519) | (cat - && uuencode /srv/$HOSTNAME/homes/${USER}/.ssh/id_${USER,,}_ed25519.ppk id_${USER,,}_ed25519.ppk) | ssmtp root
    info "Email sent."
    done
  else
    info "You have chosen to skip this step. Not sending any email."
    echo
  fi
fi
echo


#### Finish ####
section "$SECTION_HEAD - Completion Status."

echo
msg "${WHITE}Success.${NC}"
sleep 3

# Cleanup
if [ -z ${PARENT_EXEC_NEW_POWER_USER+x} ]; then
  cleanup
fi
