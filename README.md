<h1>PVE ZFS File Server (NAS)</h1>
This guide is for building PVE hosted ZFS storage to work as your NAS.

Our PVE NAS has two components referred to as the NAS backend and frontend. The NAS backend is a PVE ZFS storage pool made up of hard disks. The NAS frontend is a Linux Ubuntu PVE container providing all your NAS services to clients. 

The NAS backend uses the ZFS Raid file system which is natively supported by Proxmox. The NAS frontend container, labelled `nas-01`, supports any Linux Ubuntu file server service or networking protocol including:

- Networking protocols like NFS and Samba
- Linux user & group management, file security and permissions
- General PVE NAS administration is done using the Webmin web-based system configuration tool.

The NAS frontend is accessible via Webmin. Use your Ubuntu CT root credentials, or any newly created valid NAS user which has been granted Webmin access rights, to perform countless management tasks. The Webmin URL is https://nas-01:10000/ or https://>insert IP address<:10000/

The NAS backend uses dedicated storage disks in a ZFS Raid Pool (Tank) file system. A default set of ZFS storage folders, system users and pre-configured file permissions work with all our PVE CTs (i.e. Sonarr, Radarr, Home Assistant).

By default the new NAS hostname is `nas-01`.

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

The above users (media, home, private) are pre-installed. They are the default built-in UID and GUID granted permissions within containerized applications, such as Sonarr or Radarr, and have the correct UID & GUID access rights to NAS files. Do not delete these users!



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



<h4>Main Easy Script</h4>

Easy Scripts are based on bash scripting. Simply `Cut & Paste` the command into your terminal window, press `Enter` and follow the prompts and terminal instructions. But PLEASE first read our guide so you fully understand the prerequisites and your input requirements.

**Easy Script** - This Easy Script includes all options (including Part 2) from CT creation to NAS configuration (Recommended).

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_create_ct_18.04.sh)"
```

<h4>Optional Easy Script Components</h4>

The following optional Easy Scripts can be run anytime for adding new PVE NAS user accounts or adding the described service. But these scripts MUST BE run inside your new PVE NAS container OS (*not on the PVE Host OS*).

You can enter your new NAS OS with the PVE command `pct enter` in your PVE Host CLI terminal:

```
# Enter your NAS CT by replacing <vmid>. Example "pct enter 110"
pct enter <CTID>
```

You should now be inside your NAS CT operating system. Your CLI bash prompt should now show `root@nas-01:~#` which confirms you can now execute the following optional scripts.

Optional - Add a Jailed Chroot User


```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_add_jailuser_ct_18.04.sh)"
```

Optional - Add a Power User

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_add_poweruser_ct_18.04.sh)"
```

Optional - Add a Rsync User

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_add_rsyncuser_ct_18.04.sh)"
```

Optional - Install ProFTPd Server

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_install_proftpd_ct_18.04.sh)"
```

Optional - Install and Setup SSMTP Server

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/pve-zfs-nas/master/scripts/pve_zfs_nas_install_ssmtp_ct_18.04.sh)"
```

<h4>Table of Contents</h4>

<hr>

# Preparing your PVE NAS Hardware


Your PVE NAS host hardware should be configured as per our [PVE Host Build](https://github.com/ahuacate/pve-host-build) guide.

## PVE Host installed RAM

ZFS depends heavily on memory, so you need at least 16GB (Recommend 32GB). In practice, use as much you can get for your  hardware/budget. To prevent data corruption, we recommend the use of  high quality ECC RAM (if your mainboard supports EEC).

## PVE Host SSD Cache

ZFS allows for tiered caching of data through the use of memory caches. While ZFS cache is optional we recommend the use of ZFS cache.

Whether you use partitions on your PVE host SSD or install dedicated SSDs, ZFS cache will provide High Speed disk I/O:

- ZFS Intent Log, or ZIL, to buffer WRITE operations.
- ARC and L2ARC which are meant for READ operations.

Our [PVE Host Build](https://github.com/ahuacate/pve-host-build#302-pve-os-install---primary-host---1-2x-ssd-os--1-2x-ssd-zfs-cache---zfs-file-server) guide has more detail.

### PVE OS SSD Partition Setup

This is the most cost effective method of deploying ZFS cache. Instructions are in our [PVE Host Build](https://github.com/ahuacate/pve-host-build#12-primary-host---creating-ssd-partitions-for-zfs-cache) guide.

### Dedicated SSD ZFS Cache Setup

A dedicated ZFS cache SSD setup is the more costly method with no net performance gain. Instructions are in our [PVE Host Build](https://github.com/ahuacate/pve-host-build#122-primary-host---partition-dedicated-zfs-cache-ssd---zfs-file-server) guide.

## Installation of ZFS Storage Disks

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

Remember our Easy Script will destroy all existing data on these storage hard disks and it's not recoverable!

# Installer Prerequisite Credentials and inputs needed

Our Easy Script requires the installer to provide some inputs. The installer will be given default values to use or the option to input your own values.

We recommend you first prepare the following and have your credentials ready before running our NAS build scripts.

## A System designated Administrator Email

You need to have your system’s designated administrator email address. All server alerts and server activity notifications will be sent to this email address. Gmail works fine.

## SMTP Server Credentials

Our Easy Script will give you the the option to install a SSMTP Email server. SSMTP is Mail Transfer Agent (MTA) used to send email alerts about your machine like details about new user accounts, unwarranted login attempts and system critical alerts to the system's designated administrator.

You will be asked for the credentials of a SMTP Server. You can use Gmail, GoDaddy, AWS or any SMTP server credentials (i.e address, port, username and password, encryption type etc.

But we recommend you create a account at [Mailgun](mailgun.com) to relay your NAS system emails to your designated administrator. With [Mailgun](mailgun.com) you are not potentially exposing your private email server credentials held within a text file on your NAS. This is a added layer  of security.

## NAS Hostname

The default hostname is `nas-01`. With our NAS hostname naming convention any secondary backup servers would have hostnames like `nas-02` . You may change the hostname to to whatever you like. But for networking, use of all our scripts, hostname resolving, we recommend you use the default hostname naming convention ( `nas-01` ).

## NAS IPv4 Address

By default it is `192.168.1.10/24`. You may change it to whatever IPv4 address you want. Just note the VLAN ID.

## Network VLAN Aware

You must answer Easy Script prompt asking if your network is VLAN aware. The script will resolve your NAS VLAN ID automatically.

## NAS Gateway IPv4 Address

The script will attempt to find your Gateway IPv4 address. Confirm with `Enter` or type in the correct Gateway IP address.

## NAS Root Password

Have a root password ready and stored away safely.

## USB Passthrough to CT

There can be good reasons to access USB disk ware directly from your NAS CT. To make a physically connected USB device accessible inside a PVE CT, for example NAS-01, the PVE NAS CT configuration file requires modification.

During the installation the Easy Script will display all available USB devices on the host computer. But you need to identify which USB host device ID to passthrough to the NAS CT. The simplest way is to plugin a physical USB memory stick, for example a SanDisk Cruzer Blade, into your preferred USB port on the host machine. Then to physically identify the USB host device ID (the USB port) to passthrough to PVE NAS CT it will be displayed on your terminal when running our Easy Script  at the required USB passthrough stage as for example:

```
5) Bus 002 Device 004: ID 0781:5567 SanDisk Corp. Cruzer Blade
```

In the above example, you will select number **5** to passthrough. Then ONLY your PVE host hardware USB port where the SanDisk Blade drive  was inserted is readable by your PVE NAS in the future.

So have a spare USB drive ready and available.













The Easy Script will prompt the installer with options:

### Adding New User Accounts

The script will give you the option to create new user accounts  during the build. But you can always add users at a later stage. We have created two custom scripts for adding user accounts.

####  

#### Create New "Power User" Accounts

Power Users are trusted persons with privileged access to data and  application resources hosted on your File Server. Power Users are NOT  standard users! Standard users are added with another chrootjail script. Each new Power Users security permissions are controlled by linux  groups. Group security permission levels are as follows:

| GROUP NAME   | PERMISSIONS                                            |
|--------------|--------------------------------------------------------|
| `medialab`   | Everything to do with media (i.e movies, TV and music) |
| `homelab`    | Everything to do with a smart home including medialab  |
| `privatelab` | Private storage including medialab & homelab rights    |

You can manually add a Power User at any time using our script. To  execute the script SSH into typhoon-01(ssh root@192.168.1.101 or ssh  root@typhoon-01) or use the Proxmox web interface CLI shell typhoon-01  > >_ Shell and cut & paste the following into the CLI terminal window and press ENTER:

```
# WARNING - Enter your NAS Container CTID (i.e my CTID is 110)!
pct enter CTID
# Command to run script
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-ubuntu-fileserver/master/scripts/fileserver_add_poweruser_ct_18.04.sh)"
```

####  

#### Create Restricted and Jailed User Accounts (Standard Users)

Every new user is restricted or jailed within their own home folder.  In Linux this is called a chroot jail. But you can select the level of  restrictions which are applied to each newly created user. This  technique can be quite useful if you want a particular user to be  provided with a limited system environment, limited folder access and at the same time keep them separate from your main server system and other personal data. The chroot technique will automatically jail selected  users belonging to the `chrootjail` user group upon ssh or ftp login.

An example of a jailed user is a person who has remote access to your File Server but is restricted to your video library (TV, movies,  documentary), public folders and their home folder for cloud storage  only. Remote access to your File Server is restricted to sftp, ssh and  rsync using private SSH RSA encrypted keys. The user can backup their  mobile, tablet, notebook or any device.

When creating a new user you are given the choice to select a Level of `chrootjail` group permissions and access rights per user. We have pre-configured 3  Levels to choose from with varying degree of file access for different  types of users.

**Level 1**  -  This user is restricted to their private home folder for data storage and the NAS public folder only. This is  ideal for persons whom you DO NOT want to share any media data with.  Typical users maybe: persons wanting Cloud storage and nothing more.

**Level 2**  -  This user is restricted to their private home folder for data storage, limited access to the NAS public folder  and media library (i.e Restricted to movies, tv, documentary, homevideo  folders only). The user is also setup with a downloads folder and  special folders within their chrootjail home folder for sharing photos  and homevideos with other users or a media server like Emby or Jellyfin. Typical users maybe: family, close friends and children because of  limited media access.

**Level 3**  -  This user is restricted to their private home folder for data storage, limited access to the NAS public, audio,  books folders and media library (i.e This user level is NOT restricted  so they can view ALL media content). The user is also setup with a  downloads folder and special folders within their chrootjail home folder for sharing photos and homevideos with other users or a media server  like Emby or Jellyfin. Typical users maybe: Power users and adults with  full media library access.

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

You can manually add a Restricted and Jailed User at any time using  our script. To execute the script SSH into typhoon-01(ssh  root@192.168.1.101 or ssh root@typhoon-01) or use the Proxmox web  interface CLI shell typhoon-01 > >_ Shell and cut & paste the  following into the CLI terminal window and press ENTER:

```
# WARNING - Enter your NAS Container CTID (i.e my CTID is 110)!
pct enter CTID
# Command to run script
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-ubuntu-fileserver/master/scripts/fileserver_add_jailuser_ct_18.04.sh)"
```

####  

#### Create KODI_RSYNC User

KODI_RSYNC is a special user created for synchronising a portable or  remote media player with your File Server media library. Connection is  by rssh rsync. Its ideal for travellers or persons going away to a  remote location with poor or no internet access. Our rsync script will  securely connect to your File Server and;

- rsync mirror your selected media library to your kodi player USB disk.
- copy your latest media only to your kodi player USB disk.
- remove the oldest media to fit newer media.

This is ideally suited for holiday homes, yachts or people on the move.

The first step involves creating a new user called "kodi_rsync" on  your File Server which has limited and restricted permissions granting  rsync read access only to your media libraries.

The second step, performed at a later stage, is setting up a CoreElec or LibreElec player hardware with a USB hard disk and installing our  rsync scripts along with your File Server user "kodi_rsync" private ssh  ed25519 key.

You can manually install KODI_RSYNC at any time using our script. To  execute the script SSH into typhoon-01(ssh root@192.168.1.101 or ssh  root@typhoon-01) or use the Proxmox web interface CLI shell typhoon-01  > >_ Shell and cut & paste the following into the CLI terminal window and press ENTER:

```
# WARNING - Enter your NAS Container CTID (i.e my CTID is 110)!
pct enter CTID
# Command to run script
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-ubuntu-fileserver/master/scripts/fileserver_add_rsyncuser_ct_18.04.sh)"
```

The following is for creating a Proxmox Ubuntu CT File Server built on your primary Proxmox node typhoon-01.

Network Prerequisites are:

