#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_ct_deleteuser.sh
# Description:  Delete a PVE NAS User
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

# Command to run script
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/main/src/ubuntu/pve_nas_ct_addjailuser.sh)"

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SRC_DIR="$DIR/../../common/pve/src"

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source $COMMON_PVE_SRC_DIR/pvesource_bash_defaults.sh

# Install libcrack2
if [[ ! $(dpkg -s libcrack2) ]]
then
  apt-get install -y libcrack2 > /dev/null
fi

# Check user is root
if [ ! "$(id -u)" = 0 ]
then
  warn "This script needs to run under 'root'. Exiting in 2 seconds.\nTry again..."
  sleep 2
  exit 0
fi

# Check PVE host SMTP status
check_smtp_status
if [ "$SMTP_STATUS" = 0 ]
then
  display_msg='\nBefore proceeding with this installer we RECOMMEND you first configure all PVE hosts to support SMTP email services. A working SMTP server emails the NAS System Administrator all new User login credentials, SSH keys, application specific login credentials and written guidelines. A PVE host SMTP server makes NAS administration much easier. Also be alerted about unwarranted login attempts and other system critical alerts. PVE Host SMTP Server installer is available in our PVE Host Toolbox located at GitHub:\n\n    --  https://github.com/ahuacate/pve-host\n'
fi

#---- Static Variables -------------------------------------------------------------

# Homes folder
HOSTNAME=$(hostname)
CHROOT="/srv/$HOSTNAME/homes/chrootjail"
HOME_BASE="$CHROOT/homes"
GROUP='chrootjail'

# Easy Script Section Header Body Text
SECTION_HEAD='PVE NAS'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Creating PVE NAS Jailed Users

section "Create a Restricted and Jailed User Account"
echo
msg_box "#### PLEASE READ CAREFULLY - RESTRICTED & JAILED USER ACCOUNTS ####\n
$(if [ "$SMTP_STATUS" = 0 ]; then echo -e ${display_msg}; fi)
A Jailed user is restricted to their own home folder with optional access to NAS shared data. In Linux this is called a chroot jail. Different levels of restrictions can be applied to each newly created user. This technique can be quite useful if you want a particular user to be provided with a limited system environment, limited folder access and at the same time keep them separate from your main server system and other personal data.

The chroot technique will automatically jail selected users belonging to the 'chrootjail' user group upon ssh or sftp login.

An example of a jailed user is a person who has remote access to your PVE NAS but is restricted to your video library (series, movies, documentary), public folders and their home folder for cloud storage only. Remote access to your PVE NAS is restricted to sftp, ssh and rsync using private SSH ed25519 encrypted keys.

Default 'chrootjail' group permission options are:
  --  GROUP NAME     -- USER NAME
      chrootjail        /srv/$HOSTNAME/homes/chrootjail/'username_injail'

Selectable jail folder permission levels for each new user:
  --  LEVEL 1        -- FOLDER
      -rwx------        /srv/$HOSTNAME/homes/chrootjail/'username_injail'
      Bind Mounts       (mounted at ~/public folder)
      -rwxrwxrw-        /srv/$HOSTNAME/homes/chrootjail/'username_injail'/public

  --  LEVEL 2        -- FOLDER
      -rwx------        /srv/$HOSTNAME/homes/chrootjail/'username_injail'
      Bind Mounts       (mounted at ~/share folder)
      -rwxrwxrw-        /srv/$HOSTNAME/downloads/user/'username_downloads'
      -rwxrwxrw-        /srv/$HOSTNAME/photo/'username_photo'
      -rwxrwxrw-        /srv/$HOSTNAME/public
      -rwxrwxrw-        /srv/$HOSTNAME/video/homevideo/'username_homevideo'
      -rwxr-----        /srv/$HOSTNAME/video/movies
      -rwxr-----        /srv/$HOSTNAME/video/series
      -rwxr-----        /srv/$HOSTNAME/video/documentary

  --  LEVEL 3        -- FOLDER
      -rwx------        /srv/$HOSTNAME/homes/chrootjail/'username_injail'
      Bind Mounts       (mounted at ~/share folder)
      -rwxr-----        /srv/$HOSTNAME/audio
      -rwxr-----        /srv/$HOSTNAME/books
      -rwxrwxrw-        /srv/$HOSTNAME/downloads/user/'username_downloads'
      -rwxr-----        /srv/$HOSTNAME/music
      -rwxrwxrw-        /srv/$HOSTNAME/photo/'username_photo'
      -rwxrwxrw-        /srv/$HOSTNAME/public
      -rwxrwxrw-        /srv/$HOSTNAME/video/homevideo/'username_homevideo'
      -rwxr-----        /srv/$HOSTNAME/video (All)

All Home folders are automatically suffixed: 'username_injail'."
echo
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE00" )
OPTIONS_LABELS_INPUT=( "Jailed User Account - add a new user to the system" \
"None. Exit this User account installer" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"


#---- Create a new jailed user
if [ "$RESULTS" = TYPE01 ]
then
  #---- Checking Prerequisites
  section "Checking Prerequisites."
  # Checking SSHD status
  msg "Checking SSHD status ..."
  if [ "$(systemctl is-active --quiet sshd; echo $?)" = 0 ]
  then
    info "SSHD status: ${GREEN}active${NC}."
    sshd_status=0
    pre_check_01=0
  else
    info "SSHD status: ${RED}inactive (dead).${NC}. Your intervention is required."
    sshd_status=1
    pre_check_01=1
  fi
  echo
  # Checking for Chrootjail group
  msg "Checking chrootjail group status..."
  if [ "$(getent group chrootjail >/dev/null; echo $?)" = 0 ]
  then
    info "chrootjail status: ${GREEN}active${NC}."
    pre_check_02=0
  else
    info "chrootjail status: ${RED}inactive - non existant${NC}."
    pre_check_02=1
  fi
  echo
  # Checking for Chroot rsync
  msg "Checking for chroot rsync component..."
  if [ -f "$CHROOT/usr/bin/rsync" ]
  then
    info "chrootjail rsync component: ${GREEN}active${NC}."
    pre_check_03=0
  else
    info "chrootjail rsync component: ${RED}inactive - non existant${NC}.\nusr/bin/rsync is missing."
    pre_check_03=1
  fi
  echo
  # Checking for sshd Chrootjail Match Group
  msg "Checking for sshd chrootjail match group..."
  if [ "$(grep -Fxq "Match Group chrootjail" /etc/ssh/sshd_config > /dev/null; echo $?)" = 0 ]
  then
    info "sshd chrootjail match group status: ${GREEN}active${NC}."
    pre_check_04=0
  else
    info "sshd chrootjail match group status: ${RED}inactive - non existant${NC}.\nMatch group chrootjail is missing."
    pre_check_04=1
  fi
  echo
  # Checking for Subsystem sftp setting
  msg "Checking sshd Subsystem sftp setting..."
  if [ "$(grep -Fxq "Subsystem       sftp    internal-sftp" /etc/ssh/sshd_config > /dev/null; echo $?)" = 0 ]
  then
    info "sshd subsystem sftp status: ${GREEN}active${NC}."
    pre_check_05=0
  else
    info "sshd subsystem sftp status: ${RED}incorrect${NC}.\nCurrent set as /usr/libexec/openssh/sftp-server."
    pre_check_05=1
  fi
  echo

  # Check Results
  msg "Prerequisites check status..."
  if [ "$pre_check_01" = 0 ] && [ "$pre_check_02" = 0 ] && [ "$pre_check_03" = 0 ] && [ "$pre_check_04" = 0 ] && [ "$pre_check_05" = 0 ]
  then
    pre_check_install=1
    info "Prerequisite check status: ${GREEN}GOOD TO GO${NC}."
    echo
  elif [ "$pre_check_01" = 1 ] && [ "$pre_check_02" = 0 ] && [ "$pre_check_03" = 0 ] && [ "$pre_check_04" = 0 ] && [ "$pre_check_05" = 0 ]
  then
    pre_check_install=0
    warn "User intervention required.\nYou can enable SSHD in the next steps.\n Proceeding with installation."
    echo
  elif [ "$pre_check_01 "= 1 ] || [ "$pre_check_01" = 0 ] && [ $pre_check_02 = 1 ] && [ "$pre_check_03" = 0 ] || [ "$pre_check_03" = 1 ] && [ "$pre_check_04" = 0 ] && [ "$pre_check_05" = 0 ]
  then
    pre_check_install=1
    warn "User intervention required. Missing chrootjail user group.\nExiting installation script in 3 second."
    echo
    sleep 3
    exit 0
  elif [ "$pre_check_01" = 1 ] || [ "$pre_check_01" = 0 ] && [ "$pre_check_02" = 0 ] || [ "$pre_check_02" = 1 ] && [ "$pre_check_03" = 1 ] && [ "$pre_check_04" = 0 ] && [ "$pre_check_05" = 0 ]
  then
    pre_check_install=1
    if [ "$pre_check_02" = 1 ]
    then
      warn "User intervention required. Missing chrootjail user group."
    fi
    warn "User intervention required. Missing chroot components.\nExiting installation script in 3 second."
    echo
    sleep 3
    exit 0
  elif [ "$pre_check_01" = 1 ] || [ "$pre_check_01" = 0 ] && [ "$pre_check_02" = 0 ] || [ "$pre_check_02" = 1 ] && [ "$pre_check_03" = 0 ] || [ "$pre_check_03" = 1 ] && [ "$pre_check_04" = 1 ] && [ "$pre_check_05" = 0 ]
  then
    pre_check_install=1
    if [ "$pre_check_02" = 1 ]
    then
      warn "User intervention required. Missing chrootjail user group."
    fi
    if [ "$pre_check_03" = 1 ]
    then
      warn "User intervention required. Missing chroot components."
    fi
    warn "User intervention required. Missing sshd chrootjail match group settings.\nExiting installation script in 3 second."
    echo
    sleep 3
    exit 0
  elif [ "$pre_check_01" = 1 ] || [ "$pre_check_01" = 0 ] && [ "$pre_check_02" = 0 ] || [ "$pre_check_02" = 1 ] && [ "$pre_check_03" = 0 ] || [ "$pre_check_03" = 1 ] && [ "$pre_check_04" = 1 ] || [ "$pre_check_04" = 0 ] && [ "$pre_check_05" = 1 ]
  then
    pre_check_install=1
    if [ "$pre_check_02" = 1 ]
    then
      warn "User intervention required. Missing chrootjail user group."
    fi
    if [ "$pre_check_03" = 1 ]
    then
      warn "User intervention required. Missing chroot components."
    fi
    if [ "$pre_check_04" = 1 ]
    then
      warn "User intervention required. Missing sshd chrootjail match group settings."
    fi
    warn "User intervention required. sshd subsystem sftp is incorrect.\nExiting installation script in 3 second."
    echo
    sleep 3
    exit 0
  fi

  #---- Installing Prerequisites
  if [ "$pre_check_install" = 0 ]
  then
    section "Installing or enabling prerequisites."
    # Enable SSH Server
    if [ "$sshd_status" = 1 ] && [ "$pre_check_01" = 1 ]
    then
      msg_box "#### PLEASE READ CAREFULLY - ENABLE SSH SERVER ####\n
      If you want to use SSH (Rsync/SFTP) to connect to your PVE NAS then your SSH Server must be enabled. You need SSH to perform any of the following tasks:

        --  Secure SSH connection to this PVE NAS.
        --  Perform a secure RSync Backup to this PVE NAS.

      We also recommend you change the default SSH port '22' for added security. For added security we restrict all SSH, RSYNC and SFTP access for all chrootjail users to their chrootjail home folder only."
      echo
      while true
      do
        read -p "Enable SSH Server on your PVE NAS (NAS) [y/n]? " -n 1 -r YN
        echo
        case $YN in
          [Yy]*)
            sshd_status=0
            # Start SSH service
            if [ ! $(systemctl is-active ssh.service) = 'active' ]
            then
              msg "Enabling SSHD server..."
              systemctl start ssh.service
              systemctl enable ssh.service &> /dev/null
              while true
              do
                if [ $(systemctl is-active ssh.service) = 'active' ]
                then
                  info "OpenBSD Secure Shell server: ${GREEN}active (running).${NC}"
                  echo
                  break
                fi
                sleep 1
              done
            fi
            ;;
          [Nn]*)
            sshd_status=1
            msg "You have chosen to disable SSH server. Your users will NOT be able to use SSH (Rsync/SFTP) services."
            # Disable SSH service
            if [ "$(systemctl is-active ssh.service)" = 'active' ]
            then
              msg "Disabling SSHD server..."
              systemctl stop ssh.service
              systemctl disable ssh.service &> /dev/null
              while true
              do
                if [ ! "$(systemctl is-active ssh.service)" = 'active' ]
                then
                  info "OpenBSD Secure Shell server: ${RED}inactive (dead).${NC} (and disabled)"
                  echo
                  break
                fi
                sleep 1
              done
            fi
            ;;
          *)
            warn "Error! Entry must be 'y' or 'n'. Try again..."
            echo
            ;;
        esac
      done
    fi
  fi


  #---- Create New Jailed User Accounts
  section "Create a Jailed User Account"

  # Create new user list
  new_user_LIST=()

  # Create a new user credentials
  while true
  do
    # Create a new username
    while true
    do
      input_username_val
      USERNAME=${USERNAME,,}_injail
      msg "All jailed usernames are automatically suffixed: ${YELLOW}$USERNAME${NC}. Checking username availability..."
      if [ "$(id -u $USERNAME 2>/dev/null; echo $?)" = 0 ] || [ "$(egrep "${USERNAME}" /etc/passwd > /dev/null; echo $?)" = 0 ]
      then
        warn "The user '$USERNAME' already exists."
        while true
        do
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
    msg "Every new jailed user account has a private Home folder and a optional level of access to other PVE NAS shared folders. Choosing the level of shared folder access sets restrictions you want to apply to the new user."
    msg "Select your new users folder access rights ..."
    OPTIONS_VALUES_INPUT=( "LEVEL01" "LEVEL02" "LEVEL03" )
    OPTIONS_LABELS_INPUT=( "Home + Shared Public folder only" \
    "Home + Shared Public, Photo, Video (Movies, Series, Documentary, Homevideo) folders" \
    "Home + Shared Public, Photo, Video (all), Music, Audio & Books folders" )
    makeselect_input2
    singleselect SELECTED "$OPTIONS_STRING"
    # Set type
    JAIL_TYPE="$RESULTS"

    # Create pwd
    input_userpwd_val
    echo
    # Add Username, password, and group to list
    new_user_LIST+=( "$USERNAME $USER_PWD $GROUP $JAIL_TYPE" )
    # List new user details
    msg "Your new user details are as follows:\n"
    printf '%s\n' "${new_user_LIST[@]}" | sed '1 i\USERNAME PASSWORD GROUP LEVEL' | column -t | indent2
    echo
    # Option to create another user account
    msg "Do you want to create another new jailed user account..."
    OPTIONS_VALUES_INPUT=( "NO" "YES" )
    OPTIONS_LABELS_INPUT=( "No - I do not want to create another user account" \
    "Yes - I want to create another user account" )
    makeselect_input2
    singleselect SELECTED "$OPTIONS_STRING"
    if [ "$RESULTS" = YES ]
    then
      echo
    elif [ "$RESULTS" = NO ]
    then
      break
    fi
  done

  if [ ! "${#new_user_LIST[@]}" = 0 ]
  then
    #---- Adding new user to the system
    while read USER PASSWORD GROUP JAIL_TYPE
    do
      # Chattr set user desktop folder attributes to -a
      if [ -d "$HOME_BASE/$USER" ]
      then
        while read dir
        do
          chattr -i $HOME_BASE/$USER/$dir/.foo_protect
        done < <( ls $HOME_BASE/$USER )
      fi
      section "Adding new username '$USER'"
      pass=$(perl -e 'print crypt($ARGV[0], 'password')' $PASSWORD)
      # Backup any existing user SSH keys
      if [ -f "$HOME_BASE/$USER/.ssh/id_${USER,,}_ed25519" ]
      then
        msg_box "#### PLEASE READ CAREFULLY - PREVIOUS USER SSH KEYS ####\n\nA existing set of '$USER' SSH keys already exist. A backup copy of the SSH keys will be saved in the /srv/$HOSTNAME/sshkey folder'."
        echo
        msg "Backing up your old user $USER SSH keys..."
        backup_date=$(date +%Y%m%d-%T)
        mkdir -p /srv/$HOSTNAME/sshkey/${HOSTNAME}_users/${USER,,}_${backup_date}
        chown -R root:privatelab /srv/$HOSTNAME/sshkey/${HOSTNAME}_users/${USER,,}_${backup_date}
        chmod 0750 /srv/$HOSTNAME/sshkey/${HOSTNAME}_users/${USER,,}_${backup_date}
        cp $HOME_BASE/$USER/.ssh/id_${USER,,}_ed25519* /srv/$HOSTNAME/sshkey/${HOSTNAME}_users/${USER,,}_${backup_date}/ 2>/dev/null
        info "Old $USER SSH keys backup complete."
        echo
        msg "Deleting old $USER SSH folder..."
        rm -R $HOME_BASE/$USER/.ssh 2>/dev/null
        info "Old $USER SSH folder deleted."
        SSHKEY_BACKUP=0
        echo
      else
        SSHKEY_BACKUP=1
      fi
      #Creating new user accounts
      msg "Creating new user $USER..."
      useradd -g $GROUP -p $pass -m -d $HOME_BASE/$USER -s /bin/bash $USER
      msg "Fixing $USER home folder location to ${GROUP} setup..."
      awk -v user="$USER" -v path="/homes/$USER" 'BEGIN{FS=OFS=":"}$1==user{$6=path}1' /etc/passwd > temp_file
      mv temp_file /etc/passwd
      msg "Copy $USER password to chrooted /etc/passwd..."
      cat /etc/passwd | grep $USER >> $CHROOT/etc/passwd
      msg "Creating SSH folder and authorised keys file for user $USER..."
      mkdir -p $HOME_BASE/$USER/.ssh
      touch $HOME_BASE/$USER/.ssh/authorized_keys
      chmod -R 0700 $HOME_BASE/$USER
      msg "Creating $USER smb account..."
      (echo ${PASSWORD}; echo ${PASSWORD} ) | smbpasswd -s -a $USER
      info "User created: ${YELLOW}$USER${NC} of group ${GROUP}"
      echo
      msg "Creating new SSH keys for user $USER..." 
      ssh-keygen -o -q -t ed25519 -a 100 -f $HOME_BASE/$USER/.ssh/id_${USER,,}_ed25519 -N ""
      cat $HOME_BASE/$USER/.ssh/id_${USER,,}_ed25519.pub >> $HOME_BASE/$USER/.ssh/authorized_keys
      # Create ppk key for Putty or Filezilla
      msg "Creating a private PPK key..."
      puttygen $HOME_BASE/$USER/.ssh/id_${USER,,}_ed25519 -o $HOME_BASE/$USER/.ssh/id_${USER,,}_ed25519.ppk
      msg "Creating a public ProFTPd RFC4716 format compliant key..."
      mkdir -p /etc/proftpd/authorized_keys
      touch /etc/proftpd/authorized_keys/$USER
      ssh-keygen -e -f $HOME_BASE/$USER/.ssh/id_${USER,,}_ed25519.pub >> $HOME_BASE/$USER/.ssh/authorized_keys
      ssh-keygen -e -f $HOME_BASE/$USER/.ssh/id_${USER,,}_ed25519.pub >> /etc/proftpd/authorized_keys/$USER
      msg "Backing up $USER latest SSH keys..."
      backup_date=$(date +%Y%m%d-%T)
      mkdir -p /srv/$HOSTNAME/sshkey/${HOSTNAME}_users/${USER,,}_${backup_date}
      chown -R root:privatelab /srv/$HOSTNAME/sshkey/${HOSTNAME}_users/${USER,,}_${backup_date}
      chmod 0750 /srv/$HOSTNAME/sshkey/${HOSTNAME}_users/${USER,,}_${backup_date}
      cp $HOME_BASE/$USER/.ssh/id_${USER,,}_ed25519* /srv/$HOSTNAME/sshkey/${HOSTNAME}_users/${USER,,}_${backup_date}/
      chown -R $USER:$GROUP $HOME_BASE/$USER
      info "User $USER SSH keys have been added to the system.\nA backup of your $USER SSH keys is stored in your sshkey folder." || warn "Failed adding user $USER SSH keys!"
      echo

      # Setting Bind Mounts
      msg "Creating $USER default home folders..."
      mkdir -p $HOME_BASE/$USER/{backup,backup/{mobile,pc},documents,music,photo,video} 
      chmod 0750 $HOME_BASE/$USER/{backup,backup/{mobile,pc},documents,music,photo,video}
      chown -R $USER:$GROUP $HOME_BASE/$USER
      info "$USER default home folders: ${YELLOW}Success${NC}"
      echo

      # Checking for previous chattr locks
      if [ -d "/srv/$HOSTNAME/downloads/user/$(echo "$USERNAME" | awk -F '_' '{print $1}')_downloads" ]
      then
        chattr -i /srv/$HOSTNAME/downloads/user/$(echo "$USERNAME" | awk -F '_' '{print $1}')_downloads/.foo_protect
      fi
      if [ -d "/srv/$HOSTNAME/photo/$(echo "$USERNAME" | awk -F '_' '{print $1}')_photo" ]
      then
        chattr -i /srv/$HOSTNAME/photo/$(echo "$USERNAME" | awk -F '_' '{print $1}')_photo/.foo_protect
      fi
      if [ -d "/srv/$HOSTNAME/video/homevideo/$(echo "$USERNAME" | awk -F '_' '{print $1}')_homevideo" ]
      then
        chattr -i /srv/$HOSTNAME/video/homevideo/$(echo "$USERNAME" | awk -F '_' '{print $1}')_homevideo/.foo_protect
      fi

      # Level 01 Bind mounts
      if [ "$JAIL_TYPE" = LEVEL01 ]
      then
        mkdir -p $HOME_BASE/$USER/public
        chmod 0750 $HOME_BASE/$USER/public
        chown -R $USER:$GROUP $HOME_BASE/$USER/public
        # Create shared public bind mount
        if [ -d "/srv/$HOSTNAME/public" ] && [ "$(grep -qs $HOME_BASE/$USER/public /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/public bind mount..."
          echo "/srv/$HOSTNAME/public $HOME_BASE/$USER/public none bind,rw,xattr,acl 0 0" >> /etc/fstab
          mount $HOME_BASE/$USER/public
          info "Bind mount status: ${YELLOW}Success${NC}"
          echo
        elif [ -d "/srv/$HOSTNAME/public" ] && [ "$(grep -qs $HOME_BASE/$USER/public /proc/mounts > /dev/null; echo $?)" = 0 ]
        then
          msg "Creating /srv/$HOSTNAME/public bind mount..."
          info "Bind mount status: ${YELLOW}Success${NC}\nUsing existing mount."
          echo
        elif [ ! -d "/srv/$HOSTNAME/public" ] && [ "$(grep -qs $HOME_BASE/$USER/public /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/public bind mount..."
          warn "Bind mount status: ${RED}Failed${NC}\n Mount point /srv/$HOSTNAME/public does not exist.\nSkipping this mount point."
          echo
        fi

      # Level 02 Bind mounts
      elif [ "$JAIL_TYPE" = LEVEL02 ]
      then
        msg "Creating $USER share mount point folders..."
        mkdir -p $HOME_BASE/$USER/share
        mkdir -p $HOME_BASE/$USER/share/{downloads,photo,public,video}
        chown -R $USER:$GROUP $HOME_BASE/$USER/share
        chmod -R 0750 $HOME_BASE/$USER/share
        # Create shared downloads bind mount
        if [ -d "/srv/$HOSTNAME/downloads" ] && [ "$(grep -qs $HOME_BASE/$USER/share/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/downloads bind mount..."
          mkdir -p /srv/$HOSTNAME/downloads/{user,user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads}
          chown -R $USER:$GROUP /srv/$HOSTNAME/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads
          chmod 0750 /srv/$HOSTNAME/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads
          setfacl -Rm d:u:$USER:rwx,g:$GROUP:000,g:medialab:rwx,g:privatelab:rwx /srv/$HOSTNAME/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads
          echo "/srv/$HOSTNAME/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads $HOME_BASE/$USER/share/downloads none bind,rw,xattr,acl 0 0" >> /etc/fstab
          mount $HOME_BASE/$USER/share/downloads
          # Chattr set folder attributes to +i
          touch /srv/$HOSTNAME/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads/.foo_protect
          chattr +i /srv/$HOSTNAME/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads/.foo_protect
          info "Bind mount status: ${YELLOW}Success${NC}"
        elif [ -d "/srv/$HOSTNAME/downloads" ] && [ "$(grep -qs $HOME_BASE/$USER/share/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads /proc/mounts > /dev/null; echo $?)" = 0 ]
        then
          msg "Creating /srv/$HOSTNAME/downloads bind mount..."
          info "Bind mount status: ${YELLOW}Success${NC}\nUsing existing mount."
        elif [ ! -d "/srv/$HOSTNAME/downloads" ] && [ "$(grep -qs $HOME_BASE/$USER/share/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/downloads bind mount..."
          warn "Bind mount status: ${RED}Failed${NC}\n Mount point /srv/$HOSTNAME/downloads does not exist.\nSkipping this mount point."
        fi
        # Create shared public bind mount
        if [ -d "/srv/$HOSTNAME/public" ] && [ "$(grep -qs $HOME_BASE/$USER/share/public /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/public bind mount..."
          echo "/srv/$HOSTNAME/public $HOME_BASE/$USER/share/public none bind,rw,xattr,acl 0 0" >> /etc/fstab
          mount $HOME_BASE/$USER/share/public
          info "Bind mount status: ${YELLOW}Success${NC}"
        elif [ -d "/srv/$HOSTNAME/public" ] && [ "$(grep -qs $HOME_BASE/$USER/share/public /proc/mounts > /dev/null; echo $?)" = 0 ]
        then
          msg "Creating /srv/$HOSTNAME/public bind mount..."
          info "Bind mount status: ${YELLOW}Success${NC}\nUsing existing mount."
        elif [ ! -d "/srv/$HOSTNAME/public" ] && [ "$(grep -qs $HOME_BASE/$USER/share/public /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/public bind mount..."
          warn "Bind mount status: ${RED}Failed${NC}\n Mount point /srv/$HOSTNAME/public does not exist.\nSkipping this mount point."
        fi
        # Create shared photo bind mount
        if [ -d "/srv/$HOSTNAME/photo" ] && [ "$(grep -qs $HOME_BASE/$USER/share/photo /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/photo bind mount..."
          mkdir -p /srv/$HOSTNAME/photo/$(echo "$USER" | awk -F '_' '{print $1}')_photo
          chown -R $USER:$GROUP /srv/$HOSTNAME/photo/$(echo "$USER" | awk -F '_' '{print $1}')_photo
          chmod 1750 /srv/$HOSTNAME/photo/$(echo "$USER" | awk -F '_' '{print $1}')_photo
          setfacl -Rm g:$GROUP:rx,g:medialab:rx,g:privatelab:rwx,d:u:$USER:rwx /srv/$HOSTNAME/photo/$(echo "$USER" | awk -F '_' '{print $1}')_photo
          echo "/srv/$HOSTNAME/photo $HOME_BASE/$USER/share/photo none bind,rw,xattr,acl 0 0" >> /etc/fstab
          mount $HOME_BASE/$USER/share/photo
          # Chattr set folder attributes to +i
          touch /srv/$HOSTNAME/photo/$(echo "$USER" | awk -F '_' '{print $1}')_photo/.foo_protect
          chattr +i /srv/$HOSTNAME/photo/$(echo "$USER" | awk -F '_' '{print $1}')_photo/.foo_protect
          info "Bind mount status: ${YELLOW}Success${NC}"
        elif [ -d "/srv/$HOSTNAME/photo" ] && [ "$(grep -qs $HOME_BASE/$USER/share/photo /proc/mounts > /dev/null; echo $?)" = 0 ]
        then
          msg "Creating /srv/$HOSTNAME/photo bind mount..."
          info "Bind mount status: ${YELLOW}Success${NC}\nUsing existing mount."
        elif [ ! -d "/srv/$HOSTNAME/photo" ] && [ "$(grep -qs $HOME_BASE/$USER/share/photo /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/photo bind mount..."
          warn "Bind mount status: ${RED}Failed${NC}\n Mount point /srv/$HOSTNAME/photo does not exist.\nSkipping this mount point."
        fi
        # Create shared video bind mount
        if [ -d "/srv/$HOSTNAME/video" ] && [ "$(grep -qs $HOME_BASE/$USER/share/video /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/video bind mount..."
          mkdir -p /srv/$HOSTNAME/video/homevideo/$(echo "$USER" | awk -F '_' '{print $1}')_homevideo
          chown -R $USER:$GROUP /srv/$HOSTNAME/video/homevideo/$(echo "$USER" | awk -F '_' '{print $1}')_homevideo
          chmod -R 1750 /srv/$HOSTNAME/video/homevideo/$(echo "$USER" | awk -F '_' '{print $1}')_homevideo
          setfacl -Rm g:$GROUP:rx,g:medialab:rx,g:privatelab:rwx,d:u:$USER:rwx /srv/$HOSTNAME/video/homevideo/$(echo "$USER" | awk -F '_' '{print $1}')_homevideo
          if [ -d /srv/$HOSTNAME/video/pron ]
          then
            chattr -i /srv/$HOSTNAME/video/pron/.foo_protect
            setfacl -Rm u:$USER:000 /srv/$HOSTNAME/video/pron
            chattr +i /srv/$HOSTNAME/video/pron/.foo_protect
          fi
          echo "/srv/$HOSTNAME/video $HOME_BASE/$USER/share/video none bind,rw,xattr,acl 0 0" >> /etc/fstab
          # Chattr set folder attributes to +i
          touch /srv/$HOSTNAME/video/homevideo/$(echo "$USER" | awk -F '_' '{print $1}')_homevideo/.foo_protect
          chattr +i /srv/$HOSTNAME/video/homevideo/$(echo "$USER" | awk -F '_' '{print $1}')_homevideo/.foo_protect
          mount $HOME_BASE/$USER/share/video
          info "Bind mount status: ${YELLOW}Success${NC}"
        elif [ -d "/srv/$HOSTNAME/video" ] && [ "$(grep -qs $HOME_BASE/$USER/share/video /proc/mounts > /dev/null; echo $?)" = 0 ]
        then
          msg "Creating /srv/$HOSTNAME/video bind mount..."
          if [ -d "/srv/$HOSTNAME/video/pron" ]
          then
            setfacl -Rm u:$USER:000 /srv/$HOSTNAME/video/pron
          fi
          info "Bind mount status: ${YELLOW}Success${NC}\nUsing existing mount."
        elif [ ! -d "/srv/$HOSTNAME/video" ] && [ "$(grep -qs $HOME_BASE/$USER/share/video /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/video bind mount..."
          warn "Bind mount status: ${RED}Failed${NC}\n Mount point /srv/$HOSTNAME/video does not exist.\nSkipping this mount point."
        fi

      #Level 03 Bind mounts
      elif [ "$JAIL_TYPE" = LEVEL03 ]
      then
        msg "Creating $USER share mount point folders..."
        mkdir -p $HOME_BASE/$USER/share
        mkdir -p $HOME_BASE/$USER/share/{audio,books,downloads,music,photo,public,video}
        chown -R $USER:$GROUP $HOME_BASE/$USER/share
        chmod -R 0750 $HOME_BASE/$USER/share
        # Create shared audio bind mount
        if [ -d "/srv/$HOSTNAME/audio" ] && [ "$(grep -qs $HOME_BASE/$USER/share/audio /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/audio bind mount..."
          echo "/srv/$HOSTNAME/audio $HOME_BASE/$USER/share/audio none bind,ro,xattr,acl 0 0" >> /etc/fstab
          mount $HOME_BASE/$USER/share/audio
          info "Bind mount status: ${YELLOW}Success${NC}"
        elif [ -d "/srv/$HOSTNAME/audio" ] && [ "$(grep -qs $HOME_BASE/$USER/share/audio /proc/mounts > /dev/null; echo $?)" = 0 ]
        then
          msg "Creating /srv/$HOSTNAME/audio bind mount..."
          info "Bind mount status: ${YELLOW}Success${NC}\nUsing existing mount."
        elif [ ! -d "/srv/$HOSTNAME/audio" ] && [ "$(grep -qs $HOME_BASE/$USER/share/audio /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/audio bind mount..."
          warn "Bind mount status: ${RED}Failed${NC}\n Mount point /srv/$HOSTNAME/audio does not exist.\nSkipping this mount point."
        fi
        # Create shared books bind mount
        if [ -d "/srv/$HOSTNAME/books" ] && [ "$(grep -qs $HOME_BASE/$USER/share/books /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/books bind mount..."
          echo "/srv/$HOSTNAME/books $HOME_BASE/$USER/share/books none bind,ro,xattr,acl 0 0" >> /etc/fstab
          mount $HOME_BASE/$USER/share/books
          info "Bind mount status: ${YELLOW}Success${NC}"
        elif [ -d "/srv/$HOSTNAME/books" ] && [ "$(grep -qs $HOME_BASE/$USER/share/books /proc/mounts > /dev/null; echo $?)" = 0 ]
        then
          msg "Creating /srv/$HOSTNAME/books bind mount..."
          info "Bind mount status: ${YELLOW}Success${NC}\nUsing existing mount."
        elif [ ! -d "/srv/$HOSTNAME/books" ] && [ "$(grep -qs $HOME_BASE/$USER/share/books /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/books bind mount..."
          warn "Bind mount status: ${RED}Failed${NC}\n Mount point /srv/$HOSTNAME/books does not exist.\nSkipping this mount point."
        fi
        # Create shared downloads bind mount
        if [ -d "/srv/$HOSTNAME/downloads" ] && [ "$(grep -qs $HOME_BASE/$USER/share/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/downloads bind mount..."
          mkdir -p /srv/$HOSTNAME/downloads/{user,user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads}
          chown -R $USER:$GROUP /srv/$HOSTNAME/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads
          chmod 0750 /srv/$HOSTNAME/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads
          setfacl -Rm d:u:$USER:rwx,g:$GROUP:000,g:medialab:rwx,g:privatelab:rwx /srv/$HOSTNAME/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads
          echo "/srv/$HOSTNAME/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads $HOME_BASE/$USER/share/downloads none bind,rw,xattr,acl 0 0" >> /etc/fstab
          # Chattr set folder attributes to +i
          touch /srv/$HOSTNAME/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads/.foo_protect
          chattr +i /srv/$HOSTNAME/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads/.foo_protect
          mount $HOME_BASE/$USER/share/downloads
          info "Bind mount status: ${YELLOW}Success${NC}"
        elif [ -d "/srv/$HOSTNAME/downloads" ] && [ "$(grep -qs $HOME_BASE/$USER/share/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads /proc/mounts > /dev/null; echo $?)" = 0 ]
        then
          msg "Creating /srv/$HOSTNAME/downloads bind mount..."
          info "Bind mount status: ${YELLOW}Success${NC}\nUsing existing mount."
        elif [ ! -d "/srv/$HOSTNAME/downloads" ] && [ "$(grep -qs $HOME_BASE/$USER/share/downloads/user/$(echo "$USER" | awk -F '_' '{print $1}')_downloads > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/downloads bind mount..."
          warn "Bind mount status: ${RED}Failed${NC}\n Mount point /srv/$HOSTNAME/downloads does not exist.\nSkipping this mount point."
        fi
        # Create shared music bind mount
        if [ -d "/srv/$HOSTNAME/music" ] && [ "$(grep -qs $HOME_BASE/$USER/share/music /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/music bind mount..."
          echo "/srv/$HOSTNAME/music $HOME_BASE/$USER/share/music none bind,ro,xattr,acl 0 0" >> /etc/fstab
          mount $HOME_BASE/$USER/share/music
          info "Bind mount status: ${YELLOW}Success${NC}"
        elif [ -d "/srv/$HOSTNAME/music" ] && [ "$(grep -qs $HOME_BASE/$USER/share/music /proc/mounts > /dev/null; echo $?)" = 0 ]
        then
          msg "Creating /srv/$HOSTNAME/music bind mount..."
          info "Bind mount status: ${YELLOW}Success${NC}\nUsing existing mount."
        elif [ ! -d "/srv/$HOSTNAME/music" ] && [ "$(grep -qs $HOME_BASE/$USER/share/music /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/music bind mount..."
          warn "Bind mount status: ${RED}Failed${NC}\n Mount point /srv/$HOSTNAME/music does not exist.\nSkipping this mount point."
        fi
        # Create shared public bind mount
        if [ -d "/srv/$HOSTNAME/public" ] && [ "$(grep -qs $HOME_BASE/$USER/share/public /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/public bind mount..."
          echo "/srv/$HOSTNAME/public $HOME_BASE/$USER/share/public none bind,rw,xattr,acl 0 0" >> /etc/fstab
          mount $HOME_BASE/$USER/share/public
          info "Bind mount status: ${YELLOW}Success${NC}"
        elif [ -d "/srv/$HOSTNAME/public" ] && [ "$(grep -qs $HOME_BASE/$USER/share/public /proc/mounts > /dev/null; echo $?)" = 0 ]
        then
          msg "Creating /srv/$HOSTNAME/public bind mount..."
          info "Bind mount status: ${YELLOW}Success${NC}\nUsing existing mount."
        elif [ ! -d "/srv/$HOSTNAME/public" ] && [ "$(grep -qs $HOME_BASE/$USER/share/public /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/public bind mount..."
          warn "Bind mount status: ${RED}Failed${NC}\n Mount point /srv/$HOSTNAME/public does not exist.\nSkipping this mount point."
        fi
        # Create shared photo bind mount
        if [ -d "/srv/$HOSTNAME/photo" ] && [ "$(grep -qs $HOME_BASE/$USER/share/photo /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/photo bind mount..."
          mkdir -p /srv/$HOSTNAME/photo/$(echo "$USER" | awk -F '_' '{print $1}')_photo
          chown -R $USER:$GROUP /srv/$HOSTNAME/photo/$(echo "$USER" | awk -F '_' '{print $1}')_photo
          chmod 1750 /srv/$HOSTNAME/photo/$(echo "$USER" | awk -F '_' '{print $1}')_photo
          setfacl -Rm g:${GROUP}:rx,g:medialab:rx,g:privatelab:rwx,d:u:$USER:rwx /srv/$HOSTNAME/photo/$(echo "$USER" | awk -F '_' '{print $1}')_photo
          echo "/srv/$HOSTNAME/photo $HOME_BASE/$USER/share/photo none bind,rw,xattr,acl 0 0" >> /etc/fstab
          mount $HOME_BASE/$USER/share/photo
          # Chattr set folder attributes to +i
          touch /srv/$HOSTNAME/photo/$(echo "$USER" | awk -F '_' '{print $1}')_photo/.foo_protect
          chattr +i /srv/$HOSTNAME/photo/$(echo "$USER" | awk -F '_' '{print $1}')_photo/.foo_protect
          info "Bind mount status: ${YELLOW}Success${NC}"
        elif [ -d "/srv/$HOSTNAME/photo" ] && [ "$(grep -qs $HOME_BASE/$USER/share/photo /proc/mounts > /dev/null; echo $?)" = 0 ]
        then
          msg "Creating /srv/$HOSTNAME/photo bind mount..."
          info "Bind mount status: ${YELLOW}Success${NC}\nUsing existing mount."
        elif [ ! -d "/srv/$HOSTNAME/photo" ] && [ "$(grep -qs $HOME_BASE/$USER/share/photo /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/photo bind mount..."
          warn "Bind mount status: ${RED}Failed${NC}\n Mount point /srv/$HOSTNAME/photo does not exist.\nSkipping this mount point."
        fi
        # Create shared video bind mount
        if [ -d "/srv/$HOSTNAME/video" ] && [ "$(grep -qs $HOME_BASE/$USER/share/video /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/video bind mount..."
          mkdir -p /srv/$HOSTNAME/video/homevideo/$(echo "$USER" | awk -F '_' '{print $1}')_homevideo
          chown -R $USER:$GROUP /srv/$HOSTNAME/video/homevideo/$(echo "$USER" | awk -F '_' '{print $1}')_homevideo
          chmod -R 1750 /srv/$HOSTNAME/video/homevideo/$(echo "$USER" | awk -F '_' '{print $1}')_homevideo
          setfacl -Rm g:${GROUP}:rx,g:medialab:rx,g:privatelab:rwx,d:u:$USER:rwx /srv/$HOSTNAME/video/homevideo/$(echo "$USER" | awk -F '_' '{print $1}')_homevideo
          echo "/srv/$HOSTNAME/video $HOME_BASE/$USER/share/video none bind,rw,xattr,acl 0 0" >> /etc/fstab
          mount $HOME_BASE/$USER/share/video
          # Chattr set folder attributes to +i
          touch /srv/$HOSTNAME/video/homevideo/$(echo "$USER" | awk -F '_' '{print $1}')_homevideo/.foo_protect
          chattr +i /srv/$HOSTNAME/video/homevideo/$(echo "$USER" | awk -F '_' '{print $1}')_homevideo/.foo_protect
          info "Bind mount status: ${YELLOW}Success${NC}"
        elif [ -d "/srv/$HOSTNAME/video" ] && [ "$(grep -qs $HOME_BASE/$USER/share/video /proc/mounts > /dev/null; echo $?)" = 0 ]
        then
          msg "Creating /srv/$HOSTNAME/video bind mount..."
          info "Bind mount status: ${YELLOW}Success${NC}\nUsing existing mount."
        elif [ ! -d "/srv/$HOSTNAME/video" ] && [ "$(grep -qs $HOME_BASE/$USER/share/video /proc/mounts > /dev/null; echo $?)" = 1 ]
        then
          msg "Creating /srv/$HOSTNAME/video bind mount..."
          warn "Bind mount status: ${RED}Failed${NC}\n Mount point /srv/$HOSTNAME/video does not exist.\nSkipping this mount point."
        fi
        echo
      fi
      # Chattr set user desktop folder attributes to +a
      while read dir
      do
        touch $HOME_BASE/$USER/$dir/.foo_protect 2> /dev/null
        chattr +i $HOME_BASE/$USER/$dir/.foo_protect 2> /dev/null
      done < <( ls $HOME_BASE/$USER )
      echo
    done < <( printf '%s\n' "${new_user_LIST[@]}" )


    #---- Email User SSH Keys
    if [ "$SMTP_STATUS" = 1 ]
    then
      section "$SECTION_HEAD - Email User Credentials & SSH keys"
      echo
      msg_box "#### PLEASE READ CAREFULLY - EMAIL NEW USER CREDENTIALS ####\n
      You can email a new users login credentials and ssh keys to the hosts system administrator. The system administrator can then forward the email(s) to each new user. The email will include the following information and attachments:
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
      while true
      do
        read -p "Email new users credentials & SSH key to your system’s administrator [y/n]? " -n 1 -r YN
        echo
        case $YN in
          [Yy]*)
            while read USER PASSWORD GROUP JAIL_TYPE
            do
              source $DIR/email_templates/pve_nas_ct_newuser_msg.sh
              msg "Sending '$USER' credentials and ssh key package to '${PVE_ROOT_EMAIL}'..."
              sendmail -t < email_body.html
              info "Email sent. Check your system administrators inbox."
            done < <( printf '%s\n' "${new_user_LIST[@]}" )
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
  fi
fi


#---- Exit the script
if [ "$TYPE" = TYPE00 ]
then
  msg "You have chosen not to proceed. Moving on..."
  echo
fi


#---- Finish Line ------------------------------------------------------------------

# Cleanup
if [ -z "${PARENT_EXEC+x}" ]
then
  trap cleanup EXIT
fi
#-----------------------------------------------------------------------------------