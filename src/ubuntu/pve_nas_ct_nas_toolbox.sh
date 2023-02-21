#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_toolbox.sh
# Description:  Installer script for Proxmox Ubuntu NAS administration toolbox & Add-Ons
# ----------------------------------------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites
# Check SMTP status
check_smtp_status
if [ "$SMTP_STATUS" = 0 ]
then
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

  if [ "$RESULTS" = 'TYPE01' ]
  then
    # Exit and install SMTP
    msg "Go to our Github site and run our PVE Host Toolbox selecting our 'SMTP Email Setup' option:\n\n  --  https://github.com/ahuacate/pve-host\n\nRe-run the NAS installer after your have configured '$(hostname)' SMTP email support. Bye..."
    echo
    exit 0
  elif [ "$RESULTS" = 'TYPE02' ]
  then
    # Proceed without SMTP email support
    msg "You have chosen to proceed without SMTP email support. You can always manually configure Postfix SMTP services at a later stage."
    echo
  elif [ "$RESULTS" = 'TYPE00' ]
  then
    msg "You have chosen not to proceed. Aborting. Bye..."
    echo
    exit 0
  fi
fi

# Pushing PVE-nas setup scripts to NAS CT
msg "Pushing NAS configuration scripts to NAS CT..."
pct push $CTID $REPO_TEMP/${GIT_REPO}.tar.gz /tmp/${GIT_REPO}.tar.gz
pct exec $CTID -- tar -zxf /tmp/${GIT_REPO}.tar.gz -C /tmp
echo


#---- Run Installer
section "Select a Ubuntu NAS toolbox option"
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" "TYPE03" "TYPE04" "TYPE05" "TYPE06" "TYPE07" "TYPE08" "TYPE09" "TYPE00" )
OPTIONS_LABELS_INPUT=( "Power User Account - add a new user to the system" \
"Jailed User Account - add a new user to the system" \
"Delete Users - delete any user account (option to users keep home folder)" \
"Upgrade NAS OS - software packages, OS and patches" \
"Install Fail2Ban $(if [ "$(pct exec $CTID -- dpkg -s fail2ban >/dev/null 2>&1; echo $?)" = 0 ]; then echo "( installed & active )"; else echo "( not installed )"; fi)" \
"Install SMTP Email Support  $(if [ "$(pct exec $CTID -- bash -c 'if [ -f /etc/postfix/main.cf ]; then grep --color=never -Po "^ahuacate_smtp=\K.*" "/etc/postfix/main.cf" || true; else echo 0; fi')" = 1 ]; then echo "( installed & active )"; else echo "( not installed - recommended installation )"; fi)" \
"Install ProFTPd Server $(if [ "$(pct exec $CTID -- dpkg -s proftpd-core >/dev/null 2>&1; echo $?)" = 0 ]; then echo "( installed & active )"; else echo "( not installed )"; fi)" \
"Add ZFS Cache - create ARC/L2ARC/ZIL cache with dedicated SSD/NVMe drives" \
"Restore & update default storage - reset default dirs, permissions and ACLs" \
"None. Exit this installer" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"

if [ "$RESULTS" = TYPE01 ]
then
  #---- Check for SMTP support
  if [ "$SMTP_STATUS" = 1 ]
  then
    # PVE SMTP supported, check NAS
    if [ ! "$(pct exec $CTID -- bash -c 'if [ -f /etc/postfix/main.cf ]; then grep --color=never -Po "^ahuacate_smtp=\K.*" "/etc/postfix/main.cf" || true; else echo 0; fi')" = 1 ]
    then 
      # Install and Configure SMTP Email on NAS
      source $REPO_TEMP/$GIT_REPO/common/pve/src/pvesource_install_postfix_client.sh
    fi
  fi
  #---- Create New Power User Accounts
  pct exec $CTID -- bash -c "export PVE_ROOT_EMAIL=$(pveum user list | awk -F " │ " '$1 ~ /root@pam/' | awk -F " │ " '{ print $3 }') && /tmp/$GIT_REPO/src/ubuntu/pve_nas_ct_addpoweruser.sh"
elif [ "$RESULTS" = TYPE02 ]
then
  #---- Check for SMTP support
  if [ "$SMTP_STATUS" = 1 ]
  then
    # PVE SMTP supported, check NAS
    if [ ! "$(pct exec $CTID -- bash -c 'if [ -f /etc/postfix/main.cf ]; then grep --color=never -Po "^ahuacate_smtp=\K.*" "/etc/postfix/main.cf" || true; else echo 0; fi')" = 1 ]
    then 
      # Install and Configure SMTP Email on NAS
      source $REPO_TEMP/$GIT_REPO/common/pve/src/pvesource_install_postfix_client.sh
    fi
  fi
  #---- Create New Jailed User Accounts
  pct exec $CTID -- bash -c "export PVE_ROOT_EMAIL=$(pveum user list | awk -F " │ " '$1 ~ /root@pam/' | awk -F " │ " '{ print $3 }') && /tmp/$GIT_REPO/src/ubuntu/pve_nas_ct_addjailuser.sh"
elif [ "$RESULTS" = TYPE03 ]
then
  #---- Delete a User Account
    pct exec $CTID -- bash -c "/tmp/$GIT_REPO/src/ubuntu/pve_nas_ct_deleteuser.sh"
elif [ "$RESULTS" = TYPE04 ]
then
  #---- Perform a NAS upgrade
  pct exec $CTID -- bash -c "/tmp/$GIT_REPO/common/pve/tool/pvetool_ct_ubuntu_versionupdater.sh"
elif [ "$RESULTS" = TYPE05 ]; then
  #---- Install and Configure Fail2ban
  pct exec $CTID -- bash -c "export SSH_PORT=\$(grep Port /etc/ssh/sshd_config | sed '/^#/d' | awk '{ print \$2 }') && /tmp/$GIT_REPO/common/pve/src/pvesource_ct_ubuntu_installfail2ban.sh"
elif [ "$RESULTS" = TYPE06 ]
then
  #---- Install and Configure SMTP Email
  source $REPO_TEMP/$GIT_REPO/common/pve/src/pvesource_install_postfix_client.sh
elif [ "$RESULTS" = TYPE07 ]
then
  #---- Install and Configure ProFTPd
  # Check if ProFTPd is installed
  if [ ! "$(pct exec $CTID -- dpkg -s proftpd-core >/dev/null 2>&1; echo $?)" = 0 ]
  then
    pct exec $CTID -- bash -c "/tmp/$GIT_REPO/common/pve/src/pvesource_ct_ubuntu_installproftpd.sh"
  else
    msg "ProFTPd is already installed..."
  fi
  pct exec $CTID -- bash -c "/tmp/$GIT_REPO/src/ubuntu/proftpd_settings/pve_nas_ct_proftpdsettings.sh"
elif [ "$RESULTS" = TYPE08 ]
then
  #---- Setup ZFS Cache
  source $REPO_TEMP/pve-nas/shared/pve_nas_create_zfs_cacheaddon.sh
elif [ "$RESULTS" = TYPE09 ]
then
  #---- Restore, update default storage folder permissions
  pct exec $CTID -- bash -c "/tmp/$GIT_REPO/src/ubuntu/pve_nas_ct_restoredirperm.sh"
elif [ "$RESULTS" = TYPE00 ]
then
  # Exit installation
  msg "You have chosen not to proceed. Aborting. Bye..."
  echo
  sleep 1
fi

#---- Finish Line ------------------------------------------------------------------

# section "Completion Status"

# msg "Success. Task complete."
# echo

#---- Cleanup
# Clean up CT tmp files
pct exec $CTID -- bash -c "rm -R /tmp/${GIT_REPO} &> /dev/null; rm /tmp/${GIT_REPO}.tar.gz &> /dev/null"
#-----------------------------------------------------------------------------------