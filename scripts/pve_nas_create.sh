#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_ct_create.sh
# Description:  This script is for creating a PVE based NAS
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/master/scripts/pve_nas_create.sh)"

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SOURCE="${DIR}/../../common/pve/source"

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
source ${COMMON_PVE_SOURCE}/pvesource_bash_defaults.sh

# PCT list
function pct_list() {
  pct list | perl -lne '
  if ($. == 1) {
      @head = ( /(\S+\s*)/g );
      pop @head;
      $patt = "^";
      $patt .= "(.{" . length($_) . "})" for @head;
      $patt .= "(.*)\$";
  }
  print join ",", map {s/"/""/g; s/\s+$//; qq($_)} (/$patt/o);'
}

#---- Static Variables -------------------------------------------------------------

# Set Max CT Host CPU Cores 
HOST_CPU_CORES=$(( $(lscpu | grep -oP '^Socket.*:\s*\K.+') * ($(lscpu | grep -oP '^Core.*:\s*\K.+') * $(lscpu | grep -oP '^Thread.*:\s*\K.+')) ))
if [ ${HOST_CPU_CORES} -gt 4 ]; then 
  CT_CPU_CORES_VAR=$(( ${HOST_CPU_CORES} / 2 ))
elif [ ${HOST_CPU_CORES} -le 4 ]; then
  CT_CPU_CORES_VAR=2
fi

# PVE host IP
PVE_HOST_IP=$(hostname -i)
PVE_HOST_NAME=$(hostname)

# SSHd Status (0 is enabled, 1 is disabled)
SSH_ENABLE=0

# Developer enable git mounts inside CT (0 is enabled, 1 is disabled)
DEV_GIT_MOUNT_ENABLE=1

#---- Other Variables --------------------------------------------------------------

#---- CT Ubuntu NAS
# Container Hostname
CT_HOSTNAME_VAR='nas-04'
# Container IP Address (192.168.1.10)
CT_IP_VAR='192.168.1.10'
# CT IP Subnet
CT_IP_SUBNET='24'
# Container Network Gateway
CT_GW_VAR='192.168.1.5'
# DNS Server
CT_DNS_SERVER_VAR='192.168.1.5'
# Container Number
CTID_VAR='110'
# Container VLAN
CT_TAG_VAR='0'
# Container Virtual Disk Size (GB)
CT_DISK_SIZE_VAR='5'
# Container allocated RAM
CT_RAM_VAR='512'
# Easy Script Section Header Body Text
SECTION_HEAD='PVE NAS'
#---- Do Not Edit
# Container Swap
CT_SWAP="$(( $CT_RAM_VAR / 2 ))"
# CT CPU Cores
CT_CPU_CORES="$CT_CPU_CORES_VAR"
# CT unprivileged status
CT_UNPRIVILEGED='0'
# Features ( 0 means none )
CT_FUSE='0'
CT_KEYCTL='0'
CT_MOUNT='nfs'
CT_NESTING='1'
# Container Root Password ( 0 means none )
CT_PASSWORD='ahuacate'
# Startup Order
CT_STARTUP='1'
# PVE Container OS
OSTYPE='ubuntu'
OSVERSION='21.04'

# CT SSH Port
SSH_PORT_VAR='22' # Best not use default port 22


# #---- VM TrueNAS
# # VM Hostname
# VM_HOSTNAME=${CT_HOSTNAME}
# # VM Network Configuration
# VM_NET_BRIDGE='vmbr0'
# VM_NET_MODEL='virtio'
# VM_NET_MAC_ADDRESS='auto' # Leave as auto unless input valid mac address
# VM_NET_FIREWALL='1'
# # VM IP Address (192.168.1.10)
# VM_IP=${CT_IP}
# # VM IP Subnet
# VM_IP_SUBNET=${CT_IP_SUBNET}
# # VM Network Gateway
# VM_GW=${CT_GW}
# # DNS Server
# VM_DNS_SERVER=${CT_DNS_SERVER}
# # VM VLAN
# VM_TAG=${CT_TAG}
# # VM ID Number
# VMID=${CTID}
# # VM Virtual Disk Size (GB)
# VM_DISK_SIZE=${CT_DISK_SIZE}
# # VM allocated RAM
# VM_RAM='1024'
# # VM balloon RAM
# VM_RAM_BALLOON='512'
# #---- Do Not Edit
# # Guest OS
# VM_OS_TYPE='126'
# # VM CPU
# VM_CPU_UNITS='1024' # Default '1024'
# VM_CPU_SOCKETS='1' # Default '1'
# VM_CPU_CORES='1' # Default '1'
# VM_CPU_LIMIT='0' # Default '0'
# VM_VCPU='1' # Default '1'
# # Startup Order
# VM_AUTOSTART='1'
# VM_ONBOOT='1'
# VM_STARTUP_ORDER='1'
# VM_STARTUP_DELAY='30' # Delay in seconds
# # Start VM after it was created successfully.
# VM_START='0' # Default '0' (1 for start)
# # VM SSH Port
# SSH_PORT_VAR='22' # Best not use default port 22
# # Latest TrueNAS ISO
# for VM_ISO in $(curl -s https://download.freenas.org/latest/x64/ |
#   grep href |
#   sed 's/.*href="//' |
#   sed 's/".*//' |
#   grep '^[a-zA-Z].*' |
#   grep -i 'TrueNAS.*\.iso$'); do
#   SRC_ISO_URL="https://download.freenas.org/latest/x64/${VM_ISO}"
# done
# SRC_ISO_URL="https://download.freenas.org/latest/x64/${VM_ISO}"
# # PVE VM OS
# VM_OSVERSION="$(echo ${VM_ISO} | sed 's/^[^-]*-//g' | sed 's/\.[^.]*$//')"



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

# Required PVESM Storage Mounts for CT
cat << 'EOF' > pvesm_required_list
EOF
# cat << 'EOF' > pvesm_required_list
# none|Ignore this share
# EOF

# Required Temporary Files
touch zpool_harddisk_disklist zpool_ssd_disklist

#---- Body -------------------------------------------------------------------------

#---- Introduction
source ${COMMON_PVE_SOURCE}/pvesource_ct_intro.sh

#---- Select NAS installation type
section "Select a NAS Solution"

msg_box "#### PLEASE READ CAREFULLY ####\n
The User can choose between a Proxmox TrueNAS VM or a custom Ubuntu CT NAS solution. We RECOMMEND you read our Github installation before proceeding.

The User choices are:

1)  TrueNAS (PCIe SATA/NVMe) - PCIe SATA/NVMe Card pass-thru (Recommended)

The PVE host must be installed with a 'dedicated' PCIe SATA/NVMe Card. All NAS disks (including any ZFS Cache SSds) must be connected to this PCIe SATA/NVMe Card. You cannot co-mingle any TrueNAS disks with mainboard SATA/NVMe devices. The ZFS storage pool backend and fronted is fully managed by TrueNAS. ZFS Raid levels are determined by the number of disks are installed. You also have the option of configuring ZFS cache using SSD drives inside TrueNAS. ZFS cache will provide High Speed disk I/O.

2)  Ubuntu NAS (PVE SATA/NVMe) - PVE ZFS pool backend, Ubuntu frontend

The NAS ZFS storage pool backend is fully managed by Proxmox. ZFS Raid levels depends on the number of disks installed. You also have the option of configuring ZFS cache using SSD drives. ZFS cache will provide High Speed disk I/O.

3)  Ubuntu NAS (USB disks) - PVE USB disk backend, Ubuntu frontend

A USB based NAS provides basic NAS file storage using a single external disk only. This solution is for SFF computing hardware like Intel NUCs. Your NAS ZFS storage pool backend is fully managed by Proxmox."
echo
# Select installation type
TYPE01="${YELLOW}TrueNAS (PCIe SATA/NVMe)${NC} - PCIe SATA/NVMe Card pass-thru (Recommended)"
TYPE02="${YELLOW}Ubuntu NAS (PVE SATA/NVMe)${NC} - PVE ZFS pool backend, Ubuntu frontend"
TYPE03="${YELLOW}Ubuntu NAS (USB disks)${NC} - PVE USB disk backend, Ubuntu frontend"
TYPE04="${YELLOW}None${NC} - exit this installation."
PS3="Select the installation type you want (entering numeric) : "
msg "Your available options are:"
options=("$TYPE01" "$TYPE02" "$TYPE03" "$TYPE04")
select menu in "${options[@]}"; do
  case $menu in
    "$TYPE01")
      NAS_TYPE=1
      info "PVE NAS installation type: ${YELLOW}TrueNAS (PCIe SATA/NVMe Card pass-thru)${NC}"
      echo
      break
      ;;
    "$TYPE02")
      NAS_TYPE=2
      info "PVE NAS installation type: ${YELLOW}Ubuntu NAS (PVE SATA/NVMe)${NC}"
      echo
      break
      ;;
    "$TYPE03")
      NAS_TYPE=3
      info "PVE NAS installation type: ${YELLOW}Ubuntu NAS (USB disks)${NC}"
      echo
      break
      ;;
    "$TYPE04")
      msg "You have chosen to stop this installation. Exiting installation script in 3 seconds..."
      echo
      sleep 2
      exit 0
      ;;
    *) warn "Invalid entry. Try again.." >&2
  esac
done


#---- Setup PVE CT or VM Variables
if [ ${NAS_TYPE} = 1 ]; then
  # TrueNAS (PCIe SATA/NVMe)
  warn "Under development. Sorry." && exit 0
elif [ ${NAS_TYPE} = 2 ] || [ ${NAS_TYPE} = 3 ]; then
  # Ubuntu NAS (PVE SATA/NVMe)
  source ${COMMON_PVE_SOURCE}/pvesource_ct_setvmvars.sh
fi


#---- Prepare disk storage
if [ ${NAS_TYPE} = 1 ]; then
  # TrueNAS (PCIe SATA/NVMe)
  warn "Under development. Sorry." && exit 0
elif [ ${NAS_TYPE} = 2 ]; then
  # Ubuntu NAS (PVE SATA/NVMe)
  source ${DIR}/source/pve_nas_create_internaldiskbuild.sh
elif [ ${NAS_TYPE} = 3 ]; then
  # Ubuntu NAS (USB disks)
  source ${DIR}/source/pve_nas_create_usbdiskbuild.sh
fi


#---- Create OS CT or VM
if [ ${NAS_TYPE} = 1 ]; then
  # TrueNAS (PCIe SATA/NVMe)
  warn "Under development. Sorry." && exit 0
elif [ ${NAS_TYPE} = 2 ] || [ ${NAS_TYPE} = 3 ]; then
  #---- Setup PVE CT Variables
  source ${COMMON_PVE_SOURCE}/pvesource_ct_createvm.sh

  #---- Pre-Configuring PVE CT
  # Create CT Bind Mounts
  source ${COMMON_PVE_SOURCE}/pvesource_ct_createbindmounts.sh

  # Create LXC Mount Points
  section "Create NAS CT mount point to Zpool."

  # Add LXC mount points
  if [ -f pvesm_input_list ] && [ $(cat pvesm_input_list | wc -l) -ge 1 ]; then
    msg "Creating NAS CT mount points..."
    i=$(cat pvesm_input_list | wc -l)
    pct set $CTID -mp${i} /${POOL}/${CT_HOSTNAME},mp=/srv/${CT_HOSTNAME},acl=1 >/dev/null
    info "CT $CTID mount point created: ${YELLOW}/srv/${CT_HOSTNAME}${NC}"
    echo
  else
    pct set $CTID -mp0 /${POOL}/${CT_HOSTNAME},mp=/srv/${CT_HOSTNAME},acl=1 >/dev/null
    info "CT $CTID mount point created: ${YELLOW}/srv/${CT_HOSTNAME}${NC}"
    echo
  fi

  #---- Option to create USB pass through
  source ${COMMON_PVE_SOURCE}/pvesource_ct_usbpassthru.sh

  #---- Configure New CT OS
  source ${COMMON_PVE_SOURCE}/pvesource_ct_ubuntubasics.sh
fi

#---- Build PVE CT
if [ ${NAS_TYPE} = 2 ] || [ ${NAS_TYPE} = 3 ]; then
  #---- Create base folders
  source ${DIR}/source/pve_nas_basefoldersetup.sh

  #---- Configure PVE NAS Ubuntu CT 
  section "Configure PVE NAS Ubuntu CT."

  # Start container
  msg "Starting NAS CT..."
  pct_start_waitloop

  # Pushing variables to NAS CT
  msg "Pushing variables and conf to NAS CT..."
  printf "%b\n" '#!/usr/bin/env bash' \
  "POOL='${POOL}'" \
  "CT_HOSTNAME='${CT_HOSTNAME}'" \
  "SECTION_HEAD='${SECTION_HEAD}'" \
  "XTRA_SHARES='${XTRA_SHARES}'" \
  "SSH_PORT='${SSH_PORT}'" \
  "PVE_HOST_IP='${PVE_HOST_IP}'" \
  "PVE_HOST_NAME='${PVE_HOST_NAME}'" > ${TEMP_DIR}/pve_nas_ct_variables.sh
  pct push $CTID ${TEMP_DIR}/pve_nas_ct_variables.sh /tmp/pve_nas_ct_variables.sh -perms 755
  # Share folder lists
  pct push $CTID ${TEMP_DIR}/pve_nas_basefolderlist /tmp/pve_nas_basefolderlist
  pct push $CTID ${TEMP_DIR}/pve_nas_basefoldersubfolderlist /tmp/pve_nas_basefoldersubfolderlist
  pct push $CTID ${TEMP_DIR}/pve_nas_basefolderlist-xtra /tmp/pve_nas_basefolderlist-xtra

  # Pushing PVE common setup scripts to NAS CT
  msg "Pushing common scripts to NAS CT..."
  pct push $CTID /tmp/common.tar.gz /tmp/common.tar.gz
  pct exec $CTID -- tar -zxf /tmp/common.tar.gz -C /tmp

  # Pushing PVE-nas setup scripts to NAS CT
  msg "Pushing NAS configuration scripts to NAS CT..."
  pct push $CTID /tmp/${GIT_REPO}.tar.gz /tmp/${GIT_REPO}.tar.gz
  pct exec $CTID -- tar -zxf /tmp/${GIT_REPO}.tar.gz -C /tmp
  echo

  #---- Start NAS setup script
  # pct exec $CTID -- bash -c "/tmp/pve_nas_ct_variables.sh && /tmp/pve-nas/scripts/source/ubuntu/pve_nas_ct_setup.sh"
  pct exec $CTID -- bash -c "/tmp/pve-nas/scripts/source/ubuntu/pve_nas_ct_setup.sh"

  #---- Install and Configure Fail2ban
  pct exec $CTID -- bash -c "export SSH_PORT=\$(grep Port /etc/ssh/sshd_config | sed '/^#/d' | awk '{ print \$2 }') && /tmp/common/pve/source/pvesource_ct_ubuntu_installfail2ban.sh"

  #---- Install and Configure SSMTP Email Alerts
  pct exec $CTID -- bash -c "/tmp/common/pve/source/pvesource_ct_ubuntu_installssmtp.sh"

  #---- Install and Configure ProFTPd server
  # pct exec $CTID -- bash -c "cp /tmp/pve-nas/scripts/source/ubuntu/proftpd_settings/sftp.conf /tmp/common/pve/source/ && /tmp/common/pve/source/pvesource_ct_ubuntu_installproftpd.sh"
  pct exec $CTID -- bash -c "/tmp/common/pve/source/pvesource_ct_ubuntu_installproftpd.sh && /tmp/pve-nas/scripts/source/ubuntu/proftpd_settings/pve_nas_ct_proftpdsettings.sh"

  #---- Create New Power User Accounts
  pct exec $CTID -- bash -c "/tmp/pve-nas/scripts/source/ubuntu/pve_nas_ct_addpoweruser.sh"

  #---- Create New Power User Accounts
  pct exec $CTID -- bash -c "/tmp/pve-nas/scripts/source/ubuntu/pve_nas_ct_addjailuser.sh"
fi

#---- Finish Line ------------------------------------------------------------------
if [ ${NAS_TYPE} = 2 ] || [ ${NAS_TYPE} = 3 ]; then
  section "Completion Status."

  msg "${CT_HOSTNAME^^} installation was a success. To manage your new Ubuntu NAS use Webmin (a Linux web management tool). Webmin login credentials are user 'root' and password '${CT_PASSWORD}'. You can change your 'root' password using the Webmin webGUI.\n\n  --  ${WHITE}https://$(echo "$CT_IP" | sed  's/\/.*//g'):10000/${NC}\n  --  ${WHITE}https://${CT_HOSTNAME}:10000/${NC}\n\nUse our Ubuntu NAS management 'Easy Script' to create and delete user accounts and perform other ${CT_HOSTNAME^^} tasks. More information is available here: https://github.com/ahuacate/pve-nas\n\n  --  Power User Account - create or delete accounts\n  --  Jailed User Account - create or delete accounts\n  --  Upgrade NAS OS - OS updates, releases, software packages and patches\n  --  Install Fail2Ban $(if [ $(pct exec $CTID -- dpkg -s fail2ban >/dev/null 2>&1; echo $?) == 0 ]; then echo "( ${GREEN}installed${NC} )"; else echo "( not installed )"; fi)\n  --  Install SSMTP Email Server $(if [ $(pct exec $CTID -- dpkg -s ssmtp >/dev/null 2>&1; echo $?) = 0 ] && [ $(pct exec $CTID -- grep -qs "^root:*" /etc/ssmtp/revaliases >/dev/null; echo $?) = 0 ]; then echo "( ${GREEN}installed${NC} )"; else echo "( not installed )"; fi)\n  --  Install ProFTPd Server $(if [ $(pct exec $CTID -- dpkg -s proftpd-core >/dev/null 2>&1; echo $?) = 0 ]; then echo "( ${GREEN}installed${NC} )"; else echo "( not installed )"; fi)\n\n${CT_HOSTNAME^^} will now reboot."
fi

# Cleanup
pct exec $CTID -- bash -c "rm -R /tmp/common &> /dev/null; rm -R /tmp/pve-nas &> /dev/null; rm /tmp/common.tar.gz &> /dev/null; rm /tmp/pve-nas.tar.gz &> /dev/null"
pct reboot $CTID
rm -R /tmp/common &> /dev/null
rm -R /tmp/pve-nas &> /dev/null
rm /tmp/common.tar.gz &> /dev/null
rm /tmp/pve-nas.tar.gz &> /dev/null

trap cleanup EXIT