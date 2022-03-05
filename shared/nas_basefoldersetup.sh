#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nas_basefoldersetup.sh
# Description:  Source script for creating NAS base and sub folders
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------

# Check for ACL installation
if [ $(dpkg -s acl > /dev/null 2>&1; echo $?) != 0 ]; then
  apt-get install -y acl > /dev/null
fi

# Check for chattr
if [ ! $(chattr --help &> /dev/null; echo $?) == 1 ]; then
  apt-get -y install e2fsprogs > /dev/null
fi

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Set DIR Schema ( PVE host or CT mkdir )
if [ $(uname -a | grep -Ei --color=never '.*linux*|.*pve*' &> /dev/null; echo $?) == 0 ]; then
  DIR_SCHEMA="/${POOL}/${HOSTNAME}"
else
  # Select or input a storage path ( set DIR_SCHEMA )
  unset print_DISPLAY
  print_DISPLAY+=( $(df -hx tmpfs --output=target | sed '1d' | grep -v '/$\|^/dev.*\|^/rpool.*\|/etc.*') )
  section "Select a Storage Location"
  msg_box "#### PLEASE READ CAREFULLY - SELECT A STORAGE LOCATION ####\n\nA storage location is a parent directory, volume or ZPool where your new folder shares will be created. A scan shows the following available storage locations:\n\n$(printf -- --' %s\n' "${print_DISPLAY[@]}" | indent2)\n\nThe User must now select a storage location. Or select 'other' to manually input the full storage path."
  echo
  msg "Select a storage location from the menu:"
  unset stor_LIST
  stor_LIST+=( $(df -hx tmpfs --output=target | sed '1d' | grep -v '/$\|^/dev.*\|^/rpool.*\|/etc.*' | sed -e '$aother') )
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${stor_LIST[@]}")
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${stor_LIST[@]}" | awk '{if ($1 != "other") print $1; else print "Other. Input your own storage path."; }')
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect SELECTED "$OPTIONS_STRING"
  DIR_SCHEMA=${RESULTS}
  if [ ${DIR_SCHEMA} == "other" ]; then
    # Input a storage path
    while true; do
      msg "The User must now enter a valid storage location path. For example:\n
        --  /srv/nas-01
        --  /mnt/storage
        --  /volume1"
      echo
      read -p "Enter a valid storage path: " -e stor_path
      if [ ! -d ${stor_path} ]; then
        warn "There are problems with your input:
        
        1. '${stor_path}' location does NOT exist!
        
        Try again..."
        echo
      elif [ -d ${stor_path} ]; then
        while true; do
          read -p "Re-confirm storage path '${stor_path}' is correct [y/n]?: " -n 1 -r YN
          echo
          case $YN in
            [Yy]*)
              info "Storage path set: ${YELLOW}${stor_path}${NC}"
              DIR_SCHEMA="${stor_path}"
              echo
              break 2
              ;;
            [Nn]*)
              msg "Try again..."
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
    done
  fi
fi

#---- Create Arrays ( must be after setting 'DIR_SCHEMA' )
# Create 'nas_basefolder_LIST' array
unset nas_basefolder_LIST
nas_basefolder_LIST=()
while IFS= read -r line; do
  [[ "$line" =~ (^\#.*$|^\s*$) ]] && continue
  nas_basefolder_LIST+=( "$line" )
done < ${COMMON_DIR}/nas/src/nas_basefolderlist

# Create 'nas_subfolder_LIST' array
unset nas_subfolder_LIST
nas_subfolder_LIST=()
while IFS= read -r line; do
  [[ "$line" =~ (^\#.*$|^\s*$) ]] && continue
  nas_subfolder_LIST+=( "$(eval echo "$line")" )
done < ${COMMON_DIR}/nas/src/nas_basefoldersubfolderlist


#---- Setting Folder Permissions
section "Create and Set Folder Permissions."

# Create Default Proxmox Share points
msg_box "#### PLEASE READ CAREFULLY - SHARED FOLDERS ####\n\nShared folders are the basic directories where you can store files and folders on your NAS. Below is a list of our default NAS shared folders. You can create additional 'custom' shared folders in the coming steps.\n\n$(while IFS=',' read -r var1 var2; do msg "\t--  /srv/${HOSTNAME}/'${var1}'"; done <<< $( printf '%s\n' "${nas_basefolder_LIST[@]}" ))"
echo
nas_basefolder_extra_LIST=()
while true; do
  if [ ${#nas_basefolder_extra_LIST[@]} == '0' ]; then
    read -p "Do you want to create a custom shared folder [y/n]? " -n 1 -r YN
  else
    read -p "Do you want to another custom shared folder [y/n]? " -n 1 -r YN
  fi
  echo
  case $YN in
    [Yy]*)
      while true; do
        # Function to input dir name
        input_dirname_val
        if [ $(printf '%s\n' "${nas_basefolder_LIST[@]}" | awk -F',' '{ print $1 }' | grep -xqFe ${DIR_NAME} > /dev/null; echo $?) == 0 ];then
          warn "There are issues with your input:\n  1. The folder '${DIR_NAME}' already exists.\n  Try again..."
          echo
        else
          break
        fi
      done
      msg "Select the group permission rights for '${DIR_NAME}' custom folder..."
      # Make selection
      OPTIONS_VALUES_INPUT=( "LEVEL01" "LEVEL02" "LEVEL03" "LEVEL04" )
      OPTIONS_LABELS_INPUT=( "Standard User - For restricted jailed users (GID: chrootjail)" \
      "Medialab - Photos, series, movies, music and general media content only" \
      "Homelab - Everything to do with your smart home" \
      "Privatelab - User has access to all NAS data" )
      makeselect_input2
      singleselect SELECTED "$OPTIONS_STRING"
      # Set type
      LEVEL=${RESULTS}
      if [ ${LEVEL} == LEVEL01 ]; then
        nas_basefolder_LIST+=( "${DIR_NAME},Custom folder,root,0750,65608:rwx,65607:rwx" )
        nas_basefolder_extra_LIST+=( "${DIR_NAME},Custom folder,root,0750,65608:rwx,65607:rwx" )
        info "You have selected: ${YELLOW}Standard User${NC} for folder '${DIR_NAME}'."
        echo
      elif [ ${LEVEL} == LEVEL02 ]; then
        nas_basefolder_LIST+=( "${DIR_NAME},Custom folder,root,0750,65605:rwx,65607:rwx" )
        nas_basefolder_extra_LIST+=( "${DIR_NAME},Custom folder,root,0750,65605:rwx,65607:rwx" )
        info "You have selected: ${YELLOW}Medialab${NC} for folder '${DIR_NAME}'."
        echo
      elif [ ${LEVEL} == LEVEL03 ]; then
        nas_basefolder_LIST+=( "${DIR_NAME},Custom folder,root,0750,65606:rwx,65607:rwx" )
        nas_basefolder_extra_LIST+=( "${DIR_NAME},Custom folder,root,0750,65606:rwx,65607:rwx" )
        info "You have selected: ${YELLOW}Homelab${NC} for folder '${DIR_NAME}'."
        echo
      elif [ ${LEVEL} == LEVEL04 ]; then
        nas_basefolder_LIST+=( "${DIR_NAME},Custom folder,root,0750,65607:rwx" )
        nas_basefolder_extra_LIST+=( "${DIR_NAME},Custom folder,root,0750,65607:rwx" )
        info "You have selected: ${YELLOW}Privatelab${NC} for folder '${DIR_NAME}'."
        echo
      fi
      ;;
    [Nn]*)
      echo
      break
      ;;
    *)
      warn "Error! Entry must be 'y' or 'n'. Try again..."
      echo
      ;;
  esac
done

# Create Proxmox ZFS Share points
msg "Creating ${SECTION_HEAD} base /$POOL/$HOSTNAME folder shares..."
echo
while IFS=',' read -r dir desc group permission acl_01 acl_02 acl_03 acl_04 acl_05; do
  if [ -d "${DIR_SCHEMA}/${dir}" ]; then
    info "Pre-existing folder: ${UNDERLINE}"${DIR_SCHEMA}/${dir}"${NC}\n  Setting ${group} group permissions for existing folder."
    find "${DIR_SCHEMA}/" -name .foo_protect -exec chattr -i {} \;
    chgrp -R "${group}" "${DIR_SCHEMA}/${dir}" >/dev/null
    chmod -R "${permission}" "${DIR_SCHEMA}/${dir}" >/dev/null
    if [ ! -z ${acl_01} ]; then
      setfacl -Rm g:${acl_01} "${DIR_SCHEMA}/${dir}"
    fi
    if [ ! -z ${acl_02} ]; then
      setfacl -Rm g:${acl_02} "${DIR_SCHEMA}/${dir}"
    fi
    if [ ! -z ${acl_03} ]; then
      setfacl -Rm g:${acl_03} "${DIR_SCHEMA}/${dir}"
    fi
    if [ ! -z ${acl_04} ]; then
      setfacl -Rm g:${acl_04} "${DIR_SCHEMA}/${dir}"
    fi
    if [ ! -z ${acl_05} ]; then
      setfacl -Rm g:${acl_05} "${DIR_SCHEMA}/${dir}"
    fi
    echo
  else
    info "New base folder created:\n  ${WHITE}"${DIR_SCHEMA}/${dir}"${NC}"
    find "${DIR_SCHEMA}/" -name .foo_protect -exec chattr -i {} \;
    mkdir -p "${DIR_SCHEMA}/${dir}" >/dev/null
    chgrp -R "${group}" "${DIR_SCHEMA}/${dir}" >/dev/null
    chmod -R "${permission}" "${DIR_SCHEMA}/${dir}" >/dev/null
    if [ ! -z ${acl_01} ]; then
      setfacl -Rm g:${acl_01} "${DIR_SCHEMA}/${dir}"
    fi
    if [ ! -z ${acl_02} ]; then
      setfacl -Rm g:${acl_02} "${DIR_SCHEMA}/${dir}"
    fi
    if [ ! -z ${acl_03} ]; then
      setfacl -Rm g:${acl_03} "${DIR_SCHEMA}/${dir}"
    fi
    if [ ! -z ${acl_04} ]; then
      setfacl -Rm g:${acl_04} "${DIR_SCHEMA}/${dir}"
    fi
    if [ ! -z ${acl_05} ]; then
      setfacl -Rm g:${acl_05} "${DIR_SCHEMA}/${dir}"
    fi
    echo
  fi
done  <<< $( printf '%s\n' "${nas_basefolder_LIST[@]}" )

# # Chattr set ZFS share points attributes to +a
# while read -r dir group permission acl_01 acl_02 acl_03 acl_04 acl_05; do
#   chattr +a "${DIR_SCHEMA}/${dir}"
# done < nas_basefolderlist_input

# Create Default SubFolders
if [ ! ${#nas_subfolder_LIST[@]} == '0' ]; then
  msg "Creating $SECTION_HEAD subfolder shares..."
  echo
  while IFS=',' read -r dir group permission acl_01 acl_02 acl_03 acl_04 acl_05; do
    if [ -d "${dir}" ]; then
      info "${dir} exists.\n  Setting ${group} group permissions for this folder."
      find ${dir} -name .foo_protect -exec chattr -i {} \;
      chgrp -R "${group}" "${dir}" >/dev/null
      chmod -R "${permission}" "${dir}" >/dev/null
      if [ ! -z ${acl_01} ]; then
        setfacl -Rm g:${acl_01} "${dir}"
      fi
      if [ ! -z ${acl_02} ]; then
        setfacl -Rm g:${acl_02} "${dir}"
      fi
      if [ ! -z ${acl_03} ]; then
        setfacl -Rm g:${acl_03} "${dir}"
      fi
      if [ ! -z ${acl_04} ]; then
        setfacl -Rm g:${acl_04} "${dir}"
      fi
      if [ ! -z ${acl_05} ]; then
        setfacl -Rm g:${acl_05} "${dir}"
      fi
      echo
    else
      info "New subfolder created:\n  ${WHITE}"${dir}"${NC}"
      mkdir -p "${dir}" >/dev/null
      chgrp -R "${group}" "${dir}" >/dev/null
      chmod -R "${permission}" "${dir}" >/dev/null
      if [ ! -z ${acl_01} ]; then
        setfacl -Rm g:${acl_01} "${dir}"
      fi
      if [ ! -z ${acl_02} ]; then
        setfacl -Rm g:${acl_02} "${dir}"
      fi
      if [ ! -z ${acl_03} ]; then
        setfacl -Rm g:${acl_03} "${dir}"
      fi
      if [ ! -z ${acl_04} ]; then
        setfacl -Rm g:${acl_04} "${dir}"
      fi
      if [ ! -z ${acl_05} ]; then
        setfacl -Rm g:${acl_05} "${dir}"
      fi
      echo
    fi
  done <<< $(printf "%s\n" "${nas_subfolder_LIST[@]}")
  # Chattr set ZFS share points attributes to +a
  while IFS=',' read -r dir group permission acl_01 acl_02 acl_03 acl_04 acl_05; do
    touch ${dir}/.foo_protect
    chattr +i ${dir}/.foo_protect
    # chmod +t ${dir}/.foo_protect
  done <<< $(printf "%s\n" "${nas_subfolder_LIST[@]}")
fi

#---- Finish Line ------------------------------------------------------------------