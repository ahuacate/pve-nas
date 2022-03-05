#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     pve_nas_ct_newuser_msg.sh
# Description:  Email template for PVE NAS user credentials
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------
#---- Dependencies -----------------------------------------------------------------
#---- Static Variables -------------------------------------------------------------

# Check for Remote WAN Address status
if  [ $(cat /etc/proftpd/conf.d/global_default.conf | grep '^#\s*SFTP_REMOTE_WAN_ADDRESS=*' | awk -F'=' '{ print $2}') = 1 ]; then
    SFTP_REMOTE_WAN_ADDRESS='Not available'
elif [ $(cat /etc/proftpd/conf.d/global_default.conf | grep '^#\s*SFTP_REMOTE_WAN_ADDRESS=*' | awk -F'=' '{ print $2}') != 1 ]; then
    SFTP_REMOTE_WAN_ADDRESS=$(cat /etc/proftpd/conf.d/global_default.conf | grep '^#\s*SFTP_REMOTE_WAN_ADDRESS=*' | awk -F'=' '{ print $2 }' |  sed 's/^[ \t]*//;s/[ \t]*$//')
fi
# Check for Remote Port Address status
if  [ $(cat /etc/proftpd/conf.d/global_default.conf | grep '^#\s*SFTP_REMOTE_WAN_PORT=*' | awk -F'=' '{ print $2}') = 1 ]; then
    SFTP_REMOTE_WAN_PORT='Not available'
elif [ $(cat /etc/proftpd/conf.d/global_default.conf | grep '^#\s*SFTP_REMOTE_WAN_PORT=*' | awk -F'=' '{ print $2}') != 1 ]; then
    SFTP_REMOTE_WAN_PORT=$(cat /etc/proftpd/conf.d/global_default.conf | grep '^#\s*SFTP_REMOTE_WAN_PORT=*' | awk -F'=' '{ print $2 }' |  sed 's/^[ \t]*//;s/[ \t]*$//')
fi

# Check SFTP LAN Port
LOCAL_LAN_PORT=$(cat /etc/proftpd/conf.d/sftp.conf | grep '^\s*Port.*[0-9]$' |  sed 's/^[ \t]*//;s/[ \t]*$//' | awk -F' ' '{ print $2}')

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Email user credentials
# Email body text
cat <<-EOF > email_body.html
To: $(grep -r "root=.*" /etc/ssmtp/ssmtp.conf | grep -v "#" | sed -e 's/root=//g')
From: donotreply@${HOSTNAME}_server.local
Subject: Login Credentials for NAS user: ${USER}
Mime-Version: 1.0
Content-Type: multipart/mixed; boundary="ahuacate"

--ahuacate
Content-Type: text/html

<h3><strong>---- Login credentials for user '${USER^^}' ${HOSTNAME^} account</strong></h3>
<p>Use the attached SSH keys for authentication when you are sFTP or SSH connecting to our NAS server. Remember to always keep your private keys safe. SSH keys should never be accessible to anyone other than the NAS user account holder.</p>
<p>The Users login credentials details are:</p>
<ul style="list-style-type: square;">
<li><strong>Username</strong> : ${USER}</li>
<li><strong>Password</strong> : ${PASSWORD}</li>
<li><strong>Primary User Group</strong> : ${GROUP}</li>
<li><strong>Supplementary User Group</strong> : $(if [ ${GROUP} == chrootjail ]; then echo "None"; else echo -e ${USERMOD} | sed 's/^...//' | sed 's/,/, /'; fi)</li>
<li><strong>Private SSH Key (Standard)</strong> : id_${USER,,}_ed25519</li>
<li><strong>Private SSH Key (PPK version)</strong> : id_${USER,,}_ed25519.ppk</li>
<li><strong>NAS LAN IP Address</strong> : $(hostname -i)</li>
<li><strong>NAS WAN Address</strong> : ${SFTP_REMOTE_WAN_ADDRESS}</li>
<li><strong>SMB Status</strong> : Enabled</li>
</ul>

<h3>---- Account type (folder access level)</h3>
<p>The User has been issued a '${GROUP}' level account type. The User's folder access rights are as follows:</p>
$(if [ ${GROUP} == privatelab ]; then
echo '<div>
<ul style="list-style-type: square;">
<li>privatelab  -  <em>Private storage including 'medialab' &amp; 'homelab' rights</em></li>
</ul>
</div>'
elif [ ${GROUP} == homelab ]; then
echo '<div>
<ul style="list-style-type: square;">
<li>homelab  -  <em>Everything to do with a smart home including 'medialab'</em></li>
</ul>
</div>'
elif [ ${GROUP} == medialab ]; then
echo '<div>
<ul style="list-style-type: square;">
<li>medialab  -  <em>Everything to do with media (i.e movies, series &amp; music)</em></li>
</ul>
</div>'
elif [ ${GROUP} == chrootjail ]; then
echo '<div>'
echo '<ul style="list-style-type: square;">'
echo '<li>chrootjail  -  The User is safe and secure in a jailed account ( <em>a good thing</em> )</li>'
echo "<li>Jail Level  -  $(if [ ${JAIL_TYPE} = level01 ]; then echo -e ${LEVEL01}; elif [ ${JAIL_TYPE} = level02 ]; then echo -e ${LEVEL02}; elif [ ${JAIL_TYPE} = level03 ]; then echo -e ${LEVEL03}; fi)</li>"
echo '</ul>'
echo '</div>'
fi)

<h3>---- Client SMB LAN ${HOSTNAME^} connection</h3>
<p>SMB, or Server Message Block, is the method used by Microsoft Windows networking, and with the Samba protocol on Apple Mac and Linux/Unix.</p>
<p>1) MS Window Clients</p>
<ul style="list-style-type: square;">
<li><strong>Server address</strong> : \\\\$(hostname -i)</li>
<li><strong>User name</strong> : ${USER}</li>
<li><strong>Password</strong> : ${PASSWORD}</li>
</ul>
<p>2) Apple Mac or Linux Clients</p>
<ul style="list-style-type: square;">
<li><strong>Server address</strong> : smb://$(hostname -i)</li>
<li><strong>Connect as</strong> : Registered User</li>
<li><strong>Name</strong> : ${USER}</li>
<li><strong>Password</strong> : ${PASSWORD}</li>
</ul>

<h3>---- Client SFTP ${HOSTNAME^} connection</h3>
<p>Only SFTP is enabled (standard FTP connections are denied) with a login type by SSH key only. For connecting we recommend the free Filezilla FTP client software ( https://filezilla-project.org/download.php ). Use the Filezilla connection tool 'File' &gt; 'Site Manager' and create a 'New Site' account with the following credentials.</p>
<ul style="list-style-type: square;">
<li><strong>Protocol</strong> : SFTP - SSH File Transfer Protocol</li>
<li><strong>Login Type</strong> : Key file</li>
<li><strong>User</strong> : ${USER}</li>
<li><strong>Key file</strong> : id_${USER,,}_ed25519.ppk</li>
</ul>
<p>Depending on your account type you can select either a local and/or remote SFTP connection method.</p>
<p>1) LAN Access - For LAN access only.</p>
<ul style="list-style-type: square;">
<li><strong>Host address</strong> : $(hostname -i)</li>
<li><strong>Port</strong> : ${LOCAL_LAN_PORT}</li>
</ul>
<div>2) WAN Access - For remote internet access only.</div>
<ul style="list-style-type: square;">
<li><strong>Host address</strong> : ${SFTP_REMOTE_WAN_ADDRESS}</li>
<li><strong>Port</strong> : ${SFTP_REMOTE_WAN_PORT}</li>
</ul>
<div>Note: FileZilla requires the PPK private SSH key "id_${USER,,}_ed25519.ppk" not the standard private SSH key "id_${USER,,}_ed25519".</div>
<p> </p>
<div> </div>
<div><hr /></div>
<div>
<h3>---- Attachment Details</h3>
<p>Attached files are:</p>
<div>
<ol>
<li>Private SSH Key (Standard) : id_${USER,,}_ed25519</li>
<li>Private SSH Key (PPK version) : id_${USER,,}_ed25519.ppk</li>
</ol>

--ahuacate
Content-Type: application/zip
Content-Disposition: attachment; filename="id_${USER,,}_ed25519"
Content-Transfer-Encoding: base64
$(if [ ${GROUP} == privatelab ] || [ ${GROUP} == homelab ] || [ ${GROUP} == medialab ]; then
    echo '$(openssl base64 < /srv/${HOSTNAME}/homes/${USER}/.ssh/id_${USER,,}_ed25519)'
elif [ ${GROUP} == chrootjail ]; then
    echo '$(openssl base64 < /${HOME_BASE}${USER}/.ssh/id_${USER,,}_ed25519)'
fi)

--ahuacate
Content-Type: application/zip
Content-Disposition: attachment; filename="id_${USER,,}_ed25519.ppk"
Content-Transfer-Encoding: base64
$(if [ ${GROUP} == privatelab ] || [ ${GROUP} == homelab ] || [ ${GROUP} == medialab ]; then
    echo '$(openssl base64 < /srv/${HOSTNAME}/homes/${USER}/.ssh/id_${USER,,}_ed25519.ppk)'
elif [ ${GROUP} == chrootjail ]; then
    echo '$(openssl base64 < /${HOME_BASE}${USER}/.ssh/id_${USER,,}_ed25519.ppk)'
fi)

--ahuacate
EOF