#!/usr/bin/env bash

function info() {
  local REASON="$1"
  local FLAG="\e[36m[INFO]\e[39m"
  msg "$FLAG $REASON"
}
function msg() {
  local TEXT="$1"
  echo -e "$TEXT"
}
function warn() {
  local REASON="\e[97m$1\e[39m"
  local FLAG="\e[93m[WARNING]\e[39m"
  msg "$FLAG $REASON"
}
function section() {
  local REASON="  \e[97m$1\e[37m"
  printf -- '-%.0s' {1..100}; echo ""
  msg "$REASON"
  printf -- '-%.0s' {1..100}; echo ""
  echo
}
function pushd () {
  command pushd "$@" &> /dev/null
}
function popd () {
  command popd "$@" &> /dev/null
}
function cleanup() {
  popd
  rm -rf $TEMP_DIR
  unset TEMP_DIR
}
function box_out() {
  set +u
  local s=("$@") b w
  for l in "${s[@]}"; do
	((w<${#l})) && { b="$l"; w="${#l}"; }
  done
  tput setaf 3
  echo " -${b//?/-}-
| ${b//?/ } |"
  for l in "${s[@]}"; do
	printf '| %s%*s%s |\n' "$(tput setaf 7)" "-$w" "$l" "$(tput setaf 3)"
  done
  echo "| ${b//?/ } |
 -${b//?/-}-"
  tput sgr 0
  set -u
}
ipvalid() {
  # Set up local variables
  local ip=${1:-1.2.3.4}
  local IFS=.; local -a a=($ip)
  # Start with a regex format test
  [[ $ip =~ ^[0-9]+(\.[0-9]+){3}$ ]] || return 1
  # Test values of quads
  local quad
  for quad in {0..3}; do
    [[ "${a[$quad]}" -gt 255 ]] && return 1
  done
  return 0
}

# Colour
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
WHITE=$'\033[1;37m'
NC=$'\033[0m'

# Resize Terminal
printf '\033[8;40;120t'

# Script Variables
SECTION_HEAD="PVE NAS"

# Set Temp Folder
if [ -z "${TEMP_DIR+x}" ]; then
  TEMP_DIR=$(mktemp -d)
  pushd $TEMP_DIR >/dev/null
else
  if [ $(pwd -P) != $TEMP_DIR ]; then
    cd $TEMP_DIR >/dev/null
  fi
fi


# Download external scripts

# Command to run script
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_install_ssmtp_ct.sh)"


# Setting Variables


#### Install and Configure SSMTP Email Alerts ####
if [ -z "${INSTALL_SSMTP+x}" ] && [ -z "${PARENT_EXEC_INSTALL_SSMTP+x}" ]; then
  section "$SECTION_HEAD - Installing and configuring Email Alerts."
  echo
  box_out '#### PLEASE READ CAREFULLY - SSMTP & EMAIL ALERTS ####' '' 'Send email alerts about your machine to the system’s designated administrator.' 'Be alerted about unwarranted login attempts and other system critical alerts.' 'If you do not have a postfix or sendmail server on your network then' 'the "simple smtp" (ssmtp) package is well suited for sending critical' 'alerts to the systems designated administrator.' '' 'ssmtp is a simple Mail Transfer Agent (MTA) while easy to setup it' 'requires the following prerequisites:' '' '  --  SMTP SERVER' '      You require a SMTP server that can receive the emails from your machine' '      and send them to the designated administrator. ' '      If you use Gmail smtp server its best to enable "App Passwords". An "App' '      Password" is a 16-digit passcode that gives an app or device permission' '      to access your Google Account.' '      Or you can use a mailgun.com flex account relay server (Recommended).' '' '  --  REQUIRED SMTP SERVER CREDENTIALS' '      1. Designated administrator email address' '         (i.e your working admin email address)' '      2. smtp server address' '         (i.e smtp.gmail.com or smtp.mailgun.org)' '      3. smtp server port' '         (i.e gmail port is 587 and mailgun port is 587)' '      4. smtp server username' '         (i.e MyEmailAddress@gmail.com or postmaster@sandboxa6ac6.mailgun.org)' '      5. smtp server default password' '         (i.e your Gmail App Password or mailgun smtp password)' '' 'If you choose to proceed have your smtp server credentials available.' 'This script will install and configure a ssmtp package as well as the default' 'Webmin Sending Email on your PVE NAS.'
  echo
  read -p "Install and configure ssmtp on your $SECTION_HEAD [y/n]?: " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    msg "Installing ssmtp..."
    INSTALL_SSMTP=0 >/dev/null
  else
    INSTALL_SSMTP=1 >/dev/null
    info "You have chosen to skip this step."
    exit 0
  fi
fi
echo


#### Checking Prerequisites ####
section "$SECTION_HEAD - Checking Prerequisites."

msg "Checking ssmtp status..."
if [ $(dpkg -s ssmtp >/dev/null 2>&1; echo $?) = 0 ]; then
  info "ssmtp status: ${GREEN}active (running).${NC}"
else
  msg "Installing ssmtp (be patient, might take a long, long time)..."
  sudo apt-get install -y ssmtp >/dev/null
  sudo apt-get install -y sharutils >/dev/null
  sleep 1
  if [ $(dpkg -s ssmtp >/dev/null 2>&1; echo $?) = 0 ]; then
    info "ssmtp status: ${GREEN}active (running).${NC}"
  else
    warn "ssmtp status: ${RED}inactive or cannot install (dead).${NC}.\nYour intervention is required.\nExiting installation script in 3 second."
    sleep 3
    exit 0
  fi
fi
echo


# Message about setting variables
section "$SECTION_HEAD - Setting SSMTP Server Variables"

msg "We need to set some variables. Variables are used to create and setup\nyour ssmtp server. The next steps requires your input.\n\nYou can accept our default values by pressing ENTER on your keyboard.\n
Or overwrite the default value by typing in your own value and\npress ENTER to accept/continue."
echo

while true; do
# Set ssmtp server address
while true; do
read -p "Enter ssmtp server address: " -e SSMTP_ADDRESS
read -p "Enter ssmtp server port number: " -e -i 587 SSMTP_PORT
ip=$SSMTP_ADDRESS
if ipvalid "$ip"; then
  msg "Validating IPv4 address..."
  if [ $(ping -s 1 -c 2 "$(echo "$SSMTP_ADDRESS")" >/dev/null; echo $?) = 0 ] || [ $(nc -z -w 5 $SSMTP_ADDRESS $SSMTP_PORT 2>/dev/null; echo $?) = 0 ]; then
    info "The ssmtp address is set: ${YELLOW}$SSMTP_ADDRESS${NC}."
    echo
    break
  elif [ $(ping -s 1 -c 2 "$(echo "$SSMTP_ADDRESS")" >/dev/null; echo $?) != 0 ] || [ $(nc -z -w 5 $SSMTP_ADDRESS $SSMTP_PORT 2>/dev/null; echo $?) != 0 ]; then
    warn "There are problems with your input:\n1. Your IP address meets the IPv4 standard, BUT\n2. Your IP address $(echo "$SSMTP_ADDRESS") is not reachable.\nCheck your ssmtp server IP address, port number and firewall settings.\nTry again..."
    echo
  fi
else
  msg "Validating url address..."
  if [ $(ping -s 1 -c 2 "$(echo "$SSMTP_ADDRESS")" >/dev/null; echo $?) = 0 ] || [ $(nc -z -w 5 $SSMTP_ADDRESS $SSMTP_PORT 2>/dev/null; echo $?) = 0 ]; then
    info "The ssmtp address is set: ${YELLOW}$SSMTP_ADDRESS${NC}."
    echo
    break
  elif [ $(ping -s 1 -c 2 "$(echo "$SSMTP_ADDRESS")" >/dev/null; echo $?) != 0 ] || [ $(nc -z -w 5 $SSMTP_ADDRESS $SSMTP_PORT 2>/dev/null; echo $?) != 0 ]; then
    warn "There are problems with your input:\n1. The URL $(echo "$SSMTP_ADDRESS") is not reachable.\nCheck your ssmtp server URL address, port number and firewall settings.\nTry again..."
    echo
  fi
fi
done


# Set root address
msg "Enter the system administrator email address who receives all system\nalerts and critical server email."
while true; do
  read -p "Enter admin email address: " SSMTP_EMAIL
  echo
  if [[ "$SSMTP_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then
    msg "Email address $SSMTP_EMAIL is valid."
    info "Admin email is set: ${YELLOW}$SSMTP_EMAIL${NC}."
    echo
    break
  else
    msg "Email address $SSMTP_EMAIL is invalid."
    warn "There are problems with your input:\n1. Email address $(echo "$SSMTP_EMAIL") does not pass the validity check.\nTry again..."
    echo
  fi
done


# Notification about smtp server settings
msg "In the next steps you will be asked for ($SSMTP_ADDRESS) server\n
authorised username and password."
if [[ ${SSMTP_ADDRESS,,} == *"gmail"* ]]; then
  msg "Required actions when using gmail smtp servers:\n  --  Open your Google Account.\n  --  In the Security section, select 2-Step Verification.\n      You might need to sign in.\n      Select Turn off.\n  --  A pop-up window will appear to confirm that you want to turn\n      off 2-Step Verification. Select Turn off.\n  --  Allow Less secure app access. If you do not use 2-Step Verification,\n      you might need to allow less secure apps to access your account."
  echo
elif [[ ${SSMTP_ADDRESS,,} == *"mailgun"* ]]; then
  msg "Required actions when using mailgun smtp servers:\n  --  Do NOT use your mailgun account username and passwords.\n  --  Go to Mailgun.com website and login.\n  --  In the Sending section, select Overview tab.\n  --  Select SMTP > Select to grab your SMTP credentials.\n  --  Note and copy your Username. Usually a long username like:\n      ( i.e Username: postmaster@sandbox3bchjsdf7fsfcsfac6.mailgun.org )\n  --  Note and copy your Password. Usually a long password like:\n      ( i.e Default password: 89kf548sbsfjsdfb8b503551030-f9kl3b107-7099346 ).\n  --  You must add your $SSMTP_EMAIL to mailgun Authorized Recipients list.\n      This input is on the same page as smtp username and password\n      Sending > Overview. Add $SSMTP_EMAIL and click Save."
  echo
fi

# smtp server authorised username
read -p "Enter smtp server authorised username: " SSMTP_AUTHUSER
info "smtp authorised user is set: ${YELLOW}$SSMTP_AUTHUSER${NC}."
echo

# smtp server authorised password
while true; do
  read -p "Enter smtp server password: " SSMTP_AUTHPASS
  echo
  read -p "Confirmation. Retype smtp server password (again): " SSMTP_AUTHPASS_CHECK
  echo "Validating your smtp server password..."
  if [ "$SSMTP_AUTHPASS" = "$SSMTP_AUTHPASS_CHECK" ];then
    info "smtp server password is set: ${YELLOW}$SSMTP_AUTHPASS${NC}."
    break
  elif [ "$SSMTP_AUTHPASS" != "$SSMTP_AUTHPASS_CHECK" ]; then
    echo "Your inputs ${RED}$SSMTP_AUTHPASS${NC} and ${RED}$SSMTP_AUTHPASS_CHECK${NC} do NOT match.\nTry again..."
  fi
done
echo


# Configuring your ssmtp server
msg "Configuring /etc/ssmtp/ssmtp.conf..."
cat <<-EOF > /etc/ssmtp/ssmtp.conf
#
# Config file for sSMTP sendmail
#
# The person who gets all mail for userids < 1000
# Make this empty to disable rewriting.
#root=postmaster
root=$SSMTP_EMAIL

# The place where the mail goes. The actual machine name is required no
# MX records are consulted. Commonly mailhosts are named mail.domain.com
#mailhub=mail
mailhub=$SSMTP_ADDRESS:$SSMTP_PORT

# Where will the mail seem to come from?
#rewriteDomain=
rewritedomain=$HOSTNAME.localdomain

# The full hostname
hostname=$HOSTNAME.localdomain

# Are users allowed to set their own From: address?
# YES - Allow the user to specify their own From: address
# NO - Use the system generated From: address
#FromLineOverride=YES
FromLineOverride=YES

# Use SSL/TLS before starting negotiation
UseTLS=Yes
UseSTARTTLS=Yes

# Username/Password
AuthUser=$SSMTP_AUTHUSER
AuthPass=$SSMTP_AUTHPASS

# AuthMethod
# The authorization method to use. If unset, plain text is used.
# May also be set to LOGIN (? for gmail) and
# cram-md5, DIGEST-MD5 etc
#AuthMethod=LOGIN

#### VERY IMPORTANT !!! If other people have access to this computer
# Your GMAIL Password is left unencrypted in this file
# so make sure you have a strong root password, and make sure
# you change the permissions of this file to be 640:
# chown root:mail /etc/ssmtp/ssmtp.conf
# chmod 640 /etc/ssmtp/ssmtp.conf

EOF
msg "Configuring /etc/ssmtp/revaliases..."
if [ $(grep -q "root:$SSMTP_EMAIL:$SSMTP_ADDRESS:$SSMTP_PORT" /etc/ssmtp/revaliases; echo $?) -eq 1 ]; then
  echo "root:$SSMTP_EMAIL:$SSMTP_ADDRESS:$SSMTP_PORT" >> /etc/ssmtp/revaliases
fi
echo

# Modify /etc/ssmtp/ssmtp.conf for gmail smtp servers
if [[ ${SSMTP_ADDRESS,,} == *"gmail"* ]]; then
  msg "Modifying /etc/ssmtp/ssmtp.conf for gmail servers..."
  sudo sed -i 's|rewritedomain.*|rewriteDomain=gmail.com|g' /etc/ssmtp/ssmtp.conf
  sudo sed -i 's|#AuthMethod.*|AuthMethod=LOGIN|g' /etc/ssmtp/ssmtp.conf
  echo
fi
# Modify /etc/ssmtp/ssmtp.conf for amazonaws smtp servers
if [[ ${SSMTP_ADDRESS,,} == *"amazon"* ]]; then
  msg "Modifying /etc/ssmtp/ssmtp.conf for amazonaws servers..."
  sudo sed -i 's|UseSTARTTLS.*|#UseSTARTTLS=yes|g' /etc/ssmtp/ssmtp.conf
  echo
fi
# Modify /etc/ssmtp/ssmtp.conf for godaddy smtp servers
if [[ ${SSMTP_ADDRESS,,} == *"secureserver.net"* ]]; then
  msg "Modifying /etc/ssmtp/ssmtp.conf for godaddy servers..."
  sudo sed -i 's|UseSTARTTLS.*|#UseSTARTTLS=yes|g' /etc/ssmtp/ssmtp.conf
  echo
fi


# Securing credentials in /etc/ssmtp/ssmtp.conf file
msg "Securing password credentials..."
sudo chown root:mail /etc/ssmtp/ssmtp.conf
sudo chmod 640 /etc/ssmtp/ssmtp.conf
info "Permissions set to 0640: ${YELLOW}/etc/ssmtp/ssmtp.conf${NC}"
echo

# Testing emailing
section "$SECTION_HEAD - Testing your SSMTP Configuration."
echo
box_out '#### PLEASE READ CAREFULLY - SSMTP & EMAIL TESTING ####' '' 'In the next step you have the option to test your ssmtp settings' 'by sending a test email to your systems designated administrator.' '' 'If you choose to send a test email then:' '  --  Check the administrators mailbox to validate your ssmtp settings work.' '  --  Check the administrators mailbox spam folder and whitelist any' '      test email found there.' '  --  If you do not receive a test email then something is wrong with' '      your configuration inputs.' '      You have the option to re-enter your credentials and try again.' '' 'If you choose NOT to send a test email then:' '  --  ssmtp settings are configured but not tested.' '  --  All changes must be made manually by the system administrator.' '      (i.e edit  /etc/ssmtp/ssmtp.conf )'
echo
read -p "Do you want to send a test email to $SSMTP_EMAIL [y/n]?: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo
  msg "Sending test email to $SSMTP_EMAIL..."
  echo -e "To: $SSMTP_EMAIL\nFrom: $SSMTP_EMAIL\nSubject: This is a ssmtp test email sent from $HOSTNAME\n\nHello World.\n\nYour ssmtp mail server works.\nCongratulations.\n\n" > test_email.txt
  sudo ssmtp -vvv $SSMTP_EMAIL < test_email.txt
  echo
  msg "Check the administrators mailbox ( $SSMTP_EMAIL ) to ensure the test email\nwas delivered.\nNote: check the administrators spam folder and whitelist any\ntest email found there."
  echo
  read -p "Confirm receipt of the test email message [y/n]?: " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "Success. Your ssmtp server is configured."
    break
  else
    read -p "Do you want to re-input your credentials (again) [y/n]?: " -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      info "You have chosen to re-input your credentials. Try again."
      sleep 2
      echo
    else
      info "You have chosen to accept your inputs despite them not working.\nSkipping the validation step."
      break
    fi
  fi
else
  info "You have chosen not to test your ssmtp email server.\nSkipping the validation step.\nssmtp settings are configured but not tested. All changes must be made\nmanually by the system administrator."
  break
fi
done
echo


# Setup Webmin
section "$SECTION_HEAD - Configure Webmin send mail."
echo
# Configuring Webmin mail send mode
if [ $(grep -q "send_mode=" /etc/webmin/mailboxes/config; echo $?) -eq 0 ]; then
  msg "Configuring Webmin mail send mode /etc/webmin/mailboxes/config..."
  sudo sed -i "s|send_mode=.*|send_mode=$SSMTP_ADDRESS|g" /etc/webmin/mailboxes/config
  info "Webmin mail send mode status : ${GREEN}Set${NC}"
  echo
elif [ $(grep -q "send_mode=" /etc/webmin/mailboxes/config; echo $?) -eq 1 ]; then
  msg "Configuring Webmin mail send mode /etc/webmin/mailboxes/config..."
  echo "send_mode=$SSMTP_ADDRESS" >> /etc/webmin/mailboxes/config
  info "Webmin mail send mode status : ${GREEN}Set${NC}"
  echo
fi
# Configuring Webmin mail ssl
if [ $(grep -q "smtp_ssl=1" /etc/webmin/mailboxes/config; echo $?) -eq 0 ]; then
  msg "Configuring Webmin mail ssl /etc/webmin/mailboxes/config..."
  sudo sed -i "s|smtp_ssl=.*|smtp_ssl=1|g" /etc/webmin/mailboxes/config
  info "Webmin mail ssl status : ${GREEN}Enabled${NC}"
  echo
elif [ $(grep -q "smtp_ssl=1" /etc/webmin/mailboxes/config; echo $?) -eq 1 ]; then
  msg "Configuring Webmin mail ssl /etc/webmin/mailboxes/config..."
  echo "smtp_ssl=1" >> /etc/webmin/mailboxes/config
  info "Webmin mail ssl status : ${GREEN}Enabled${NC}"
  echo
fi
# Configuring Webmin mail smtp port
if [ $(grep -q "smtp_port=465" /etc/webmin/mailboxes/config; echo $?) -eq 0 ]; then
  msg "Configuring Webmin mail smtp port /etc/webmin/mailboxes/config..."
  sudo sed -i "s|smtp_port=.*|smtp_port=465|g" /etc/webmin/mailboxes/config
  info "Webmin mail smtp port : ${GREEN}465${NC}"
  echo
elif [ $(grep -q "smtp_port=465" /etc/webmin/mailboxes/config; echo $?) -eq 1 ]; then
  msg "Configuring Webmin mail smtp port /etc/webmin/mailboxes/config..."
  echo "smtp_port=465" >> /etc/webmin/mailboxes/config
  info "Webmin mail smtp port : ${GREEN}465${NC}"
  echo
fi
# Configuring Webmin smtp username
if [ $(grep -q "smtp_user=$SSMTP_AUTHUSER" /etc/webmin/mailboxes/config; echo $?) -eq 0 ]; then
  msg "Configuring Webmin smtp username /etc/webmin/mailboxes/config..."
  sudo sed -i "s|smtp_user=.*|smtp_user=$SSMTP_AUTHUSER|g" /etc/webmin/mailboxes/config
  info "Webmin mail smtp username : ${GREEN}Set${NC}"
  echo
elif [ $(grep -q "smtp_user=$SSMTP_AUTHUSER" /etc/webmin/mailboxes/config; echo $?) -eq 1 ]; then
  msg "Configuring Webmin smtp username /etc/webmin/mailboxes/config..."
  echo "smtp_user=$SSMTP_AUTHUSER" >> /etc/webmin/mailboxes/config
  info "Webmin mail smtp username : ${GREEN}Set${NC}"
  echo
fi
# Configuring Webmin smtp authorised password
if [ $(grep -q "smtp_pass=$SSMTP_AUTHPASS" /etc/webmin/mailboxes/config; echo $?) -eq 0 ]; then
  msg "Configuring Webmin smtp authorised password /etc/webmin/mailboxes/config..."
  sudo sed -i "s|smtp_pass=.*|smtp_pass=$SSMTP_AUTHPASS|g" /etc/webmin/mailboxes/config
  info "Webmin mail smtp authorised password : ${GREEN}Set${NC}"
  echo
elif [ $(grep -q "smtp_pass=$SSMTP_AUTHPASS" /etc/webmin/mailboxes/config; echo $?) -eq 1 ]; then
  msg "Configuring Webmin smtp authorised password /etc/webmin/mailboxes/config..."
  echo "smtp_pass=$SSMTP_AUTHPASS" >> /etc/webmin/mailboxes/config
  info "Webmin mail smtp authorised password : ${GREEN}Set${NC}"
  echo
fi
# Configuring Webmin smtp authentication method
if [ $(grep -q "smtp_auth=Login" /etc/webmin/mailboxes/config; echo $?) -eq 0 ]; then
  msg "Configuring Webmin smtp authentication method /etc/webmin/mailboxes/config..."
  sudo sed -i "s|smtp_auth=.*|smtp_auth=Login|g" /etc/webmin/mailboxes/config
  info "Webmin mail smtp authentication method : ${GREEN}Login${NC}"
  echo
elif [ $(grep -q "smtp_auth=Login" /etc/webmin/mailboxes/config; echo $?) -eq 1 ]; then
  msg "Configuring Webmin smtp authentication method /etc/webmin/mailboxes/config..."
  echo "smtp_auth=Login" >> /etc/webmin/mailboxes/config
  info "Webmin mail smtp authentication method : ${GREEN}Login${NC}"
  echo
fi

info "Webmin sending email has been configured.\n  --  The from address for email sent by webmin is:\n      ${YELLOW}webmin@${HOSTNAME,,}.localdomain${NC}\n  --  SMTP server is: ${YELLOW}$SSMTP_ADDRESS${NC} port 465\n  --  Changes can be made by the system administrator using the\n      webmin configuration frontend.\n\n  --  Use the Webmin webgui to enable and configure your System\n      and Server Alerts."
echo

 
#### Finish ####
section "$SECTION_HEAD - Completion Status."

echo
msg "${WHITE}Success.${NC}"
sleep 1

# Cleanup
if [ -z ${PARENT_EXEC_INSTALL_SSMTP+x} ]; then
  cleanup
fi
