#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_ct_ubuntu_installer.sh
# Description:  This script is for creating a PVE Ubuntu based NAS
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#---- Source Github
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/main/pve_nas_installer.sh)"

#---- Source local Git
# /mnt/pve/nas-01-git/ahuacate/pve-nas/pve_nas_installer.sh

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Check SMTP Status
check_smtp_status

#---- Static Variables -------------------------------------------------------------

# Easy Script Section Head
SECTION_HEAD='PVE Ubuntu NAS'

# PVE host IP
PVE_HOST_IP=$(hostname -i)
PVE_HOSTNAME=$(hostname)

# SSHd Status (0 is enabled, 1 is disabled)
SSH_ENABLE=1

# Developer enable git mounts inside CT  (0 is enabled, 1 is disabled)
DEV_GIT_MOUNT_ENABLE=1

# Set file source (path/filename) of preset variables for 'pvesource_ct_createvm.sh'
PRESET_VAR_SRC="$( dirname "${BASH_SOURCE[0]}" )/$( basename "${BASH_SOURCE[0]}" )"

#---- Other Variables --------------------------------------------------------------

#---- Common Machine Variables
# VM Type ( 'ct' or 'vm' only lowercase )
#VM_TYPE='' Set at NAS type selection
# Use DHCP. '0' to disable, '1' to enable.
NET_DHCP='1'
#  Set address type 'dhcp4'/'dhcp6' or '0' to disable.
NET_DHCP_TYPE='dhcp4'
# CIDR IPv4
CIDR='24'
# CIDR IPv6
CIDR6='64'
# SSHd Port
SSH_PORT='22'

#----[COMMON_GENERAL_OPTIONS]
# Hostname
HOSTNAME='nas-01'
# Description for the Container (one word only, no spaces). Shown in the web-interface CT’s summary. 
DESCRIPTION=''
# Virtual OS/processor architecture.
ARCH='amd64'
# Allocated memory or RAM (MiB).
MEMORY='512'
# Limit number of CPU sockets to use.  Value 0 indicates no CPU limit.
CPULIMIT='0'
# CPU weight for a VM. Argument is used in the kernel fair scheduler. The larger the number is, the more CPU time this VM gets.
CPUUNITS='1024'
# The number of cores assigned to the vm/ct. Do not edit - its auto set.
CORES='1'

#----[COMMON_NET_OPTIONS]
# Bridge to attach the network device to.
BRIDGE='vmbr0'
# A common MAC address with the I/G (Individual/Group) bit not set. 
HWADDR=""
# Controls whether this interface’s firewall rules should be used.
FIREWALL='1'
# VLAN tag for this interface (value 0 for none, or VLAN[2-N] to enable).
TAG='0'
# VLAN ids to pass through the interface
TRUNKS=""
# Apply rate limiting to the interface (MB/s). Value "" for unlimited.
RATE=""
# MTU - Maximum transfer unit of the interface.
MTU=""

#----[COMMON_NET_DNS_OPTIONS]
# Nameserver server IP (IPv4 or IPv6) (value "" for none).
NAMESERVER='192.168.1.5'
# Search domain name (local domain)
SEARCHDOMAIN='local'

#----[COMMON_NET_STATIC_OPTIONS]
# IP address (IPv4). Only works with static IP (DHCP=0).
IP='192.168.1.10'
# IP address (IPv6). Only works with static IP (DHCP=0).
IP6=''
# Default gateway for traffic (IPv4). Only works with static IP (DHCP=0).
GW='192.168.1.5'
# Default gateway for traffic (IPv6). Only works with static IP (DHCP=0).
GW6=''

#---- PVE CT
#----[CT_GENERAL_OPTIONS]
# Unprivileged container status 
CT_UNPRIVILEGED='0'
# Memory swap
CT_SWAP='512'
# OS
CT_OSTYPE='ubuntu'
# Onboot startup
CT_ONBOOT='1'
# Timezone
CT_TIMEZONE='host'
# Root credentials
CT_PASSWORD='ahuacate'
# Virtual OS/processor architecture.
CT_ARCH='amd64'

#----[CT_FEATURES_OPTIONS]
# Allow using fuse file systems in a container.
CT_FUSE='0'
# For unprivileged containers only: Allow the use of the keyctl() system call.
CT_KEYCTL='0'
# Allow mounting file systems of specific types. (Use 'nfs' or 'cifs' or 'nfs;cifs' for both or leave empty "")
CT_MOUNT='nfs'
# Allow nesting. Best used with unprivileged containers with additional id mapping.
CT_NESTING='1'
# A public key for connecting to the root account over SSH (insert path).

#----[CT_ROOTFS_OPTIONS]
# Virtual Disk Size (GB).
CT_SIZE='5'
# Explicitly enable or disable ACL support.
CT_ACL='1'

#----[CT_STARTUP_OPTIONS]
# Startup and shutdown behavior ( '--startup order=1,up=1,down=1' ). Order is a non-negative number defining the general startup order. Up=1 means first to start up. Shutdown in done with reverse ordering so down=1 means last to shutdown.
CT_ORDER='1'
CT_UP='1'
CT_DOWN='1'

#----[CT_NET_OPTIONS]
# Name of the network device as seen from inside the VM/CT.
CT_NAME='eth0'
CT_TYPE='veth'

#----[CT_OTHER]
# OS Version
CT_OSVERSION='22.04'
# CTID numeric ID of the given container.
CTID='112'


#----[App_UID_GUID]
# App user
APP_USERNAME='root'
# App user group
APP_GRPNAME='root'

#----[REPO_PKG_NAME]
# Repo package name
REPO_PKG_NAME='pve-nas'

#---- Other Files ------------------------------------------------------------------

# Required PVESM Storage Mounts for CT ( new version )
unset pvesm_required_LIST
pvesm_required_LIST=()
while IFS= read -r line; do
  [[ "$line" =~ ^\#.*$ ]] && continue
  pvesm_required_LIST+=( "$line" )
done << EOF
# Example
# backup:CT settings backup storage
EOF

#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Introduction
source ${COMMON_PVE_SRC_DIR}/pvesource_ct_intro.sh

#---- Check SMTP status
if [ "${SMTP_STATUS}" == 0 ]; then
  # Options if SMTP is inactive
  display_msg='Before proceeding with this installer we RECOMMEND you first configure all PVE hosts to support SMTP email services. A working SMTP server emails the NAS System Administrator all new User login credentials, SSH keys, application specific login credentials and written guidelines. A PVE host SMTP server makes NAS administration much easier. Also be alerted about unwarranted login attempts and other system critical alerts. PVE Host SMTP Server installer is available in our PVE Host Toolbox located at GitHub:\n\n    --  https://github.com/ahuacate/pve-host'

  msg_box "#### PLEASE READ CAREFULLY ####\n\n$(echo ${display_msg})"
  echo
  msg "Select your options..."
  OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE00" )
  OPTIONS_LABELS_INPUT=( "Agree - Install PVE host SMTP email support" \
  "Decline - Proceed without SMTP email support" \
  "None. Exit this installer" )
  makeselect_input2
  singleselect SELECTED "$OPTIONS_STRING"

  if [ ${RESULTS} == 'TYPE01' ]; then
    # Exit and install SMTP
    msg "Go to our Github site and run our PVE Host Toolbox selecting our 'SMTP Email Setup' option:\n\n  --  https://github.com/ahuacate/pve-host\n\nRe-run the NAS installer after your have configured '$(hostname)' SMTP email support. Bye..."
    echo
    exit 0
  elif [ ${RESULTS} == 'TYPE02' ]; then
    # Proceed without SMTP email support
    msg "You have chosen to proceed without SMTP email support. You can always manually configure Postfix SMTP services at a later stage."
    echo
  elif [ ${RESULTS} == 'TYPE00' ]; then
    msg "You have chosen not to proceed. Aborting. Bye..."
    echo
    exit 0
  fi
fi


#---- Select NAS installation type
section "Select a NAS Solution"

msg_box "#### PLEASE READ CAREFULLY ####\n
The User can choose between a Proxmox OMV VM or a custom Ubuntu CT NAS solution. We RECOMMEND you read our Github installation before proceeding.

The User choices are:

1)  Ubuntu NAS (PCIe HBA SAS/SATA/NVMe) - PCIe HBA card pass-thru

Under development. Sorry.
The PVE host must be installed with a 'dedicated' PCIe HBA SAS/SATA/NVMe Card. All NAS disks (including any Cache SSds) must be connected to this PCIe HBA Card. You cannot co-mingle any OMV NAS disks with mainboard SATA/NVMe devices. All storage, both backend and fronted is fully managed by OMV NAS. You also have the option of configuring SSD cache using SSD drives inside OMV NAS. SSD cache will provide High Speed disk I/O.

2)  Ubuntu NAS (PVE LVM/ZFS/Basic) - PVE backend, Ubuntu frontend (including USB)

The storage backend is fully managed by Proxmox. A Ubuntu frontend provides file server SMB and NFS, User management, SSH, FTP and permissions. Choose between LVM, ZFS or a  basic single disk file system. LVM and ZFS Raid levels depends on the number of disks installed. You also have the option of configuring LVM and ZFS cache using SSD/NVMe drives. LVM and ZFS cache will provide High Speed disk I/O. An options exists to use a single USB disk."
echo
msg "Select the NAS type you want..."
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE00" )
OPTIONS_LABELS_INPUT=( "Ubuntu NAS (PCIe HBA SAS/SATA/NVMe) - PCIe HBA card pass-thru: Not available" \
"Ubuntu NAS (PVE LVM/ZFS/Basic) - PVE backend, Ubuntu frontend" \
"None. Exit this installer" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"
# Set installer type
TYPE=${RESULTS}

#---- Exit selection
if [ ${TYPE} == 'TYPE01' ]; then
  msg "Sorry. Your selected option is not available. Try again. Bye..."
  echo
  return
elif [ ${TYPE} == 'TYPE00' ]; then
  msg "You have chosen not to proceed. Aborting. Bye..."
  echo
  exit 0
fi


#---- Setup PVE CT or VM Variables
if [ ${TYPE} == TYPE01 ]; then
  # Ubuntu NAS (PCIe HBA SAS/SATA/NVMe)
  warn "Under development. Sorry." && exit 0
elif [ ${TYPE} == TYPE02 ]; then
  # VM Type ( 'ct' or 'vm' only lowercase )
  VM_TYPE='ct'
  # Ubuntu NAS (all)
  source ${COMMON_PVE_SRC_DIR}/pvesource_set_allvmvars.sh
fi


#---- Prepare disk storage
if [ ${TYPE} == TYPE01 ]; then
  # Ubuntu NAS (PCIe HBA SAS/SATA/NVMe)
  warn "Under development. Sorry." && exit 0
elif [ ${TYPE} == TYPE02 ]; then
  # Ubuntu NAS (PVE LVM/ZFS/Basic)
  source ${SHARED_DIR}/pve_nas_create_storagediskbuild.sh
fi


#---- Create OS CT or VM
if [ ${TYPE} == TYPE01 ]; then
  # Ubuntu NAS (PCIe HBA SAS/SATA/NVMe)
  warn "Under development. Sorry." && exit 0
elif [ ${TYPE} == TYPE02 ]; then
  # Ubuntu NAS (PVE LVM/ZFS/Basic)
  #---- Setup PVE CT Variables
  source ${COMMON_PVE_SRC_DIR}/pvesource_ct_createvm.sh

  #---- Pre-Configuring PVE CT
  # Create CT Bind Mounts
  source ${COMMON_PVE_SRC_DIR}/pvesource_ct_createbindmounts.sh

  # Create LXC Mount Points
  section "Create NAS CT mount point to host storage pool"

  # Add LXC mount points
  if [ -f pvesm_input_list ] && [ $(cat pvesm_input_list | wc -l) -ge 1 ]; then
    msg "Creating NAS CT mount points..."
    i=$(cat pvesm_input_list | wc -l)
    pct set $CTID -mp${i} ${PVE_SRC_MNT},mp=/srv/${HOSTNAME},acl=1 >/dev/null
    # pct set $CTID -mp${i} /${POOL}/${HOSTNAME},mp=/srv/${HOSTNAME},acl=1 >/dev/null
    info "CT $CTID mount point created: ${YELLOW}/srv/${HOSTNAME}${NC}"
    echo
  else
    pct set $CTID -mp0 ${PVE_SRC_MNT},mp=/srv/${HOSTNAME},acl=1 >/dev/null
    # pct set $CTID -mp0 /${POOL}/${HOSTNAME},mp=/srv/${HOSTNAME},acl=1 >/dev/null
    info "CT $CTID mount point created: ${YELLOW}/srv/${HOSTNAME}${NC}"
    echo
  fi

  #---- Configure New CT OS
  source ${COMMON_PVE_SRC_DIR}/pvesource_ct_ubuntubasics.sh
fi


#---- PVE NAS ----------------------------------------------------------------------

#---- PVE NAS build
if [ ${TYPE} == TYPE01 ] || [ ${TYPE} == TYPE02 ]; then
  # Set DIR Schema ( PVE host or CT mkdir )
  if [ $(uname -a | grep -Ei --color=never '.*pve*' &> /dev/null; echo $?) == 0 ]; then
    DIR_SCHEMA="${PVE_SRC_MNT}"
    # DIR_SCHEMA="/${POOL}/${HOSTNAME}"
  else
    # Select or input a storage path ( set DIR_SCHEMA )
    source ${COMMON_DIR}/nas/src/nas_identify_storagepath.sh
  fi

  #---- Create default base and sub folders
  source ${COMMON_DIR}/nas/src/nas_basefoldersetup.sh
  # Create temporary files of lists
  printf "%s\n" "${nas_subfolder_LIST[@]}" > nas_basefoldersubfolderlist
  printf '%s\n' "${nas_basefolder_LIST[@]}" > nas_basefolderlist
  printf '%s\n' "${nas_basefolder_extra_LIST[@]}" > nas_basefolderlist_extra

  #---- Configure PVE NAS Ubuntu CT 
  section "Configure PVE NAS Ubuntu CT"

  # Start container
  msg "Starting NAS CT..."
  pct_start_waitloop

  # Pushing variables to NAS CT
  msg "Pushing variables and conf to NAS CT..."
  printf "%b\n" '#!/usr/bin/env bash' \
  "POOL='${POOL}'" \
  "HOSTNAME='${HOSTNAME}'" \
  "SECTION_HEAD='${SECTION_HEAD}'" \
  "XTRA_SHARES='${XTRA_SHARES}'" \
  "SSH_PORT='${SSH_PORT}'" \
  "PVE_HOST_IP='${PVE_HOST_IP}'" \
  "DIR_SCHEMA='/srv/${HOSTNAME}'" \
  "GIT_REPO='${GIT_REPO}'" \
  "APP_NAME='${APP_NAME}'" \
  "PVE_HOSTNAME='${PVE_HOSTNAME}'" > ${TEMP_DIR}/pve_nas_ct_variables.sh
  pct push $CTID ${TEMP_DIR}/pve_nas_ct_variables.sh /tmp/pve_nas_ct_variables.sh -perms 755
  # Share folder lists
  pct push $CTID ${TEMP_DIR}/nas_basefolderlist /tmp/nas_basefolderlist
  pct push $CTID ${TEMP_DIR}/nas_basefoldersubfolderlist /tmp/nas_basefoldersubfolderlist
  pct push $CTID ${TEMP_DIR}/nas_basefolderlist_extra /tmp/nas_basefolderlist_extra

  # Pushing PVE-nas setup scripts to NAS CT
  msg "Pushing NAS configuration scripts to NAS CT..."
  pct push $CTID /tmp/${GIT_REPO}.tar.gz /tmp/${GIT_REPO}.tar.gz
  pct exec $CTID -- tar -zxf /tmp/${GIT_REPO}.tar.gz -C /tmp
  echo

  #---- Start NAS setup script
  pct exec $CTID -- bash -c "/tmp/pve-nas/src/ubuntu/pve-nas_sw.sh"

  #---- Install and Configure Fail2ban
  pct exec $CTID -- bash -c "export SSH_PORT=\$(grep Port /etc/ssh/sshd_config | sed '/^#/d' | awk '{ print \$2 }') && /tmp/pve-nas/common/pve/src/pvesource_ct_ubuntu_installfail2ban.sh"

  #---- Install and Configure SSMTP Email Alerts
  source ${COMMON_PVE_SRC_DIR}/pvesource_install_postfix_client.sh
fi

#---- Finish Line ------------------------------------------------------------------
if [ ${TYPE} == 'TYPE01' ] || [ ${TYPE} == 'TYPE02' ]; then
  section "Completion Status"

  # Get port
  port=10000
  # Interface
  interface=$(pct exec $CTID -- ip route ls | grep default | grep -Po '(?<=dev )(\S+)')
  # Get IP type
  if [[ $(pct exec $CTID -- ip addr show ${interface} | grep -q dynamic > /dev/null; echo $?) == 0 ]]; then # ip -4 addr show eth0 
      ip_type='dhcp - best use dhcp IP reservation'
  else
      ip_type='static IP'
  fi

  #---- Set display text
  # Webmin access URL
  display_msg1=( "https://$(pct exec $CTID -- hostname).$(pct exec $CTID -- hostname -d):${port}/" )
  display_msg1+=( "https://$(pct exec $CTID -- hostname -I | sed -r 's/\s+//g'):${port}/ (${ip_type})" )
  # Check Fail2ban Status
  if [ $(pct exec $CTID -- dpkg -s fail2ban >/dev/null 2>&1; echo $?) == 0 ]; then
    display_msg2=( "Fail2ban SW:installed" )
  else
    display_msg2=( "Fail2ban SW:not installed" )
  fi
  # Check SMTP Mailserver Status
  if [ "$(pct exec $CTID -- bash -c 'if [ -f /etc/postfix/main.cf ]; then grep --color=never -Po "^ahuacate_smtp=\K.*" "/etc/postfix/main.cf" || true; else echo 0; fi')" == '1' ]; then
    display_msg2+=( "SMTP Mail Server:installed" )
  else
    display_msg2+=( "SMTP Mail Server:not installed ( recommended install )" )
  fi
  # Check ProFTPd Status
  if [ "$(pct exec $CTID -- dpkg -s proftpd-core >/dev/null 2>&1; echo $?)" == '0' ]; then
    display_msg2+=( "ProFTPd Server:installed" )
  else
    display_msg2+=( "ProFTPd Server:not installed" )
  fi
  # Upgrade NAS
  display_msg2+=( "Upgrade NAS OS:OS updates, releases, software packages and patches" )
  # Add ZFS Cache
  display_msg2+=( "Add ZFS Cache:ARC/L2ARC cache and ZIL log using SSD/NVMe" )
  # User Management
  display_msg3=( "Power User Accounts:For all privatelab, homelab or medialab accounts" )
  display_msg3+=( "Jailed User Accounts:For all jailed and restricted user accounts" )
  # File server login
  x='\\\\'
  display_msg4=( "$x${HOSTNAME}.$(hostname -d)\:" )
  display_msg4+=( "$x$(pct exec $CTID -- hostname -I | sed -r 's/\s+//g')\: (${ip_type})" )

  # Display msg
  msg_box "${HOSTNAME^^} installation was a success.\n\nTo manage your new Ubuntu NAS use Webmin (a Linux web management tool). Webmin login credentials are user 'root' and password '${CT_PASSWORD}'. You can change your 'root' password using the Webmin WebGUI.\n\n$(printf '%s\n' "${display_msg1[@]}" | indent2)\n\nUse our 'Easy Script Toolbox' to install add-ons and perform other tasks. More information is available here: https://github.com/ahuacate/pve-nas\n\n$(printf '%s\n' "${display_msg2[@]}" | column -s ":" -t -N "APPLICATION,STATUS" | indent2)\n\nAlso use our 'Easy Scripts Toolbox' to create or delete NAS user accounts.\n\n$(printf '%s\n' "${display_msg3[@]}" | column -s ":" -t -N "USER ACCOUNT TYPE,DESCRIPTION" | indent2)\n\nTo access ${HOSTNAME^^} files use SMB.\n\n$(printf '%s\n' "${display_msg4[@]}" | column -s ":" -t -N "SMB NETWORK ADDRESS" | indent2)\n\nNFSv4 is enabled and ready for creating PVE host storage mounts.\n\n${HOSTNAME^^} will now reboot."
fi
#-----------------------------------------------------------------------------------