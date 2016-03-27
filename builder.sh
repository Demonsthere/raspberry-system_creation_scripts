#!/bin/bash -ex

echo SET FOLDER STRUCTURE
BASEDIR=$(pwd)
BUILDDIR=${BASEDIR}/build
export TZ='Europe/Warsaw'
R=${BUILDDIR}/chroot
mkdir -p $R
mv *.sh $R
RELEASE=$1

function bootstrap() {
  echo '----> Bootstraping base system'
  qemu-debootstrap --verbose --arch=armhf $RELEASE $R http://ports.ubuntu.com/
  cp /usr/bin/qemu-arm-static $R/bin/
}

function mount_system() {
  echo '----> Mounting empty filesystems to populate'
  mount -t proc none $R/proc
  mount -t sysfs none $R/sys
  mount -o bind /dev $R/dev
  mount -o bind /dev/pts $R/dev/pts
}

function set_locales() {
  echo '----> Set locales'
  for LOCALE in $(chroot $R locale | cut -d'=' -f2 | grep -v : | sed 's/"//g' | uniq); do
  if [ -n "${LOCALE}" ]; then
    chroot $R locale-gen $LOCALE
  fi
done
}

function set_network() {
  echo '----> Set network interfaces'
  chroot $R ./setNetwork.sh
}

function set_sources() {
  echo '----> Set source lists'
  chroot $R ./setSources.sh $RELEASE
}

function apt_upgrade() {
  echo '----> Perform apt_upgrade'
  chroot $R apt-get update
  chroot $R apt-get -y -u dist-upgrade
}

function ubuntu_minimal() {
  echo '----> Install minimal system'
  chroot $R apt-get -y install f2fs-tools software-properties-common ubuntu-keyring ubuntu-minimal
}

function apt_clean() {
  echo '----> System cleanup'
  chroot $R apt-get -y autoremove
  chroot $R apt-get clean
}

function stage_01_base() {
  bootstrap
  mount_system
  set_locales
  set_network
  set_sources
  apt_upgrade
  ubuntu_minimal
  apt_clean
}

function create_groups() {
  echo '----> Create system groups'
  chroot $R groupadd -f --system gpio
  chroot $R groupadd -f --system i2c
  chroot $R groupadd -f --system input
  chroot $R groupadd -f --system spi
}

function create_user() {
  echo '----> Create the base ubuntu user'
  chroot $R adduser --gecos "RPiBbuntu user" --add_extra_groups --disabled-password ubuntu
  chroot $R usermod -a -G sudo,adm,gpio,i2c,input,spi,video -p '$6$iTPEdlv4$HSmYhiw2FmvQfueq32X30NqsYKpGDoTAUV2mzmHEgP/1B7rV3vfsjZKnAWn6M2d.V2UsPuZ2nWHg1iqzIu/nF/' ubuntu
}

function install_software() {
  echo '----> Install base software'
  chroot $R ./getSoftware.sh
}

function stage_02_customize() {
  create_groups
  create_user
  install_software
  apt_upgrade
  apt_clean
}

function set_hardware() {
  echo '----> Setting hardware options'
  chroot $R ./setFirmware.sh
}

function clean_up() {
  echo '----> Cleanup system, prepare to build image'
  chroot $R ./cleanUp.sh
}

function umount_system() {
  echo '----> Unmount filesystems'
  umount -l $R/sys
  umount -l $R/proc
  umount -l $R/dev/pts
  umount -l $R/dev
}

function build_image() {
  echo '----> Building image'
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
  mkfs.vfat -n PI_BOOT -S 512 -s 16 -v "$VFAT_LOOP"
  mkfs.ext4 -L PI_ROOT -m 0 "$EXT4_LOOP"
  MOUNTDIR="$BUILDDIR/mount"
  mkdir -p "$MOUNTDIR"
  mount "$EXT4_LOOP" "$MOUNTDIR"
  mkdir -p "$MOUNTDIR/boot"
  mount "$VFAT_LOOP" "$MOUNTDIR/boot"
  rsync -a --progress "$R/" "$MOUNTDIR/"
  umount "$MOUNTDIR/boot"
  umount "$MOUNTDIR"
  losetup -d "$EXT4_LOOP"
  losetup -d "$VFAT_LOOP"
}

function stage_03_raspi2() {
  set_hardware
  apt_upgrade
  apt_clean
  clean_up
  umount_system
  build_image
  make_raspi2_image ${FS_TYPE} ${FS_SIZE}
}

stage_01_base
stage_02_customize
stage_03_raspi2