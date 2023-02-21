#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_ct_addjailuser.sh
# Description:  Create a new PVE NAS Jail User
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------

# Command to run script
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/main/pve_nas_toolbox.sh)"

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SRC_DIR="$DIR/../../common/pve/src"

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source $COMMON_PVE_SRC_DIR/pvesource_bash_defaults.sh

# Check user is root
if [ ! "$(id -u)" = 0 ]
then
  warn "This script needs to run under 'root'. Exiting in 2 seconds.\nTry again..."
  sleep 2
  exit 0
fi

#---- Static Variables -------------------------------------------------------------

# Easy Script Section Header Body Text
SECTION_HEAD='PVE NAS'

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------

# Delete a username (permanent action)
function delete_username() {
  # Usage: delete_username "harry" "medialab"

  local username="$1"
  local group="$2"
  # Homes folder
  local HOSTNAME=$(hostname)
  local HOME_BASE="/srv/$HOSTNAME/homes"

  # Deleting existing user name
  while true
  do
    read -p "Also delete the user '${WHITE}$username${NC}' home folder including their files [y/n]?: " -n 1 -r YN < /dev/tty
    echo
    case $YN in
      [Yy]*)
        # Chattr set user desktop folder attributes to -i
        while read dir
        do
          if [ -f "$(awk -F: -v v="$username" '{if ($1==v) print $6}' /etc/passwd)/$dir/.foo_protect" ]
          then
            chattr -i $(awk -F: -v v="$username" '{if ($1==v) print $6}' /etc/passwd)/$dir/.foo_protect
          fi
        done <<< $( ls $(awk -F: -v v="$username" '{if ($1==v) print $6}' /etc/passwd) )

        # Delete ProFTPd key
        rm -f /etc/proftpd/authorized_keys/$username

        # Delete SMB user
        smbpasswd -x $username 2>/dev/null

        # Delete Unix Account
        userdel -r $username 2>/dev/null
        echo
        break
        ;;
      [Nn]*)
        # Delete SMB user
        smbpasswd -x $username 2>/dev/null

        # Delete Unix Account
        userdel $username 2>/dev/null
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
}

# Delete a username (permanent action)
function delete_jailed_username() {
  # Usage: delete_jailed_username "harry" "chrootjail"
  local username="$1"
  local group="$2"
  # Args
  local HOSTNAME=$(hostname)
  local CHROOT="/srv/$HOSTNAME/homes/chrootjail"
  local HOME_BASE="$CHROOT/homes"

  # Umount & remove existing user bind mounts
  if [[ $(grep "$HOME_BASE/$username" /etc/fstab) ]]
  then
    while read -r path
    do
      # Umount
      if [[ $(mount | grep $path) ]]
      then
        umount $path 2>/dev/null
      fi

      # Remove the entry from fstab
      escaped_path="$(echo "$path" | sed 's/\//\\\//g')"
      sed -i "/${escaped_path}/d" /etc/fstab
    done < <( grep $HOME_BASE/$username /etc/fstab | awk '{print $2}' ) # listing of bind mounts
  fi

  # Deleting user
  while true
  do
    read -p "Also delete user '${WHITE}$username${NC}' home folder including user files[y/n]?: " -n 1 -r YN < /dev/tty
    echo
    case $YN in
      [Yy]*)
        # Chattr set user desktop folder attributes to -i
        while read dir
        do
          if [ -f "$HOME_BASE/$username/$dir/.foo_protect" ]
          then
            chattr -i $HOME_BASE/$username/$dir/.foo_protect
          fi
        done < <( ls $HOME_BASE/$username )

        # Delete ProFTPd key
        rm -f /etc/proftpd/authorized_keys/$username

        # Delete user
        userdel $username 2>/dev/null
        rm -R $HOME_BASE/$username 2>/dev/null
        sed -i "/^$username/d" $CHROOT/etc/passwd

        # Remove other User folders
        if [ -d "/srv/$HOSTNAME/downloads/user/$(echo "$username" | awk -F '_' '{print $1}')_downloads" ]
        then
          chattr -i /srv/$HOSTNAME/downloads/user/$(echo "$username" | awk -F '_' '{print $1}')_downloads/.foo_protect
          rm -R /srv/$HOSTNAME/downloads/user/$(echo "$username" | awk -F '_' '{print $1}')_downloads
        fi
        if [ -d "/srv/$HOSTNAME/photo/$(echo "$username" | awk -F '_' '{print $1}')_photo" ]
        then
          chattr -i /srv/$HOSTNAME/photo/$(echo "$username" | awk -F '_' '{print $1}')_photo/.foo_protect
          rm -R /srv/$HOSTNAME/photo/$(echo "$username" | awk -F '_' '{print $1}')_photo
        fi
        if [ -d "/srv/$HOSTNAME/video/homevideo/$(echo "$username" | awk -F '_' '{print $1}')_homevideo" ]
        then
          chattr -i /srv/$HOSTNAME/video/homevideo/$(echo "$username" | awk -F '_' '{print $1}')_homevideo/.foo_protect
          rm -R /srv/$HOSTNAME/video/homevideo/$(echo "$username" | awk -F '_' '{print $1}')_homevideo
        fi
        echo
        break
        ;;
      [Nn]*)
        # Delete user
        userdel $username 2>/dev/null
        sed -i "/^$username/d" $CHROOT/etc/passwd
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
}

#---- Body -------------------------------------------------------------------------

#---- Prerequisites

# Create user list
user_LIST=()
# user_LIST+=( $(cat /etc/passwd | egrep "^*injail\:" | awk -F':' 'BEGIN{OFS=FS} {if ($4 ~ /65608/) ($4="chrootjail"); print $1, $4 }') )
user_LIST+=( $(cat /etc/passwd | awk -F':' 'BEGIN{OFS=FS} {if ($4 ~ /65605|65606|65607|65608/ && $3 !~ /1605|1606|1607/ ) {print $1, $4}}' | awk -F':' '{if ($2 == "65605") $2="medialab"; else if ($2 == "65606") $2="homelab"; else if ($2 == "65607") $2="privatelab"; else if ($2 == "65608") $2="chrootjail"; print $1":"$2}') )

# Check if users exist for deletion
if [ "${#user_LIST[@]}" = 0 ]
then
  warn "There are no valid users for deletion. This script can only delete users who are members of medialab, homelab, privatelab and chrootjail groups. Users which belong to other groups can be deleted using the NAS Webmin webGUI. Bye.."
  echo
  exit 0
fi

#---- Select user for deletion

section "$SECTION_HEAD - Select the users for deletion"

msg_box "#### PLEASE READ CAREFULLY - USER ACCOUNT DELETION ####\n
Select any number of users you want to permanently delete. The User will be prompted with the option to keep or remove each selected users home folder and their private files. If you choose to delete a user and their home folder all personal files will be permanently lost and not recoverable."
echo
OPTIONS_VALUES_INPUT=$(printf '%s\n' "${user_LIST[@]}" | sed -e '$aTYPE00')
OPTIONS_LABELS_INPUT=$(printf '%s\n' "${user_LIST[@]}" | awk -F':' '{ print "User name: "$1, "| Member of user group: "$2; }' | sed -e '$aNone. Exit this installer')
makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
multiselect SELECTED "$OPTIONS_STRING"

# Abort option
if [ "$RESULTS" = 'TYPE00' ] || [ -z ${RESULTS} ]
then
  msg "You have chosen not to proceed. Aborting. Bye..."
  echo
  exit 0
fi

#---- Delete the user

# Delete each selected username
while IFS=':' read username group
do
  # Run delete function
  if [[ "$group" =~ ^chrootjail$ ]]
  then
    # Delete Chrootjail user
    delete_jailed_username "$username" "$group"
  elif [[ "$group" =~ ^(privatelab|homelab|medialab)$ ]]
  then
    # Delete standard user
    delete_username "$username" "$group"
  fi
done < <( printf '%s\n' "${RESULTS[@]}" )
#-----------------------------------------------------------------------------------
