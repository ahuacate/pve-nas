#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_ct_proftpdsettings.sh
# Description:  ProFTPd settings script for PVE Ubuntu NAS
# ----------------------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
COMMON_PVE_SRC_DIR="${DIR}/../../../common/pve/src"

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source ${COMMON_PVE_SRC_DIR}/pvesource_bash_defaults.sh

#---- Static Variables -------------------------------------------------------------
#---- Other Variables --------------------------------------------------------------

# Section Header Body Text
SECTION_HEAD='PVE NAS'

# Check if IP is static or DHCP
if [[ $(ip r | head -n 1 | grep -n 'proto dhcp') ]]; then
  DHCP=1
else
  DHCP=0
fi

#---- Other Files ------------------------------------------------------------------
#---- Functions --------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Setting Folder Permissions
section "Setup ProFTPd SFTP service."

# Check for ProFTPd installation
msg "Checking for ProFTPd status..."
if [ $(dpkg -s proftpd-core >/dev/null 2>&1; echo $?) == '0' ]; then
  info "ProFTPd status: ${GREEN}installed.${NC} ( $(proftpd --version) )"
  echo
else
  info "ProFTPd is not installed. Exiting ProFTP installation script..."
  echo
  exit 0
fi

# Creating sftp Configuration
msg "Checking sftp configuration..."
echo
if [ -f /etc/proftpd/conf.d/sftp.conf ] || [ -f /etc/proftpd/conf.d/global_default.conf ] || [ -f /etc/proftpd/conf.d/global_desktopdir.conf ]; then
  msg_box "#### PLEASE READ CAREFULLY - SFTP CONFIGURATION ####\n
  Existing ProFTPd settings files have been found. Updating will overwrite the following settings files:

    --  /etc/proftpd/conf.d/sftp.conf
    --  /etc/proftpd/conf.d/global_default.conf
    --  /etc/proftpd/conf.d/global_desktopdir.conf

    The User also has the option to set the following:
    -- SFTP WAN address ( i.e a HAProxy URL, DynDNS provider or static IP)
    -- SFTP WAN port
    -- SFTP local port

  If the User has made custom changes to the existing ProFTPd configuration files DO NOT proceed to update this file (first make a backup). Otherwise we RECOMMEND you update (overwrite) ProFTPd settings file with our latest version."
  echo
  while true; do
    read -p "Update your ProFTPd settings (Recommended) [y/n]? " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        PROFTPD_SETTING=0
        echo
        break
        ;;
      [Nn]*)
        PROFTPD_SETTING=1
        info "You have chosen to skip this step."
        echo
        break
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
else
  PROFTPD_SETTING=0
fi

# WAN address and Port settings
msg_box "#### PLEASE READ CAREFULLY - PROFTP Settings ####

Our ProFTPd settings are tailored and configured to work out of the box. But the User may want change our basic default settings to meet their network requirements:

Local ProFTPd server settings.
  --  SFTP server local LAN port : 2222
  --  SFTP server local IPv4 address : $(if [ ${DHCP} == '0' ]; then echo "$(hostname -i) ( static IP )"; else echo "$(hostname).$(hostname -d) ( dhcp IP )"; fi)

If you have configured your network for remote access using HAProxy or by DynDNS you should enter the details when prompted. It will be included in all new user account instruction emails along with their user credentials.
  --  SFTP remote WAN HTTPS URL address : none
  --  SFTP server WAN port : none"
echo

# Set 
msg "The User can custom set a ProFTPd server SFTP local LAN Port number. The SFTP default LAN Port number is : 2222 ( Recommended ). Valid ports can be from 1 to 65535; however, ports less than 1024 are reserved for other protocols. It is best to choose ports greater than or equal to 50000 for SFTP mode."
echo
while true; do
  read -p "Enter a ProFTPd SFTP Port number: " -e -i 2222 SFTP_LOCAL_LAN_PORT
  if [[ "${SFTP_LOCAL_LAN_PORT}" =~ ^[0-9]+$ ]]; then
    info "SFTP local LAN Port is set: ${YELLOW}${SFTP_LOCAL_LAN_PORT}${NC}"
    echo
    break  
  else
    warn "There are problems with your input:
    
    1. A WAN Port number must be integers only (numerics).
    
    Try again..."
    echo
  fi
done

# Set remote connection address
msg "Select a connection method from the menu. To connect remotely you must have HAProxy, Cloudflare or a Dynamic DNS service provider account up and running ( and know your connection address URL ). If the User has none of these then select 'None'."
echo
OPTIONS_VALUES_INPUT=( "TYPE01" "TYPE02" )
OPTIONS_LABELS_INPUT=( "Remote Access Address - connect remotely from the internet" "None - connect using LAN $(if [ ${DHCP} == '0' ]; then echo "$(hostname -i)"; else echo "$(hostname).$(hostname -d)"; fi)" )
makeselect_input2
singleselect SELECTED "$OPTIONS_STRING"
if [ ${RESULTS} == TYPE01 ]; then
  while true; do
    msg "The User must input a valid internet HTTPS URL. This could be a Dynamic DNS server URL, domain address URL ( i.e Cloudflare hosted web address ) or even a static WAN IP address if your have one."
    read -p "Enter a valid HTTPS URL address: " SFTP_REMOTE_WAN_ADDRESS_VAR
    SFTP_REMOTE_WAN_ADDRESS=${SFTP_REMOTE_WAN_ADDRESS_VAR,,}
    if ping -c1 ${SFTP_REMOTE_WAN_ADDRESS} &>/dev/null; then
      info "SFTP connection address is set: ${YELLOW}${SFTP_REMOTE_WAN_ADDRESS}${NC}"
      SFTP_REMOTE_WAN_PORT=0
      echo
      break  
    else
      warn "There are problems with your input:
      
      1. HTTPS URL '${SFTP_REMOTE_WAN_ADDRESS}' is not reachable.
      2. A valid URL resembles: sftp-site1.foo.bar or mysftp.dyndns.org
      
      Check your URL address, remember to include any subdomain and try again..."
      echo
    fi
  done
elif [ ${RESULTS} == TYPE02 ]; then
  SFTP_REMOTE_WAN_ADDRESS=1
  SFTP_REMOTE_WAN_PORT=1
  msg "You can always add a SFTP remote WAN HTTPS URL address at a later stage."
  info "SFTP connection address is set: ${YELLOW}$(hostname -i)${NC}"
  echo
fi

# Set remote port number
if [ ${SFTP_REMOTE_WAN_PORT} = 0 ]; then
  msg "Your remote internet connection URL is set: ${WHITE}${SFTP_REMOTE_WAN_ADDRESS}${NC}.
  The User must provide a incoming WAN Port number used to access the ${HOSTNAME^^} LAN network. If the User has configured pfSense HAProxy with Cloudflare the port would be '443'. For a Dynamic DNS provider configuration the WAN Port number is set by the User at the network Gateway device (modem/USG) port forwarding settings table ( i.e mysftp.dyndns.org WAN: ${WHITE}502222${NC} --> LAN: $(hostname -i):2222 )."
  echo
  while true; do
    read -p "Enter a WAN Port number: " -e -i 443 SFTP_REMOTE_WAN_PORT
    if [[ "${SFTP_REMOTE_WAN_PORT}" =~ ^[0-9]+$ ]]; then
      info "SFTP WAN Port is set: ${YELLOW}${SFTP_REMOTE_WAN_PORT}${NC}"
      echo
      break  
    else
      warn "There are problems with your input:
      
      1. A WAN Port number must be integers only (numerics).
      
      Try again..."
      echo
    fi
  done
fi

# Modifying ProFTPd Defaults
if [ ${PROFTPD_SETTING} == 0 ]; then
  msg "Modifying ProFTPd defaults and settings..."
  if [ "$(systemctl is-active proftpd)" == "active" ]; then
    systemctl stop proftpd
    while ! [[ "$(systemctl is-active proftpd)" == "inactive" ]]; do
      echo -n .
    done
  fi
  eval "echo \"$(cat ${DIR}/sftp.conf)\"" > /etc/proftpd/conf.d/sftp.conf
  eval "echo \"$(cat ${DIR}/global_default.conf)\"" > /etc/proftpd/conf.d/global_default.conf
  eval "echo \"$(cat ${DIR}/global_desktopdir.conf)\"" > /etc/proftpd/conf.d/global_desktopdir.conf
  sed -i 's|# DefaultRoot.*|DefaultRoot ~|g' /etc/proftpd/proftpd.conf
  sed -i 's|ServerName.*|ServerName \"'$(echo ${HOSTNAME^^})'\"|g' /etc/proftpd/proftpd.conf
  sed -i 's|UseIPv6.*|UseIPv6 off|g' /etc/proftpd/proftpd.conf
  sed -i 's|#LoadModule mod_sftp.c|LoadModule mod_sftp.c|g' /etc/proftpd/modules.conf
  sed -i 's|#LoadModule mod_sftp_pam.c|LoadModule mod_sftp_pam.c|g' /etc/proftpd/modules.conf
  sed -i "s|^#\s*SFTP_LOCAL_LAN_ADDRESS=.*|# SFTP_LOCAL_LAN_ADDRESS='$(if [ ${DHCP} == '0' ]; then echo "$(hostname -i)"; else echo "$(hostname).$(hostname -d)"; fi)'|g" /etc/proftpd/conf.d/global_default.conf
  sed -i "s|^#\s*SFTP_LOCAL_LAN_PORT=.*|# SFTP_LOCAL_LAN_PORT='${SFTP_LOCAL_LAN_PORT}'|g" /etc/proftpd/conf.d/global_default.conf
  sed -i "s|^#\s*SFTP_REMOTE_WAN_ADDRESS=.*|# SFTP_REMOTE_WAN_ADDRESS='${SFTP_REMOTE_WAN_ADDRESS}'|g" /etc/proftpd/conf.d/global_default.conf
  sed -i "s|^\s*SFTP_REMOTE_WAN_PORT.*|# SFTP_REMOTE_WAN_PORT='${SFTP_REMOTE_WAN_PORT}'|g" /etc/proftpd/conf.d/global_default.conf
  # SFTP Conf
  sed -i "s|^\s*Port.*|    Port ${SFTP_LOCAL_LAN_PORT}|g" /etc/proftpd/conf.d/sftp.conf
  info "ProFTPd settings status: ${YELLOW}updated${NC}"
  echo
fi

# ProFTPd Status
# Starting ProFTPd service 
msg "Checking ProFTP status..."
if [ "$(systemctl is-active proftpd)" == "inactive" ]; then
  msg "Starting ProFTPd..."
  systemctl start proftpd
  msg "Waiting to hear from ProFTPd..."
  while ! [[ "$(systemctl is-active proftpd)" == "active" ]]; do
    echo -n .
  done
  sleep 1
  info "ProFTPd status: ${GREEN}running${NC}"
  echo
fi

#---- Finish Line ------------------------------------------------------------------
if [ ! ${PROFTPD_SETTING} == 1 ]; then
  section "Completion Status."

  info "${WHITE}Success.${NC} ProFTPd settings have been updated."
  echo
fi

# Cleanup
if [ -z "${PARENT_EXEC+x}" ]; then
  trap cleanup EXIT
fi