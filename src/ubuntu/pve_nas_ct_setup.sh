#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_ct_setup.sh
# Description:  Setup for Ubuntu NAS server
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_DIR="${DIR}/../../common"
COMMON_PVE_SRC="${DIR}/../../common/pve/src"
SHARED_DIR="${DIR}/../../shared"

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source ${COMMON_PVE_SRC}/pvesource_bash_defaults.sh

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='PVE NAS'

#---- Other Files ------------------------------------------------------------------

# Copy default lists of folder shares
mv /tmp/nas_basefolderlist .
mv /tmp/nas_basefoldersubfolderlist .
mv /tmp/nas_basefolderlist_extra .

#---- Body -------------------------------------------------------------------------

#---- Performing Prerequisites
section "Performing Prerequisites"

# Setting Variables
msg "Setting the $SECTION_HEAD variables..."
if [ -f /tmp/pve_nas_ct_variables.sh ]; then
  mv /tmp/pve_nas_ct_variables.sh . 2>/dev/null
  # Import Variables
  . ./pve_nas_ct_variables.sh
  info "${SECTION_HEAD} variables are set."
  echo
fi

# Checking NAS storage mount point
if [ ! -d "/srv/${HOSTNAME}" ]; then
  warn "Cannot locate, identify and PVE storage backend: "/srv/${HOSTNAME}"\nAborting installation."
  exit 0
fi

# Download and Install Prerequisites
msg "Installing ACL..."
apt-get install -y acl >/dev/null
msg "Installing Putty Tools..."
apt-get install -y putty-tools >/dev/null
echo


#---- Creating PVE NAS Users and Groups
section "Creating Users and Groups"

# Change Home folder permissions
msg "Setting default adduser home folder permissions (DIR_MODE)..."
sed -i "s/DIR_MODE=.*/DIR_MODE=0750/g" /etc/adduser.conf
info "Default adduser permissions set: ${WHITE}0750${NC}"
msg "Setting default HOME folder destination..."
sed -i "s/DHOME=.*/DHOME=\/srv\/$HOSTNAME\/homes/g" /etc/adduser.conf
sed -i "s/# HOME=.*/HOME=\/srv\/$HOSTNAME\/homes/g" /etc/default/useradd
echo "HOME_MODE 0750" | sudo tee -a /etc/login.defs
info "Default HOME destination folder set: ${WHITE}/srv/$HOSTNAME/homes${NC}"

# Create users and groups
msg "Creating CT default user groups..."
# Create Groups
if [ $(egrep -i "^medialab" /etc/group >/dev/null; echo $?) != 0 ]; then
  groupadd -g 65605 medialab > /dev/null
  info "Default user group created: ${YELLOW}medialab${NC}"
fi
if [ $(egrep -i "^homelab" /etc/group >/dev/null; echo $?) -ne 0 ]; then
  groupadd -g 65606 homelab > /dev/null
  info "Default user group created: ${YELLOW}homelab${NC}"
fi
if [ $(egrep -i "^privatelab" /etc/group >/dev/null; echo $?) -ne 0 ]; then
  groupadd -g 65607 privatelab > /dev/null
  info "Default user group created: ${YELLOW}privatelab${NC}"
fi
if [ $(egrep -i "^chrootjail" /etc/group >/dev/null; echo $?) -ne 0 ]; then
  groupadd -g 65608 chrootjail > /dev/null
  info "Default user group created: ${YELLOW}chrootjail${NC}"
fi
echo

# Create Base User Accounts
msg "Creating CT default users..."
mkdir -p /srv/$HOSTNAME/homes >/dev/null
chgrp -R root /srv/$HOSTNAME/homes >/dev/null
chmod -R 0755 /srv/$HOSTNAME/homes >/dev/null
if [ $(id -u media &>/dev/null; echo $?) = 1 ]; then
  useradd -m -d /srv/$HOSTNAME/homes/media -u 1605 -g medialab -s /bin/bash media >/dev/null
  chmod 0700 /srv/$HOSTNAME/homes/media
  info "Default user created: ${YELLOW}media${NC} of group medialab"
fi
if [ $(id -u home &>/dev/null; echo $?) = 1 ]; then
  useradd -m -d /srv/$HOSTNAME/homes/home -u 1606 -g homelab -G medialab -s /bin/bash home >/dev/null
  chmod 0700 /srv/$HOSTNAME/homes/home
  info "Default user created: ${YELLOW}home${NC} of groups medialab, homelab"
fi
if [ $(id -u private &>/dev/null; echo $?) = 1 ]; then
  useradd -m -d /srv/$HOSTNAME/homes/private -u 1607 -g privatelab -G medialab,homelab -s /bin/bash private >/dev/null
  chmod 0700 /srv/$HOSTNAME/homes/private
  info "Default user created: ${YELLOW}private${NC} of groups medialab, homelab and privatelab"
fi
echo

# Creating Chroot jail environment
export PARENT_EXEC=0 >/dev/null
source ${COMMON_PVE_SRC}/pvesource_ct_ubuntu_installchroot.sh
SECTION_HEAD='PVE NAS'

#---- Validating your network setup

# Run Check Host IP
# source ${SHARED_DIR}/nas_set_nasip.sh

# Identify PVE host IP
source ${COMMON_PVE_SRC}/pvesource_identify_pvehosts.sh

# Modifying SSHd
cat <<EOF >> /etc/ssh/sshd_config
# Settings for privatelab
Match Group privatelab
        AuthorizedKeysFile /srv/$HOSTNAME/homes/%u/.ssh/authorized_keys
        PubkeyAuthentication yes
        PasswordAuthentication no
        AllowTCPForwarding no
        X11Forwarding no
# Settings for medialab
Match Group medialab
        AuthorizedKeysFile /srv/$HOSTNAME/homes/%u/.ssh/authorized_keys
        PubkeyAuthentication yes
        PasswordAuthentication no
        AllowTCPForwarding no
        X11Forwarding no
EOF


#---- Install and Configure Samba
source ${SHARED_DIR}/nas_installsamba.sh


#---- Install and Configure NFS
source ${SHARED_DIR}/nas_installnfs.sh


#---- Install and Configure Webmin
section "Installing and configuring Webmin."


#---- Install Webmin Prerequisites
msg "Installing Webmin prerequisites (be patient, might take a while)..."
# apt-get install -y gnupg2 >/dev/null
# bash -c 'echo "deb http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list' >/dev/null
# wget -qL http://www.webmin.com/jcameron-key.asc
# apt-key add jcameron-key.asc 2>/dev/null
# apt-get update >/dev/null
if (( $(echo "$(lsb_release -sr) >= 22.04" | bc -l) )); then
  apt-get install -y gnupg2 >/dev/null
  echo "deb https://download.webmin.com/download/repository sarge contrib" | tee /etc/apt/sources.list.d/webmin.list
  wget -qO - http://www.webmin.com/jcameron-key.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/jcameron-key.gpg
  apt-get update >/dev/null
elif (( $(echo "$(lsb_release -sr) < 22.04" | bc -l) )); then
  apt-get install -y gnupg2 >/dev/null
  bash -c 'echo "deb [arch=amd64] http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list' >/dev/null
  wget -qL https://download.webmin.com/jcameron-key.asc
  apt-key add jcameron-key.asc 2>/dev/null
  apt-get update >/dev/null
fi

# Install Webmin
msg "Installing Webmin (be patient, might take a long, long, long while)..."
apt-get install -y webmin >/dev/null
ufw allow 10000 > /dev/null
if [ "$(systemctl is-active --quiet webmin; echo $?) -eq 0" ]; then
	info "Webmin Server status: ${GREEN}active (running).${NC}"
	echo
elif [ "$(systemctl is-active --quiet webmin; echo $?) -eq 3" ]; then
	info "Webmin Server status: ${RED}inactive (dead).${NC}. Your intervention is required."
	echo
fi