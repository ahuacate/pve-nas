#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pvesource_identify_pvehosts.sh
# Description:  Identify and set Proxmox PVE host IP and Hostnames
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Hostname regex
hostname_regex='^(([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])$'

# PVE hostname regex
pve_hostname_regex='^(([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[0-9])$'

#---- Other Variables --------------------------------------------------------------

# No. of reserved PVE node IPs
PVE_HOST_NODE_CNT='5'

#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Input PVE primary host IP address & hostname
section "Input Proxmox primary hostname and IP address"

HOSTNAME_FAIL_MSG="The PVE hostname is not valid. A valid PVE hostname is when all of the following constraints are satisfied:\n
  --  it does exists on the network.
  --  it contains only lowercase characters.
  --  it may include numerics, hyphens (-) and periods (.) but not start or end with them.
  --  it must end with a numeric.
  --  it doesn't contain any other special characters [!#$&%*+_].
  --  it doesn't contain any white space.\n
Why is this important?
Because Proxmox computing power is expanded using clusters of PVE machine hosts. Each PVE hostname should be denoted and sequenced with a numeric suffix beginning with '1' or '01' for easy installation scripting identification. Our standard PVE host naming convention is 'pve-01', 'pve-02', 'pve-03' and so on. Our scripts by default create NFS and SMB export permissions based on consecutive PVE hostnames beginning with the primary hostname (i.e pve-01 to pve-0${PVE_HOST_NODE_CNT}). If you proceed with '${PVE_HOSTNAME}', which has no identifiable numeric suffix, only the single PVE host '${PVE_HOSTNAME}' will be recognised or configured. This will cause problems with NFS exports for example.\n
We recommend the User immediately changes the PVE primary hostname to 'pve-01' and all secondary PVE hosts to 'pve-02' and so on before proceeding.\n"
IP_FAIL_MSG="The IP address is not valid. A valid IP address is when all of the following constraints are satisfied:\n
  --  it meets the IPv4 or IPv6 standard.
  --  it doesn't contain any white space.\n
Try again..."

# ES Validate PVE primary hostname and IP address
if [[ ${PVE_HOSTNAME} =~ ^.*([1|0])$ ]] && [ $(valid_ip ${PVE_HOST_IP} > /dev/null; echo $?) == '0' ]; then
  msg "ES validating PVE primary hostname and IP address..."
  info "PVE primary hostname is set: ${YELLOW}${PVE_HOSTNAME}${NC}"
  info "PVE primary host IP address is set: ${YELLOW}${PVE_HOST_IP}${NC}"
  echo
else
  msg_box "#### PLEASE READ CAREFULLY ####\n\nThe User must confirm the PVE primary hostname and IP address ( lookup results '${PVE_HOSTNAME} : ${PVE_HOST_IP}' ). Only input the PVE primary host details and NOT the secondary host. These inputs are required for critical system and application configuring."
  # Manual Confirm PVE primary hostname
  while true; do
    read -p "Enter your PVE primary host hostname: " -e -i ${PVE_HOSTNAME} PVE_HOSTNAME_VAR
    if [[ ${PVE_HOSTNAME_VAR} =~ ${pve_hostname_regex} ]] && [[ ${PVE_HOSTNAME_VAR} =~ ^.*([1|0])$ ]]; then
      PVE_HOSTNAME=${PVE_HOSTNAME_VAR}
      info "PVE primary hostname is set: ${YELLOW}${PVE_HOSTNAME}${NC}"
      # pve_hostname_base=$(echo ${PVE_HOSTNAME} | grep -o '.*[^0-9]')
      # pve_hostname_num_start=$(echo ${PVE_HOSTNAME} | grep -Eo '[0-9]+$')
      break
    else
      warn "$HOSTNAME_FAIL_MSG"
      unset OPTIONS_VALUES_INPUT
      unset OPTIONS_LABELS_INPUT
      OPTIONS_VALUES_INPUT+=( "OPTION_01" "OPTION_02" "OPTION_03" )
      OPTIONS_LABELS_INPUT+=( "Exit installer and fix the naming of your Proxmox PVE hostnames ( Recommended )" \
      "Proceed with '${PVE_HOSTNAME_VAR} ( invalid PVE hostname )" \
      "Input a different PVE hostname" )
      makeselect_input2
      singleselect SELECTED "$OPTIONS_STRING"
      if [ ${RESULTS} == 'OPTION_01' ]; then
        msg "Good choice. Fix the issue and run this installer again. Bye..."
        echo
        trap cleanup EXIT
      elif [ ${RESULTS} == 'OPTION_02' ]; then
        PVE_HOSTNAME=${PVE_HOSTNAME_VAR}
        info "PVE primary hostname is set: ${YELLOW}${PVE_HOSTNAME}${NC}"
        echo
        break
      elif [ ${RESULTS} == 'OPTION_03' ]; then
        msg "Try a different PVE hostname. But it must be a PVE primary hostname!"
        echo
      fi
    fi
  done

  # Manual Confirm PVE primary IP
  while true; do
    read -p "Enter your PVE primary host IP address: " -e -i ${PVE_HOST_IP} PVE_HOST_IP_VAR
    msg "Performing checks on your input ( be patient, may take a while )..."
    if [ $(valid_ip ${PVE_HOST_IP} > /dev/null; echo $?) == 0 ]; then
      PVE_HOST_IP=${PVE_HOST_IP_VAR}
      info "PVE primary host IP address is set: ${YELLOW}${PVE_HOST_IP}${NC}"
      echo
      break
    else
      warn "$IP_FAIL_MSG"
      echo
    fi
  done
fi


#---- Creating export settings
section "Setting PVE host node hostnames and IP addresses"

if [[ ! ${PVE_HOSTNAME} =~ ^.*([1|0])$ ]]; then
  # Single PVE node
  msg "The User has chosen a invalid PVE primary hostname: ${PVE_HOSTNAME}. This will limit settings for NFS or SMB exports."
  # Add first node to array
  unset pve_node_LIST
  pve_node_LIST=()
  pve_node_LIST+=( "${PVE_HOSTNAME},${PVE_HOST_IP},primary host" )
  echo
  printf '%s\n' "${pve_node_LIST[@]}" | column -s "," -t -N "PVE HOSTNAME,IP ADDRESS,CLUSTER NODE TYPE" | indent2
  echo
elif [[ ${PVE_HOSTNAME} =~ ^.*([1|0])$ ]] && [[ ${PVE_HOST_IP} =~ ${ip4_regex} ]]; then
  # Multi PVE nodes IPv4
  msg "Setting your PVE host nodes identities as shown ( total of ${PVE_HOST_NODE_CNT} reserved PVE nodes ):"
  unset pve_node_LIST
  pve_node_LIST=()
  # IP vars
  i=$(( $(echo ${PVE_HOST_IP} | cut -d . -f 4) + 1 ))
  # Hostname vars
  j=$(( $(echo ${PVE_HOSTNAME} | awk '{print substr($0,length,1)}') + 1 ))
  PVE_HOSTNAME_VAR=$(echo ${PVE_HOSTNAME} | sed 's/.$//')
  counter=1
  # Add first node to array
  pve_node_LIST+=( "${PVE_HOSTNAME},${PVE_HOST_IP},primary host" )
  until [ $counter -eq ${PVE_HOST_NODE_CNT} ]
  do
    pve_node_LIST+=( "${PVE_HOSTNAME_VAR}${j},$(echo ${PVE_HOST_IP} | cut -d"." -f1-3).${i},secondary host" )
    ((i=i+1))
    ((j=j+1))
    ((counter++))
  done
  echo
  printf '%s\n' "${pve_node_LIST[@]}" | column -s "," -t -N "PVE HOSTNAME,IP ADDRESS,CLUSTER NODE TYPE" | indent2
  echo
elif [[ ${PVE_HOSTNAME} =~ ^.*([1|0])$ ]] && [[ ${PVE_HOST_IP} =~ ${ip6_regex} ]]; then
  # Multi PVE nodes IPv6
  msg "Setting ${PVE_HOST_NODE_CNT} reserved PVE host nodes identities as shown:"
  unset pve_node_LIST
  pve_node_LIST=()
  # Hostname vars
  j=$(( $(echo ${PVE_HOSTNAME} | awk '{print substr($0,length,1)}') + 1 ))
  PVE_HOSTNAME_VAR=$(echo ${PVE_HOSTNAME} | sed 's/.$//')
  counter=1
  # Add first node to array
  pve_node_LIST+=( "${PVE_HOSTNAME},${PVE_HOST_IP},primary host" )
  until [ $counter -eq ${PVE_HOST_NODE_CNT} ]
  do
    pve_node_LIST+=( "${PVE_HOSTNAME_VAR}${j},IPv6,secondary host" )
    ((j=j+1))
    ((counter++))
  done
  echo
  printf '%s\n' "${pve_node_LIST[@]}" | column -s "," -t -N "PVE HOSTNAME,IP ADDRESS,CLUSTER NODE TYPE" | indent2
  echo
fi

#---- Finish Line ------------------------------------------------------------------