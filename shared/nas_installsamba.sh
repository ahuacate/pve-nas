#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nas_installsamba.sh
# Description:  Source script for installing & setup of Samba
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------

# Default samba .conf file
SMB_CONF='/etc/samba/smb.conf'

# Samba directory to store samba configuration files individually
SMB_CONF_DIR='/etc/samba/smb.conf.d'
mkdir -p ${SMB_CONF_DIR}

# File which contains all includes to samba configuration files individually
SMB_INCLUDES=/etc/samba/includes.conf

# Allowed hosts
HOSTS_ALLOW="127.0.0.1 $(echo $PVE_HOST_IP | cut -d"." -f1-3).0/24 $(echo $PVE_HOST_IP | cut -d"." -f1-2).20.0/24 $(echo $PVE_HOST_IP | cut -d"." -f1-2).30.0/24 $(echo $PVE_HOST_IP | cut -d"." -f1-2).40.0/24 $(echo $PVE_HOST_IP | cut -d"." -f1-2).50.0/24 $(echo $PVE_HOST_IP | cut -d"." -f1-2).60.0/24 $(echo $PVE_HOST_IP | cut -d"." -f1-2).80.0/24"

#---- Other Files ------------------------------------------------------------------

# New smb.conf 
cat << EOF > smb.conf.tmp
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
  min protocol = SMB2
  max protocol = SMB3
  include = /etc/samba/includes.conf
EOF

# homes.conf
cat << EOF > homes.conf.tmp
[homes]
comment = home directories
browseable = yes
read only = no
create mask = 0775
directory mask = 0775
hide dot files = yes
valid users = %S
EOF

# public.conf
cat << EOF > public.conf.tmp
[public]
comment = public anonymous access
path = ${DIR_SCHEMA}/public
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

# Create nas_basefolderlist-xtra
if [ ! -f ${TEMP_DIR}/nas_basefolderlist_extra ]; then
  touch ${TEMP_DIR}/nas_basefolderlist_extra
fi

#---- Body -------------------------------------------------------------------------

#---- Install and Configure Samba
section "Installing and configuring SMB (samba)"

# Check for SMB installation
if [ ! $(dpkg -s samba > /dev/null 2>&1; echo $?) == 0 ]; then
  msg "Installing SMB (be patient, may take a while)..."
  apt-get install -y samba-common-bin samba >/dev/null
fi

# Create Samba directory to store samba configuration files individually
mkdir -p ${SMB_CONF_DIR}

# Stopping SMB service
service smbd stop 2>/dev/null

# Create a backup of any existing smb.conf
mv ${SMB_CONF} /etc/samba/smb.conf.bak &> /dev/null

# Copy smb.conf files (global,homes,public)
msg "Creating default SMB folder shares ( global, homes, public )..."
cp ${TEMP_DIR}/smb.conf.tmp ${SMB_CONF}
cp ${TEMP_DIR}/homes.conf.tmp ${SMB_CONF_DIR}/homes.conf
cp ${TEMP_DIR}/public.conf.tmp ${SMB_CONF_DIR}/public.conf

# Create new Samba share list
cat nas_basefolderlist nas_basefolderlist_extra \
| sed '/^#/d' \
| sed '/^$/d' \
| awk '!seen[$0]++' \
| sed 's/65605:.\{3\}/@medialab/g' \
| sed 's/65606:.\{3\}/@homelab/g' \
| sed 's/65607:.\{3\}/@privatelab/g' \
| sed 's/\(,\)65608:.\{3\}//g' \
| sed '/homes/d;/public/d' \
> nas_basefolderlist-samba_dir

# Create new include conf files
msg "Creating new SMB folder shares..."
while IFS=',' read -r dir desc group permission user_groups; do
  # Check for dir
  if [ -d "${DIR_SCHEMA}/$dir" ]; then
    # Create a includes conf file
    printf "%b\n" "[$dir]" \
    "  comment = $desc" \
    "  path = ${DIR_SCHEMA}/${dir}" \
    "  browsable = yes" \
    "  read only = no" \
    "  create mask = 0775" \
    "  directory mask = 0775" \
    "  valid users = %S,$(echo "$user_groups")\n" > ${SMB_CONF_DIR}/${dir}.conf
    info "New SMB folder share: ${YELLOW}[${dir^}]${NC} ${DIR_SCHEMA}/${dir}"
  else
    info "${DIR_SCHEMA}/${dir} does not exist. Skipping..."
  fi
done < nas_basefolderlist-samba_dir
echo

# Populate includes.conf with files in smb.conf.d directory
ls "${SMB_CONF_DIR}"/* | sed -e 's/^/include = /' > $SMB_INCLUDES

# Restart Samba server
msg "Starting SMB service..."
service smbd start 2>/dev/null
systemctl is-active smbd >/dev/null 2>&1 && info "SMB server status: ${GREEN}active (running).${NC}" || info "SMB server status: ${RED}inactive (dead).${NC} Your intervention is required."
echo

#---- Finish Line ------------------------------------------------------------------