#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_vm_nas_installer.sh
# Description:  This script is for creating a PVE VM OMV based NAS
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

# Set Audio
if [ -f "/proc/asound/cards" ]
then
  # Set audio device
  if [[ $(cat /proc/asound/cards | grep -i 'HDA-Intel') ]]
  then
    VM_DEVICE_VAR='intel-hda'
    VM_DRIVER_VAR='none'
  elif [[ $(cat /proc/asound/cards | grep -i 'ICH9\|Intel ICH9') ]]
  then
    VM_DEVICE_VAR='ich9-intel-hda'
    VM_DRIVER_VAR='none'
  elif [[ $(cat /proc/asound/cards | grep -i 'ac97') ]]
  then
    VM_DEVICE_VAR='AC97'
    VM_DRIVER_VAR='none'
  elif [[ ! $(cat /proc/asound/cards | grep -i 'ICH9\|Intel ICH9') ]]
  then
    VM_DEVICE_VAR=''
    VM_DRIVER_VAR=''
  fi
fi

#---- Static Variables -------------------------------------------------------------

# Easy Script Section Head
SECTION_HEAD='PVE OMV NAS'

# PVE host IP
PVE_HOST_IP=$(hostname -i)
PVE_HOSTNAME=$(hostname)

# SSHd Status (0 is enabled, 1 is disabled)
SSH_ENABLE=1

# Developer enable git mounts inside CT  (0 is enabled, 1 is disabled)
DEV_GIT_MOUNT_ENABLE=1

# Validate & set architecture dependent variables
ARCH=$(dpkg --print-architecture)

# Set file source (path/filename) of preset variables for 'pvesource_vm_createvm.sh'
PRESET_VAR_SRC="$( dirname "${BASH_SOURCE[0]}" )/$( basename "${BASH_SOURCE[0]}" )"

#---- Other Variables --------------------------------------------------------------

#---- Common Machine Variables
# VM Type ( 'ct' or 'vm' only lowercase )
VM_TYPE='vm'
# Use DHCP. '0' to disable, '1' to enable.
NET_DHCP='1'
#  Set address type 'dhcp4'/'dhcp6' or '0' to disable. Use in conjunction with 'NET_DHCP'.
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
# Description for the vm/ct (one word only, no spaces). Shown in the web-interface vm/ct's summary. 
DESCRIPTION=''
# Allocated memory or RAM (MiB). Minimum 512Gb. This is the maximum available memory when you use the balloon device. 
MEMORY='2048'
# Limit number of CPU sockets to use.  Value 0 indicates no CPU limit.
CPULIMIT='0'
# CPU weight for a VM. Argument is used in the kernel fair scheduler. The larger the number is, the more CPU time this VM gets.
CPUUNITS='1024'
# The number of cores assigned to the vm/ct. Do not edit - its auto set.
CORES='1'

#----[COMMON_NET_OPTIONS]
# Network Card Model. The virtio model provides the best performance with very low CPU overhead. Otherwise use e1000. (virtio | e1000) 
MODEL='virtio'
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
SEARCHDOMAIN=$(hostname -d)

#----[COMMON_NET_STATIC_OPTIONS]
# IP address (IPv4). Only works with static IP (DHCP=0).
IP='192.168.1.10'
# IP address (IPv6). Only works with static IP (DHCP=0).
IP6=''
# Default gateway for traffic (IPv4). Only works with static IP (DHCP=0).
GW='192.168.1.5'
# Default gateway for traffic (IPv6). Only works with static IP (DHCP=0).
GW6=''

#---- PVE VM
# Do not edit here down unless you know what you are doing.
# ---- Common variable aliases
# Virtual Disk Size (GB).
VM_SIZE=10

#----[VM_GENERAL_OPTIONS]
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='1:0'
# Name (Set a name for the VM. Only used on the configuration web interface.)
VM_NAME="${HOSTNAME}"
# Description. Shown in the web-interface VM’s summary.
VM_DESCRIPTION="${DESCRIPTION}"
# Specifies whether a VM will be started during system bootup. 
VM_ONBOOT='1'
# Virtual OS/processor architecture. Use '' to default to host. ( <'' | aarch64 | x86_64>)
VM_ARCH=''
# Automatic restart after crash
VM_AUTOSTART='1'
# Hotplug. Selectively enable hotplug features. Default network, disk, usb. Use '0' to disable '1' to enable.
VM_HOTPLUG='1'
# Enable/disable the USB tablet device. Set to '0' when using Spice. This device is usually needed to allow absolute mouse positioning with VNC.
VM_TABLET='1'

#----[VM_SYSTEM_OPTIONS]
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='1:0'
# Specifies the Qemu machine type. Best use default ''. Q35 supports PCIe so I it can do GPU passthrough etc. (pc|pc(-i440fx)?-\d+(\.\d+)+(\+pve\d+)?(\.pxe)?|q35|pc-q35-\d+(\.\d+)+(\+pve\d+)?(\.pxe)?|virt(?:-\d+(\.\d+)+)?(\+pve\d+)?)
VM_MACHINE=''
# SCSI controller model ( recommend 'virtio-scsi' or 'virtio-scsi-single'. Virtio scsi single use 1 scsi controller by disk , virtio scsi classic use 1 controller for 16disk. Iothread only work by controller.)
VM_SCSIHW='virtio-scsi-pci'
# BIOS implementation
VM_BIOS='seabios'

#----[VM_BOOT_OPTIONS]
# Specify guest boot order.
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='1:boot'
# Set boot order. Default is 'scsi0,ide2' (ide2=cdrom).
VM_ORDER='scsi0;ide2'

#----[VM_QEMU_OPTIONS]
# Qemu agent. Enable/disable communication with the Qemu Guest Agent and its properties. Use '0' to disable '1' to enable. (default = 0)
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='1:agent'
VM_QEMU_ENABLED='1'
# Run fstrim after moving a disk or migrating the VM. (default = 0)
VM_QEMU_FSTRIM_CLONED_DISKS='0'
# Select the agent type (isa | virtio). (default = virtio) 
VM_QEMU_TYPE='virtio'

#----[VM_SPICE_OPTIONS]
# Other required options must be set: --tablet 0; --vga qx1,memory=32; --usb spice,usb3=0; --audio0 device=?,driver=spice
# Configure additional enhancements for SPICE.
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='0:spice_enhancements'
# Foldersharing enables you to share a local folder with the VM you are connecting to. The "spice-webdavd" daemon needs to be installed in the VM. (1|0)
VM_FOLDERSHARING='1'
# Videostreaming will encode fast refreshing areas in a lossy video stream. (off | all | filter)
VM_VIDEOSTREAMING='all'

#----[VM_AUDIO_OPTIONS]
# Values determined by script:
#  VM_DEVICE="${VM_DEVICE_VAR}"
#  VM_DRIVER="${VM_DRIVER_VAR}"
# Or manual overwrite with your own values. Spice must be manually set.
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='0:audio0'
# Configure a audio device, useful in combination with QXL/Spice. (ich9-intel-hda|intel-hda|AC97)
VM_DEVICE="$VM_DEVICE_VAR"
# Driver select. (spice|none)
VM_DRIVER="$VM_DRIVER_VAR"

#----[VM_VGA_OPTIONS]
# Configure the VGA Hardware. Since QEMU 2.9 the default VGA display type is 'std' for all OS types besides older Windows versions (XP and older) which use cirrus.
# Display type: cirrus | none | qxl | qxl2 | qxl3 | qxl4 | serial0 | serial1 | serial2 | serial3 | std | virtio | virtio-gl | vmware> (default = std)
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='1:vga'
# Set display type to 'qx1' when using Spice.
VM_VGA_TYPE='std'
# GPU memory (MiB) (4 - 512). Sets the VGA memory (in MiB). Has no effect with serial display. 
VM_VGA_MEMORY='32'

#----[VM_CPUSPECS_OPTIONS]
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='1:0'
# The number of cores per socket. Auto set by script.(default = 1)
VM_CORES=$CORES
# Limit of CPU usage.
VM_CPULIMIT="$CPULIMIT"
# CPU weight for a VM. Argument is used in the kernel fair scheduler. The larger the number is, the more CPU time this VM gets.
VM_CPUUNITS="$CPUUNITS"
# The number of CPU sockets.
VM_SOCKETS='1'
# Number of hotplugged vcpus. Default is ''.
VM_VCPUS=''
# Enable/disable NUMA. Default is '0'.
VM_NUMA='0'

#----[VM_MEMORY_OPTIONS]
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='1:0'
# Memory. Amount of RAM for the VM in MB. This is the maximum available memory when you use the balloon device. 
VM_MEMORY="$MEMORY"
# Amount of target RAM for the VM in MB. Using zero disables the ballon driver. 
VM_BALLOON='512'

#----[VM_NET_OPTIONS]
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='1:net0'
# Network Card Model. The virtio model provides the best performance with very low CPU overhead. Otherwise use e1000. (virtio | e1000) 
VM_MODEL="$MODEL"
# Bridge to attach the network device to.
VM_BRIDGE="$BRIDGE"
# A common MAC address with the I/G (Individual/Group) bit not set. 
VM_MACADDR="$HWADDR"
# Controls whether this interface’s firewall rules should be used.
VM_FIREWALL="$FIREWALL"
# VLAN tag for this interface (value 0 for none, or VLAN[2-N] to enable).
VM_TAG="$TAG"
# VLAN ids to pass through the interface.
VM_TRUNKS="$TRUNKS"
# Apply rate limiting to the interface (MB/s). Value "" for unlimited.
VM_RATE="$RATE"
# MTU - Maximum transfer unit of the interface.
VM_MTU="$MTU"

#----[VM_GUEST_OS_OPTIONS]
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='1:0'
# OS. Set args: l26 (Linux 2.6 Kernel) | l24 (Linux 2.4 Kernel) | other | solaris | w2k | w2k3 | w2k8 | win10 | win11 | win7 | win8 | wvista | wxp
VM_OSTYPE='l26'

#----[VM_CPU_OPTIONS]
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='1:cpu'
# Emulated CPU type.
VM_CPUTYPE='kvm64'

#----[VM_STARTUP_OPTIONS]
# Startup and shutdown behavior ( '--startup order=1,up=1,down=1' ).
# Order is a non-negative number defining the general startup order. Up=1 means first to start up. Shutdown in done with reverse ordering so down=1 means last to shutdown.
# Up: Startup delay. Defines the interval between this container start and subsequent containers starts. For example, set it to 240 if you want to wait 240 seconds before starting other containers.
# Down: Shutdown timeout. Defines the duration in seconds Proxmox VE should wait for the container to be offline after issuing a shutdown command. By default this value is set to 60, which means that Proxmox VE will issue a shutdown request, wait 60s for the machine to be offline, and if after 60s the machine is still online will notify that the shutdown action failed. 
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='1:startup'
VM_ORDER='1'
VM_UP='30'
VM_DOWN='60'

#----[VM_SCSI0_OPTIONS]
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='1:scsi0'
# Virtual Disk Size (GB).
VM_SCSI0_SIZE="$VM_SIZE"
# Cache
VM_SCSI0_CACHE=''
# Allows the node to reclaim the free space that does not have any data. Must use 'VirtIO SCSI controller'. Enable for ZFS. Set <ignore|on>
VM_SCSI0_DISCARD=''
# SSD emulation
VM_SCSI0_SSD='1'
# Include volume in backup job
VM_SCSI0_BACKUP='1'
# IOThread. Creates one I/O thread per storage controller, rather than a single thread for all I/O. Works with 'virtio-scsi-single' only.
VM_SCSI0_IOTHREAD=''

#----[VM_SCSI1_OPTIONS]
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='0:scsi1'
# Virtual Disk Size (GB).
VM_SCSI1_SIZE=''
# Cache
VM_SCSI1_CACHE=''
# Allows the node to reclaim the free space that does not have any data. Must use 'VirtIO SCSI controller'. Enable for ZFS. Set <ignore|on>
VM_SCSI1_DISCARD=''
# SSD emulation
VM_SCSI1_SSD=''
# Include volume in backup job
VM_SCSI1_BACKUP=''
# IOThread. Creates one I/O thread per storage controller, rather than a single thread for all I/O. Works with 'virtio-scsi-single' only.
VM_SCSI1_IOTHREAD=''

#----[VM_CDROM_OPTIONS]
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='1:cdrom'
# ISO src
VM_ISO_SRC='OS_TMPL'
# Media type
VM_MEDIA=cdrom

#----[VM_CLOUD_INIT_OPTIONS]
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='1:0'
# Root credentials
VM_CIUSER='root'
VM_CIPASSWORD='ahuacate'
# Specifies the cloud-init configuration format. Use the nocloud format for Linux, and configdrive2 for windows.
VM_CITYPE='nocloud'
# Sets DNS server IP address for a container.
VM_NAMESERVER=$NAMESERVER
# Sets DNS search domains for a container.
VM_SEARCHDOMAIN=$SEARCHDOMAIN
# SSH Keys. Setup public SSH keys (one key per line, OpenSSH format).
VM_SSHKEYS=''

#----[VM_CLOUD_INIT_IPCONFIG_OPTIONS]
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='1:ipconfig0'
# IP address (IPv4). Set IPv4 or 'dhcp'.
VM_IP="$IP"
# IP address (IPv6). Set IPv6 or 'dhcp'.
VM_IP6=""
# Default gateway for traffic (IPv4).
VM_GW="$GW"
# Default gateway for traffic (IPv6).
VM_GW6=""

#----[VM_SERIAL_OPTIONS]
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>'). Default is '0' (disabled).
OPTION_STATUS='0:0'
# Create a serial device inside the VM (n is 0 to 3) 
VM_SERIAL0='socket'
VM_VGA='serial0'

#----[VM_USB_OPTIONS]
# Configure an USB device (n is 0 to 4). (HOSTUSBDEVICE | spice)
# The Host USB device or port or the value spice. HOSTUSBDEVICE syntax is:
# 'bus-port(.port)*' (decimal numbers) or
# 'vendor_id:product_id' (hexadeciaml numbers) or 'spice'
# Use '0' to disable, '1' to enable to enable ('<0 | 1>:<0 | string name>').
OPTION_STATUS='0:usb0'
# Set host to 'spice' when using Spice. (<HOSTUSBDEVICE | spice>)
VM_HOST=''
# Enable usb3. Specifies whether if given host option is a USB3 device or port. Use '0' to disable '1' to enable.
VM_USB3=''

#----[VM_OTHER]
# OS Name (options are: 'ubuntu', 'debian'. Set '' when setting custom URLs - "VM_OTHER_OS_URL")
VM_OS_DIST=''
# OS Version (options for ubuntu: '18.04', '20.04', '21.10', '22.04' ; options for debian: '9', '10'. Set '' when setting custom URLs - "VM_OTHER_OS_URL")
VM_OSVERSION=''
# OS Other URL ()
# For custom URLS to ISO files. If not used leave empty ''.
VM_OTHER_OS_URL='http://sourceforge.net/projects/openmediavault/files/latest/download?source=files'
# PCI passthrough. Use '0' to disable, '1' to enable to enable ('<0 | 1>').
VM_PCI_PT='1'
# VM numeric ID of the given machine.
VMID='110'

#----[App_UID_GUID]
# App user
APP_USERNAME='root'
# App user group
APP_GRPNAME='root'

#----[REPO_PKG_NAME]
# Repo package name
REPO_PKG_NAME='pve-nas'

#---- Other Files ------------------------------------------------------------------

# Required PVESM Storage Mounts for VM ( new version )
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

#---- Prerequisites

# PCI IOMMU passthru
source $COMMON_PVE_SRC_DIR/pvesource_precheck_iommu.sh

# Host SMTP support
source $COMMON_PVE_SRC_DIR/pvesource_precheck_hostsmtp.sh


#---- Introduction
source $COMMON_PVE_SRC_DIR/pvesource_vm_intro.sh


#---- Set variables
source $COMMON_PVE_SRC_DIR/pvesource_set_allvmvars.sh


#---- Create VM
source $COMMON_PVE_SRC_DIR/pvesource_vm_createvm.sh


#---- Set PCI HBA or physical disk pass-through
source $COMMON_PVE_SRC_DIR/pvesource_vm_diskpassthru.sh "onboard"


#---- Finish Line ------------------------------------------------------------------
section "Completion Status"

#---- Set display text
if [ "$VM_DISK_PT" = 0 ]
then
  # Aborted disk pass-through
  display_msg1="You have chosen to abort setting disk pass-through for your VM '${HOSTNAME,,}'. No disk pass-through has been configured. You can manually configure your pass-through options using the Proxmox WebGUI interface > ''${VMID} (${HOSTNAME,,})' > 'Hardware' to pass-through your required devices.\n\nOr you can destroy VM '${VMID} (${HOSTNAME,,})', fix any issue you have with your disks and run the installer again."
elif [ "$VM_DISK_PT" = 1 ]
then
  # PCIe disk Pass-through
  display_msg1="Using the PVE web interface on PVE host '$(hostname)', go to VM '${VMID} (${HOSTNAME,,})' > '_Shell' and start the VM. The OMV installation frontend WebGUI will start. Complete the OMV installation as per our Github guide:\n\n    --  https://github.com/ahuacate/nas-hardmetal\n\nAfter completing the OMV installation your login credentials are:\n\n    Web interface\n    --  URL: http://${HOSTNAME,,}.$(hostname -d) (hostname.domain)\n    --  User: admin\n    --  Password: openmediavault\n\n    Client (SSH, console)\n    --  User: root\n    --  Password: The password that you have set during installation."
elif [ "$VM_DISK_PT" = 2 ]
then
  # PCIe HBA Pass-through
  display_msg1="You have chosen to configure your NAS with PCIe HBA card pass-through. Steps to be taken are:\n\n    --  Connect your NAS disks to your SATA/SAS/NVMe PCIe HBA card\n    --  Follow the steps in our guide: https://github.com/ahuacate/nas-hardmetal\n\nAfter configuring your PCIe HBA card pass-through using the PVE web interface on PVE host '$(hostname)', go to VM '${VMID} (${HOSTNAME,,})' > '_Shell' and start the VM. The OMV installation frontend WebGUI will start. Complete the OMV installation as per our Github guide:\n\n    --  https://github.com/ahuacate/nas-hardmetal\n\nAfter completing the OMV installation your login credentials are:\n\n    Web interface\n    --  URL: http://${HOSTNAME,,}.$(hostname -d) (hostname.domain)\n    --  User: admin\n    --  Password: openmediavault\n\n    Client (SSH, console)\n    --  User: root\n    --  Password: The password that you have set during installation."
fi

msg_box "${HOSTNAME^^} VM creation was a success. To complete the build you must now follow these steps.

$(echo ${display_msg1})"
#-----------------------------------------------------------------------------------