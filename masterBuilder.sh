set -e
set -x

echo SET FOLDER STRUCTURE
BASEDIR=$(pwd)
BUILDDIR=${BASEDIR}/build
export TZ='Europe/Warsaw'
R=${BUILDDIR}/chroot
mkdir -p $R
mv *.sh $R
RELEASE=$1

echo BASE DEBOOTSTRAP
sudo qemu-debootstrap --arch armhf $RELEASE $R http://ports.ubuntu.com/

echo COPY QEMU_USER_STATIC
sudo cp /usr/bin/qemu-arm-static $R/bin/

echo MOUNT FILESYSTEMS
sudo mount -o rw,exec,users -t proc none $R/proc
sudo mount -o rw,exec,users -t sysfs mone $R/sys

echo SET SOURCES
sudo chroot $R ./setSources.sh $RELEASE

echo SET LOCALES
for LOCALE in $(sudo chroot $R locale | cut -d'=' -f2 | grep -v : | sed 's/"//g' | uniq); do
  if [ -n "${LOCALE}" ]; then
    sudo chroot $R locale-gen $LOCALE
  fi
done

echo TRICK DUMMY SYSTEM TO UPGRADE
sudo chroot $R apt-get update
sudo chroot $R apt-get -fuy -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --force-yes dist-upgrade

echo INSTALL RPi PPA
sudo chroot $R ./setPPA.sh

sudo chroot $R apt-get -y install software-properties-common ubuntu-keyring
#sudo chroot $R apt-add-repository -y ppa:fo0bar/rpi2 raspberrypi-bootloader-nokernel rpi2-ubuntu-errata
sudo chroot $R apt-add-repository -y ppa:ubuntu-pi-flavour-makers/ppa
sudo chroot $R apt-get update

echo INSTALL STANDARD PACKAGES 
sudo chroot $R apt-get -fuy -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --force-yes \
install f2fs-tools software-properties-common ubuntu-standard apt-utils initramfs-tools \
language-pack-en openssh-server language-pack-pl

#echo  INSTALL MINIMALL DESKTOP
#sudo chroot $R apt-get install -fuy --no-install-recommends lubuntu-core

echo INSTALL KERNEL. Use flash-kernel tp avoid fail platform detection
sudo chroot $R apt-get -y install libraspberrypi-bin libraspberrypi-dev \
libraspberrypi-doc libraspberrypi0 raspberrypi-bootloader rpi-update
sudo chroot $R rpi-update
sudo chroot $R apt-get -y install linux-firmware linux-firmware-nonfree
sudo chroot $R apt-get -y --no-install-recommends install linux-image-rpi2
sudo chroot $R apt-get -y install flash-kernel
VMLINUZ="$(ls -1 $R/boot/vmlinuz-* | sort | tail -n 1)"
[ -z "$VMLINUZ" ] && exit 1
sudo cp $VMLINUZ $R/boot/firmware/kernel7.img
INITRD="$(ls -1 $R/boot/initrd.img-* | sort | tail -n 1)"
[ -z "$INITRD" ] && exit 1
sudo cp $INITRD $R/boot/firmware/initrd7.img

echo SETUP FSTAB
sudo chroot $R ./setFstab.sh

echo SETUP HOST
sudo chroot $R ./setHost.sh

echo CREATE UBUNTU USER
sudo chroot $R adduser --gecos "RPiBbuntu user" --add_extra_groups --disabled-password ubuntu
sudo chroot $R usermod -a -G sudo,adm -p '$6$iTPEdlv4$HSmYhiw2FmvQfueq32X30NqsYKpGDoTAUV2mzmHEgP/1B7rV3vfsjZKnAWn6M2d.V2UsPuZ2nWHg1iqzIu/nF/' ubuntu

echo SYSTEM CLEANUP
sudo chroot $R apt-get autoclean
sudo chroot $R apt-get -y autoremove

echo SETUP INTERFACES
sudo chroot $R ./setInterfaces.sh

echo SETUP FIRMWARE CONFIG FOR THE PI
sudo chroot $R ./setFirmware.sh

sudo ln -sf firmware/config.txt $R/boot/config.txt
sudo ln -sf firmware/cmdline.txt $R/boot/cmdline.txt

echo ENABLE SOUND ON BOOT
sudo chroot $R ./setSound.sh

echo DISABLE MODUES NOT APPLICABLE ON THE PI2
sudo chroot $R ./setBlacklist.sh

echo UNMOUNT FILESYSTEMS
sudo chroot $R umount -l proc
sudo chroot $R umount -l sys

echo CLEANUP FILES
sudo chroot $R ./cleanUp.sh

echo BUILD BASE IMAGE 1.75GiB
DATE="$(date +%Y-%m-%d)"
dd if=/dev/zero of="$BASEDIR/${DATE}-ubuntu-${RELEASE}.img" bs=1M count=1
dd if=/dev/zero of="$BASEDIR/${DATE}-ubuntu-${RELEASE}.img" bs=1M count=0 seek=1792
sfdisk -f "$BASEDIR/${DATE}-ubuntu-${RELEASE}.img" <<EOF
unit: sectors

1 : start=     2048, size=   131072, Id= c, bootable
2 : start=   133120, size=  3536896, Id=83
3 : start=        0, size=        0, Id= 0
4 : start=        0, size=        0, Id= 0
EOF

VFAT_LOOP="$(sudo losetup -o 1M --sizelimit 64M -f --show $BASEDIR/${DATE}-ubuntu-${RELEASE}.img)"
EXT4_LOOP="$(sudo losetup -o 65M --sizelimit 1727M -f --show $BASEDIR/${DATE}-ubuntu-${RELEASE}.img)"
sudo mkfs.vfat "$VFAT_LOOP"
sudo mkfs.ext4 "$EXT4_LOOP"
MOUNTDIR="$BUILDDIR/mount"
mkdir -p "$MOUNTDIR"
sudo mount "$EXT4_LOOP" "$MOUNTDIR"
sudo mkdir -p "$MOUNTDIR/boot/firmware"
sudo mount "$VFAT_LOOP" "$MOUNTDIR/boot/firmware"
sudo rsync -a "$R/" "$MOUNTDIR/"
sudo umount "$MOUNTDIR/boot/firmware"
sudo umount "$MOUNTDIR"
sudo losetup -d "$EXT4_LOOP"
sudo losetup -d "$VFAT_LOOP"