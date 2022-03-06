<h1>PVE File Server (NAS)</h1>

Our PVE File Server is a fully functional NAS built on a Proxmox CT or VM.

The CT type is a lightweight Ubuntu container requiring only 512Mb of RAM. Storage is provided by Proxmox ZFS Raid using SATA/NVMe or USB connected disks.

The VM type is based on Open Media Vault and requires a SATA/SAS HBA Card.


<h2>Features</h2>

All NAS installation types are fully configured and ready built to support Ahuacate CTs or VMs. Each NAS type install includes:

* Power User & Group Accounts
    * Groups: medialab:65605, homelab:65606, privatelab:65607, chrootjail:65608
    * Users: media:1605, home:1606, private:1607
    * Users media, home and private are for running CT applications
* Chrootjail Group for general User accounts.
* Ready for all Medialab applications such as Sonarr, Radarr, JellyFin, NZBGet and more.
* Full set of base and sub-folders ready for all CT applications
* Folder and user permissions are set including ACLs
* NFS 4.1 exports ready for PVE hosts backend storage mounts
* SMB 3.0 shares with access permissions set ( by User Group accounts )
* Has a Local Domain option to set ( i.e .local, .localdomain, .home.arpa, .lan )
* Toolbox of Easy Scripts to create or delete User accounts, perform OS upgrades and install add-on services (i.e SSMTP, ProFTP)

The NAS is a full turnkey installation. After start-up simply add your user accounts using our Easy Script toolbox.

> It's mandatory your NAS has ALL the required folder share exports, subfolders, permissions, ACLs, Users & Groups ( i.e medialab, homelab and privatelab ), localdomain and networking (SMB/CIF and NFS) configured. If not our CTs for Sonarr, Radarr, Jellyfin and more will not work.


<h2>Prerequisites</h2>

**Network Prerequisites**

- [x] Layer 2/3 Network Switches
- [x] Network Gateway (*default is xxx.xxx.xxx.5*)
- [x] Network DHCP server (*default is xxx.xxx.xxx.5*)
- [x] Search domain server
- [x] Local domain is set on all network devices (see note below)
- [x] PVE host has internet access

Note: The network Local Domain or Search domain must be set. We recommend only top-level domain (spTLD) names for residential and small networks names because they cannot be resolved across the internet. Routers and DNS servers know, in theory, not to forward ARPA requests they do not understand onto the public internet. It is best to choose one of our listed names. Best use one of the following valid names: local, home.arpa, localdomain or lan only.

**Optional Prerequisites**

- [ ] PVE Host SSD/NVMe Cache (Recommended)
- [ ] PCIe SATA/NVMe HBA Adapter Card (i.e LSI 9207-8i)
- [ ] PVE host installed with a minimum of 1x spare empty disk. ( PVE hosted NAS only )


<h2>Installation Options</h2>

If you want dedicated hard-metal NAS, not Proxmox hosted, look at this GitHub [repository](https://github.com/ahuacate/nas-hardmetal). In includes configuration scripts for Synology NAS appliances.

For PVE hosts limited by RAM, less than 16GB, we recommended our Ubuntu-based NAS builds. They require only 512MB RAM and run on a lightweight PVE CT.
<ol>
<li> <h4><b>Ubuntu NAS (PVE SATA/NVMe)</b></h4> - PVE ZFS pool backend, Ubuntu frontend

Proxmox manages the ZFS storage pool backend while Ubuntu does the frontend. ZFS Raid levels depend on the number of disks installed. You also have the option of configuring ZFS cache using SSD drives. ZFS cache will provide High-Speed disk I/O.</li>
<li><h4><b>Ubuntu NAS (USB disks)</b></h4> - PVE USB disk backend, Ubuntu frontend

Here the NAS stores all data on an external USB disk. This is for SFF computing hardware such as Intel NUCs. Your NAS ZFS storage pool backend is fully managed by the Proxmox host.</li>
</ol>

The other build option is a NAS OS solution VM.
<ol>
<li> <h4><b>OMV NAS (HBA Adapter)</b><h/4> - PCIe SATA/NVMe HBA card pass-thru based on Open Media Vault (Under Development)

Here a dedicated PCIe SATA/NVMe HBA Adapter Card (i.e LSI 9207-8i) supports all NAS disks. All OMV storage disks, including any ZFS Cache SSDs, must be connected to the HBA Adapter Card. You cannot co-mingle OMV disks with the PVE hosts mainboard onboard SATA/NVMe devices. OMV manages both backend and frontend.</li>
</ol>

<h4><b>Easy Scripts</b></h4>

Easy Scripts automate the installation and/or configuration processes. Easy Scripts are hardware type-dependent so choose carefully. Easy Scripts are based on bash scripting. `Cut & Paste` our Easy Script command into a terminal window, press `Enter`, and follow the prompts and terminal instructions. 

Our Easy Scripts have preset configurations. The installer may accept or decline the ES values. If you decline the User will be prompted to input all required configuration settings. PLEASE read our guide if you are unsure.


<h4>1. PVE Hosted NAS Installer</h4>
Run in a PVE host SSH terminal.

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/master/pve_nas_installer.sh)"
```
<h4>2. PVE Hosted 'Ubuntu NAS' Administration Toolbox</h4>
Run in a PVE host SSH terminal.

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/master/pve_nas_toolbox.sh)"
```

<hr>

<h4>Table of Contents</h4>
<!-- TOC -->

- [1. PVE Hosted NAS](#1-pve-hosted-nas)
    - [1.1. PVE Host required RAM](#11-pve-host-required-ram)
    - [1.2. ZFS SSD Cache](#12-zfs-ssd-cache)
        - [1.2.1. OMV NAS](#121-omv-nas)
        - [1.2.2. Ubuntu NAS](#122-ubuntu-nas)
            - [1.2.2.1. Partition ZFS Cache Setup -  PVE OS SSD/NVMe](#1221-partition-zfs-cache-setup----pve-os-ssdnvme)
            - [1.2.2.2. Dedicated ZFS Cache Setup - SSD/NVMe](#1222-dedicated-zfs-cache-setup---ssdnvme)
    - [1.3. NAS ZFS Storage Disks](#13-nas-zfs-storage-disks)
    - [1.4. Installer required Inputs](#14-installer-required-inputs)
        - [1.4.1. A System designated Administrator Email](#141-a-system-designated-administrator-email)
        - [1.4.2. SSMTP Server Credentials](#142-ssmtp-server-credentials)
        - [1.4.3. NAS Hostname](#143-nas-hostname)
        - [1.4.4. NAS IPv4 Address](#144-nas-ipv4-address)
        - [1.4.5. NAS Search domain or Local domain](#145-nas-search-domain-or-local-domain)
        - [1.4.6. Network VLAN Aware](#146-network-vlan-aware)
        - [1.4.7. NAS Gateway IPv4 Address](#147-nas-gateway-ipv4-address)
        - [1.4.8. NAS Root Password](#148-nas-root-password)
- [2. Ubuntu NAS Administration Toolbox](#2-ubuntu-nas-administration-toolbox)
    - [2.1. Create new User Accounts](#21-create-new-user-accounts)
        - [2.1.1. Create "Power User" Accounts](#211-create-power-user-accounts)
        - [2.1.2. Create Restricted and Jailed User Accounts (Standard Users)](#212-create-restricted-and-jailed-user-accounts-standard-users)
- [3. Other Toolbox options](#3-other-toolbox-options)

<!-- /TOC -->

<hr>

# 1. PVE Hosted NAS
Your PVE NAS host hardware determines your NAS frontend options.
  - OMV requires a PCIe SATA/NVMe HBA Adapter Card (i.e LSI 9207-8i).
  - Ubuntu Frontend, PVE ZFS backend (SATA or USB).

## 1.1. PVE Host required RAM 

A ZFS backend depends heavily on RAM, so you need at least 16GB (Recommend 32GB). OMV specifies a minimum of 8GB RAM.

Our Ubuntu NAS CT requires only 512MB RAM because the ZFS backend is managed by the Proxmox host. In practice, install as much RAM you can get for your hardware/budget.

## 1.2. ZFS SSD Cache

ZFS allows for tiered caching of data through the use of memory caches. While ZFS cache is optional we recommend the use of ZFS cache.

With a Ubuntu NAS, cache partitions can be made using PVE host drives or better use dedicated SSD/NVMe disks. ZFS cache will provide High-Speed disk I/O:

- ZFS Intent Log, or ZIL, to buffer WRITE operations.
- ARC and L2ARC are meant for READ operations.

### 1.2.1. OMV NAS
For optimum performance install a dedicated PCIe NVMe HBA Adapter Card dedicated for ZFS Cache.

### 1.2.2. Ubuntu NAS

Create an SSD/NVMe root drive cache partition or install a dedicated SSD/NVMe disk for ZFS Cache.

#### 1.2.2.1. Partition ZFS Cache Setup -  PVE OS SSD/NVMe 

This is the most cost-effective method of deploying ZFS cache. Instructions are in our [PVE Host Setup](https://github.com/ahuacate/pve-host-setup#121-primary-host---partition-pve-os-ssds-for-zfs-cache---zfs-file-server) guide.

#### 1.2.2.2. Dedicated ZFS Cache Setup - SSD/NVMe

A dedicated ZFS cache SSD setup is the more costly method with no net performance gain. Instructions are in our [PVE Host Setup](https://github.com/ahuacate/pve-host-setup#122-primary-host---partition-dedicated-zfs-cache-ssd---zfs-file-server) guide.

## 1.3. NAS ZFS Storage Disks

Both OMV and Ubuntu NAS grant the User the option to set different ZFS Raid levels.

We recommend you install a minimum of 3x NAS certified rotational hard disks in your host. When installing the disks make a note of the logical SATA port IDs ( i.e sdc, sdd, sde ) you are connecting to. This helps you identify which disks to format and add to your new ZFS storage pool.

Our Ubuntu NAS Easy Script has the options to use the following ZFS Raid builds:

|ZFS Raid Type|Description
|----|----|
|RAID0|Also called “striping”. No redundancy, so the failure of a single drive makes the volume unusable.
|RAID1|Also called “mirroring”. Data is written identically to all disks. The resulting capacity is that of a single disk.
|RAID10|A combination of RAID0 and RAID1. Requires at least 4 disks.
|RAIDZ1|A variation on RAID-5, single parity. Requires at least 3 disks.
|RAIDZ2|A variation on RAID-5, double parity. Requires at least 4 disks.
|RAIDZ3|A variation on RAID-5, triple parity. Requires at least 5 disks.

Remember, our Easy Script will destroy all existing data on these storage hard disks!

## 1.4. Installer required Inputs

Our Easy Script requires the User to provide some inputs. The installer will be given default values to use or the option to input your values.

With a OMV build, the installer must enter the details manually using the native OMV WebGUI. No Easy Script exists for configuring OMV.

We recommend you first prepare the following and have your credentials ready before running our NAS build scripts.

### 1.4.1. A System designated Administrator Email

You need a designated administrator email address. All server alerts and activity notifications will be sent to this email address. Gmail works fine.

### 1.4.2. SSMTP Server Credentials

Our Ubuntu NAS Easy Script will give you the option to install an SSMTP Email server (Recommended). SSMTP is Mail Transfer Agent (MTA) used to send email alerts about your machines like details about new user accounts, unwarranted login attempts, and system critical alerts to the system's designated administrator.

Having a working SMTP server makes life much easier. For example, you can receive all new User Account SSH keys and login credentials via email.

You will be asked for the credentials of an SMTP Server. You can use GMail, GoDaddy, AWS or any SMTP server credentials (i.e address, port, username and password, encryption type etc.

But we recommend you create an account at [Mailgun](https://mailgun.com) to relay your NAS system emails to your designated administrator. With [Mailgun](https://mailgun.com) you are not potentially exposing your private email server credentials held within a text file on your NAS. This is an added layer of security.

### 1.4.3. NAS Hostname

The default hostname is `nas-01`. Our naming convention stipulates all NAS hostnames end with a numeric suffix. Extra NAS appliances should be named `nas-02`, `nas-03` and so on. You may change the hostname to whatever you like. But for networking, integration with our Easy Scripts, hostname resolving, we recommend you use the default hostname naming convention ( `nas-01` ).

### 1.4.4. NAS IPv4 Address

The default is 'dhcp' IPv4. We recommend you use DHCP and fix the IP assignment at DHCP server ( i.e router, PiHole ). You may change to whatever IPv4 or IPv6 address you want. Just note the VLAN ID.

### 1.4.5. NAS Search domain or Local domain

The default search domain is 'local'. The User must set a 'search domain' or 'local domain' name.

The search domain name must match the setting used in your router configuration setting labelled as 'Local Domain' or 'Search Domain' depending on the device manufacturer. 

We recommend top-level domain (spTLD) names for residential and small networks names because they cannot be resolved across the internet. Routers and DNS servers know, in theory, not to forward ARPA requests they do not understand onto the public internet. It is best to choose one of our listed names.

* local ( Recommended )
* home.arpa ( Recommended )
* lan
* localdomain

If you insist on using a made-up search domain name, then DNS requests may go unfulfilled by your router and forwarded onto global internet DNS root servers. This leaks information about your network such as device names. Alternatively, you can use a registered domain name or subdomain if you know what you are doing by selecting the 'Other' option.

### 1.4.6. Network VLAN Aware

You must answer an Easy Script prompt asking if your network is VLAN aware. The script will resolve your NAS VLAN ID automatically.

### 1.4.7. NAS Gateway IPv4 Address

The script will attempt to find your Gateway IPv4 address. Confirm with `Enter` or type in the correct Gateway IP address.

### 1.4.8. NAS Root Password

The default root password is 'ahuacate'. You can always change it at a later stage.

# 2. Ubuntu NAS Administration Toolbox

'Easy Scripts' are available for administrative tasks. (i.e for creating new user accounts, installing SMTP servers, and more.)

Run the following Easy Script and select the task you want to perform.

```Ubuntu NAS administration tasks
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/master/pve_nas_toolbox.sh)"
```

## 2.1. Create new User Accounts

New user accounts can be created using our Ubuntu NAS administration tool.

The Easy Script will prompt the installer with selectable options:

### 2.1.1. Create "Power User" Accounts

Power Users are trusted persons with privileged access to data and application resources hosted on your PVE NAS. Power Users are NOT standard users! Standard users are added with the 'Jailed User Account' option. Each new Power Users security permissions are controlled by Linux groups. Group security permission levels are as follows:

| GROUP NAME   | PERMISSIONS                                            |
|--------------|--------------------------------------------------------|
| `medialab`   | Everything to do with media (i.e movies, TV and music) |
| `homelab`    | Everything to do with a smart home including medialab  |
| `privatelab` | Private storage including medialab & homelab rights    |

### 2.1.2. Create Restricted and Jailed User Accounts (Standard Users)

Every new user is restricted or jailed within their own home folder. In Linux, this is called a chroot jail. But you can select a level of restriction which is applied to each newly created user. This technique can be quite useful if you want a particular user to be provided with a limited system environment, limited folder access and at the same time keep them separate from your main server system and other personal data. The chroot technique will automatically jail selected users belonging to the `chrootjail` user group upon ssh or ProFTPd SFTP login (standard FTP mode is disabled).

An example of a jailed user is a person who has remote access to your PVE NAS but is restricted to your video library (TV, movies, documentary), public folders and their home folder for cloud storage only. Remote access to your PVE NAS is restricted to sftp, ssh and rsync using private SSH RSA encrypted keys. The user can backup their mobile, tablet, notebook or any device.

When creating a new user you are given the choice to select a Level of `chrootjail` group permissions and access rights per user. We have pre-configured 3 Levels to choose from with varying degrees of file access for different types of users.

**Level 1**  -  This user is restricted to their private home folder for data storage and the NAS public folder only. This is ideal for persons whom you DO NOT want to share any media data with. Typical users maybe: persons wanting Cloud storage and nothing more.

**Level 2**  -  This user is restricted to their private home folder for data storage, limited access to the NAS public folder and media library (i.e Restricted to movies, tv, documentary, homevideo folders only). The user is also setup with a downloads folder and special folders within their chrootjail home folder for sharing photos and homevideos with other users or a media server like Emby or Jellyfin. Typical users maybe: family, close friends and children because of limited media access.

**Level 3**  -  This user is restricted to their private home folder for data storage, limited access to the NAS public, audio, books folders, and media library (i.e This user level is NOT restricted so they can view ALL media content). The user is also set up with a downloads folder and special folders within their chrootjail home folder for sharing photos and home videos with other users or a media server like Emby or Jellyfin. Typical users maybe: Power users and adults with full media library access.

The options are options are:

| GROUP NAME   | USER NAME                                               |
|--------------|---------------------------------------------------------|
| `chrootjail` | /srv/hostname/homes/chrootjail/`username_injail`        |
|              |                                                         |
| LEVEL 1      | FOLDER                                                  |
| -rwx----     | /srv/hostname/homes/chrootjail/`username_injail`        |
|              | Bind Mounts - mounted at ~/public folder                |
| -rwxrwxrw-   | /srv/hostname/homes/chrootjail/`username_injail`/public |
|              |                                                         |
| LEVEL 2      | FOLDER                                                  |
| -rwx----     | /srv/hostname/homes/chrootjail/`username_injail`        |
|              | Bind Mounts - mounted at ~/share folder                 |
| -rwxrwxrw-   | /srv/hostname/downloads/user/`username_downloads`       |
| -rwxrwxrw-   | /srv/hostname/photo/`username_photo`                    |
| -rwxrwxrw-   | /srv/hostname/public                                    |
| -rwxrwxrw-   | /srv/hostname/video/homevideo/`username_homevideo`      |
| -rwxr---     | /srv/hostname/video/movies                              |
| -rwxr---     | /srv/hostname/video/tv                                  |
| -rwxr---     | /srv/hostname/video/documentary                         |
|              |                                                         |
| LEVEL 3      | FOLDER                                                  |
| -rwx----     | /srv/`hostname`/homes/chrootjail/`username_injail`      |
|              | Bind Mounts - mounted at ~/share folder                 |
| -rwxr---     | /srv/hostname/audio                                     |
| -rwxr---     | /srv/hostname/books                                     |
| -rwxrwxrw-   | /srv/hostname/downloads/user/`username_downloads`       |
| -rwxr---     | /srv/hostname/music                                     |
| -rwxrwxrw-   | /srv/hostname/photo/`username_photo`                    |
| -rwxrwxrw-   | /srv/hostname/public                                    |
| -rwxrwxrw-   | /srv/hostname/video/homevideo/`username_homevideo`      |
| -rwxr---     | /srv/hostname/video (All)                               |

All Home folders are automatically suffixed: `username_injail`.


# 3. Other Toolbox options
User options include:
1. Upgrade NAS Ubuntu OS
2. Install & Configure Fail2ban
3. Install & Configure a SSMTP server
4. Install & Configure ProFTPd server

<hr>