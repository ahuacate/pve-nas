#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nas_create_users.sh
# Description:  Create Ahuacate base Groups and Users (medialab, homelab, private etc)
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------


#---- Create users groups
msg "Creating default user groups..."
# Group 'medialab'
if [[ ! $(getent group medialab) ]]
then
  groupadd -g 65605 medialab > /dev/null
  info "Default user group created: ${YELLOW}medialab${NC}"
fi
# Group 'homelab'
if [[ ! $(getent group homelab) ]]
then
  groupadd -g 65606 homelab > /dev/null
  info "Default user group created: ${YELLOW}homelab${NC}"
fi
# Group 'privatelab'
if [[ ! $(getent group privatelab) ]]
then
  groupadd -g 65607 privatelab > /dev/null
  info "Default user group created: ${YELLOW}privatelab${NC}"
fi
# Group 'chrootjail'
if [[ ! $(getent group chrootjail) ]]
then
  groupadd -g 65608 chrootjail > /dev/null
  info "Default user group created: ${YELLOW}chrootjail${NC}"
fi
echo

#---- Create Base User Accounts
msg "Creating default users..."
mkdir -p "$DIR_SCHEMA/homes" >/dev/null
chgrp -R root "$DIR_SCHEMA/homes" >/dev/null
chmod -R 0755 "$DIR_SCHEMA/homes" >/dev/null
# User 'media'
if [[ ! $(id -u media 2> /dev/null) ]]
then
  # Remove old dir
  if [ -d "$DIR_SCHEMA/homes/media" ]
  then
    rm -R -f "$DIR_SCHEMA/homes/media"
  fi
  # Add user
  useradd -m -d "$DIR_SCHEMA/homes/media" -u 1605 -g medialab -s /bin/bash media >/dev/null
  chmod 0700 "$DIR_SCHEMA/homes/media"
  info "Default user created: ${YELLOW}media${NC} of group medialab"
fi
# User 'home'
if [[ ! $(id -u home 2> /dev/null) ]]
then
  # Remove old dir
  if [ -d "$DIR_SCHEMA/homes/home" ]
  then
    rm -R -f "$DIR_SCHEMA/homes/home"
  fi
  # Add user
  useradd -m -d "$DIR_SCHEMA/homes/home" -u 1606 -g homelab -G medialab -s /bin/bash home >/dev/null
  chmod 0700 "$DIR_SCHEMA/homes/home"
  info "Default user created: ${YELLOW}home${NC} of groups medialab, homelab"
fi
# User 'private'
if [[ ! $(id -u private 2> /dev/null) ]]
then
  # Remove old dir
  if [ -d "$DIR_SCHEMA/homes/private" ]
  then
    rm -R -f "$DIR_SCHEMA/homes/private"
  fi
  # Add user
  useradd -m -d "$DIR_SCHEMA/homes/private" -u 1607 -g privatelab -G medialab,homelab -s /bin/bash private >/dev/null
  chmod 0700 "$DIR_SCHEMA/homes/private"
  info "Default user created: ${YELLOW}private${NC} of groups medialab, homelab and privatelab"
fi
echo
#-----------------------------------------------------------------------------------