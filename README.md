<h1>PVE ZFS File Server (NAS)</h1>

This guide is for building PVE hosted ZFS storage to work as your NAS.

Our PVE NAS has two components referred to as the NAS backend and frontend. The NAS backend is a PVE ZFS storage pool made up of hard disks. The NAS frontend is a Linux Ubuntu PVE container providing all of your general NAS services to network clients. 

The NAS backend uses the ZFS Raid file system which is natively supported by Proxmox. The NAS frontend container, labelled `nas-01`, supports any Linux Ubuntu file server service or networking protocol including:

- Networking protocols like NFS and Samba
- Linux user & group management, file security and permissions
- General PVE NAS administration is done using the Webmin web-based system configuration tool.

The NAS frontend is accessible via Webmin. Use your Ubuntu CT root credentials, or any newly created valid NAS user which has been granted Webmin access rights, to perform countless management tasks. The Webmin URL is https://nas-01:10000/ or https://>insert IP address<:10000/

The NAS backend uses dedicated storage disks in a ZFS Raid Pool (Tank) file system. A default ZFS file system of storage folders, system users are pre-configured with file permissions that work with all our PVE CTs (i.e. Sonarr, Radarr, Home Assistant).

Our default NAS hostname is `nas-01`.

As with all our guides there is a Easy Script to automate your PVE NAS build, installation and configuration. The Easy Script offers the installer options based on your available hardware.

Our Easy Script creates the following base set of users, groups and folders:

| Defaults                 | Description                   | Notes                                                                                                                |
|--------------------------|-------------------------------|----------------------------------------------------------------------------------------------------------------------|
| **Default User Groups**  |                               |                                                                                                                      |
|                          | medialab - GUID 65605         | For media Apps (Sonarr, Radar, Jellyfin etc)                                                                         |
|                          | homelab - GUID 65606          | For everything to do with your Smart Home (CCTV, Home Assistant)                                                     |
|                          | privatelab - GUID 65607       | Power, trusted, admin Users                                                                                          |
|                          | chrootjail - GUID 65608       | Users are restricted or jailed within their own home folder. But they they have read only access to medialab folders |
| **Default Users**        |                               |                                                                                                                      |
|                          | media - UID 1605              | Member of group medialab                                                                                             |
|                          | home - UID 1606               | Member of group homelab. Supplementary member of group medialab                                                      |
|                          | private - UID 1607            | Member of group private lab. Supplementary member of group medialab, homelab                                         |
| **Default Base Folders** |                               |                                                                                                                      |
|                          | /srv/CT_HOSTNAME/audio        |                                                                                                                      |
|                          | /srv/CT_HOSTNAME/backup       |                                                                                                                      |
|                          | /srv/CT_HOSTNAME/books        |                                                                                                                      |
|                          | /srv/CT_HOSTNAME/cloudstorage |                                                                                                                      |
|                          | /srv/CT_HOSTNAME/docker       |                                                                                                                      |
|                          | /srv/CT_HOSTNAME/downloads    |                                                                                                                      |
|                          | /srv/CT_HOSTNAME/git          |                                                                                                                      |
|                          | /srv/CT_HOSTNAME/homes        |                                                                                                                      |
|                          | /srv/CT_HOSTNAME/music        |                                                                                                                      |
|                          | /srv/CT_HOSTNAME/openvpn      |                                                                                                                      |
|                          | /srv/CT_HOSTNAME/photo        |                                                                                                                      |
|                          | /srv/CT_HOSTNAME/proxmox      |                                                                                                                      |
|                          | /srv/CT_HOSTNAME/public       |                                                                                                                      |
|                          | /srv/CT_HOSTNAME/sshkey       |                                                                                                                      |
|                          | /srv/CT_HOSTNAME/video        |                                                                                                                      |

The above default Linux users and groups (media:medialab, home:homelab, private:privatelab) are special users with a UID and GUID ready for our containerized (CT) applications, such as Sonarr, Radarr and Jellyfin. These special users have restricted custom UID & GUID access rights to NAS files. Do not delete these users!

**Network Prerequisites**

- [x] Layer 2/3 Network Switches
- [x] Network Gateway is `XXX.XXX.XXX.5` ( *default is 192.168.1.5* )
- [x] Network DHCP server is `XXX.XXX.XXX.5` ( *default is 192.168.1.5* )
- [x] Internet access for the PVE host

**Mandatory Prerequisites**

- [ ] PVE host installed with a minimum of 3x NAS certified rotational hard disks

**Optional Prerequisites**

- [ ] PVE Host configured with PVE Host SSD Cache (Recommended)

**Other prerequisites** (information the installer should have readily available before starting):

- [ ] Read the list.


<h4>Easy Script</h4>

Easy Scripts are based on bash scripting. Simply `Cut & Paste` our Easy Script command into your terminal window, press `Enter` and follow the prompts and terminal instructions. But PLEASE first read our guide so you fully understand each scripts prerequisites and your input requirements.

**Installation**
This Easy Script will create a new PVE NAS CT, create PVE NAS User Accounts, give the installer options to run our optional add-ons, and fully configure your new PVE NAS (Recommended).

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_create_ct.sh)"
```

**Add-on** (optional)
Optional Add-on Easy Scripts can be run anytime. They are for adding new PVE NAS user accounts, installing a new service or even updating your PVE NAS OS release. Your options include:
1. Adding a Jailed Chroot User Account
2. Adding a Power User Account
3. Adding a Kodi Rsync User Account
4. Install & Configure a SSMTP Server
5. Install & Configure ProFTPd Server
6. PVE NAS OS Version Release Updater
7. Create a new Medialab-Rsync Server CT (for Kodi players only)

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_easyscript_addon_ct.sh)"
```

<hr>

<h4>Table of Contents</h4>
<!-- TOC -->

- [1. Preparing your PVE NAS Hardware](#1-preparing-your-pve-nas-hardware)
    - [1.1. PVE Host installed RAM](#11-pve-host-installed-ram)
    - [1.2. PVE Host SSD Cache](#12-pve-host-ssd-cache)
        - [1.2.1. PVE OS SSD Partition Setup](#121-pve-os-ssd-partition-setup)
        - [1.2.2. Dedicated SSD ZFS Cache Setup](#122-dedicated-ssd-zfs-cache-setup)
    - [1.3. Installation of ZFS Storage Disks](#13-installation-of-zfs-storage-disks)
- [2. Installer Prerequisite Credentials and inputs needed](#2-installer-prerequisite-credentials-and-inputs-needed)
    - [2.1. A System designated Administrator Email](#21-a-system-designated-administrator-email)
    - [2.2. SMTP Server Credentials](#22-smtp-server-credentials)
    - [2.3. NAS Hostname](#23-nas-hostname)
    - [2.4. NAS IPv4 Address](#24-nas-ipv4-address)
    - [2.5. Network VLAN Aware](#25-network-vlan-aware)
    - [2.6. NAS Gateway IPv4 Address](#26-nas-gateway-ipv4-address)
    - [2.7. NAS Root Password](#27-nas-root-password)
    - [2.8. USB Passthrough to CT](#28-usb-passthrough-to-ct)
- [3. About our User Accounts](#3-about-our-user-accounts)
    - [3.1. Create New "Power User" Accounts](#31-create-new-power-user-accounts)
    - [3.2. Create Restricted and Jailed User Accounts (Standard Users)](#32-create-restricted-and-jailed-user-accounts-standard-users)
    - [3.3. Create a KODI_RSYNC User](#33-create-a-kodi_rsync-user)

<!-- /TOC -->
<hr>

# 1. Preparing your PVE NAS Hardware

Your PVE NAS host hardware should be configured as per our [PVE Host Build](https://github.com/ahuacate/pve-host-build) guide.

## 1.1. PVE Host installed RAM

ZFS depends heavily on memory, so you need at least 16GB (Recommend 32GB). In practice, use as much you can get for your hardware/budget. To prevent data corruption, we recommend the use of high quality ECC RAM (if your mainboard supports EEC).

## 1.2. PVE Host SSD Cache

ZFS allows for tiered caching of data through the use of memory caches. While ZFS cache is optional we recommend the use of ZFS cache.

Whether you use partitions on your PVE host SSD or install dedicated SSDs, ZFS cache will provide High Speed disk I/O:

- ZFS Intent Log, or ZIL, to buffer WRITE operations.
- ARC and L2ARC which are meant for READ operations.

Our [PVE Host Build](https://github.com/ahuacate/pve-host-build#302-pve-os-install---primary-host---1-2x-ssd-os--1-2x-ssd-zfs-cache---zfs-file-server) guide has more detail.

### 1.2.1. PVE OS SSD Partition Setup

This is the most cost effective method of deploying ZFS cache. Instructions are in our [PVE Host Build](https://github.com/ahuacate/pve-host-build#12-primary-host---creating-ssd-partitions-for-zfs-cache) guide.

### 1.2.2. Dedicated SSD ZFS Cache Setup

A dedicated ZFS cache SSD setup is the more costly method with no net performance gain. Instructions are in our [PVE Host Build](https://github.com/ahuacate/pve-host-build#122-primary-host---partition-dedicated-zfs-cache-ssd---zfs-file-server) guide.

## 1.3. Installation of ZFS Storage Disks

We recommend you install a minimum of 3x NAS certified rotational hard disks in your host. When installing the disks make a note of logical SATA port IDs ( i.e sdc, sdd, sde ) you are connecting each hard disk to. This will help you identify which disks to format and add to your new ZFS storage pool.

Our Easy Script has the options to use the following ZFS Raid builds:

|ZFS Raid Type|Description
|----|----|
|RAID0|Also called “striping”. No redundancy, so the failure of a single drive makes the volume unusable.
|RAID1|Also called “mirroring”. Data is written identically to all disks. The resulting capacity is that of a single disk.
|RAID10|A combination of RAID0 and RAID1. Requires at least 4 disks.
|RAIDZ1|A variation on RAID-5, single parity. Requires at least 3 disks.
|RAIDZ2|A variation on RAID-5, double parity. Requires at least 4 disks.
|RAIDZ3|A variation on RAID-5, triple parity. Requires at least 5 disks.

Remember our Easy Script will destroy all existing data on these storage hard disks and its not recoverable!

# 2. Installer Prerequisite Credentials and inputs needed

Our Easy Script requires the installer to provide some inputs. The installer will be given default values to use or the option to input your own values.

We recommend you first prepare the following and have your credentials ready before running our NAS build scripts.

## 2.1. A System designated Administrator Email

You need a designated administrator email address. All server alerts and server activity notifications will be sent to this email address. GMail works fine.

## 2.2. SMTP Server Credentials

Our Easy Script will give you the the option to install a SSMTP Email server. SSMTP is Mail Transfer Agent (MTA) used to send email alerts about your machine like details about new user accounts, unwarranted login attempts and system critical alerts to the systems designated administrator.

You will be asked for the credentials of a SMTP Server. You can use Gmail, GoDaddy, AWS or any SMTP server credentials (i.e address, port, username and password, encryption type etc.

But we recommend you create a account at [Mailgun](mailgun.com) to relay your NAS system emails to your designated administrator. With [Mailgun](mailgun.com) you are not potentially exposing your private email server credentials held within a text file on your NAS. This is a added layer of security.

## 2.3. NAS Hostname

The default hostname is `nas-01`. With our naming convention any secondary NAS appliances should have a hostname like `nas-02`. You may change the hostname to to whatever you like. But for networking, use of all our Easy Scripts, hostname resolving, we recommend you use the default hostname naming convention ( `nas-01` ).

## 2.4. NAS IPv4 Address

By default it is `192.168.1.10/24`. You may change it to whatever IPv4 address you want. Just note the VLAN ID.

## 2.5. Network VLAN Aware

You must answer a Easy Script prompt asking if your network is VLAN aware. The script will resolve your NAS VLAN ID automatically.

## 2.6. NAS Gateway IPv4 Address

The script will attempt to find your Gateway IPv4 address. Confirm with `Enter` or type in the correct Gateway IP address.

## 2.7. NAS Root Password

Have a root password ready and stored away safely.

## 2.8. USB Passthrough to CT

There can be good reasons to access USB disk ware directly from yo CT. To make a physically connected USB device accessible inside a CT, for example NAS-01, t CT configuration file requires modification.

During the installation the Easy Script will display all available USB devices on the host computer. But you need to identify which USB host device ID to passthrough to the NAS CT. The simplest way is to plugin a physical USB memory stick, for example a SanDisk Cruzer Blade, into your preferred USB port on the host machine. Then to physically identify the USB host device ID (the USB port) to passthrough to PVE NAS CT it will be displayed on your terminal when running our Easy Script at the required USB passthrough stage as for example:

```
5) Bus 002 Device 004: ID 0781:5567 SanDisk Corp. Cruzer Blade
```

In the above example, you will select number **5** to passthrough. Then ONLY your PVE host hardware USB port where the SanDisk Blade drive was inserted is readable by yo in the future.

So have a spare USB drive ready and available.

# 3. About our User Accounts

New user accounts can be created using our Add-on Easy Script.

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_easyscript_addon_ct.sh)"
```

The Add-on Easy Script will prompt the installer with options:

## 3.1. Create New "Power User" Accounts

Power Users are trusted persons with privileged access to data and application resources hosted on your PVE NAS. Power Users are NOT standard users! Standard users are added with another chroot jail script. Each new Power Users security permissions are controlled by Linux groups. Group security permission levels are as follows:

| GROUP NAME   | PERMISSIONS                                            |
|--------------|--------------------------------------------------------|
| `medialab`   | Everything to do with media (i.e movies, TV and music) |
| `homelab`    | Everything to do with a smart home including medialab  |
| `privatelab` | Private storage including medialab & homelab rights    |

## 3.2. Create Restricted and Jailed User Accounts (Standard Users)

Every new user is restricted or jailed within their own home folder. In Linux this is called a chroot jail. But you can select the level of restrictions which are applied to each newly created user. This technique can be quite useful if you want a particular user to be provided with a limited system environment, limited folder access and at the same time keep them separate from your main server system and other personal data. The chroot technique will automatically jail selected users belonging to the `chrootjail` user group upon ssh or ftp login.

An example of a jailed user is a person who has remote access to your PVE NAS but is restricted to your video library (TV, movies, documentary), public folders and their home folder for cloud storage only. Remote access to your PVE NAS is restricted to sftp, ssh and rsync using private SSH RSA encrypted keys. The user can backup their mobile, tablet, notebook or any device.

When creating a new user you are given the choice to select a Level of `chrootjail` group permissions and access rights per user. We have pre-configured 3 Levels to choose from with varying degree of file access for different types of users.

**Level 1**  -  This user is restricted to their private home folder for data storage and the NAS public folder only. This is ideal for persons whom you DO NOT want to share any media data with. Typical users maybe: persons wanting Cloud storage and nothing more.

**Level 2**  -  This user is restricted to their private home folder for data storage, limited access to the NAS public folder and media library (i.e Restricted to movies, tv, documentary, homevideo folders only). The user is also setup with a downloads folder and special folders within their chrootjail home folder for sharing photos and homevideos with other users or a media server like Emby or Jellyfin. Typical users maybe: family, close friends and children because of limited media access.

**Level 3**  -  This user is restricted to their private home folder for data storage, limited access to the NAS public, audio, books folders and media library (i.e This user level is NOT restricted so they can view ALL media content). The user is also setup with a downloads folder and special folders within their chrootjail home folder for sharing photos and homevideos with other users or a media server like Emby or Jellyfin. Typical users maybe: Power users and adults with full media library access.

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

## 3.3. Create a KODI_RSYNC User

"kodi_rsync" is a special user account created for synchronising a portable or remote kodi media player with a hard disk to your PVE NAS media video, music and photo libraries. Connection is by rSSH rSync. This is for persons wanting a portable copy of their media for travelling to remote locations where there is limited bandwidth or no internet access.

"kodi_rsync" is NOT a media server for Kodi devices. If you want a home media server then create our PVE Jellyfin CT.  Our rSync script will securely connect to your PVE NAS and;
- rsync mirror your selected media library to your kodi player USB disk
- copy your latest media only to your kodi player USB disk
- remove the oldest media to fit newer media
- fill your USB disk to a limit set by you.

The first step involves creating a new user called "kodi_rsync" on your PVE NAS which has limited and restricted permissions granting rSync read access only to your media libraries. The second step, performed at a later stage, is setting up a CoreElec or LibreElec player hardware with a USB hard disk and installing our rSync client scripts along with your PVE NAS user "kodi_rsync" private ssh ed25519 key.

