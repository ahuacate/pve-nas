<h1>PVE File Server (NAS)</h1>

**Lightweight - Ubuntu NAS (CT)**
A lightweight NAS built on a CT with 512Mb RAM. Ubuntu OS and Webmin WebGui frontend.

Backend storage is by Proxmox. Choose between LVM or ZFS Raid or a basic single disk ext4 file system. A USB disk-based NAS is also supported.

**Heavyweight - OMV NAS (VM)**
Open Media Vault (OMV) NAS built in a Proxmox VM. Requires direct attached storage or PCI SAS/SATA/NVMe HBA Card pass-through. Our default file system is EXT4 or BTRFS using MergerFS and SnapRaid.

<h2>Features</h2>
All builds include:

* Power User & Group Accounts
    * Groups: medialab:65605, homelab:65606, privatelab:65607, chrootjail:65608
    * Users: media:1605, home:1606, private:1607
    * Users media, home and private are our default CT App users
* Chrootjail Group for general User accounts
* Support all Medialab file permissions required by Sonarr, Radarr, JellyFin, NZBGet and more
* Includes all storage folders ready for all CT applications
* Folder and user permissions are set including ACLs
* NFS 4.0 exports ready for PVE host's backend storage mounts
* SMB 3.0 shares with access permissions set ( by User Group accounts )
* Setting Local Domain option( i.e .local, .localdomain, .home.arpa, .lan )
* Easy Script Toolbox to create or delete User accounts, perform OS upgrades and install add-on services (i.e SSMTP, ProFTP and ZFS Cache)

<h2>Prerequisites</h2>

**Network Prerequisites**

- [x] Layer 2/3 Network Switches
- [x] Network Gateway (*recommend xxx.xxx.xxx.5*)
- [x] Network DHCP server (*recommend xxx.xxx.xxx.5*)
- [x] Network DNS server (*recommend xxx.xxx.xxx.5*)
- [x] Network Name Server
- [x] Network Name Server resolves all device hostnames (*static and dhcp IP*)
- [x] Local domain name is set on all network devices (*see note below*)
- [x] PVE host hostnames are suffixed with a numeric (*i.e pve-01 or pve01 or pve1*)
- [x] PVE host has internet access

**Required Prerequisites**

- [x] PVE host installed or USB connection with a minimum of 1x spare empty disk.

**Optional Prerequisites**

- [ ] PVE Host installed SSD/NVMe ZFS Cache (Ubuntu CT builds)
- [ ] HBA installed SSD/NVMe ZFS Cache (OMV VM builds)
- [ ] PCIe SAS/SATA/NVMe HBA Adapter Card (i.e LSI 9207-8i)

<h2>Local DNS Records</h2>

We recommend <span style="color:red">you read</span> about network Local DNS and why a PiHole server is a necessity. Click <a href="https://github.com/ahuacate/common/tree/main/pve/src/local_dns_records.md" target="_blank">here</a> to learn more before proceeding any further.

Your network Local Domain or Search domain must be also set. We recommend only top-level domain (spTLD) names for residential and small networks names because they cannot be resolved across the internet. Routers and DNS servers know, in theory, not to forward ARPA requests they do not understand onto the public internet. It is best to choose one of our listed names: local, home.arpa, localdomain or lan only. Do NOT use made-up names.


<h2>Installation Options</h2>

Our lightweight NAS is for PVE hosts limited by RAM.
<ol>
<li><h4><b>Ubuntu NAS CT - PVE SATA/NVMe</b></h4></li>

LVM or ZFS backend filesystem, Ubuntu frontend.

LVM and ZFS Raid levels depend on the number of disks installed. You also have the option of configuring ZFS cache using SSD/NVMe drives. ZFS cache is for High-Speed disk I/O.

<li><h4><b>Ubuntu NAS CT - Basic USB disk</b></h4></li>

USB disk ext4 backend, Ubuntu frontend.

All data is stored on a single external USB disk. A basic ext4 file system backend is managed by your Proxmox host.
</ol>

The heavyweight NAS option is our OMV VM. If you have adequate RAM (32Gb or more) and want a user-friendly NAS WebGUI interface we recommend you install OMV.

<ol>
<li><h4><b>OMV NAS VM - Direct attached storage</b><h/4></li>

**Physical Disk pass-through**
Physical disks are configured to pass through to the VM as SCSI devices. You can configure as many disks as you like. This is a cost-effective solution because you can use native SATA ports on your PVE hosts' mainboard. OMV manages both the backend and front end. Requires PVE host bootloader kernel config file edits shown [here](https://pve.proxmox.com/wiki/Pci_passthrough#Introduction) before installing.

**PCIe SAS/SATA/NVMe HBA Card**
PCIe SAS/SATA/NVMe HBA Adapter Card (i.e LSI 9207-8i) pass-through will likely deliver superior NAS performance.

A dedicated PCIe SAS/SATA/NVMe HBA Adapter Card (i.e LSI 9207-8i) is required for all NAS storage disks. All OMV storage disks, including any LVM/ZFS Cache SSDs, must be connected to the HBA Adapter Card. You cannot co-mingle OMV disks with the PVE host's mainboard onboard SATA/NVMe devices. OMV manages both the backend and front end. Requires PVE host bootloader kernel config file edits shown [here](https://pve.proxmox.com/wiki/Pci_passthrough#Introduction) before installing.
</ol>

For a dedicated hard-metal NAS, not Proxmox hosted, go to this GitHub [repository](https://github.com/ahuacate/nas-hardmetal). Options include between Easy Scripts to configure a Synology v7 or OMV NAS appliance.

<h4><b>Easy Scripts</b></h4>

Easy Scripts automate the installation and/or configuration processes. Easy Scripts are hardware type-dependent so choose carefully. Easy Scripts are based on bash scripting. `Cut & Paste` our Easy Script command into a terminal window, press `Enter`, and follow the prompts and terminal instructions. 

Our Easy Scripts have preset configurations. The installer may accept or decline the ES values. If you decline the User will be prompted to input all required configuration settings. PLEASE read our guide if you are unsure.

<h4><b>1) PVE NAS Installer Easy Script</b></h4>
Use this script to start the PVE NAS installer for all PVE NAS types. The User will be prompted to select an installation type (i.e Ubuntu, USB, OMV). Run in a PVE host SSH terminal.

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/main/pve_nas_installer.sh)"
```
<h4><b>2) PVE Ubuntu NAS Toolbox Easy Script</b></h4>
For creating and deleting user accounts, installing optional add-ons and upgrading your Ubuntu NAS OS. Run in your PVE host SSH terminal.

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/main/pve_nas_toolbox.sh)"
```

<hr>

<h4>Table of Contents</h4>
<!-- TOC -->

- [1. Introduction](#1-introduction)
    - [1.1. Backend storage - PVE Ubuntu NAS](#11-backend-storage---pve-ubuntu-nas)
    - [1.2. Direct Attached storage - OMV NAS](#12-direct-attached-storage---omv-nas)
    - [1.3. PVE RAM recommendations](#13-pve-ram-recommendations)
- [2. OMV NAS VM](#2-omv-nas-vm)
    - [2.1. Create the OMV NAS VM](#21-create-the-omv-nas-vm)
    - [2.2. PCIe Passthrough (optional)](#22-pcie-passthrough-optional)
    - [2.3. Configuring OMV NAS VM](#23-configuring-omv-nas-vm)
- [3. Ubuntu NAS CT](#3-ubuntu-nas-ct)
    - [3.1. Create the Ubuntu NAS CT](#31-create-the-ubuntu-nas-ct)
    - [3.2. Supported File Systems](#32-supported-file-systems)
        - [3.2.1. ZFS storage](#321-zfs-storage)
            - [3.2.1.1. ZFS Cache support](#3211-zfs-cache-support)
        - [3.2.2. LVM storage](#322-lvm-storage)
    - [3.3. Easy Script Toolbox options](#33-easy-script-toolbox-options)
- [4. Preparation & General requirements](#4-preparation--general-requirements)
    - [4.1. Required Installer Inputs](#41-required-installer-inputs)
    - [4.2. A System designated Administrator Email](#42-a-system-designated-administrator-email)
    - [4.3. SMTP Server Credentials](#43-smtp-server-credentials)
    - [4.4. NAS Hostname](#44-nas-hostname)
    - [4.5. NAS IPv4 Address](#45-nas-ipv4-address)
    - [4.6. NAS Search Domain or Local Domain](#46-nas-search-domain-or-local-domain)
    - [4.7. Network VLAN Aware](#47-network-vlan-aware)
    - [4.8. NAS Gateway IPv4 Address](#48-nas-gateway-ipv4-address)
    - [4.9. NAS Root Password](#49-nas-root-password)
- [5. Ubuntu NAS Administration Toolbox](#5-ubuntu-nas-administration-toolbox)
    - [5.1. Create new User Accounts](#51-create-new-user-accounts)
        - [5.1.1. Create "Power User" Accounts](#511-create-power-user-accounts)
        - [5.1.2. Create Restricted and Jailed User Accounts (Standard Users)](#512-create-restricted-and-jailed-user-accounts-standard-users)
- [6. Q&A](#6-qa)
    - [6.1. What's the NAS root password?](#61-whats-the-nas-root-password)
    - [6.2. Ubuntu NAS with a USB disk has I/O errors?](#62-ubuntu-nas-with-a-usb-disk-has-io-errors)

<!-- /TOC -->

<hr>

# 1. Introduction

When selecting your NAS type to build you have the option of PVE backend or direct attached storage (PCIe HBA card or disk pass-through).

## 1.1. Backend storage - PVE Ubuntu NAS

Choose ZFS Raid, LVM Raid or basic single-disk storage for your NAS build. Your PVE NAS host hardware configuration determines your NAS options:

  - Ubuntu Frontend, PVE LVM or ZFS backend (SATA/SAS).
  - Ubuntu Frontend, PVE ext4 backend (USB only).

## 1.2. Direct Attached storage - OMV NAS
  - OMV requires a PCIe SAS/SATA/NVMe HBA Adapter Card (i.e LSI 9207-8i)
  - OMV Physical Disk Pass-through (i.e as SCSI devices).

## 1.3. PVE RAM recommendations
A Ubuntu NAS CT requires only 512MB RAM because the LVM or ZFS backend storage is managed by the Proxmox host. In practice, install as much RAM as you can get for your hardware/budget.

A ZFS backend depends heavily on RAM, so you need at least 16GB (32GB recommended).

OMV specifies a minimum of 8GB RAM.

<hr>

# 2. OMV NAS VM
Prepare your PVE host with a PCIe SAS/SATA/NVMe HBA Adapter Card (i.e LSI 9207-8i) or use Direct Attached Storage (requires [IOMMU enabled](https://pve.proxmox.com/wiki/Pci_passthrough)). Connect all the storage and parity disks. Make a note of the device IDs (i.e /dev/sda).

## 2.1. Create the OMV NAS VM
Use this script to start the PVE NAS Installer. You will be prompted to select an installation type. Select `Omv Nas - OMV based NAS`. Run in a PVE host SSH terminal.

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/main/pve_nas_installer.sh)"
```

## 2.2. PCIe Passthrough (optional)
PCI passthrough allows you to use a physical mainboard PCI SATA or HBA device inside a PVE VM (KVM virtualization only).

If you configure a "PCI passthrough" device, the device is not available to the host anymore.

Navigate using the Proxmox web interface to VM `vmid (nas-xx)` > `Hardware` > `Add` > `PCI device` and select a PCIe HBA device. The selected device will be passed through to your NAS.

## 2.3. Configuring OMV NAS VM
After creating your OMV VM go to our detailed [configuration guide](https://github.com/ahuacate/nas-hardmetal) to complete the installation. Follow all the OMV-related steps.

<hr>

# 3. Ubuntu NAS CT
Prepare all new disks by wiping them. You can also re-connect to an existing Ubuntu NAS storage backend.

## 3.1. Create the Ubuntu NAS CT
Use this script to start the PVE NAS Installer. The User will be prompted to select an installation type. Select `Ubuntu Nas - Ubuntu CT based NAS`. Run in your PVE host SSH terminal.

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/main/pve_nas_installer.sh)"
```

## 3.2. Supported File Systems

The User can choose to create a new file system or re-connect to an existing file system. 

The installer script allows for the re-connection to a previously prepared storage volume. Supported filesystems are LVM, ZFS and USB ext4 storage.

### 3.2.1. ZFS storage

The User has the option to set different ZFS Raid levels.

We recommend you install a minimum of 3x NAS-certified rotational hard disks in your host. When installing the disks make a note of the logical SATA port IDs ( i.e sdc, sdd, sde ) you are connecting to. This helps you identify which disks to format and add to your new ZFS storage pool.

Our Ubuntu NAS Easy Script has the option to use the following ZFS Raid builds:

|ZFS Raid Type|Description
|----|----|
|RAID0|Also called “striping”. No redundancy, so the failure of a single drive makes the volume unusable.
|RAID1|Also called “mirroring”. Data is written identically to all disks. The resulting capacity is that of a single disk.
|RAID10|A combination of RAID0 and RAID1. Requires at least 4 disks.
|RAIDZ1|A variation on RAID-5, single parity. Requires at least 3 disks.
|RAIDZ2|A variation on RAID-5, double parity. Requires at least 4 disks.
|RAIDZ3|A variation on RAID-5, triple parity. Requires at least 5 disks.

Remember, our Easy Script will destroy all existing data on these storage hard disks!

#### 3.2.1.1. ZFS Cache support

The User can add ZFS Cache with our `NAS Toolbox Easy Script` addon. Use only SSD or NVMe drives. Do not co-mingle SSD and NVMe cache devices together. We recommend a maximum of 2x devices only.

The devices will be erased and wiped of all data and partitioned ready for ZIL and ARC or L2ARC cache. The ARC or L2ARC and ZIL cache build options are:
1.  Standard Cache: Select 1x device only. No ARC, L2ARC or ZIL disk redundancy
2.  Accelerated Cache: Select 2x devices. ARC or L2ARC cache set to Raid0 (stripe) and ZIL set to Raid1 (mirror)."

The maximum size of a ZIL log should be about half the size of your host's installed physical RAM BUT not less than 8GB. The ARC or L2ARC cache size should not be less than 64GB but will be sized to use the whole ZFS cache device. The installer will automatically calculate the best partition sizes for you. A device over-provisioning factor will be applied.

### 3.2.2. LVM storage

The Ubuntu NAS Easy Script has the option to use the following LVM Raid builds:

|LVM Raid Type|Description
|----|----|
|RAID0|Also called “striping”. Fast but no redundancy, so the failure of a single drive makes the volume unusable.
|RAID1|Also called “mirroring”. Data is written identically to all disks. The resulting capacity is that of a single disk.
|RAID5|Striping with single parity. Minimum 3 disks.
|RAID6|Striping with double parity. Minimum 5 disks.
|RAID10|A combination of RAID0 and RAID1. Minimum 4 disks (even unit number only).

Remember, our Easy Script will destroy all existing data on these storage hard disks!

## 3.3. Easy Script Toolbox options

Once you have completed your Ubuntu NAS installation you can perform administration tasks using our Easy Script Toolbox.

Tasks include:

* Create user accounts
* Delete user accounts
* Upgrade your NAS OS
* Install options:
    * Fail2Ban
    * SMTP
    * ProFTPd
* Add ZFS Cache - create ARC/L2ARC/ZIL cache
* Restore & update default storage folders & permissions

Run the following Easy Script, select your and select the task you want to perform. Run in a PVE host SSH terminal.

```Ubuntu NAS administration tasks
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/main/pve_nas_toolbox.sh)"
```

<hr>

# 4. Preparation & General requirements

Get your hardware in order before running a NAS build script.

## 4.1. Required Installer Inputs

Our Easy Script requires the User to provide some inputs. The installer will be given default values to use or the option to input your values.

We recommend you prepare the following and have your credentials ready before running our NAS build scripts.

## 4.2. A System designated Administrator Email

You need a designated administrator email address. All server alerts and activity notifications will be sent to this email address. Gmail works fine.

## 4.3. SMTP Server Credentials

Before proceeding with this installer we recommend you first configure all PVE hosts to support SMTP email services. A working SMTP server emails the NAS System Administrator all-new User login credentials, SSH keys, application-specific login credentials and written guidelines.

A PVE host SMTP server makes NAS administration much easier. Also, be alerted about unwarranted login attempts and other system critical alerts. PVE Host SMTP Server installer is available in our PVE Host Toolbox located at GitHub:
* https://github.com/ahuacate/pve-host

We recommend you create an account at [Mailgun](https://mailgun.com) to relay your NAS system emails to your designated administrator. With [Mailgun](https://mailgun.com) you are not potentially exposing your private email server credentials held within a text file on your NAS. This is an added layer of security.

## 4.4. NAS Hostname

The default hostname is `nas-01`. Our naming convention stipulates all NAS hostnames end with a numeric suffix. Extra NAS appliances should be named `nas-02`, `nas-03` and so on. You may change the hostname to whatever you like. But for networking, integration with our Easy Scripts, hostname resolving, we recommend you use our default hostname naming convention ( `nas-01` ).

## 4.5. NAS IPv4 Address

By default DHCP IPv4 is enabled. We recommend you use DHCP IP reservation at your DHCP server ( i.e router, PiHole ) to create a static IP address to avoid any local DNS lookup issues. You may change to whatever IPv4 or IPv6 address you want. Just note the VLAN ID.

## 4.6. NAS Search Domain or Local Domain

The default search domain is 'local'. The User must set a 'search domain' or 'local domain' name.

The search domain name must match the setting used in your router configuration setting labeled as 'Local Domain' or 'Search Domain' depending on the device manufacturer. 

We recommend top-level domain (spTLD) names for residential and small network names because they cannot be resolved across the internet. Routers and DNS servers know, in theory, not to forward ARPA requests they do not understand onto the public internet. It is best to choose one of our listed names.

* local ( Recommended )
* home.arpa ( Recommended )
* lan
* localdomain

If you insist on using a made-up search domain name, then DNS requests may go unfulfilled by your router and be forwarded onto global internet DNS root servers. This leaks information about your network such as device names. Alternatively, you can use a registered domain name or subdomain if you know what you are doing by selecting the 'Other' option.

## 4.7. Network VLAN Aware

You must answer an Easy Script prompt asking if your network is VLAN aware. The script will resolve your NAS VLAN ID automatically.

## 4.8. NAS Gateway IPv4 Address

The script will attempt to find your Gateway IPv4 address. Confirm with `Enter` or type in the correct Gateway IP address.

## 4.9. NAS Root Password

The default root password is 'ahuacate'. You can always change it at a later stage.

<hr>

# 5. Ubuntu NAS Administration Toolbox
Once you have completed your Ubuntu NAS installation you can perform administration tasks using our Easy Script Toolbox.

Tasks include:

* Create user accounts
* Upgrade your NAS OS
* Install options:
    * Fail2Ban
    * SMTP
    * ProFTPd
* Add ZFS Cache - create ARC/L2ARC/ZIL cache
* Restore & update default storage folders & permissions

Run the following Easy Script and select the task you want to perform. Run in a PVE host SSH terminal.

```Ubuntu NAS administration tasks
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-nas/main/pve_nas_toolbox.sh)"
```

Your User account options are as follows.

## 5.1. Create new User Accounts

New user accounts can be created using our Ubuntu NAS administration tool.

The Easy Script will prompt the installer with selectable options:

### 5.1.1. Create "Power User" Accounts

Power Users are trusted persons with privileged access to data and application resources hosted on your PVE NAS. Power Users are NOT standard users! Standard users are added with the 'Jailed User Account' option. Each new Power Users security permissions are controlled by Linux groups. Group security permission levels are as follows:

| GROUP NAME   | PERMISSIONS                                            |
|--------------|--------------------------------------------------------|
| `medialab`   | Everything to do with media (i.e movies, TV and music) |
| `homelab`    | Everything to do with a smart home including medialab  |
| `privatelab` | Private storage including medialab & homelab rights    |

### 5.1.2. Create Restricted and Jailed User Accounts (Standard Users)

Every new user is restricted or jailed within their own home folder. In Linux, this is called a chroot jail. But you can select a level of restriction which is applied to each newly created user. This technique can be quite useful if you want a particular user to be provided with a limited system environment, limited folder access and at the same time keep them separate from your main server system and other personal data. The chroot technique will automatically jail selected users belonging to the `chrootjail` user group upon ssh or ProFTPd SFTP login (standard FTP mode is disabled).

An example of a jailed user is a person who has remote access to your PVE NAS but is restricted to your video library (TV, movies, documentary), public folders and their home folder for cloud storage only. Remote access to your PVE NAS is restricted to sftp, ssh and rsync using private SSH RSA encrypted keys. The user can backup their mobile, tablet, notebook or any device.

When creating a new user you are given the choice to select a Level of `chrootjail` group permissions and access rights per user. We have pre-configured 3 Levels to choose from with varying degrees of file access for different types of users.

**Level 1**  -  This user is restricted to their private home folder for data storage and the NAS public folder only. This is ideal for persons whom you DO NOT want to share any media data with. Typical users maybe: persons wanting Cloud storage and nothing more.

**Level 2**  -  This user is restricted to their private home folder for data storage, limited access to the NAS public folder and media library (i.e Restricted to movies, tv, documentary, homevideo folders only). The user is also setup with a downloads folder and special folders within their chrootjail home folder for sharing photos and homevideos with other users or a media server like Emby or Jellyfin. Typical users are: family, close friends and children because of limited media access.

**Level 3**  -  This user is restricted to their private home folder for data storage, limited access to the NAS public, audio, books folders, and media library (i.e This user level is NOT restricted so they can view ALL media content). The user is also set up with a downloads folder and special folders within their chrootjail home folder for sharing photos and home videos with other users or a media server like Emby or Jellyfin. Typical users are Power users and adults with full media library access.

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

<hr>

# 6. Q&A
## 6.1. What's the NAS root password?
Installation default credentials for Ubuntu based NAS:
* User:  root
* Password:  ahuacate

Default credentials for OMV NAS:
* User:  admin
* Password:  openmediavault

## 6.2. Ubuntu NAS with a USB disk has I/O errors?
A known issue is a USB power management called autosuspend. Our install uses UDEV rule to disable autosuspend but the problem might your USB hub or SATA adapter. Try these fixes:
* [Kernel Patch](https://unix.stackexchange.com/questions/91027/how-to-disable-usb-autosuspend-on-kernel-3-7-10-or-above)
* [USB Autosuspend deaktivieren](https://blog.vulkanbox.dontexist.com/promox-mit-zram/)

<hr>