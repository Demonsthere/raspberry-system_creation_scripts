# Raspberry-system_creation_scripts

Set of scripts used to create the RPiBuntu (custom Ubuntu for RPi) OS used in the building plan. The script are speerated, as they are called by the new root of chroot and need to be separated from the jenkins userspace

## Building script

The masterBuilder is the main script that creates the basic system, it is quite complex, but consist of the following parts:

+	Qemu-deboostrap 	-> A wrapper for the base debootstrap, that allows to 'hide' the CPU of the computer and use a differnt one instead (ARMv7 in this case)
+	Qemu-user-static 	-> A binary of Qemu that allows to emulate only the processor and the the whole system. 
+	Debootstrap 		-> A tool that downloads the entire, basic catalog strocture of a debian based distro (together with the most basic binaries and programs like cat, nano, bash). This structure will be called a skeleton.
+	Chroot 				-> The most used tool. Chroot allows to change a chosen folder as the root folder for a new user (so that the chosen folder is seen as the /, and all that is in it, as a the system parts)


## Basic operation pipeline

The very operation of this script can be shown as a sequential list of operations:

1.	Create a folder structure to work with (BASEDIR/BUILDIR/CHROOT)
2.	Run Qemu-debootstrap to download the system skeleton (the --arch armfh flag will trigger the download for the armhf platform)
3.	Copy the Qemu-user-static binary form armhf to the skeleton (This will enable the use of chroot within the system with a different CPU)
4.	Mount additional, empty drives to the skeleton (/proc and /sys)
5.  Commands bellow are done in the new system with the help of chroot !
5.	Set /etc/apt/souces.list (! Setting is files is only possible with scipts or wrappers as the chroot will take 1 argument for the command)
6.	Update/Upgrade the skeleton to download missing base packages
7.	Set PPa for Raspberry Drivers
8.	Install standard packages (ubuntu-minimal/standard, ssh, no-kernel-bootloader, etc)
9.	Install basic Xserver packages (Optional)
10.	Install the kernel (flash-kernel is used, as it is non-platform dependent)
11.	Set FStab (!Important as the Raspberry Pi requires only 2 partitions: one acting as / and the second for /boot/firmware which has the boot drivers and settings)
12.	Set Host (hostname and /etc/hosts)
13.	Create basic user (hybris)
14.	Perform initial system cleanup (packages)
15.	Set initial interfaces (using /etc/network/interface as no network-manages is present yet)
16.	Set Firmware (!Important, this file has the config of CPU clock, voltage settings for the machine, and has to be tinkered with correctly)
17.	Enable sound drivers
18.	Disable modules that would broke the Pi (!Important, do not change)
19.	Unmount filesystem and cleanup (unmount /sys /proc /run/cgmanager/fs/ and then destroy all temporary files and saves)
20.	Use DD, mkfs, losetup and rsync to create the system image (RAW format as .img, but could use qemu-img to create Virtualbox readable format) and sync created files to it
21. Zip and send to server (Optional)


## Usage

Altough this method is used to create a system for the Raspberry Pi, with only a few adjustments it can be used to create system for the standart x64_86 processor. With that it is possible to ommit the system creation used by packer (downloading an iso with system instalation software, and installing it onto a blank virtual drive), but instead create ready-to-go virtual drives.

### Pros:

+	Fully automatised with the use of scripts
+	Base system is created, allowing full control of desired software
+	Relativly fast
+	Ready to go, rewritteable discs (Live-CD's)
+	Can be changed to vagrant boxes 

### Cons:

-	More difficult to program than packer
-	No debugging or verification modules, as it works on the system level
-	Requires more system knowledge