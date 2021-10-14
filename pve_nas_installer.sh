#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_installer.sh
# Description:  Installer script for Proxmox NAS
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

#---- Source Github
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/master/pve_nas_installer.sh)"

#---- Source local Git
# /mnt/pve/nas-01-git/ahuacate/pve-nas/pve_nas_installer.sh

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

# Set Package Installer Temp Folder
cd /tmp


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
# Installer App script
GIT_APP_SCRIPT='pve_nas_create.sh'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------

#---- Package loader
if [ -f /mnt/pve/nas-*[0-9]-git/${GIT_USER}/developer_settings.git ] && [ -f /mnt/pve/nas-*[0-9]-git/${GIT_USER}/common/bash/source/pve_repo_loader.sh ]; then
  # Developer Options loader
  source /mnt/pve/nas-*[0-9]-git/${GIT_USER}/common/bash/source/pve_repo_loader.sh
else
  # Download Github loader
  bash -c "$(wget -qLO - https://raw.githubusercontent.com/${GIT_USER}/common/master/bash/source/pve_repo_loader.sh)"
fi

#---- Body -------------------------------------------------------------------------

#---- Run Installer
/tmp/${GIT_REPO}/scripts/${GIT_APP_SCRIPT}