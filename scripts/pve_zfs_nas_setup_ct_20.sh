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
function cleanup() {
  popd >/dev/null
  rm -rf $TEMP_DIR
}
function load_module() {
  if ! $(lsmod | grep -Fq $1); then
    modprobe $1 &>/dev/null || \
      die "Failed to load '$1' module."
  fi
  MODULES_PATH=/etc/modules
  if ! $(grep -Fxq "$1" $MODULES_PATH); then
    echo "$1" >> $MODULES_PATH || \
      die "Failed to add '$1' module to load at boot."
  fi
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

# Set Temp Folder
TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null

# Command to run script
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_setup_ct_20.sh)"

# Script Variables
SECTION_HEAD="PVE ZFS NAS"

# Download external scripts
wget -qL https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_add_jailuser_ct_20.sh
wget -qL https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_add_poweruser_ct_20.sh
wget -qL https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_add_rsyncuser_ct_20.sh
wget -qL https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_base_folder_setup
wget -qL https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_base_subfolder_setup
wget -qL https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_chroot_programs_ct_20
wget -qL https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_install_ssmtp_ct_20.sh
wget -qL https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_install_proftpd_ct_20.sh



#### Performing Prerequisites ####
section "$SECTION_HEAD - Performing Prerequisites"

# Setting Variables
msg "Setting the $SECTION_HEAD variables..."
if [ -f /tmp/pve_zfs_nas_setup_ct_variables.sh ]; then
  cp /tmp/pve_zfs_nas_setup_ct_variables.sh . 2>/dev/null
  # Import Variables
  . ./pve_zfs_nas_setup_ct_variables.sh
  info "$SECTION_HEAD variables are set."
  echo
elif [ ! -f /tmp/pve_zfs_nas_setup_ct_variables.sh ]; then
  if [ $(zfs list | grep -v "rpool" | awk '{print $1}' | grep "^.*/$(hostname)" >/dev/null; echo $?) = 0 ]; then
    msg "Setting the ZFS Pool name..."
    POOL=$(zfs list | grep -v "rpool" | awk '{print $1}' | grep "^.*/$(hostname)" | sed "s/\/$(hostname)//g")
    info "ZFS pool name is set: ${YELLOW}$POOL${NC}."
    echo
  elif [ $(zfs list | grep -v "rpool" | awk '{print $1}' | grep "^.*/$(hostname)" >/dev/null; echo $?) = 1 ]; then
    msg "Setting the ZFS Pool name..."
    warn "Cannot locate, identify and set a ZFS pool name (PVE ZFS backend).\nAborting installation."
    exit 0
  fi
fi


# Download and Install Prerequisites
msg "Installing Samba..."
apt-get install -y samba-common-bin >/dev/null
msg "Installing ACL..."
apt-get install -y acl >/dev/null
msg "Installing Putty Tools..."
apt-get install -y putty-tools >/dev/null
echo


#### Creating PVE ZFS NAS Users and Groups ####
section "$SECTION_HEAD - Creating Users and Groups."

# Change Home folder permissions
msg "Setting default adduser home folder permissions (DIR_MODE)..."
sed -i "s/DIR_MODE=.*/DIR_MODE=0750/g" /etc/adduser.conf
info "Default adduser permissions set: ${WHITE}0750${NC}"

# Create users and groups
msg "Creating CT default user groups..."
# Create Groups
getent group medialab >/dev/null
if [ $? -ne 0 ]; then
	groupadd -g 65605 medialab
  info "Default user group created: ${YELLOW}medialab${NC}"
fi
getent group homelab >/dev/null
if [ $? -ne 0 ]; then
	groupadd -g 65606 homelab
  info "Default user group created: ${YELLOW}homelab${NC}"
fi
getent group privatelab >/dev/null
if [ $? -ne 0 ]; then
	groupadd -g 65607 privatelab
  info "Default user group created: ${YELLOW}privatelab${NC}"
fi
getent group chrootjail >/dev/null
if [ $? -ne 0 ]; then
	groupadd -g 65608 chrootjail
  info "Default user group created: ${YELLOW}chrootjail${NC}"
fi
echo


# Create Base User Accounts
msg "Creating CT default users..."
sudo mkdir -p /srv/$HOSTNAME/homes >/dev/null
sudo chgrp -R root /srv/$HOSTNAME/homes >/dev/null
sudo chmod -R 0750 /srv/$HOSTNAME/homes >/dev/null
id -u media &>/dev/null
if [ $? = 1 ]; then
	useradd -m -d /srv/$HOSTNAME/homes/media -u 1605 -g medialab -s /bin/bash media >/dev/null
  info "Default user created: ${YELLOW}media${NC} of group medialab"
fi
id -u home &>/dev/null
if [ $? = 1 ]; then
	useradd -m -d /srv/$HOSTNAME/homes/home -u 1606 -g homelab -G medialab -s /bin/bash home >/dev/null
  info "Default user created: ${YELLOW}home${NC} of groups medialab, homelab"
fi
id -u private &>/dev/null
if [ $? = 1 ]; then
	useradd -m -d /srv/$HOSTNAME/homes/private -u 1607 -g privatelab -G medialab,homelab -s /bin/bash private >/dev/null
  info "Default user created: ${YELLOW}private${NC} of groups medialab, homelab and privatelab"
fi
echo


# Creating Chroot jail environment
msg "Creating basic chroot jail environment..."
CHROOT=/srv/$HOSTNAME/homes/chrootjail
mkdir -p $CHROOT
mkdir -p $CHROOT/{homes,dev,bin,lib,lib/x86_64-linux-gnu,lib64,etc,lib/terminfo/x,usr,usr/bin}
mknod -m 666 $CHROOT/dev/null c 1 3
mknod -m 666 $CHROOT/dev/tty c 5 0
mknod -m 666 $CHROOT/dev/zero c 1 5
mknod -m 666 $CHROOT/dev/random c 1 8
sudo chown root:root $CHROOT
sudo chmod 0711 $CHROOT
sudo chmod 0711 $CHROOT/homes
cat << EOF > $CHROOT/etc/debian_chroot
chroot
EOF
# Copy command libraries
msg "Copying command libraries for chroot jail..."
sudo apt-get install -y libtinfo5 >/dev/null
cp -f /lib/x86_64-linux-gnu/{libtinfo.so.5,libdl.so.2,libc.so.6} $CHROOT/lib/ >/dev/null
cp -f /lib64/ld-linux-x86-64.so.2 $CHROOT/lib64/ >/dev/null
cp -f /bin/bash $CHROOT/bin/ >/dev/null
cp -f /lib/x86_64-linux-gnu/libnsl.so.1 $CHROOT/lib/x86_64-linux-gnu/ >/dev/null
cp -f /lib/x86_64-linux-gnu/libnss_* $CHROOT/lib/x86_64-linux-gnu/ >/dev/null
for i in $( ldd $(cat pve_zfs_nas_chroot_programs_ct_20 | awk '{ print $1 }') | grep -v dynamic | cut -d " " -f 3 | sed 's/://' | sort | uniq )
  do
    sudo cp -f --parents $i $CHROOT
done < pve_zfs_nas_chroot_programs_ct_20
# ARCH amd64
if [ -f /lib64/ld-linux-x86-64.so.2 ]; then
   cp -f --parents /lib64/ld-linux-x86-64.so.2 $CHROOT
fi
# ARCH i386
if [ -f  /lib/ld-linux.so.2 ]; then
   cp -f --parents /lib/ld-linux.so.2 $CHROOT
fi
# Xterm for nano
if [ -d  /lib/terminfo/x ]; then
   cp -r /lib/terminfo/x/* $CHROOT/lib/terminfo/x/
fi
info "Chroot jail created. Command libraries for chroot jail have been copied."
echo


#### Setting Folder Permissions ####
section "$SECTION_HEAD - Creating and Setting Folder Permissions."

# Create Default Proxmox ZFS Share points
echo
box_out '#### PLEASE READ CAREFULLY - SHARED FOLDERS ####' '' 'Shared folders are the basic directories where you can store files and folders on your PVE ZFS NAS.' 'Below is a list of shared folders that are created automatically in this build:' '' '  --  /srv/CT_HOSTNAME/"audio"' '  --  /srv/CT_HOSTNAME/"backup"' '  --  /srv/CT_HOSTNAME/"books"' '  --  /srv/CT_HOSTNAME/"cloudstorage"' '  --  /srv/CT_HOSTNAME/"docker"' '  --  /srv/CT_HOSTNAME/"downloads"' '  --  /srv/CT_HOSTNAME/"git"' '  --  /srv/CT_HOSTNAME/"homes"' '  --  /srv/CT_HOSTNAME/"music"' '  --  /srv/CT_HOSTNAME/"openvpn"' '  --  /srv/CT_HOSTNAME/"photo"' '  --  /srv/CT_HOSTNAME/"proxmox"' '  --  /srv/CT_HOSTNAME/"public"' '  --  /srv/CT_HOSTNAME/"sshkey"' '  --  /srv/CT_HOSTNAME/"video"' '' 'You can create additional shared folders in the coming steps.'
echo
echo
touch pve_zfs_nas_base_folder_setup-xtra
while true; do
  read -p "Do you want to create additional shared folders on your $SECTION_HEAD [y/n]?: " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    while true; do
      echo
      read -p "Enter a new shared folder name : " xtra_sharename
      read -p "Confirm new shared folder name (type again): " xtra_sharename2
      xtra_sharename=${xtra_sharename,,}
      xtra_sharename=${xtra_sharename2,,}
      echo
      if [ "$xtra_sharename" = "$xtra_sharename2" ];then
        info "Shared folder name is set: ${YELLOW}$xtra_sharename${NC}."
        XTRA_SHARES=0 >/dev/null
        break
      elif [ "$xtra_sharename" != "$xtra_sharename2" ]; then
        warn "Your inputs do NOT match. Try again..."
      fi
    done
    msg "Select your new shared folders group permission rights."
    XTRA_SHARE01="Standard User - For restricted jailed users (GID: chrootjail)." >/dev/null
    XTRA_SHARE02="Medialab - Photos, TV, movies, music and general media content only." >/dev/null
    XTRA_SHARE03="Homelab - Everything to do with your smart home." >/dev/null
    XTRA_SHARE04="Privatelab - User has access to all NAS data." >/dev/null
    PS3="Select your new shared folders group permission rights (entering numeric) : "
    echo
    select xtra_type in "$XTRA_SHARE01" "$XTRA_SHARE02" "$XTRA_SHARE03" "$XTRA_SHARE04"
    do
    echo
    info "You have selected: $xtra_type ..."
    echo
    break
    done
    if [ "$xtra_type" = "$XTRA_SHARE01" ]; then
      XTRA_USERGRP="root 0750 chrootjail:rwx privatelab:rwx"
    elif [ "$xtra_type" = "$XTRA_SHARE02" ]; then
      XTRA_USERGRP="root 0750 medialab:rwx privatelab:rwx"
    elif [ "$xtra_type" = "$XTRA_SHARE03" ]; then
      XTRA_USERGRP="root 0750 homelab:rwx privatelab:rwx"
    elif [ "$xtra_type" = "$XTRA_SHARE04" ]; then
      XTRA_USERGRP="root 0750 privatelab:rwx"
    fi
    echo "$xtra_sharename $XTRA_USERGRP" >> pve_zfs_nas_base_folder_setup
    echo "$xtra_sharename $XTRA_USERGRP" >> pve_zfs_nas_base_folder_setup-xtra
  else
    info "Skipping creating anymore additional shared folders."
    XTRA_SHARES=1 >/dev/null
    break
  fi
done
echo

# Create Proxmox ZFS Share points
msg "Creating $SECTION_HEAD base /$POOL/$HOSTNAME folder shares..."
echo
cat pve_zfs_nas_base_folder_setup | sed '/^#/d' | sed '/^$/d' >/dev/null > pve_zfs_nas_base_folder_setup_input
dir_schema="/srv/$HOSTNAME/"
while read -r dir group permission acl_01 acl_02 acl_03 acl_04 acl_05; do
  if [ -d "$dir_schema${dir}" ]; then
    info "Pre-existing folder: ${RED}"$dir_schema${dir}"${NC}\n  Setting ${group} group permissions for existing folder."
    sudo chgrp -R "${group}" "$dir_schema${dir}" >/dev/null
    sudo chmod -R "${permission}" "$dir_schema${dir}" >/dev/null
    if [ ! -z ${acl_01} ]; then
      setfacl -Rm g:${acl_01} "$dir_schema${dir}"
    fi
    if [ ! -z ${acl_02} ]; then
      setfacl -Rm g:${acl_02} "$dir_schema${dir}"
    fi
    if [ ! -z ${acl_03} ]; then
      setfacl -Rm g:${acl_03} "$dir_schema${dir}"
    fi
    if [ ! -z ${acl_04} ]; then
      setfacl -Rm g:${acl_04} "$dir_schema${dir}"
    fi
    if [ ! -z ${acl_05} ]; then
      setfacl -Rm g:${acl_05} "$dir_schema${dir}"
    fi
    echo
  else
    info "New base folder created:\n  ${WHITE}"$dir_schema${dir}"${NC}"
    sudo mkdir -p "$dir_schema${dir}" >/dev/null
    sudo chgrp -R "${group}" "$dir_schema${dir}" >/dev/null
    sudo chmod -R "${permission}" "$dir_schema${dir}" >/dev/null
    if [ ! -z ${acl_01} ]; then
      setfacl -Rm g:${acl_01} "$dir_schema${dir}"
    fi
    if [ ! -z ${acl_02} ]; then
      setfacl -Rm g:${acl_02} "$dir_schema${dir}"
    fi
    if [ ! -z ${acl_03} ]; then
      setfacl -Rm g:${acl_03} "$dir_schema${dir}"
    fi
    if [ ! -z ${acl_04} ]; then
      setfacl -Rm g:${acl_04} "$dir_schema${dir}"
    fi
    if [ ! -z ${acl_05} ]; then
      setfacl -Rm g:${acl_05} "$dir_schema${dir}"
    fi
    echo
  fi
done < pve_zfs_nas_base_folder_setup_input

# Create Default SubFolders
if [ -f pve_zfs_nas_base_subfolder_setup ]; then
  msg "Creating $SECTION_HEAD subfolder shares..."
  echo
  echo -e "$(eval "echo -e \"`<pve_zfs_nas_base_subfolder_setup`\"")" | sed '/^#/d' | sed '/^$/d' >/dev/null > pve_zfs_nas_base_subfolder_setup_input
  while read -r dir group permission acl_01 acl_02 acl_03 acl_04 acl_05; do
    if [ -d "${dir}" ]; then
      info "${dir} exists, setting ${group} group permissions for this folder."
      sudo chgrp -R "${group}" "${dir}" >/dev/null
      sudo chmod -R "${permission}" "${dir}" >/dev/null
      if [ ! -z ${acl_01} ]; then
        setfacl -Rm g:${acl_01} "${dir}"
      fi
      if [ ! -z ${acl_02} ]; then
        setfacl -Rm g:${acl_02} "${dir}"
      fi
      if [ ! -z ${acl_03} ]; then
        setfacl -Rm g:${acl_03} "${dir}"
      fi
      if [ ! -z ${acl_04} ]; then
        setfacl -Rm g:${acl_04} "${dir}"
      fi
      if [ ! -z ${acl_05} ]; then
        setfacl -Rm g:${acl_05} "${dir}"
      fi
      echo
    else
      info "New subfolder created:\n  ${WHITE}"${dir}"${NC}"
      sudo mkdir -p "${dir}" >/dev/null
      sudo chgrp -R "${group}" "${dir}" >/dev/null
      sudo chmod -R "${permission}" "${dir}" >/dev/null
      if [ ! -z ${acl_01} ]; then
        setfacl -Rm g:${acl_01} "${dir}"
      fi
      if [ ! -z ${acl_02} ]; then
        setfacl -Rm g:${acl_02} "${dir}"
      fi
      if [ ! -z ${acl_03} ]; then
        setfacl -Rm g:${acl_03} "${dir}"
      fi
      if [ ! -z ${acl_04} ]; then
        setfacl -Rm g:${acl_04} "${dir}"
      fi
      if [ ! -z ${acl_05} ]; then
        setfacl -Rm g:${acl_05} "${dir}"
      fi
      echo
    fi
  done < pve_zfs_nas_base_subfolder_setup_input
fi


#### Configure SSH Server ####
section "$SECTION_HEAD - Setup SSH Server."

box_out '#### PLEASE READ CAREFULLY - ENABLE SSH SERVER ####' '' 'If you want to use SSH (Rsync/SFTP) to connect to your PVE ZFS NAS then' 'your SSH Server must be enabled. You need SSH to perform any' 'of the following tasks:' '' '  --  Secure SSH Connection to the PVE ZFS NZS.' '  --  Perform a secure RSync Backup to the PVE ZFS NAS.' '  --  Create a portable Kodi media player using our "kodi_rsync" user scripts.' '' 'We also recommend you change the default SSH port 22 for added security.' '' 'For added security we only enable the following ssh services for "kodi_rsync"' 'and chroot jail users:' '' '  --  allowsftp: User is allowed to use SFTP protocol and transfers.' '  --  allowrsync: User is allowed to use rsync transfers.'


if [ "$(systemctl is-active --quiet sshd; echo $?) -eq 0" ]; then
  sudo systemctl stop ssh 2>/dev/null
  SSHD_STATUS=1
else
  SSHD_STATUS=1
fi

# Configure ssh settings
msg "Configuring sshd default settings..."
sudo sed -i 's|#PubkeyAuthentication yes|PubkeyAuthentication yes|g' /etc/ssh/sshd_config
sudo sed -i 's|#AuthorizedKeysFile.*|AuthorizedKeysFile     ~/.ssh/authorized_keys|g' /etc/ssh/sshd_config

# Configure sshd for chroot jail
msg "Configuring sshd settings for chrootjail..."
sudo sed -i 's|Subsystem.*sftp.*|Subsystem       sftp    internal-sftp|g' /etc/ssh/sshd_config # Sets sftp to use proFTP #Subsystem sftp /usr/libexec/openssh/sftp-server
cat <<EOF >> /etc/ssh/sshd_config

# Settings for chrootjail
Match group chrootjail
        AuthorizedKeysFile $CHROOT/homes/%u/.ssh/authorized_keys
        ChrootDirectory $CHROOT
        PubkeyAuthentication yes
        PasswordAuthentication no
        AllowTCPForwarding no
        X11Forwarding no
        ForceCommand internal-sftp
EOF
if [ $SSHD_STATUS = 1 ]; then
  sudo systemctl restart ssh 2>/dev/null
  SSHD_STATUS=0
fi
echo

read -p "Enable SSH Server on your $SECTION_HEAD (Recommended) [y/n]?: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  read -p "Confirm SSH Port number: " -e -i 22 SSH_PORT
  info "SSH Port is set: ${YELLOW}Port $SSH_PORT${NC}."
  sudo systemctl stop ssh 2>/dev/null
  SSHD_STATUS=1
  sudo sed -i "s|#Port.*|Port $SSH_PORT|g" /etc/ssh/sshd_config
  sudo ufw allow ssh 2>/dev/null
  sudo systemctl restart ssh 2>/dev/null
  SSHD_STATUS=0
  msg "Enabling SSHD server..."
  systemctl is-active sshd >/dev/null 2>&1 && info "OpenBSD Secure Shell server: ${GREEN}active (running).${NC}" || info "OpenBSD Secure Shell server: ${RED}inactive (dead).${NC}"
  echo
else
  sudo systemctl stop ssh 2>/dev/null
  sudo systemctl disable ssh 2>/dev/null
  SSHD_STATUS=1
  msg "Disabling SSHD server..."
  systemctl is-active sshd >/dev/null 2>&1 && info "OpenBSD Secure Shell server: ${GREEN}active (running).${NC}" || info "OpenBSD Secure Shell server: ${RED}inactive (dead).${NC}"
  echo
fi


#### Install and Configure Samba ####
section "$SECTION_HEAD - Installing and configuring Samba."

# Install Samba
msg "Installing Samba..."
apt-get update >/dev/null
apt-get install -y samba >/dev/null

# Configure Samba Basics
msg "Configuring Samba..."
service smbd stop 2>/dev/null
cat << EOF > /etc/samba/smb.conf
[global]
workgroup = WORKGROUP
server string = $HOSTNAME
server role = standalone server
disable netbios = yes
dns proxy = no
interfaces = 127.0.0.0/8 eth0
bind interfaces only = yes
log file = /var/log/samba/log.%m
max log size = 1000
syslog = 0
panic action = /usr/share/samba/panic-action %d
passdb backend = tdbsam
obey pam restrictions = yes
unix password sync = yes
passwd program = /usr/bin/passwd %u
passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
pam password change = yes
map to guest = bad user
usershare allow guests = yes
inherit permissions = yes
inherit acls = yes
vfs objects = acl_xattr
follow symlinks = yes
hosts allow = 127.0.0.1 192.168.1.0/24 192.168.20.0/24 192.168.30.0/24 192.168.40.0/24 192.168.50.0/24 192.168.60.0/24 192.168.80.0/24
hosts deny = 0.0.0.0/0

[homes]
comment = home directories
browseable = yes
read only = no
create mask = 0775
directory mask = 0775
hide dot files = yes
valid users = %S

[public]
comment = public anonymous access
path = /srv/$HOSTNAME/public
writable = yes
browsable =yes
public = yes
read only = no
create mode = 0777
directory mode = 0777
force user = nobody
guest ok = yes
hide dot files = yes
EOF

# Create your Default and Custom Samba Shares 
msg "Creating default and custom Samba folder shares..."
cat pve_zfs_nas_base_folder_setup pve_zfs_nas_base_folder_setup-xtra | sed '/^#/d' | sed '/^$/d' | awk '!seen[$0]++' | awk '{ print $1 }' | sed '/homes/d;/public/d' > pve_zfs_nas_base_folder_setup-samba_dir
schemaExtractDir="/srv/$HOSTNAME"
while read dir; do
  dir01="$schemaExtractDir/$dir"
  if [ -d "$dir01" ]; then
    dirgrp01=$(cat pve_zfs_nas_base_folder_setup | sed '/^#/d' | grep -i $dir | awk '{ print $2}' | sed 's/chrootjail.*//') || true >/dev/null
    dirgrp02=$(cat pve_zfs_nas_base_folder_setup | sed '/^#/d' | grep -i $dir | awk '{ print $4}' | sed 's/chrootjail.*//' | sed 's/:.*//') || true >/dev/null
    dirgrp03=$(cat pve_zfs_nas_base_folder_setup | sed '/^#/d' | grep -i $dir | awk '{ print $5}' | sed 's/chrootjail.*//' | sed 's/:.*//') || true >/dev/null
    dirgrp04=$(cat pve_zfs_nas_base_folder_setup | sed '/^#/d' | grep -i $dir | awk '{ print $6}' | sed 's/chrootjail.*//' | sed 's/:.*//') || true >/dev/null
    dirgrp05=$(cat pve_zfs_nas_base_folder_setup | sed '/^#/d' | grep -i $dir | awk '{ print $7}' | sed 's/chrootjail.*//' | sed 's/:.*//') || true >/dev/null
    dirgrp06=$(cat pve_zfs_nas_base_folder_setup | sed '/^#/d' | grep -i $dir | awk '{ print $8}' | sed 's/chrootjail.*//' | sed 's/:.*//') || true >/dev/null
	eval "cat <<-EOF >> /etc/samba/smb.conf

	[$dir]
		comment = $dir folder access
		path = ${dir01}
		browsable =yes
		read only = no
		create mask = 0775
		directory mask = 0775
		valid users = %S$([ ! -z "$dirgrp01" ] && echo ", @$dirgrp01")$([ ! -z "$dirgrp02" ] && echo ", @$dirgrp02")$([ ! -z "$dirgrp03" ] && echo ", @$dirgrp03")$([ ! -z "$dirgrp04" ] && echo ", @$dirgrp04")$([ ! -z "$dirgrp05" ] && echo ", @$dirgrp05")$([ ! -z "$dirgrp06" ] && echo ", @$dirgrp06")
	EOF"
  else
	info "${dir01} does not exist: skipping."
	echo
  fi
done < pve_zfs_nas_base_folder_setup-samba_dir # file listing of folders to create
service smbd start 2>/dev/null # Restart Samba
systemctl is-active smbd >/dev/null 2>&1 && info "Samba server status: ${GREEN}active (running).${NC}" || info "Samba server status: ${RED}inactive (dead).${NC} Your intervention is required."
echo


#### Install and Configure NFS ####
section "$SECTION_HEAD - Installing and configuring NFS Server."

# Install nfs
msg "Installing NFS Server..."
sudo apt-get update >/dev/null
sudo apt-get install -y nfs-kernel-server >/dev/null

# Edit Exports
msg "Modifying $HOSTNAME /etc/exports file..."
if [ "$XTRA_SHARES" = 0 ]; then
	echo
	box_out '#### PLEASE READ CAREFULLY - ADDITIONAL NFS SHARED FOLDERS ####' '' 'In a previous step you created additional shared folders.' '' 'You can now choose which additional folders are to be included as NFS shares.'
	echo
	read -p "Do you want to create NFS shares for your additional shared folders [y/n]? " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    NFS_XTRA_SHARES=0 >/dev/null
  else
    NFS_XTRA_SHARES=1 >/dev/null
    info "Your additional shared folders will not be available as NFS shares (default shared folders only) ..."
    echo
  fi
	echo
else
  NFS_XTRA_SHARES=1 >/dev/null
fi

if [ "$NFS_XTRA_SHARES" = 0 ] && [ "$XTRA_SHARES" = 0 ]; then
  set +u
  msg "Please select which additional folders are to be included as NFS shares."
  menu() {
    echo "Available options:"
    for i in ${!options[@]}; do 
        printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
    done
    if [[ "$msg" ]]; then echo "$msg"; fi
  }
  cat pve_zfs_nas_base_folder_setup-xtra | awk '{ print $1,$2 }' | sed -e 's/^/"/g' -e 's/$/"/g' | tr '\n' ' ' | sed -e 's/^\|$//g' | sed 's/\s*$//' > pve_zfs_nas_base_folder_setup-xtra_options
  mapfile -t options < pve_zfs_nas_base_folder_setup-xtra_options
  prompt="Check an option (again to uncheck, ENTER when done): "
  while menu && read -rp "$prompt" num && [[ "$num" ]]; do
    [[ "$num" != *[![:digit:]]* ]] &&
    (( num > 0 && num <= ${#options[@]} )) ||
    { msg="Invalid option: $num"; continue; }
    ((num--)); msg="${options[num]} was ${choices[num]:+un}checked"
    [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
  done
  echo
  printf "You selected:\n"; msg=" nothing"
  for i in ${!options[@]}; do 
    [[ "${choices[i]}" ]] && { printf " %s" "${options[i]}"; msg=""; } && echo $({ printf " %s" "${options[i]}"; msg=""; }) | sed 's/\"//g' >> included_nfs_xtra_folders
  done
  echo
  set -u
else
  touch included_nfs_xtra_folders
fi
echo

# Create Input lists to create NFS Exports
grep -v -Ff included_nfs_xtra_folders pve_zfs_nas_base_folder_setup-xtra > excluded_nfs_xtra_folders # all rejected NFS additional folders
cat included_nfs_xtra_folders | sed '/medialab/!d' > included_nfs_folders-media_dir # included additional medialab NFS folders
cat included_nfs_xtra_folders | sed '/medialab/d' > included_nfs_folders-default_dir # included additional default NFS folders

# Create Default NFS exports
grep -vxFf excluded_nfs_xtra_folders pve_zfs_nas_base_folder_setup | sed '$r included_nfs_folders-default_dir' | sed '/git/d;/homes/d;/openvpn/d;/sshkey/d' | sed '/audio/d;/books/d;/music/d;/photo/d;/video/d' | awk '{ print $1 }' | sed '/^#/d' | sed '/^$/d' > pve_zfs_nas_base_folder_setup-nfs_default_dir
schemaExtractDir="/srv/$HOSTNAME"
while read dir; do
  dir01="$schemaExtractDir/$dir"
  if [ -d "$dir01" ]; then
	eval "cat <<-EOF >> /etc/exports

	# $dir export
	/srv/$HOSTNAME/$dir 192.168.1.101(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) 192.168.1.102(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) 192.168.1.103(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) 192.168.1.104(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100)
	EOF"
  else
	info "${dir01} does not exist: skipping..."
	echo
  fi
done < pve_zfs_nas_base_folder_setup-nfs_default_dir # file listing of folders to create
# Create Media NFS exports
cat pve_zfs_nas_base_folder_setup | grep -i 'audio\|books\|music\|photo\|\video' | sed '$r included_nfs_folders-media_dir' | awk '{ print $1 }' | sed '/^#/d' | sed '/^$/d' > pve_zfs_nas_base_folder_setup-nfs_media_dir 
schemaExtractDir="/srv/$HOSTNAME"
while read dir; do
  dir01="$schemaExtractDir/$dir"
  if [ -d "$dir01" ]; then
	eval "cat <<-EOF >> /etc/exports

	# $dir export
	/srv/$HOSTNAME/$dir 192.168.1.101(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) 192.168.1.102(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) 192.168.1.103(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) 192.168.1.104(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) 192.168.50.0/24(rw,async,no_wdelay,crossmnt,insecure,all_squash,insecure_locks,sec=sys,anonuid=1024,anongid=100)
	EOF"
  else
	info "${dir01} does not exist: skipping..."
	echo
  fi
done < pve_zfs_nas_base_folder_setup-nfs_media_dir # file listing of folders to create

# NFS Server Restart
msg "Restarting NFS Server..."
service nfs-kernel-server restart 2>/dev/null
if [ "$(systemctl is-active --quiet nfs-kernel-server; echo $?) -eq 0" ]; then
	info "NFS Server status: ${GREEN}active (running).${NC}"
	echo
elif [ "$(systemctl is-active --quiet nfs-kernel-server; echo $?) -eq 3" ]; then
	info "NFS Server status: ${RED}inactive (dead).${NC}. Your intervention is required."
	echo
fi


#### Install and Configure Fail2Ban ####
section "$SECTION_HEAD - Installing and configuring Fail2Ban."

# Install Fail2Ban 
msg "Installing Fail2Ban..."
sudo apt-get install -y fail2ban >/dev/null

# Configuring Fail2Ban
msg "Configuring Fail2Ban..."
sudo systemctl start fail2ban 2>/dev/null
sudo systemctl enable fail2ban 2>/dev/null
cat << EOF > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF
sudo systemctl restart fail2ban 2>/dev/null
if [ "$(systemctl is-active --quiet fail2ban; echo $?) -eq 0" ]; then
	info "Fail2Ban status: ${GREEN}active (running).${NC}"
	echo
elif [ "$(systemctl is-active --quiet fail2ban; echo $?) -eq 3" ]; then
	info "Fail2Ban status: ${RED}inactive (dead).${NC}. Your intervention is required."
	echo
fi


#### Install and Configure ProFTPd ####
section "$SECTION_HEAD - Installing and configuring ProFTPd Server."

echo
box_out '#### PLEASE READ CAREFULLY - PROFTPD INSTALLATION ####' '' 'ProFTPDs is to be a highly feature rich FTP server, exposing a large amount of' 'configuration options to the user. This software allows you to create a' 'FTP connection between a remote or local computer and a your PVE ZFS NAS.' '' 'ProFTPd management can be done using the Webmin management frontend.' 'ProFTPd is installed by default.'
echo

# Run FroFTPd installation script
export PARENT_EXEC_INSTALL_PROFTPD=0 >/dev/null
chmod +x pve_zfs_nas_install_proftpd_ct_20.sh
./pve_zfs_nas_install_proftpd_ct_20.sh


#### Install and Configure Webmin ####
section "$SECTION_HEAD - Installing and configuring Webmin."

# Install Webmin Prerequisites
msg "Installing Webmin prerequisites..."
apt-get install -y gnupg2 >/dev/null
bash -c 'echo "deb http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list' >/dev/null
wget -qL http://www.webmin.com/jcameron-key.asc
sudo apt-key add jcameron-key.asc 2>/dev/null
apt-get update >/dev/null

# Install Webmin
msg "Installing Webmin (be patient, might take a while)..."
apt-get install -y webmin >/dev/null
if [ "$(systemctl is-active --quiet webmin; echo $?) -eq 0" ]; then
	info "Webmin Server status: ${GREEN}active (running).${NC}"
	echo
elif [ "$(systemctl is-active --quiet webmin; echo $?) -eq 3" ]; then
	info "Webmin Server status: ${RED}inactive (dead).${NC}. Your intervention is required."
	echo
fi


#### Install and Configure SSMTP Email Alerts ####
section "$SECTION_HEAD - Installing and configuring Email Alerts."

echo
box_out '#### PLEASE READ CAREFULLY - SSMTP & EMAIL ALERTS ####' '' 'Send email alerts about your machine to the system’s designated administrator.' 'Be alerted about unwarranted login attempts and other system critical alerts.' 'If you do not have a postfix or sendmail server on your network then' 'the "simple smtp" (ssmtp) package is well suited for sending critical' 'alerts to the systems designated administrator.' '' 'ssmtp is a simple Mail Transfer Agent (MTA) while easy to setup it' 'requires the following prerequisites:' '' '  --  SMTP SERVER' '      You require a SMTP server that can receive the emails from your machine' '      and send them to the designated administrator. ' '      If you use Gmail smtp server its best to enable "App Passwords". An "App' '      Password" is a 16-digit passcode that gives an app or device permission' '      to access your Google Account.' '      Or you can use a mailgun.com flex account relay server (Recommended).' '' '  --  REQUIRED SMTP SERVER CREDENTIALS' '      1. Designated administrator email address' '         (i.e your working admin email address)' '      2. smtp server address' '         (i.e smtp.gmail.com or smtp.mailgun.org)' '      3. smtp server port' '         (i.e gmail port is 587 and mailgun port is 587)' '      4. smtp server username' '         (i.e MyEmailAddress@gmail.com or postmaster@sandboxa6ac6.mailgun.org)' '      5. smtp server default password' '         (i.e your Gmail App Password or mailgun smtp password)' '' 'If you choose to proceed have your smtp server credentials available.' 'This script will install and configure a ssmtp package as well as the default' 'Webmin Sending Email on your PVE ZFS NAS.'
echo
read -p "Install and configure ssmtp on your $SECTION_HEAD [y/n]?: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  msg "Installing ssmtp..."
  export INSTALL_SSMTP=0 >/dev/null
  export PARENT_EXEC_INSTALL_SSMTP=0 >/dev/null
  chmod +x pve_zfs_nas_install_ssmtp_ct_20.sh
  ./pve_zfs_nas_install_ssmtp_ct_20.sh
else
  INSTALL_SSMTP=1 >/dev/null
  info "You have chosen to skip this step."
fi
echo


#### Create New Power User Accounts ####
section "$SECTION_HEAD - Create New Power User Accounts"

echo
box_out '#### PLEASE READ CAREFULLY - CREATING POWER USER ACCOUNTS ####' '' 'Power Users are trusted persons with privileged access to data and application' 'resources hosted on your PVE ZFS NAS. Power Users are NOT standard users!' 'Standard users are added at a later stage.' '' 'Each new Power Users security permissions are controlled by linux groups.' 'Group security permission levels are as follows:' '' '  --  GROUP NAME    -- PERMISSIONS' '  --  "medialab"    -- Everything to do with media (i.e movies, TV and music)' '  --  "homelab"     -- Everything to do with a smart home including "medialab"' '  --  "privatelab"  -- Private storage including "medialab" & "homelab" rights' '' 'A Personal Home Folder will be created for each new user. The folder name is' 'the users name. You can access Personal Home Folders and other shares' 'via CIFS/Samba and NFS.' '' 'Remember your PVE ZFS NAS is also pre-configured with user names' 'specifically tasked for running hosted applications (i.e Proxmox LXC,CT,VM).' 'These application users names are as follows:' '' '  --  GROUP NAME    -- USER NAME' '  --  "medialab"    -- /srv/CT_HOSTNAME/homes/"media"' '  --  "homelab"     -- /srv/CT_HOSTNAME/homes/"home"' '  --  "privatelab"  -- /srv/CT_HOSTNAME/homes/"private"'

echo
read -p "Create new power user accounts on your PVE ZFS NAS [y/n]?: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
	export NEW_POWER_USER=0 >/dev/null
  export PARENT_EXEC_NEW_POWER_USER=0 >/dev/null
  chmod +x pve_zfs_nas_add_poweruser_ct_20.sh
  ./pve_zfs_nas_add_poweruser_ct_20.sh
else
	NEW_POWER_USER=1 >/dev/null
	info "You have chosen to skip this step."
fi
echo


#### Create Restricted and Jailed User Accounts ####
section "$SECTION_HEAD - Create Restricted and Jailed User Accounts"

echo
box_out '#### PLEASE READ CAREFULLY - RESTRICTED & JAILED USER ACCOUNTS ####' '' 'Every new user is restricted or jailed within their own home folder. In Linux' 'this is called a chroot jail. But you can select the level of restrictions which' 'are applied to each newly created user. This technique can be quite useful if' 'you want a particular user to be provided with a limited system environment,' 'limited folder access and at the same time keep them separate from your' 'main server system and other personal data.' '' 'The chroot technique will automatically jail selected users belonging' 'to the "chrootjail" user group upon ssh or ftp login.' '' 'An example of a jailed user is a person who has remote access to your' 'PVE ZFS NAS but is restricted to your video library (TV, movies, documentary),' 'public folders and their home folder for cloud storage only.' 'Remote access to your PVE ZFS NAS is restricted to sftp, ssh and rsync' 'using private SSH RSA encrypted keys.' '' 'Default "chrootjail" group permission options are:' '' '  --  GROUP NAME     -- USER NAME' '      "chrootjail"   -- /srv/hostname/homes/chrootjail/"username_injail"' '' 'Selectable jail folder permission levels for each new user:' '' '  --  LEVEL 1        -- FOLDER' '      -rwx------     -- /srv/hostname/homes/chrootjail/"username_injail"' '                     -- Bind Mounts - mounted at ~/public folder' '      -rwxrwxrw-     -- /srv/hostname/homes/chrootjail/"username_injail"/public' '' '  --  LEVEL 2        -- FOLDER' '      -rwx------     -- /srv/hostname/homes/chrootjail/"username_injail"' '                     -- Bind Mounts - mounted at ~/share folder' '      -rwxrwxrw-     -- /srv/hostname/downloads/user/"username_downloads"' '      -rwxrwxrw-     -- /srv/hostname/photo/"username_photo"' '      -rwxrwxrw-     -- /srv/hostname/public' '      -rwxrwxrw-     -- /srv/hostname/video/homevideo/"username_homevideo"' '      -rwxr-----     -- /srv/hostname/video/movies' '      -rwxr-----     -- /srv/hostname/video/tv' '      -rwxr-----     -- /srv/hostname/video/documentary' '' '  --  LEVEL 3        -- FOLDER' '      -rwx------     -- /srv/"hostname"/homes/chrootjail/"username_injail"' '                     -- Bind Mounts - mounted at ~/share folder' '      -rwxr-----     -- /srv/hostname/audio' '      -rwxr-----     -- /srv/hostname/books' '      -rwxrwxrw-     -- /srv/hostname/downloads/user/"username_downloads"' '      -rwxr-----     -- /srv/hostname/music' '      -rwxrwxrw-     -- /srv/hostname/photo/"username_photo"' '      -rwxrwxrw-     -- /srv/hostname/public' '      -rwxrwxrw-     -- /srv/hostname/video/homevideo/"username_homevideo"' '      -rwxr-----     -- /srv/hostname/video (All)' '' 'All Home folders are automatically suffixed: "username_injail".'
echo
read -p "Create jailed user accounts on your $SECTION_HEAD [y/n]? " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
	export NEW_JAIL_USER=0 >/dev/null
  export PARENT_EXEC_NEW_JAIL_USER=0 >/dev/null
  chmod +x pve_zfs_nas_add_jailuser_ct_20.sh
  ./pve_zfs_nas_add_jailuser_ct_20.sh
else
	NEW_JAIL_USER=1 >/dev/null
	info "You have chosen to skip this step."
fi


#### Create & Setup kodi_rsync user #####
section "$SECTION_HEAD - Create kodi_rsync user."

echo
box_out '#### PLEASE READ CAREFULLY - KODI_RSYNC USER ####' '' '"kodi_rsync" is a special user account created for synchronising a portable' 'or remote kodi media player with a hard disk to your PVE ZFS NAS media' 'video, music and photo libraries. Connection is by RSSH rsync.' 'This is for persons wanting a portable copy of their media for travelling to' 'remote locations where there is limited bandwidth or no internet access.' '' '"kodi_rsync" is NOT a media server for Kodi devices. If you want a home media' 'server then create our PVE Jellyfin CT.' '' 'Our rsync script will securely connect to your PVE ZFS NAS and;' '' '  --  rsync mirror your selected media library to your kodi player USB disk.' '  --  copy your latest media only to your kodi player USB disk.' '  --  remove the oldest media to fit newer media.' '  --  fill your USB disk to a limit set by you.' '' 'The first step involves creating a new user called "kodi_rsync" on your PVE ZFS NAS' 'which has limited and restricted permissions granting rsync read access only' 'to your media libraries.' 'The second step, performed at a later stage, is setting up a CoreElec or' 'LibreElec player hardware with a USB hard disk and installing our' 'rsync scripts along with your PVE ZFS NAS user "kodi_rsync" private ssh ed25519 key.'
echo
warn "The kodi_rsync based user is being deprecated. It is replaced with our\nPVE medialab rsync server CT (Recommended)."
echo
read -p "Create the user kodi_rsync on your $SECTION_HEAD [y/n]?: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  msg "Creating user kodi_rsync..."
  export NEW_KODI_RSYNC_USER=0 >/dev/null
  export PARENT_EXEC_NEW_KODI_RSYNC_USER=0 >/dev/null
  chmod +x pve_zfs_nas_add_rsyncuser_ct_20.sh
  ./pve_zfs_nas_add_rsyncuser_ct_20.sh
else
  NEW_KODI_RSYNC_USER=1 >/dev/null
  info "You have chosen to skip this step."
fi
echo

sleep 5