set -e
set -x

echo '----> SET FOLDER STRUCTURE'
BASEDIR=$(pwd)
BUILDDIR=${BASEDIR}/build
export TZ='Europe/Warsaw'
R=${BUILDDIR}/chroot
mkdir -p $R
mv *.sh $R
RELEASE=$1

echo '----> BASE DEBOOTSTRAP'
qemu-debootstrap --arch armhf $RELEASE $R http://ports.ubuntu.com/

echo '----> COPY QEMU_USER_STATIC'
cp /usr/bin/qemu-arm-static $R/bin/

echo '----> MOUNT FILESYSTEMS'
mount -o rw,exec,users -t proc none $R/proc
mount -o rw,exec,users -t sysfs mone $R/sys

echo '----> SET SOURCES'
chroot $R ./setSources.sh $RELEASE

echo '----> SET LOCALES'
for LOCALE in $(chroot $R locale | cut -d'=' -f2 | grep -v : | sed 's/"//g' | uniq); do
  if [ -n "${LOCALE}" ]; then
    chroot $R locale-gen $LOCALE
  fi
done

echo '----> TRICK DUMMY SYSTEM TO UPGRADE'
chroot $R apt-get update
chroot $R apt-get -fuy -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --force-yes dist-upgrade

echo '----> INSTALL RPi PPA'
chroot $R ./setPPA.sh
chroot $R apt-get -y install software-properties-common ubuntu-keyring
chroot $R apt-add-repository -y ppa:fo0bar/rpi2
chroot $R apt-get update

echo '----> INSTALL STANDARD PACKAGES'
chroot $R apt-get -fuy -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --force-yes \
	install ubuntu-minimal apt-utils initramfs-tools raspberrypi-bootloader-nokernel \
    rpi2-ubuntu-errata language-pack-en openssh-server language-pack-pl

echo  '----> INSTALL XSERVER LIBRARIES'
chroot $R apt-get install -fuy xserver-xorg-video-fbturbo

echo '----> INSTALL KERNEL. Use flash-kernel tp avoid fail platform detection'
chroot $R apt-get -y --no-install-recommends install linux-image-rpi2
chroot $R apt-get -y install flash-kernel

VMLINUZ="$(ls -1 $R/boot/vmlinuz-* | sort | tail -n 1)"
[ -z "$VMLINUZ" ] && exit 1
cp $VMLINUZ $R/boot/firmware/kernel7.img
INITRD="$(ls -1 $R/boot/initrd.img-* | sort | tail -n 1)"
[ -z "$INITRD" ] && exit 1
cp $INITRD $R/boot/firmware/initrd7.img

echo '----> SETUP FSTAB'
chroot $R ./setFstab.sh

echo '----> SETUP HOST'
chroot $R ./setHost.sh

echo '----> CREATE UBUNTU USER'
chroot $R groupadd -f --system gpio
chroot $R groupadd -f --system i2c
chroot $R groupadd -f --system input
chroot $R groupadd -f --system spi
chroot $R adduser --gecos "RPiBbuntu user" --add_extra_groups --disabled-password ubuntu
chroot $R usermod -a -G sudo,adm,gpio,i2c,input,spi,video -p '$6$iTPEdlv4$HSmYhiw2FmvQfueq32X30NqsYKpGDoTAUV2mzmHEgP/1B7rV3vfsjZKnAWn6M2d.V2UsPuZ2nWHg1iqzIu/nF/' ubuntu

echo '----> SYSTEM CLEANUP'
chroot $R apt-get autoclean
chroot $R apt-get -y autoremove

echo '----> SETUP INTERFACES'
chroot $R ./setInterfaces.sh

echo '----> SETUP UDEV RULES'
chroot $R ./setUdev.sh

echo '----> SETUP FIRMWARE CONFIG FOR THE PI'
chroot $R ./setFirmware.sh

ln -sf firmware/config.txt $R/boot/config.txt
ln -sf firmware/cmdline.txt $R/boot/cmdline.txt

echo '----> ENABLE SOUND ON BOOT'
chroot $R ./setSound.sh

echo '-----> DISABLE MODUES NOT APPLICABLE ON THE PI2'
chroot $R ./setBlacklist.sh

echo '----> UNMOUNT FILESYSTEMS'
chroot $R umount -l proc
chroot $R umount -l sys

echo '----> CLEANUP FILES'
chroot $R ./cleanUp.sh
.$R/isMouned.sh
chroot $R ./cleanUp.sh

echo '----> BUILD BASE IMAGE 1.75GiB'
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

VFAT_LOOP="$(losetup -o 1M --sizelimit 64M -f --show $BASEDIR/${DATE}-ubuntu-${RELEASE}.img)"
EXT4_LOOP="$(losetup -o 65M --sizelimit 1727M -f --show $BASEDIR/${DATE}-ubuntu-${RELEASE}.img)"
mkfs.vfat "$VFAT_LOOP"
mkfs.ext4 "$EXT4_LOOP"
MOUNTDIR="$BUILDDIR/mount"
mkdir -p "$MOUNTDIR"
mount "$EXT4_LOOP" "$MOUNTDIR"
mkdir -p "$MOUNTDIR/boot/firmware"
mount "$VFAT_LOOP" "$MOUNTDIR/boot/firmware"
rsync -a "$R/" "$MOUNTDIR/"
umount "$MOUNTDIR/boot/firmware"
umount "$MOUNTDIR"
losetup -d "$EXT4_LOOP"
losetup -d "$VFAT_LOOP"