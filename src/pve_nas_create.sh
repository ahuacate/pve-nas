#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_ct_create.sh
# Description:  This script is for creating a PVE based NAS
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/master/src/pve_nas_create.sh)"

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_DIR="${DIR}/../common"
COMMON_PVE_SRC="${DIR}/../common/pve/src"
SHARED_DIR="${DIR}/../shared"

#---- Dependencies -----------------------------------------------------------------

# Check for Internet connectivity
if nc -zw1 google.com 443; then
  echo
else
  echo "Checking for internet connectivity..."
  echo -e "Internet connectivity status: \033[0;31mDown\033[0m\n\nCannot proceed without a internet connection.\nFix your PVE hosts internet connection and try again..."
  echo
  exit 0
fi

# Run Bash Header
source ${COMMON_PVE_SRC}/pvesource_bash_defaults.sh

#---- Static Variables -------------------------------------------------------------

# Easy Script Section Head
SECTION_HEAD='PVE NAS'

# PVE host IP
PVE_HOST_IP=$(hostname -i)
PVE_HOSTNAME=$(hostname)

# SSHd Status (0 is enabled, 1 is disabled)
SSH_ENABLE=0

# Developer enable git mounts inside CT (0 is enabled, 1 is disabled)
DEV_GIT_MOUNT_ENABLE=1

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
CT_OSVERSION='21.04'
# CTID numeric ID of the given container.
CTID='112'


#---- Repo variables
# Git server
GIT_SERVER='https://github.com'
# Git user
GIT_USER='ahuacate'
# Git repository
GIT_REPO='pve-nas'
# Git branch
GIT_BRANCH='master'
# Git common
GIT_COMMON='0'

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

# Required Temporary Files
# touch zpool_harddisk_disklist zpool_ssd_disklist

#---- Functions --------------------------------------------------------------------

# # PCT list
# function pct_list() {
#   pct list | perl -lne '
#   if ($. == 1) {
#       @head = ( /(\S+\s*)/g );
#       pop @head;
#       $patt = "^";
#       $patt .= "(.{" . length($_) . "})" for @head;
#       $patt .= "(.*)\$";
#   }
#   print join ",", map {s/"/""/g; s/\s+$//; qq($_)} (/$patt/o);'
# }

#---- Body -------------------------------------------------------------------------

#---- Introduction
source ${COMMON_PVE_SRC}/pvesource_ct_intro.sh

#---- Select NAS installation type
section "Select a NAS Solution"

msg_box "#### PLEASE READ CAREFULLY ####\n
The User can choose between a Proxmox OMV VM or a custom Ubuntu CT NAS solution. We RECOMMEND you read our Github installation before proceeding.

The User choices are:

1)  OMV NAS (PCIe SATA/NVMe) - PCIe SATA/NVMe Card pass-thru

The PVE host must be installed with a 'dedicated' PCIe HBA SATA/NVMe Card. All NAS disks (including any ZFS Cache SSds) must be connected to this PCIe SATA/NVMe HBA Card. You cannot co-mingle any OMV NAS disks with mainboard SATA/NVMe devices. All storage, both backend and fronted is fully managed by OMV NAS. You also have the option of configuring SSD cache using SSD drives inside OMV NAS. SSD cache will provide High Speed disk I/O.

2)  Ubuntu NAS (PVE SATA/NVMe) - PVE ZFS pool backend, Ubuntu frontend

The NAS ZFS storage pool backend is fully managed by Proxmox. ZFS Raid levels depends on the number of disks installed. You also have the option of configuring ZFS cache using SSD drives. ZFS cache will provide High Speed disk I/O.

3)  Ubuntu NAS (USB disks) - PVE USB disk backend, Ubuntu frontend

A USB based NAS is fixed to a single external disk only for SFF computing hardware like Intel NUCs. Your NAS ZFS storage pool backend is fully managed by Proxmox."
echo
msg "Select the NAS type you want..."
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" "TYPE04" )
OPTIONS_LABELS_INPUT=( "OpenMediaVault (PCIe SATA/NVMe) - PCIe SATA/NVMe Card pass-thru" \
"Ubuntu NAS (PVE SATA/NVMe) - PVE ZFS pool backend, Ubuntu frontend" \
"Ubuntu NAS (USB disks) - PVE USB disk backend, Ubuntu frontend" \
"None. Exit this installer" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"
# Set installer type
TYPE=${RESULTS}


#---- Setup PVE CT or VM Variables
if [ ${TYPE} == TYPE01 ]; then
  # OMV NAS (PCIe SATA/NVMe)
  warn "Under development. Sorry." && exit 0
elif [ ${TYPE} == TYPE02 ] || [ ${TYPE} == TYPE03 ]; then
  # VM Type ( 'ct' or 'vm' only lowercase )
  VM_TYPE='ct'
  # Ubuntu NAS (PVE SATA/NVMe)
  source ${COMMON_PVE_SRC}/pvesource_set_allvmvars.sh
fi


#---- Prepare disk storage
if [ ${TYPE} == TYPE01 ]; then
  # OMV NAS (PCIe SATA/NVMe)
  warn "Under development. Sorry." && exit 0
elif [ ${TYPE} == TYPE02 ]; then
  # Ubuntu NAS (PVE SATA/NVMe)
  source ${SHARED_DIR}/pve_nas_create_internaldiskbuild.sh
elif [ ${TYPE} == TYPE03 ]; then
  # Ubuntu NAS (USB disks)
  source ${SHARED_DIR}/pve_nas_create_usbdiskbuild.sh
fi


#---- Create OS CT or VM
if [ ${TYPE} == TYPE01 ]; then
  # OMV NAS (PCIe SATA/NVMe)
  warn "Under development. Sorry." && exit 0
elif [ ${TYPE} == TYPE02 ] || [ ${TYPE} == TYPE03 ]; then
  #---- Setup PVE CT Variables
  source ${COMMON_PVE_SRC}/pvesource_ct_createvm.sh

  #---- Pre-Configuring PVE CT
  # Create CT Bind Mounts
  source ${COMMON_PVE_SRC}/pvesource_ct_createbindmounts.sh

  # Create LXC Mount Points
  section "Create NAS CT mount point to ZPool"

  # Add LXC mount points
  if [ -f pvesm_input_list ] && [ $(cat pvesm_input_list | wc -l) -ge 1 ]; then
    msg "Creating NAS CT mount points..."
    i=$(cat pvesm_input_list | wc -l)
    pct set $CTID -mp${i} /${POOL}/${HOSTNAME},mp=/srv/${HOSTNAME},acl=1 >/dev/null
    info "CT $CTID mount point created: ${YELLOW}/srv/${HOSTNAME}${NC}"
    echo
  else
    pct set $CTID -mp0 /${POOL}/${HOSTNAME},mp=/srv/${HOSTNAME},acl=1 >/dev/null
    info "CT $CTID mount point created: ${YELLOW}/srv/${HOSTNAME}${NC}"
    echo
  fi

  #---- Configure New CT OS
  source ${COMMON_PVE_SRC}/pvesource_ct_ubuntubasics.sh
fi

#---- Build PVE CT
if [ ${TYPE} == TYPE02 ] || [ ${TYPE} == TYPE03 ]; then
  #---- Create default base and sub folders
  source ${SHARED_DIR}/nas_basefoldersetup.sh
  # Create temporary files of lists
  printf "%s\n" "${nas_subfolder_LIST[@]}" > nas_basefoldersubfolderlist
  printf '%s\n' "${nas_basefolder_LIST[@]}" > nas_basefolderlist
  printf '%s\n' "${nas_basefolder_extra_LIST[@]}" > nas_basefolderlist_extra

  #---- Configure PVE NAS Ubuntu CT 
  section "Configure PVE NAS Ubuntu CT."

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
  # pct exec $CTID -- bash -c "/tmp/pve_nas_ct_variables.sh && /tmp/pve-nas/src/ubuntu/pve_nas_ct_setup.sh"
  pct exec $CTID -- bash -c "/tmp/pve-nas/src/ubuntu/pve_nas_ct_setup.sh"

  #---- Install and Configure Fail2ban
  pct exec $CTID -- bash -c "export SSH_PORT=\$(grep Port /etc/ssh/sshd_config | sed '/^#/d' | awk '{ print \$2 }') && /tmp/pve-nas/common/pve/src/pvesource_ct_ubuntu_installfail2ban.sh"

  #---- Install and Configure SSMTP Email Alerts
  pct exec $CTID -- bash -c "/tmp/pve-nas/common/pve/src/pvesource_ct_ubuntu_installssmtp.sh"

  #---- Install and Configure ProFTPd server
  # pct exec $CTID -- bash -c "cp /tmp/pve-nas/src/ubuntu/proftpd_settings/sftp.conf /tmp/pve-nas/common/pve/src/ && /tmp/pve-nas/common/pve/src/pvesource_ct_ubuntu_installproftpd.sh"
    # pct exec $CTID -- bash -c "/tmp/pve-nas/common/pve/src/pvesource_ct_ubuntu_installproftpd.sh && /tmp/pve-nas/src/ubuntu/proftpd_settings/pve_nas_ct_proftpdsettings.sh"
  pct exec $CTID -- bash -c "/tmp/pve-nas/common/pve/src/pvesource_ct_ubuntu_installproftpd.sh"

  #---- Create New Power User Accounts
  pct exec $CTID -- bash -c "/tmp/pve-nas/src/ubuntu/pve_nas_ct_addpoweruser.sh"

  #---- Create New Power User Accounts
  pct exec $CTID -- bash -c "/tmp/pve-nas/src/ubuntu/pve_nas_ct_addjailuser.sh"
fi

#---- Finish Line ------------------------------------------------------------------
if [ ${TYPE} == 'TYPE02' ] || [ ${TYPE} == 'TYPE03' ]; then
  section "Completion Status."

  #---- Set display text
  unset display_msg1
  unset display_msg2
  unset display_msg3
  unset display_msg4
  # Webmin access URL
  if [ -n "${IP}" ] && [ ! ${IP} == 'dhcp' ]; then
    display_msg1+=( "https://${IP}:10000/" )
  elif [ -n "${IP6}" ] && [ ! ${IP6} == 'dhcp' ]; then
    display_msg1+=( "https://${IP6}:10000/" )
  fi
  display_msg1+=( "https://${HOSTNAME}.$(hostname -d):10000/" )

  # Check Fail2ban Status
  if [ $(pct exec $CTID -- dpkg -s fail2ban >/dev/null 2>&1; echo $?) == 0 ]; then
    display_msg2+=( "Fail2ban SW:installed" )
  else
    display_msg2+=( "Fail2ban SW:not installed" )
  fi
  # Check SSMTP Mailserver Status
  if [ $(pct exec $CTID -- dpkg -s ssmtp >/dev/null 2>&1; echo $?) == 0 ]; then
    display_msg2+=( "SSMTP Mail Server:installed" )
  else
    display_msg2+=( "SSMTP Mail Server:not installed" )
  fi
  # Check ProFTPd Status
  if [ $(pct exec $CTID -- dpkg -s proftpd-core >/dev/null 2>&1; echo $?) == 0 ]; then
    display_msg2+=( "ProFTPd Server:installed" )
  else
    display_msg2+=( "ProFTPd Server:not installed" )
  fi
  # Upgrade NAS
  display_msg2+=( "Upgrade NAS OS:OS updates, releases, software packages and patches" )

  # User Management
  display_msg3+=( "Power User Accounts:For all privatelab, homelab or medialab accounts" )
  display_msg3+=( "Jailed User Accounts:For all jailed and restricted user accounts" )

  # File server login
  x='\\\\'
  if [ -n "${IP}" ] && [ ! ${IP} == 'dhcp' ]; then
    display_msg4+=( "$x${IP}\:" )
  elif [ -n "${IP6}" ] && [ ! ${IP6} == 'dhcp' ]; then
    display_msg4+=( "$x${IP6}\:" )
  fi
  display_msg4+=( "$x${HOSTNAME}.$(hostname -d)\:" )

  msg_box "${HOSTNAME^^} installation was a success. To manage your new Ubuntu NAS use Webmin (a Linux web management tool). Webmin login credentials are user 'root' and password '${CT_PASSWORD}'. You can change your 'root' password using the Webmin webGUI.\n\n$(printf '%s\n' "${display_msg1[@]}" | indent2)\n\nUse our 'Easy Scripts' toolbox to install add-ons and perform other tasks. More information is available here: https://github.com/ahuacate/pve-nas\n\n$(printf '%s\n' "${display_msg2[@]}" | column -s ":" -t -N "APPLICATION,STATUS" | indent2)\n\nAlso use our 'Easy Scripts' toolbox to create or delete NAS user accounts.\n\n$(printf '%s\n' "${display_msg3[@]}" | column -s ":" -t -N "ACCOUNT TYPE,DESCRIPTION" | indent2)\n\nTo access ${HOSTNAME^^} files use SMB ( Samba ).\n\n$(printf '%s\n' "${display_msg4[@]}" | column -s ":" -t -N "SMB NETWORK ADDRESS" | indent2)\n\n${HOSTNAME^^} will now reboot. NFSv4 is enabled and ready for your PVE hosts."
fi

# Cleanup
pct exec $CTID -- bash -c "rm -R /tmp/pve-nas &> /dev/null; rm /tmp/pve-nas.tar.gz &> /dev/null"
pct reboot $CTID
rm -R /tmp/pve-nas &> /dev/null
rm /tmp/pve-nas.tar.gz &> /dev/null

trap cleanup EXIT