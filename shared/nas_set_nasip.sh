#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     nas_set_nasip.sh
# Description:  Set NAS IP address
# ----------------------------------------------------------------------------------

#---- Bash command to run script ---------------------------------------------------
#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Set NAS host IP
NAS_IP="$(hostname -i)"

# Guess PVE-01 IP
PVE_HOST_IP=$(echo ${NAS_IP} | awk -F'.' 'BEGIN { OFS = "." } { print $1,$2,$3,"101" }')

#---- Other Variables --------------------------------------------------------------

# No. of reserved PVE node IPs
PVE_HOST_NODE_CNT='5'

#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Confirm NAS IP address
section "Confirm NAS IP address"

msg "Confirming NAS IP..."
i=$(( $(echo ${PVE_HOST_IP} | cut -d . -f 4) + 1 ))
k=2
if [[ "${NAS_IP}" == *10.0.1.* || "${NAS_IP}" == *192.168.1.* ]] && [[ ! "${NAS_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.(101|102|103|104|105)$ ]]; then
  info "NAS IP status: ${YELLOW}accepted${NC}\nOur recommended PVE node cluster using your current NAS IP address '${NAS_IP}'\nwould be (note the ascending IP addresses):\n\n  -- pve-01  ${PVE_HOST_IP} ( Primary host )\n$(until [ ${i} = $(( $(echo ${PVE_HOST_IP} | cut -d . -f 4) + ${PVE_HOST_NODE_CNT} )) ]; do echo "  -- pve-0${k}  $(echo ${PVE_HOST_IP} | cut -d"." -f1-3).${i} ( Secondary host )";  ((i=i+1)); ((k=k+1)); done)\n\nWe recommend you reserve the above ${PVE_HOST_NODE_CNT}x IP addresses for your PVE nodes ( cluster )."
  echo
elif [[ "${NAS_IP}" == *10.0.1.* || "${NAS_IP}" == *192.168.1.* ]] && [[ "${NAS_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.(101|102|103|104|105)$ ]]; then
  warn "#### PLEASE READ CAREFULLY - IP Conflict? ####"
  msg "Your NAS IP address '${NAS_IP}' meets our scripts network prefix standards BUT there is a 'potential' IP conflict. The last IP octet of your NAS conflicts with our recommended standard PVE node cluster IP addresses. A typical PVE node cluster using your NAS IP network prefix would be ( note the ascending IP addresses ):\n\n  -- pve-01  ${PVE_HOST_IP} ( Primary host )\n$(until [ ${i} = $(( $(echo ${PVE_HOST_IP} | cut -d . -f 4) + ${PVE_HOST_NODE_CNT} )) ]; do echo "  -- pve-0${k}  $(echo ${PVE_HOST_IP} | cut -d"." -f1-3).${i} ( Secondary host ) $(if [ "${NAS_IP}" == "$(echo ${PVE_HOST_IP} | cut -d"." -f1-3).${i}" ]; then echo "<< ${RED}IP conflict${NC}"; fi)";  ((i=i+1)); ((k=k+1)); done)\n\nWe RECOMMEND the User changes the NAS IP to '$(echo ${NAS_IP} | awk -F'.' 'BEGIN { OFS = "." } { print $1,$2,$3,"10" }')' and try running this install script again. Or accept '${NAS_IP}' but continue with caution when inputting your Proxmox host IP addresses in the next steps to avoid IP conflicts."
  echo
  while true; do
    read -p "Accept current NAS IP '${WHITE}${NAS_IP}${NC}' [y/n]? " -n 1 -r YN
    echo
    case $YN in
      [Yy]*)
        info "NAS IP status: ${YELLOW}accepted${NC}"
        echo
        break
        ;;
      [Nn]*)
        msg "No problem. Change your NAS IP and try again. Bye..."
        echo
        exit 0
        ;;
      *)
        warn "Error! Entry must be 'y' or 'n'. Try again..."
        echo
        ;;
    esac
  done
elif [[ ! "${NAS_IP}" == *10.0.0.* || ! "${NAS_IP}" == *192.168.1.* ]] && [[ ! "${NAS_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.(101|102|103|104|105)$ ]]; then
  msg "Your NAS IP address '${NAS_IP}' is non-standard but is acceptable. A typical PVE node cluster using your NAS IP network prefix would be ( note the ascending IP addresses ):\n\n  -- pve-01  ${PVE_HOST_IP} ( Primary host )\n$(until [ ${i} = $(( $(echo ${PVE_HOST_IP} | cut -d . -f 4) + ${PVE_HOST_NODE_CNT} )) ]; do echo "  -- pve-0${k}  $(echo ${PVE_HOST_IP} | cut -d"." -f1-3).${i} ( Secondary host ) $(if [ "${NAS_IP}" == "$(echo ${PVE_HOST_IP} | cut -d"." -f1-3).${i}" ]; then echo "<< ${RED}IP conflict${NC}"; fi)";  ((i=i+1)); ((k=k+1)); done)\n\nWe recommend you reserve the above ${PVE_HOST_NODE_CNT}x IP addresses for your PVE nodes ( cluster )."
  echo
fi
#---- Finish Line ------------------------------------------------------------------