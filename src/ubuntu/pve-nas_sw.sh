#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve-nas_sw.sh
# Description:  Setup for Ubuntu NAS server
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_DIR="$DIR/../../common"
COMMON_PVE_SRC_DIR="$DIR/../../common/pve/src"
SHARED_DIR="$DIR/../../shared"

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source $COMMON_PVE_SRC_DIR/pvesource_bash_defaults.sh

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

#---- Prerequisites
section "Performing Prerequisites"

# Setting Variables
msg "Setting the $SECTION_HEAD variables..."
if [ -f "/tmp/pve_nas_ct_variables.sh" ]
then
  mv /tmp/pve_nas_ct_variables.sh . 2>/dev/null
  # Import Variables
  . ./pve_nas_ct_variables.sh
  info "${SECTION_HEAD} variables are set."
  echo
fi

# Checking NAS storage mount point
if [ ! -d "/srv/$HOSTNAME" ]
then
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
sed -i "s/^DIR_MODE=.*/DIR_MODE=0750/g" /etc/adduser.conf
info "Default adduser permissions set: ${WHITE}0750${NC}"
msg "Setting default HOME folder destination..."
sed -i "s|^DHOME=.*|DHOME=$DIR_SCHEMA/homes|g" /etc/adduser.conf
sed -i "s|^# HOME=.*|HOME=$DIR_SCHEMA/homes|g" /etc/default/useradd
echo "HOME_MODE 0750" | sudo tee -a /etc/login.defs
info "Default HOME destination folder set: ${WHITE}$DIR_SCHEMA/homes${NC}"

# Create User Acc
# Set base dir
DIR_SCHEMA="/srv/$(hostname)"
source $SHARED_DIR/pve_nas_create_users.sh

# Creating Chroot jail environment
source $COMMON_PVE_SRC_DIR/pvesource_ct_ubuntu_installchroot.sh


#---- Validating your network setup

# Run Check Host IP
# source $COMMON_DIR/nas/src/nas_set_nasip.sh

# Identify PVE host IP
source $COMMON_DIR/nas/src/nas_identify_pvehosts.sh
# source $COMMON_PVE_SRC_DIR/pvesource_identify_pvehosts.sh

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
source $COMMON_DIR/nas/src/nas_installsamba.sh


#---- Install and Configure NFS
source $COMMON_DIR/nas/src/nas_installnfs.sh


#---- Install and Configure Webmin
source $COMMON_PVE_SRC_DIR/pvesource_install_webmin.sh
#-----------------------------------------------------------------------------------