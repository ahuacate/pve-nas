#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_ct_setup.sh
# Description:  Setup for Ubuntu NAS server
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SOURCE="${DIR}/../../../../common/pve/source"
SRC_DIR=${DIR}
SRC_COMMON_PVE_SOURCE=${COMMON_PVE_SOURCE}

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source ${COMMON_PVE_SOURCE}/pvesource_bash_defaults.sh

# IP validate
function valid_ip() {
  local  ip=$1
  local  stat=1
  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      OIFS=$IFS
      IFS='.'
      ip=($ip)
      IFS=$OIFS
      [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
          && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
      stat=$?
  fi
  return $stat
}

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='PVE NAS'

#---- Other Files ------------------------------------------------------------------

# Copy default lists of folder shares
mv /tmp/pve_nas_basefolderlist .
mv /tmp/pve_nas_basefoldersubfolderlist .
mv /tmp/pve_nas_basefolderlist-xtra .

# Create empty files
# touch pve_nas_basefolderlist-xtra

#---- Body -------------------------------------------------------------------------

#---- Performing Prerequisites
section "Performing Prerequisites."

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
if [ ! -d "/srv/${CT_HOSTNAME}" ]; then
  warn "Cannot locate, identify and PVE storage backend: "/srv/${CT_HOSTNAME}"\nAborting installation."
  exit 0
fi

# Updates & Upgrades

# Download and Install Prerequisites
msg "Installing ACL..."
apt-get install -y acl >/dev/null
msg "Installing Putty Tools..."
apt-get install -y putty-tools >/dev/null
echo


#---- Creating PVE NAS Users and Groups
section "Creating Users and Groups."

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
source ${COMMON_PVE_SOURCE}/pvesource_ct_ubuntu_installchroot.sh
SECTION_HEAD='PVE NAS'

#---- Validating your network setup

if [ ${PVE_HOST_IP} = '192.168.1.101' ] && [ ${PVE_HOST_NAME} = 'pve-01' ] || [ ${PVE_HOST_IP} = '192.168.1.102' ] && [ ${PVE_HOST_NAME} = 'pve-02' ]  || [ ${PVE_HOST_IP} = '192.168.1.103' ] && [ ${PVE_HOST_NAME} = 'pve-03' ]  || [ ${PVE_HOST_IP} = '192.168.1.104' ] && [ ${PVE_HOST_NAME} = 'pve-04' ] ; then
  PVE_01_IP='192.168.1.101'
  PVE_02_IP='192.168.1.102'
  PVE_03_IP='192.168.1.103'
  PVE_04_IP='192.168.1.104'
  MEDIA_VLAN='192.168.50.0/24'
  HOSTS_ALLOW='127.0.0.1 192.168.1.0/24 192.168.20.0/24 192.168.30.0/24 192.168.40.0/24 192.168.50.0/24 192.168.60.0/24 192.168.80.0/24'
else
  section "Validating your network setup."
  i=$(( $(echo ${PVE_HOST_IP} | cut -d . -f 4) + 1 ))
  k=2
  msg_box "#### PLEASE READ CAREFULLY ####\n
  Your PVE host IP address '${PVE_HOST_IP}' does not conform to our scripts standard IP addressing range. So we need to determine if '${PVE_HOST_NAME} ${PVE_HOST_IP}' is your PVE host primary or ONLY host node. A typical PVE node cluster using your PVE host IP address format would be (note the ascending IP addresses):\n\n  -- pve-01  '${PVE_HOST_IP}' ( Primary host )\n$(until [ $i = $(( $(echo ${PVE_HOST_IP} | cut -d . -f 4) + 4 )) ]; do echo "  -- pve-0$k  $(echo ${PVE_HOST_IP} | cut -d"." -f1-3).$i ( Secondary host )";  ((i=i+1)); ((k=k+1)); done)
  
  All of the above PVE host nodes could form a Proxmox cluster. If only one PVE host node is installed then '${PVE_HOST_NAME} ${PVE_HOST_IP}' must be your PVE primary host. Always reserve the next ascending IP addresses for a PVE cluster build. This installation assumes '${PVE_HOST_NAME} ${PVE_HOST_IP}' is a PVE primary host.

  FYI our standard PVE primary (pve-01) host IPv4 address starts with the following IPv4 addresses and three are reserved for PVE cluster building:\n\n  -- pve-01  '192.168.1.101' ( Primary host )

  Now we MUST confirm if IPv4 address '${PVE_HOST_IP}' is your PVE primary host or not in order to set NFS and SMB export share permissions."
  echo

  # Checking PVE-01 host IP address
  while true; do
    read -p "Enter your PVE primary host (pve-01) IPv4 address: " -e -i ${PVE_HOST_IP} PVE_01_IP
    msg "Performing checks on your input (be patient, may take a while)..."
    if [ $(valid_ip $PVE_01_IP > /dev/null; echo $?) != 0 ]; then
      warn "There are problems with your input:
      
      1. The IP address is incorrectly formatted. It must be in the IPv4 format, quad-dotted octet format (i.e xxx.xxx.xxx.xxx ).
      
      Try again..."
      echo
    elif [ $(valid_ip $PVE_01_IP > /dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 $PVE_01_IP > /dev/null; echo $?) != 0 ]; then
      warn "There are problems with your input:
      
      1. The IP address meets the IPv4 standard.
      2. The PVE host IP address '$PVE_01_IP' is not reachable.
      
      Make sure the PVE host is running. Try again..."
      echo
    elif [ $(valid_ip $PVE_01_IP > /dev/null; echo $?) == 0 ] && [ $(ping -s 1 -c 2 $PVE_01_IP > /dev/null; echo $?) = 0 ]; then
      info "Your input appears okay:\n\n  1. The IP address meets the IPv4 standard.\n  2. The PVE host IP address '$PVE_01_IP' is reachable.\n\nSetting your PVE host nodes IPv4 addresses as shown:"
      echo
      msg "  -- pve-01  $PVE_01_IP ( Primary host )"
      i=$(( $(echo $PVE_01_IP | cut -d . -f 4) + 1 ))
      k=2
      j=2
      counter=1
      until [ $counter -eq 4 ]
      do
        msg "  -- pve-0$k  $(echo $PVE_01_IP | cut -d"." -f1-3).$i ( Secondary host )"
        export "PVE_0${j}_IP=$(echo $PVE_01_IP | cut -d"." -f1-3).$i"
        ((i=i+1))
        ((k=k+1))
        ((j=j+1))
        ((counter++))
      done
      MEDIA_VLAN=$(awk -F"." '{print $1"."$2"."50".0/24"}'<<<$PVE_01_IP)
      echo
      while true; do
        read -p "Accept PVE primary host (pve-01) IPv4 address ${WHITE}$PVE_01_IP${NC} [y/n]? " -n 1 -r YN
        echo
        case $YN in
          [Yy]*)
            info "PVE primary host node IPv4 address is set: ${YELLOW}$PVE_01_IP${NC}"
            msg "Default SMB share permissions are:\n\n  --  $(echo $PVE_01_IP | cut -d"." -f1-3).0/24 (Host Vlan)\n  --  $(echo $PVE_01_IP | cut -d"." -f1-2).20.0/24 (Vlan 20 - LAN smart)\n  --  $(echo $PVE_01_IP | cut -d"." -f1-2).30.0/24 (Vlan 30 - LAN vpngate world)\n  --  $(echo $PVE_01_IP | cut -d"." -f1-2).40.0/24 (Vlan 40 - LAN vpngate local)\n  --  $(echo $PVE_01_IP | cut -d"." -f1-2).50.0/24 (Vlan 50 - LAN media)\n  --  $(echo $PVE_01_IP | cut -d"." -f1-2).60.0/24 (Vlan 60 - LAN vpn)\n  --  $(echo $PVE_01_IP | cut -d"." -f1-2).80.0/24 (Vlan 80 - LAN homelab)"
            HOSTS_ALLOW="127.0.0.1 $(echo $PVE_01_IP | cut -d"." -f1-3).0/24 $(echo $PVE_01_IP | cut -d"." -f1-2).20.0/24 $(echo $PVE_01_IP | cut -d"." -f1-2).30.0/24 $(echo $PVE_01_IP | cut -d"." -f1-2).40.0/24 $(echo $PVE_01_IP | cut -d"." -f1-2).50.0/24 $(echo $PVE_01_IP | cut -d"." -f1-2).60.0/24 $(echo $PVE_01_IP | cut -d"." -f1-2).80.0/24"
            MEDIA_VLAN="$(echo $PVE_01_IP | cut -d"." -f1-2).50.0/24"
            echo
            break 2
            ;;
          [Nn]*)
            msg "No problem. Try again ..."
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
fi

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
section "Installing and configuring SMB (samba)"

# Install Samba
msg "Installing SMB (be patient, may take a while)..."
apt-get install -y samba-common-bin samba >/dev/null

# Configure Samba Basics
msg "Configuring SMB..."
service smbd stop 2>/dev/null
cat << EOF > /etc/samba/smb.conf
[global]
workgroup = WORKGROUP
server string = ${HOSTNAME}
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
hosts allow = ${HOSTS_ALLOW}
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
msg "Creating default and custom SMB folder shares..."
cat pve_nas_basefolderlist pve_nas_basefolderlist-xtra | sed '/^#/d' | sed '/^$/d' | awk '!seen[$0]++' | awk '{ print $1 }' | sed '/homes/d;/public/d' > pve_nas_basefolderlist-samba_dir
schemaExtractDir="/srv/$HOSTNAME"
while read dir; do
  dir01="$schemaExtractDir/$dir"
  if [ -d "$dir01" ]; then
    dirgrp01=$(cat pve_nas_basefolderlist | sed '/^#/d' | grep -i $dir | awk '{ print $2}' | sed 's/65608.*//') || true >/dev/null
    dirgrp02=$(cat pve_nas_basefolderlist | sed '/^#/d' | grep -i $dir | awk '{ print $4}' | sed 's/65608.*//' | sed 's/:.*//') || true >/dev/null
    dirgrp03=$(cat pve_nas_basefolderlist | sed '/^#/d' | grep -i $dir | awk '{ print $5}' | sed 's/65608.*//' | sed 's/:.*//') || true >/dev/null
    dirgrp04=$(cat pve_nas_basefolderlist | sed '/^#/d' | grep -i $dir | awk '{ print $6}' | sed 's/65608.*//' | sed 's/:.*//') || true >/dev/null
    dirgrp05=$(cat pve_nas_basefolderlist | sed '/^#/d' | grep -i $dir | awk '{ print $7}' | sed 's/65608.*//' | sed 's/:.*//') || true >/dev/null
    dirgrp06=$(cat pve_nas_basefolderlist | sed '/^#/d' | grep -i $dir | awk '{ print $8}' | sed 's/65608.*//' | sed 's/:.*//') || true >/dev/null
  # Edit /etc/samba/smb.conf
  printf "%b\n" "\n[$dir]" \
  "  comment = $dir folder access" \
  "  path = ${dir01}" \
  "  browsable = yes" \
  "  read only = no" \
  "  create mask = 0775" \
  "  directory mask = 0775" \
  "  valid users = %S$([ ! -z "$dirgrp01" ] && echo ", @$dirgrp01")$([ ! -z "$dirgrp02" ] && echo ", @$dirgrp02")$([ ! -z "$dirgrp03" ] && echo ", @$dirgrp03")$([ ! -z "$dirgrp04" ] && echo ", @$dirgrp04")$([ ! -z "$dirgrp05" ] && echo ", @$dirgrp05")$([ ! -z "$dirgrp06" ] && echo ", @$dirgrp06")\n" >> /etc/samba/smb.conf
  else
  info "${dir01} does not exist: skipping."
  echo
  fi
done < pve_nas_basefolderlist-samba_dir # file listing of folders to create
service smbd start 2>/dev/null # Restart Samba
systemctl is-active smbd >/dev/null 2>&1 && info "SMB server status: ${GREEN}active (running).${NC}" || info "SMB server status: ${RED}inactive (dead).${NC} Your intervention is required."
echo

#---- Install and Configure NFS
section "Installing and configuring NFS Server."

# Install nfs
msg "Installing NFS Server..."
apt-get install -y nfs-kernel-server >/dev/null

# Edit Exports
msg "Modifying ${HOSTNAME} /etc/exports file..."
if [ ${XTRA_SHARES} = 0 ]; then
  echo
  msg_box "#### PLEASE READ CAREFULLY - ADDITIONAL NFS SHARED FOLDERS ####\n
  In a previous step you created additional shared folders. You can now choose which additional folders are to be included as NFS shares."
  echo
  while true; do
    read -p "Do you want to create NFS shares for your additional shared folders [y/n]? " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        NFS_XTRA_SHARES=0
        echo
        break
        ;;
      [Nn]*)
        NFS_XTRA_SHARES=1
        info "Your additional shared folders will not be available as NFS shares (default shared folders only) ..."
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
  NFS_XTRA_SHARES=1
fi

if [ ${NFS_XTRA_SHARES} = 0 ] && [ ${XTRA_SHARES} = 0 ]; then
  set +u
  msg "Please select which additional folders are to be included as NFS shares."
  menu() {
    echo "Available options:"
    for i in ${!options[@]}; do 
        printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
    done
    if [[ "$msg" ]]; then echo "$msg"; fi
  }
  cat pve_nas_basefolderlist-xtra | awk '{ print $1,$2 }' | sed -e 's/^/"/g' -e 's/$/"/g' | tr '\n' ' ' | sed -e 's/^\|$//g' | sed 's/\s*$//' > pve_nas_basefolderlist-xtra_options
  mapfile -t options < pve_nas_basefolderlist-xtra_options
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
if [ $(cat included_nfs_xtra_folders | wc -l) -gt '0' ]; then
  grep -v -Ff included_nfs_xtra_folders pve_nas_basefolderlist-xtra > excluded_nfs_xtra_folders # all rejected NFS additional folders
else
  touch excluded_nfs_xtra_folders
fi
cat included_nfs_xtra_folders | sed '/medialab/!d' > included_nfs_folders-media_dir # included additional medialab NFS folders
cat included_nfs_xtra_folders | sed '/medialab/d' > included_nfs_folders-default_dir # included additional default NFS folders

# Create Default NFS exports
grep -vxFf excluded_nfs_xtra_folders pve_nas_basefolderlist | sed '$r included_nfs_folders-default_dir' | sed '/git/d;/homes/d;/openvpn/d;/sshkey/d' | sed '/audio/d;/books/d;/music/d;/photo/d;/video/d' | awk '{ print $1 }' | sed '/^#/d' | sed '/^$/d' > pve_nas_basefolderlist-nfs_default_dir
schemaExtractDir="/srv/$HOSTNAME"
while read dir; do
  dir01="$schemaExtractDir/$dir"
  if [ -d "$dir01" ]; then
    printf "%b\n" "\n# $dir export" \
    "/srv/$HOSTNAME/$dir ${PVE_01_IP}(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) ${PVE_02_IP}(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) ${PVE_03_IP}(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) ${PVE_04_IP}(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100)" >> /etc/exports
  else
  info "${dir01} does not exist: skipping..."
  echo
  fi
done < pve_nas_basefolderlist-nfs_default_dir # file listing of folders to create
# Create Media NFS exports
cat pve_nas_basefolderlist | grep -i 'audio\|books\|music\|photo\|\video' | sed '$r included_nfs_folders-media_dir' | awk '{ print $1 }' | sed '/^#/d' | sed '/^$/d' > pve_nas_basefolderlist-nfs_media_dir 
schemaExtractDir="/srv/$HOSTNAME"
while read dir; do
  dir01="$schemaExtractDir/$dir"
  if [ -d "$dir01" ]; then
    printf "%b\n" "\n# $dir export" \
    "/srv/$HOSTNAME/$dir ${PVE_01_IP}(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) ${PVE_02_IP}(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) ${PVE_03_IP}(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) ${PVE_04_IP}(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) ${MEDIA_VLAN}(rw,async,no_wdelay,crossmnt,insecure,all_squash,insecure_locks,sec=sys,anonuid=1024,anongid=100)" >> /etc/exports
  else
  info "${dir01} does not exist: skipping..."
  echo
  fi
done < pve_nas_basefolderlist-nfs_media_dir # file listing of folders to create

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

#---- Install and Configure Webmin
section "Installing and configuring Webmin."

# Install Webmin Prerequisites
msg "Installing Webmin prerequisites (be patient, might take a while)..."
apt-get install -y gnupg2 >/dev/null
bash -c 'echo "deb http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list' >/dev/null
wget -qL http://www.webmin.com/jcameron-key.asc
apt-key add jcameron-key.asc 2>/dev/null
apt-get update >/dev/null

# Install Webmin
msg "Installing Webmin (be patient, might take a long, long, long while)..."
apt-get install -y webmin >/dev/null
if [ "$(systemctl is-active --quiet webmin; echo $?) -eq 0" ]; then
	info "Webmin Server status: ${GREEN}active (running).${NC}"
	echo
elif [ "$(systemctl is-active --quiet webmin; echo $?) -eq 3" ]; then
	info "Webmin Server status: ${RED}inactive (dead).${NC}. Your intervention is required."
	echo
fi