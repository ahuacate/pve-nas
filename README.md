<h1>PVE File Server (NAS)</h1>

This guide is for building a Proxmox based NAS. 

You can choose between a TrueNAS or a Ubuntu-based NAS. Both systems have the same folder shares, network permissions, ACLs, default Users & Groups ( medialab, homelab and privatelab ), samba, networking (SMB/CIF and NFS), and are ready for our suite of PVE CTs (Sonarr, Radarr etc).

For PVE hosts limited by RAM, less than 16GB, we recommended the Ubuntu-based NAS. It requires only 512MB RAM on a PVE LXC container.

NAS build options are:

1)  **TrueNAS (HBA Adapter)** - PCIe SATA/NVMe HBA card pass-thru (UNDER DEVELOPMENT - NOT WORKING)

Here a dedicated PCIe SATA/NVMe HBA Adapter Card (i.e LSI 9207-8i) supports all NAS disks. All TrueNAS storage disks, including any ZFS Cache SSDs, must be connected to the HBA Adapter Card. You cannot co-mingle TrueNAS disks with the PVE hosts mainboard onboard SATA/NVMe devices. TrueNAS manages both backend and frontend.

2)  **Ubuntu NAS (PVE SATA/NVMe)** - PVE ZFS pool backend, Ubuntu frontend

Proxmox manages the ZFS storage pool backend while Ubuntu does the frontend. ZFS Raid levels depend on the number of disks installed. You also have the option of configuring ZFS cache using SSD drives. ZFS cache will provide High-Speed disk I/O.

3)  **Ubuntu NAS (USB disks)** - PVE USB disk backend, Ubuntu frontend

Here the NAS stores all data on an external USB disk. This is for SFF computing hardware such as Intel NUCs. Your NAS ZFS storage pool backend is fully managed by the Proxmox host.

As with all our guides, our Easy Script automates the Users NAS installation and configuration. The Easy Script offers the installer options based on your available hardware.

Upon completion your NAS storage will include a our custom set of users, groups and folders:

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
|                          | /srv/HOSTNAME/audio        |                                                                                                                      |
|                          | /srv/HOSTNAME/backup       |                                                                                                                      |
|                          | /srv/HOSTNAME/books        |                                                                                                                      |
|                          | /srv/HOSTNAME/cloudstorage |                                                                                                                      |
|                          | /srv/HOSTNAME/docker       |                                                                                                                      |
|                          | /srv/HOSTNAME/downloads    |                                                                                                                      |
|                          | /srv/HOSTNAME/git          |                                                                                                                      |
|                          | /srv/HOSTNAME/homes        |                                                                                                                      |
|                          | /srv/HOSTNAME/music        |                                                                                                                      |
|                          | /srv/HOSTNAME/openvpn      |                                                                                                                      |
|                          | /srv/HOSTNAME/photo        |                                                                                                                      |
|                          | /srv/HOSTNAME/proxmox      |                                                                                                                      |
|                          | /srv/HOSTNAME/public       |                                                                                                                      |
|                          | /srv/HOSTNAME/sshkey       |                                                                                                                      |
|                          | /srv/HOSTNAME/video        |                                                                                                                      |
|                          | /srv/HOSTNAME/transcode    | Optional: For high I/O use a dedicated SSD                                                                           |

The above default Linux users and groups (media:medialab, home:homelab, private:privatelab) are special users with a UID and GUID ready for our containerized (CT) applications, such as Sonarr, Radarr and Jellyfin. These special users have restricted custom UID & GUID access rights to NAS files. Do not delete these users!

**Network Prerequisites**

- [x] Layer 2/3 Network Switches
- [x] Network Gateway is `XXX.XXX.XXX.5` ( *default is 192.168.1.5* )
- [x] Network DHCP server is `XXX.XXX.XXX.5` ( *default is 192.168.1.5* )
- [x] PVE host requires internet access

**Mandatory Prerequisites**

- [X] PVE host installed with a minimum of 1x spare empty disk. Backup all data before proceeding with our Easy Script.

**Optional Prerequisites**

- [ ] PVE Host SSD/NVMe Cache (Recommended)
- [ ] PCIe SATA/NVMe HBA Adapter Card (i.e LSI 9207-8i)

Our Easy Scripts assumes your network is VLAN ready. If not, simply decline the Easy Script prompt to accept our default settings (Proceed with our Easy Script defaults (recommended) [y/n]?). You can then set your PVE container or VM variable options.

<h4>PVE NAS Easy Script</h4>
Easy Scripts are based on bash scripting. `Cut & Paste` our Easy Script command into your terminal window, press `Enter`, and follow the prompts and terminal instructions. But PLEASE first read our guide.

**Installation**

NAS Installer & Builder
```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/master/pve_nas_installer.sh)"
```
NAS Administration and Add-On Installer
```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/master/pve_nas_ct_admin_installer.sh)"
```
<hr>

<h4>Table of Contents</h4>
<!-- TOC -->

- [1. Preparing your PVE NAS Hardware](#1-preparing-your-pve-nas-hardware)
    - [1.1. PVE Host required RAM](#11-pve-host-required-ram)
    - [1.2. ZFS SSD Cache](#12-zfs-ssd-cache)
        - [1.2.1. TrueNAS NAS](#121-truenas-nas)
        - [1.2.2. Ubuntu NAS](#122-ubuntu-nas)
            - [1.2.2.1. Partition ZFS Cache Setup -  PVE OS SSD/NVMe](#1221-partition-zfs-cache-setup----pve-os-ssdnvme)
            - [1.2.2.2. Dedicated ZFS Cache Setup - SSD/NVMe](#1222-dedicated-zfs-cache-setup---ssdnvme)
    - [1.3. NAS ZFS Storage Disks](#13-nas-zfs-storage-disks)
- [2. Installer Prerequisite Credentials and inputs needed](#2-installer-prerequisite-credentials-and-inputs-needed)
    - [2.1. A System designated Administrator Email](#21-a-system-designated-administrator-email)
    - [2.2. SSMTP Server Credentials](#22-ssmtp-server-credentials)
    - [2.3. NAS Hostname](#23-nas-hostname)
    - [2.4. NAS IPv4 Address](#24-nas-ipv4-address)
    - [2.5. Network VLAN Aware](#25-network-vlan-aware)
    - [2.6. NAS Gateway IPv4 Address](#26-nas-gateway-ipv4-address)
    - [2.7. NAS Root Password](#27-nas-root-password)
    - [2.8. USB Passthrough to CT](#28-usb-passthrough-to-ct)
- [3. Ubuntu NAS](#3-ubuntu-nas)
    - [3.1. Create new User Accounts](#31-create-new-user-accounts)
        - [3.1.1. Create "Power User" Accounts](#311-create-power-user-accounts)
        - [3.1.2. Create Restricted and Jailed User Accounts (Standard Users)](#312-create-restricted-and-jailed-user-accounts-standard-users)
        - [3.1.3. Add-ons (optional)](#313-add-ons-optional)
- [4. TrueNAS](#4-truenas)

<!-- /TOC -->

<hr>

# 1. Preparing your PVE NAS Hardware
Your PVE NAS host hardware determines your NAS frontend options.
  - TrueNAS requires a PCIe SATA/NVMe HBA Adapter Card (i.e LSI 9207-8i).
  - Ubuntu Frontend, PVE ZFS backend (SATA or USB).

## 1.1. PVE Host required RAM 

A ZFS backend depends heavily on RAM, so you need at least 16GB (Recommend 32GB). TrueNAS specifies a minimum of 8GB RAM.

Our Ubuntu NAS CT requires only 512MB RAM because the ZFS backend is managed by the Proxmox host. In practice, use as much RAM you can get for your hardware/budget.

## 1.2. ZFS SSD Cache

ZFS allows for tiered caching of data through the use of memory caches. While ZFS cache is optional we recommend the use of ZFS cache.

With a Ubuntu NAS, cache partitions can be made using PVE host drives or better use dedicated SSD/NVMe disks. ZFS cache will provide High-Speed disk I/O:

- ZFS Intent Log, or ZIL, to buffer WRITE operations.
- ARC and L2ARC are meant for READ operations.

### 1.2.1. TrueNAS NAS
For optimum performance install a dedicated PCIe NVMe HBA Adapter Card dedicated for ZFS Cache.

### 1.2.2. Ubuntu NAS

Create an SSD/NVMe root drive cache partition or install a dedicated SSD/NVMe disk for ZFS Cache.

#### 1.2.2.1. Partition ZFS Cache Setup -  PVE OS SSD/NVMe 

This is the most cost-effective method of deploying ZFS cache. Instructions are in our [PVE Host Setup](https://github.com/ahuacate/pve-host-setup#121-primary-host---partition-pve-os-ssds-for-zfs-cache---zfs-file-server) guide.

#### 1.2.2.2. Dedicated ZFS Cache Setup - SSD/NVMe

A dedicated ZFS cache SSD setup is the more costly method with no net performance gain. Instructions are in our [PVE Host Setup](https://github.com/ahuacate/pve-host-setup#122-primary-host---partition-dedicated-zfs-cache-ssd---zfs-file-server) guide.

## 1.3. NAS ZFS Storage Disks

Both TrueNAS and Ubuntu NAS grant the User the option to set different ZFS Raid levels.

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

# 2. Installer Prerequisite Credentials and inputs needed

Our Easy Script requires the User to provide some inputs. The installer will be given default values to use or the option to input your values.

With a TrueNAS build, the installer must enter the details manually using the native TrueNAS WebGUI. No Easy Script exists for configuring TrueNAS.

We recommend you first prepare the following and have your credentials ready before running our NAS build scripts.

## 2.1. A System designated Administrator Email

You need a designated administrator email address. All server alerts and activity notifications will be sent to this email address. Gmail works fine.

## 2.2. SSMTP Server Credentials

Our Ubuntu NAS Easy Script will give you the option to install an SSMTP Email server (Recommended). SSMTP is Mail Transfer Agent (MTA) used to send email alerts about your machines like details about new user accounts, unwarranted login attempts, and system critical alerts to the system's designated administrator.

Having a working SMTP server makes life much easier. For example, you can receive all new User Account SSH keys and login credentials via email.

You will be asked for the credentials of an SMTP Server. You can use GMail, GoDaddy, AWS or any SMTP server credentials (i.e address, port, username and password, encryption type etc.

But we recommend you create an account at [Mailgun](https://mailgun.com) to relay your NAS system emails to your designated administrator. With [Mailgun](https://mailgun.com) you are not potentially exposing your private email server credentials held within a text file on your NAS. This is an added layer of security.

## 2.3. NAS Hostname

The default hostname is `nas-01`. Our naming convention applies a secondary NAS appliance to be named `nas-02`, `nas-03` and so on. You may change the hostname to whatever you like. But for networking, integration with our Easy Scripts, hostname resolving, we recommend you use the default hostname naming convention ( `nas-01` ).

## 2.4. NAS IPv4 Address

By default `nas-01` is `192.168.1.10/24`. You may change to whatever IPv4 address you want. Just note the VLAN ID.

## 2.5. Network VLAN Aware

You must answer an Easy Script prompt asking if your network is VLAN aware. The script will resolve your NAS VLAN ID automatically.

## 2.6. NAS Gateway IPv4 Address

The script will attempt to find your Gateway IPv4 address. Confirm with `Enter` or type in the correct Gateway IP address.

## 2.7. NAS Root Password

The default root password is 'ahuacate'. You can always change it.

## 2.8. USB Passthrough to CT

There can be good reasons to access USB disk ware directly from your NAS CT. To make a physically connected USB device accessible inside a CT, for example, NAS-01, the CT configuration file requires modification.

During the installation, the Easy Script will display all available USB devices on the host computer. But you need to identify which USB host device ID to pass through to the NAS CT. The simplest way is to plug in a physical USB memory stick, for example, a SanDisk Cruzer Blade, into your preferred USB port on the host machine. Then to physically identify the USB host device ID (the USB port) to passthrough to PVE NAS CT it will be displayed on your terminal when running our Easy Script at the required USB passthrough stage as shown:

```
5) Bus 002 Device 004: ID 0781:5567 SanDisk Corp. Cruzer Blade
```

In the above example, you will select the number **5** to passthrough. Then ONLY your PVE host hardware USB port where the SanDisk Blade drive was inserted is readable by you in the future.

So have a spare USB drive ready and available.

# 3. Ubuntu NAS

'Easy Scripts' are available for administrative tasks. (i.e for creating new user accounts, installing SMTP servers, and more.)

Run the following Easy Script and select the task you want to perform.

```Ubuntu NAS administration tasks
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/master/pve_nas_ct_admin_installer.sh)"
```

## 3.1. Create new User Accounts

New user accounts can be created using our Ubuntu NAS administration tool.

The Easy Script will prompt the installer with selectable options:

### 3.1.1. Create "Power User" Accounts

Power Users are trusted persons with privileged access to data and application resources hosted on your PVE NAS. Power Users are NOT standard users! Standard users are added with the 'Jailed User Account' option. Each new Power Users security permissions are controlled by Linux groups. Group security permission levels are as follows:

| GROUP NAME   | PERMISSIONS                                            |
|--------------|--------------------------------------------------------|
| `medialab`   | Everything to do with media (i.e movies, TV and music) |
| `homelab`    | Everything to do with a smart home including medialab  |
| `privatelab` | Private storage including medialab & homelab rights    |

### 3.1.2. Create Restricted and Jailed User Accounts (Standard Users)

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


### 3.1.3. Add-ons (optional)
Optional 'Easy Script' Add-ons can be run anytime. They are for installing a new service and updating your PVE NAS OS release. User options include:
1. Upgrade NAS Ubuntu OS
2. Install & Configure Fail2ban
3. Install & Configure a SSMTP server
4. Install & Configure ProFTPd server

# 4. TrueNAS
Under development. Coming soon.