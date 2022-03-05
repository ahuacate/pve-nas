#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nas_identify_storagepath.sh
# Description:  Identify and set Storage path
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Select or input a storage path ( set DIR_SCHEMA )

section "Select a Storage Location"
msg_box "#### PLEASE READ CAREFULLY - SELECT A STORAGE LOCATION ####\n
A Storage location is the parent directory, volume or pool where all your new folder shares are located. Below is our system scan list of available storage locations:

$(while read -r var1; do echo "  -- '${var1}'"; done < <( df -hx tmpfs --output=target | grep -v 'Mounted on\|^/dev$\|^/$\|^/rpool$\|^/rpool/ROOT$\|^/etc.*' ))

The User must now identify and select a storage location."
echo
while true; do
  msg "User must identify and select Storage Location from the menu:"
  unset stor_LIST
  stor_LIST+=( $(df -hx tmpfs --output=target | grep -v 'Mounted on\|^/dev$\|^/$\|^/rpool$\|^/rpool/ROOT$\|^/etc.*' | sed -e '$aother') )
  OPTIONS_VALUES_INPUT=$(printf '%s\n' "${stor_LIST[@]}")
  OPTIONS_LABELS_INPUT=$(printf '%s\n' "${stor_LIST[@]}" | awk '{if ($1 != "other") print $1; else print "Other. Input your own storage path."; }')
  makeselect_input1 "$OPTIONS_VALUES_INPUT" "$OPTIONS_LABELS_INPUT"
  singleselect SELECTED "$OPTIONS_STRING"
  DIR_SCHEMA_TMP=${RESULTS}
  if [ ${DIR_SCHEMA_TMP} == "other" ]; then
    # Input a storage path
    while true; do
      msg "The User must now enter a valid storage location path. For example:\n
        --  '/srv/nas-01'
        --  '/mnt/storage'
        --  '/volume1'"
      echo
      read -p "Enter a valid storage path: " -e stor_PATH
      if [ ! -d ${stor_PATH} ]; then
        warn "There are problems with your input:
        
        1. '${stor_PATH}' location does NOT exist!
        
        Try again..."
        echo
      elif [ -d ${stor_PATH} ]; then
        while true; do
          msg "Input path '${stor_PATH}' is valid & available."
          read -p "Confirm your input path '${stor_PATH}' [y/n]?: " -n 1 -r YN
          echo
          case $YN in
            [Yy]*)
              info "Storage path set: ${YELLOW}${stor_PATH}${NC}"
              DIR_SCHEMA="${stor_PATH}"
              echo
              break 3
              ;;
            [Nn]*)
              msg "Try again..."
              echo
              break 2
              ;;
            *)
              warn "Error! Entry must be 'y' or 'n'. Try again..."
              echo
              ;;
          esac
        done
      fi
    done
  else
    DIR_SCHEMA="${DIR_SCHEMA_TMP}"
    break
  fi
done

#---- Finish Line ------------------------------------------------------------------