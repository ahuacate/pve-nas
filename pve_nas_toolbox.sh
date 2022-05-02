#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_toolbox.sh
# Description:  Installer script for Proxmox Ubuntu NAS administration toolbox & Add-Ons
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#---- Source Github
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/master/pve_nas_toolbox.sh)"

#---- Source local Git
# /mnt/pve/nas-01-git/ahuacate/pve-nas/pve_nas_toolbox.sh

#---- Source -----------------------------------------------------------------------
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


# Installer cleanup
function installer_cleanup () {
rm -R ${REPO_TEMP}/${GIT_REPO} &> /dev/null
rm ${REPO_TEMP}/${GIT_REPO}.tar.gz &> /dev/null
}


#---- Static Variables -------------------------------------------------------------

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

# Set Package Installer Temp Folder
REPO_TEMP='/tmp'
cd ${REPO_TEMP}

#---- Other Variables --------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='PVE NAS Toolbox'

#---- Other Files ------------------------------------------------------------------

#---- Package loader
if [ -f /mnt/pve/nas-*[0-9]-git/${GIT_USER}/developer_settings.git ] && [ -f /mnt/pve/nas-*[0-9]-git/${GIT_USER}/${GIT_REPO}/common/bash/src/pve_repo_loader.sh ]; then
  # Developer Options loader
  source /mnt/pve/nas-*[0-9]-git/${GIT_USER}/${GIT_REPO}/common/bash/src/pve_repo_loader.sh
else
  # Download Github loader
  wget -qL - https://raw.githubusercontent.com/${GIT_USER}/${GIT_REPO}/common/master/bash/src/pve_repo_loader.sh -O ${REPO_TEMP}/pve_repo_loader.sh
  chmod +x ${REPO_TEMP}/pve_repo_loader.sh
  source ${REPO_TEMP}/pve_repo_loader.sh
fi

#---- Body -------------------------------------------------------------------------

#---- Run Bash Header
source ${REPO_TEMP}/pve-nas/common/pve/src/pvesource_bash_defaults.sh

#---- Select NAS CTID
section "Select and Connect with your NAS"
msg "User must identify and select a PVE Ubuntu NAS from the menu:"
unset vmid_LIST
vmid_LIST+=( $(pct list | sed 's/[ ]\+/:/g' | sed 's/:$//' | awk -F':' 'BEGIN { OFS=FS } { if(NR > 1) print $3, $1 }' | sed -e '$anone:none') )
OPTIONS_VALUES_INPUT=$(printf '%s\n' "${vmid_LIST[@]}" | awk -F':' '{ print $2}')
OPTIONS_LABELS_INPUT=$(printf '%s\n' "${vmid_LIST[@]}" | awk -F':' '{if ($1 != "none" && $2 != "none") print "NAME: "$1, "| VMID: "$2; else print "None. Exit installation."; }')
makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
singleselect SELECTED "$OPTIONS_STRING"
CTID=${RESULTS}
# If 'none' clean and exit
if [ ${CTID} = "none" ]; then
  installer_cleanup
  trap cleanup EXIT
  exit 0
fi

# Check NAS run status
pct_start_waitloop

# Pushing PVE-nas setup scripts to NAS CT
msg "Pushing NAS configuration scripts to NAS CT..."
pct push $CTID ${REPO_TEMP}/${GIT_REPO}.tar.gz /tmp/${GIT_REPO}.tar.gz
pct exec $CTID -- tar -zxf /tmp/${GIT_REPO}.tar.gz -C /tmp
echo


#---- Run Installer
section "Run a Ubuntu NAS Toolbox task"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" "TYPE04" "TYPE05" "TYPE06" "TYPE07" "TYPE00" )
OPTIONS_LABELS_INPUT=( "Power User Account - create or delete account" "Jailed User Account - create or delete account" "Upgrade NAS OS - software packages, OS and patches" "Install Fail2Ban $(if [ $(pct exec $CTID -- dpkg -s fail2ban >/dev/null 2>&1; echo $?) = 0 ]; then echo "( installed & active )"; else echo "( not installed )"; fi)" "Install SSMTP Email Server $(if [ $(pct exec $CTID -- dpkg -s ssmtp >/dev/null 2>&1; echo $?) = 0 ] && [ $(pct exec $CTID -- grep -qs "^root:*" /etc/ssmtp/revaliases >/dev/null; echo $?) = 0 ]; then echo "( installed & active )"; else echo "( not installed - A RECOMMENDED installation )"; fi)" "Install ProFTPd Server $(if [ $(pct exec $CTID -- dpkg -s proftpd-core >/dev/null 2>&1; echo $?) = 0 ]; then echo "( installed & active )"; else echo "( not installed )"; fi)" "Add ZFS Cache - create ARC/L2ARC/ZIL cache with dedicated SSD/NVMe drives" "None. Exit this installer" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ ${RESULTS} == 'TYPE01' ]; then
  #---- Create New Power User Accounts
  pct exec $CTID -- bash -c "/tmp/${GIT_REPO}/src/ubuntu/pve_nas_ct_addpoweruser.sh"
elif [ ${RESULTS} == 'TYPE02' ]; then
  #---- Create New Jailed User Accounts
  pct exec $CTID -- bash -c "/tmp/${GIT_REPO}/src/ubuntu/pve_nas_ct_addjailuser.sh"
elif [ ${RESULTS} == 'TYPE03' ]; then
  #---- Perform a NAS upgrade
  pct exec $CTID -- bash -c "/tmp/${GIT_REPO}/common/pve/tool/pvetool_ct_ubuntu_versionupdater.sh"
elif [ ${RESULTS} == 'TYPE04' ]; then
  #---- Install and Configure Fail2ban
  pct exec $CTID -- bash -c "export SSH_PORT=\$(grep Port /etc/ssh/sshd_config | sed '/^#/d' | awk '{ print \$2 }') && /tmp/${GIT_REPO}/common/pve/src/pvesource_ct_ubuntu_installfail2ban.sh"
elif [ ${RESULTS} == 'TYPE05' ]; then
  #---- Install and Configure SSMTP Email Alerts
  pct exec $CTID -- bash -c "/tmp/${GIT_REPO}/common/pve/src/pvesource_ct_ubuntu_installssmtp.sh"
elif [ ${RESULTS} == 'TYPE06' ]; then
  #---- Install and Configure ProFTPd
  # pct exec $CTID -- bash -c "cp /tmp/pve-nas/src/ubuntu/proftpd_settings/sftp.conf /tmp/common/pve/src/ && /tmp/common/pve/src/pvesource_ct_ubuntu_installproftpd.sh"
  # Check if ProFTPd is installed
  if [ $(pct exec $CTID -- dpkg -s proftpd-core >/dev/null 2>&1; echo $?) != 0 ]; then
    pct exec $CTID -- bash -c "/tmp/${GIT_REPO}/common/pve/src/pvesource_ct_ubuntu_installproftpd.sh"
  else
    msg "ProFTPd is already installed..."
  fi
  pct exec $CTID -- bash -c "/tmp/${GIT_REPO}/src/ubuntu/proftpd_settings/pve_nas_ct_proftpdsettings.sh"
elif [ ${RESULTS} == 'TYPE07' ]; then
  #---- Setup ZFS Cache
  source ${REPO_TEMP}/pve-nas/shared/pve_nas_create_zfs_cacheaddon.sh
elif [ ${RESULTS} == 'TYPE00' ]; then
  # Exit installation
  msg "You have chosen not to proceed. Aborting. Bye..."
  echo
  sleep 1
fi

#---- Finish Line ------------------------------------------------------------------

section "Completion Status."

msg "Success. Task complete."
echo

#---- Cleanup
# Clean up CT tmp files
pct exec $CTID -- bash -c "rm -R /tmp/${GIT_REPO} &> /dev/null; rm /tmp/${GIT_REPO}.tar.gz &> /dev/null"
# Clean up pve host
installer_cleanup
trap cleanup EXIT