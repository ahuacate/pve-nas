#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_ct_addpoweruser.sh
# Description:  Create a new PVE NAS Power User
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

# Command to run script
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/master/scripts/source/ubuntu/pve_nas_ct_addpoweruser.sh)"

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SOURCE="${DIR}/../../../../common/pve/source"

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source ${COMMON_PVE_SOURCE}/pvesource_bash_defaults.sh

# Install libcrack2
if [ $(dpkg -s libcrack2 >/dev/null 2>&1; echo $?) != 0 ]; then
  apt-get install -y libcrack2 > /dev/null
fi

# Check user is root
if [ $(id -u) != 0 ]; then
  warn "This script needs to run under 'root'. Exiting in 2 seconds.\nTry again..."
  sleep 2
  exit 0
fi

#---- Static Variables -------------------------------------------------------------

# List of new users
NEW_USERS=usersfile
# Homes folder
HOSTNAME=$(hostname)
HOME_BASE="/srv/${HOSTNAME}/homes/"


#---- Other Variables --------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='PVE NAS'

# Delete a username (permanent action)
function delete_username() {
  while true; do
    msg "Your power user accounts are:\n\n$(cat /etc/passwd | awk -F':' '$4 = /65605|65606|65607/ && $4 !~ /65608:/ && $3 = !/1605|1606|1607/ {print "  --  "$1}')\n"
    read -p "Enter the user name you want to delete: " USERNAME
    if [ $(egrep "^${USERNAME}:" /etc/passwd > /dev/null; echo $?) -eq 0 ]; then
      msg "User name ${WHITE}${USERNAME}${NC} exists."
      while true; do
        read -p "Are you sure your want delete user ${WHITE}${USERNAME}${NC} [y/n]?" -n 1 -r YN
        echo
        case $YN in
          [Yy]*)
            # Deleting existing user name
            while true; do
              read -p "Also delete ${WHITE}${USERNAME}${NC} home folder and contents [y/n]?: "  -n 1 -r YN
              echo
              case $YN in
                [Yy]*)
                  msg "Deleting existing user ${WHITE}${USERNAME}${NC} (including home folder)..."
                  # Chattr set user desktop folder attributes to -i
                  while read dir; do
                    if [ -f $(awk -F: -v v="${USERNAME}" '{if ($1==v) print $6}' /etc/passwd)/${dir}/.foo_protect ]; then
                      chattr -i $(awk -F: -v v="${USERNAME}" '{if ($1==v) print $6}' /etc/passwd)/${dir}/.foo_protect
                    fi
                  done <<< $( ls $(awk -F: -v v="${USERNAME}" '{if ($1==v) print $6}' /etc/passwd) )
                  # Delete ProFTPd key
                  rm -f /etc/proftpd/authorized_keys/${USERNAME}
                  userdel -r ${USERNAME} 2>/dev/null
                  info "User ${WHITE}${USERNAME}${NC} and its home folder and contents have been deleted."
                  echo
                  break 3
                  ;;
                [Nn]*)
                  msg "Deleting existing user ${WHITE}${USERNAME}${NC} (excluding home folder)..."
                  userdel ${USERNAME} 2>/dev/null
                  info "User ${WHITE}${USERNAME}${NC} has been deleted.\nThe home folder and contents still exist."
                  echo
                  break 3
                  ;;
                *)
                  warn "Error! Entry must be 'y' or 'n'. Try again..."
                  echo
                  ;;
              esac
            done
            ;;
          [Nn]*)
            while true; do
              read -p "Do you want to try another user name [y/n]?: "  -n 1 -r YN
              echo
              case $YN in
                [Yy]*)
                  echo
                  break 2
                  ;;
                [Nn]*)
                  msg "You have chosen not to proceed. Bye..."
                  echo
                  break 3
                  ;;
                *)
                  warn "Error! Entry must be 'y' or 'n'. Try again..."
                  echo
                  ;;
              esac
            done
            ;;
          *)
            warn "Error! Entry must be 'y' or 'n'. Try again..."
            echo
            ;;
        esac
      done
    else
      msg "User name ${WHITE}'${USERNAME}'${NC} does not exist. Try again...\n"
      unset USERNAME
    fi
  done
}

#---- Other Files ------------------------------------------------------------------

# User file list
touch ${NEW_USERS}

#---- Body -------------------------------------------------------------------------

#---- Create New Power User Accounts
section "Create a New Power User Account"

echo
msg_box "#### PLEASE READ CAREFULLY - CREATING POWER USER ACCOUNTS ####

Power Users are trusted persons with privileged access to data and application resources hosted on your PVE NAS. Power Users are NOT standard users! Standard users are added at a later stage. Each new Power Users security permissions are controlled by Linux groups. Group security permission levels are as follows:

  --  GROUP NAME    -- PERMISSIONS
  --  'medialab'    -- Everything to do with media (i.e movies, series & music)
  --  'homelab'     -- Everything to do with a smart home including 'medialab'
  --  'privatelab'  -- Private storage including 'medialab' & 'homelab' rights
  
A Personal Home Folder will be created for each new user. The folder name is the new users name. You can access Personal Home Folders and other shares via CIFS/Samba and NFS.

Remember your PVE NAS is also pre-configured with user names specifically tasked for running hosted applications (i.e Proxmox LXC,CT,VM - Sonarr, Radarr, Lidarr). These application users names are as follows:

  --  GROUP NAME    -- USER NAME
  --  'medialab'    -- /srv/CT_HOSTNAME/homes/'media'
  --  'homelab'     -- /srv/CT_HOSTNAME/homes/'home'
  --  'privatelab'  -- /srv/CT_HOSTNAME/homes/'private'"
echo
TYPE01="${YELLOW}Create a new Power User Account${NC} - add a new user to the system."
TYPE02="${YELLOW}Delete a Existing Power User Account${NC} - delete a user (permanent)."
TYPE03="${YELLOW}Quit${NC} - quit this Power User account installation."
PS3="Select the action type you want to do (entering numeric) : "
msg "Your choices are:"
options=("$TYPE01" "$TYPE02" "$TYPE03")
select menu in "${options[@]}"; do
  case $menu in
    "$TYPE01")
      USER_TYPE=1
      echo
      break
      ;;
    "$TYPE02")
      USER_TYPE=2
      echo
      break
      ;;
    "$TYPE03")
      USER_TYPE=3
      echo
      msg "You have chosen not to proceed. Moving on..."
      echo
      sleep 1
      break
      ;;
    *) warn "Invalid entry. Try again.." >&2
  esac
done


#---- Create a new users credentials
if [ ${USER_TYPE} = 1 ]; then
  while true; do
    # Create a new username
    while true; do
      input_username_val
      if [ $(egrep "^${USERNAME}" /etc/passwd > /dev/null; echo $?) = 0 ]; then
        warn "The user '${USERNAME}' already exists."
        while true; do
          read -p "Do you want to try another user name [y/n]? " -n 1 -r YN
          echo
          case $YN in
            [Yy]*)
              info "You have chosen to try another user name.\nTry again..."
              echo
              break 1
              ;;
            [Nn]*)
              echo
              break 3
              ;;
            *)
              warn "Error! Entry must be 'y' or 'n'. Try again..."
              echo
              ;;
          esac
        done
      else
        break
      fi
    done
    echo
    msg "Choose your new user's group member account."
    GRP01="Medialab - Everything to do with media (i.e movies, series and music)." >/dev/null
    GRP02="Homelab - Everything to do with a smart home including medialab." >/dev/null
    GRP03="Privatelab - Private storage including medialab & homelab rights." >/dev/null
    PS3="Select your new user's group member account (entering numeric) : "
    echo
    select grp_type in "$GRP01" "$GRP02" "$GRP03"; do
      echo
      info "You have selected:\n\t${WHITE}$grp_type${NC}"
      echo
      break
    done
    if [ "$grp_type" = "$GRP01" ]; then
      USERGRP='medialab'
    elif [ "$grp_type" = "$GRP02" ]; then
      USERGRP='homelab -G medialab'
    elif [ "$grp_type" = "$GRP03" ]; then
      USERGRP='privatelab -G medialab,homelab'
    fi
    # Create User password
    input_userpwd_val
    echo
    # Add Username, password, and group to list
    echo "${USERNAME} $USER_PWD $USERGRP" >> ${NEW_USERS}
    # List new user details
    msg "Your new user details are as follows:\n"
    cat ${NEW_USERS} | sed '1 i\USERNAME PASSWORD GROUP' | column -t | indent2
    echo
    while true; do
      read -p "Do you want to create another new power user account [y/n]? " -n 1 -r YN
      echo
      case $YN in
        [Yy]*)
          echo
          break
          ;;
        [Nn]*)
          echo
          break 2
          ;;
        *)
          warn "Error! Entry must be 'y' or 'n'. Try again..."
          echo
          ;;
      esac
    done
  done

  if [ $(cat ${NEW_USERS} | wc -l) -gt 0 ]; then
    # Add user to the system
    while read USER PASSWORD GROUP USERMOD; do
      pass=$(perl -e 'print crypt($ARGV[0], 'password')' $PASSWORD)
      if [ -d "${HOME_BASE}/${USER}" ]; then # User home folder pre-existing
        # Chattr set user desktop folder attributes to -a
        while read dir; do
          chattr -i ${HOME_BASE}/${USER}/${dir}/.foo_protect
        done <<< $( ls ${HOME_BASE}/${USER} )
        msg "Creating new user ${USER}..."
        useradd -g ${GROUP} -p ${pass} ${USERMOD} -m -d ${HOME_BASE}/${USER} -s /bin/bash ${USER}
        msg "Creating default home folders (xdg-user-dirs-update)..."
        sudo -iu ${USER} xdg-user-dirs-update
        msg "Creating SSH folder and authorised keys file for user ${USER}..."
        mkdir -p ${HOME_BASE}${USER}/.ssh
        touch ${HOME_BASE}${USER}/.ssh/authorized_keys
        chmod -R 0700 ${HOME_BASE}${USER}
        chown -R ${USER}:${GROUP} ${HOME_BASE}${USER}
        ssh-keygen -o -q -t ed25519 -a 100 -f ${HOME_BASE}${USER}/.ssh/id_${USER,,}_ed25519 -N ""
        cat ${HOME_BASE}${USER}/.ssh/id_${USER,,}_ed25519.pub >> ${HOME_BASE}${USER}/.ssh/authorized_keys
        # Create ppk key for Putty or Filezilla or ProFTPd
        msg "Creating a private PPK key..."
        puttygen ${HOME_BASE}${USER}/.ssh/id_${USER,,}_ed25519 -o ${HOME_BASE}${USER}/.ssh/id_${USER,,}_ed25519.ppk
        msg "Creating a public ProFTPd RFC4716 format compliant key..."
        mkdir -p /etc/proftpd/authorized_keys
        touch /etc/proftpd/authorized_keys/${USER}
        ssh-keygen -e -f ${HOME_BASE}${USER}/.ssh/id_${USER,,}_ed25519.pub >> ${HOME_BASE}${USER}/.ssh/authorized_keys
        ssh-keygen -e -f ${HOME_BASE}${USER}/.ssh/id_${USER,,}_ed25519.pub >> /etc/proftpd/authorized_keys/${USER}
        msg "Backing up ${USER} latest SSH keys..."
        BACKUP_DATE=$(date +%Y%m%d-%T)
        mkdir -p /srv/${HOSTNAME}/sshkey/${HOSTNAME}_users/${USER,,}_${BACKUP_DATE}
        chown -R root:privatelab /srv/${HOSTNAME}/sshkey/${HOSTNAME}_users/${USER,,}_${BACKUP_DATE}
        chmod 0750 /srv/${HOSTNAME}/sshkey/${HOSTNAME}_users/${USER,,}_${BACKUP_DATE}
        cp ${HOME_BASE}${USER}/.ssh/id_${USER,,}_ed25519* /srv/${HOSTNAME}/sshkey/${HOSTNAME}_users/${USER,,}_${BACKUP_DATE}/
        msg "Creating ${USER} smb account..."
        (echo ${PASSWORD}; echo ${PASSWORD} ) | smbpasswd -s -a ${USER}
        info "User $USER has been added to the system. Existing home folder found.\nUsing existing home folder."
        echo
      elif [ ! -d "${HOME_BASE}/${USER}" ]; then # Create new user home folder
        msg "Creating new user ${USER}..."
        useradd -g ${GROUP} -p ${pass} ${USERMOD} -m -d ${HOME_BASE}/${USER} -s /bin/bash ${USER}
        msg "Creating default home folders (xdg-user-dirs-update)..."
        sudo -iu ${USER} xdg-user-dirs-update --force
        msg "Creating SSH folder and authorised keys file for user ${USER}..."
        mkdir -p ${HOME_BASE}${USER}/.ssh
        touch ${HOME_BASE}${USER}/.ssh/authorized_keys
        chmod -R 0700 ${HOME_BASE}${USER}
        chown -R ${USER}:${GROUP} ${HOME_BASE}${USER}
        ssh-keygen -o -q -t ed25519 -a 100 -f ${HOME_BASE}${USER}/.ssh/id_${USER,,}_ed25519 -N ""
        cat ${HOME_BASE}${USER}/.ssh/id_${USER,,}_ed25519.pub >> ${HOME_BASE}${USER}/.ssh/authorized_keys
        # Create ppk key for Putty or Filezilla or ProFTPd
        msg "Creating a private PPK key..."
        puttygen ${HOME_BASE}${USER}/.ssh/id_${USER,,}_ed25519 -o ${HOME_BASE}${USER}/.ssh/id_${USER,,}_ed25519.ppk
        msg "Creating a public ProFTPd RFC4716 format compliant key..."
        mkdir -p /etc/proftpd/authorized_keys
        touch /etc/proftpd/authorized_keys/${USER}
        ssh-keygen -e -f ${HOME_BASE}${USER}/.ssh/id_${USER,,}_ed25519.pub >> ${HOME_BASE}${USER}/.ssh/authorized_keys
        ssh-keygen -e -f ${HOME_BASE}${USER}/.ssh/id_${USER,,}_ed25519.pub >> /etc/proftpd/authorized_keys/${USER}
        msg "Backing up ${USER} latest SSH keys..."
        BACKUP_DATE=$(date +%Y%m%d-%T)
        mkdir -p /srv/${HOSTNAME}/sshkey/${HOSTNAME}_users/${USER,,}_${BACKUP_DATE}
        chown -R root:privatelab /srv/${HOSTNAME}/sshkey/${HOSTNAME}_users/${USER,,}_${BACKUP_DATE}
        chmod 0750 /srv/${HOSTNAME}/sshkey/${HOSTNAME}_users/${USER,,}_${BACKUP_DATE}
        cp ${HOME_BASE}${USER}/.ssh/id_${USER,,}_ed25519* /srv/${HOSTNAME}/sshkey/${HOSTNAME}_users/${USER,,}_${BACKUP_DATE}/
        msg "Creating ${USER} smb account..."
        (echo ${PASSWORD}; echo ${PASSWORD} ) | smbpasswd -s -a ${USER}
        info "User '${USER}' has been added to the system."
        echo
      fi
      # Chattr set user desktop folder attributes to +i
      while read dir; do
        touch ${HOME_BASE}${USER}/${dir}/.foo_protect
        chattr +i ${HOME_BASE}${USER}/${dir}/.foo_protect
      done <<< $( ls ${HOME_BASE}${USER} )
    done <<< $( cat ${NEW_USERS} )

    #---- Email User SSH Keys
    if [ $(dpkg -s ssmtp >/dev/null 2>&1; echo $?) = 0 ] && [ $(grep -qs "^root:*" /etc/ssmtp/revaliases >/dev/null; echo $?) = 0 ]; then
      section "Email User Credentials & SSH keys"
      echo
      msg_box "#### PLEASE READ CAREFULLY - EMAIL NEW USER CREDENTIALS ####\n
      You can email a new user's login credentials and ssh keys to the NAS system administrator. The NAS system administrator can then forward the email(s) to each new user.

      The email will include the following information and attachments:
        --  Username
        --  Password
        --  User Group
        --  Private SSH Key (Standard)
        --  Private SSH Key (PPK Version)
        --  SMB NAS Server connection credentials
        --  SMB Status
        --  SFTP NAS connection credentials
        --  Account type (folder access level)"
      echo
      while true; do
        read -p "Email new users credentials & SSH key to your system’s administrator [y/n]? " -n 1 -r YN
        echo
        case $YN in
          [Yy]*)
            while read USER PASSWORD GROUP USERMOD; do
              source ${DIR}/email_templates/pve_nas_ct_newuser_msg.sh
              msg "Sending '${USER}' credentials and ssh key package to $(grep -r "root=.*" /etc/ssmtp/ssmtp.conf | grep -v "#" | sed -e 's/root=//g')..."
              sendmail -t < email_body.html
              info "Email sent. Check your system administrators inbox."
            done <<< $( cat ${NEW_USERS} )
            break
            ;;
          [Nn]*)
            info "You have chosen to skip this step. Not sending any email(s)."
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
    echo
  else
    msg "No new users have been created."
    echo
  fi
fi

#---- Delete a existing user
if [ ${USER_TYPE} = 2 ]; then
  delete_username
fi

#---- Finish Line ------------------------------------------------------------------
section "Completion Status."

msg "${WHITE}Success.${NC}"
echo

# Cleanup
if [ -z "${PARENT_EXEC+x}" ]; then
  trap cleanup EXIT
fi