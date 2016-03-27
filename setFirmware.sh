#!/bin/bash -x

apt-add-repository -y ppa:ubuntu-pi-flavour-makers/ppa
apt-get update
apt-get -y install gdebi-core wget
COFI="http://archive.raspberrypi.org/debian/pool/main/r/raspi-copies-and-fills/raspi-copies-and-fills_0.5-1_armhf.deb"

# Firmware Kernel installation
apt-get -y install libraspberrypi-bin libraspberrypi-dev libraspberrypi-doc libraspberrypi0 raspberrypi-bootloader rpi-update
apt-get -y install linux-firmware linux-firmware-nonfree

rpi-update

# Add VideoCore libs to ld.so
echo "/opt/vc/lib" > etc/ld.so.conf.d/vmcs.conf

apt-get -y install xserver-xorg-video-fbturbo
cat << EOF > etc/X11/xorg.conf
Section "Device"
    Identifier "Raspberry Pi FBDEV"
    Driver "fbturbo"
    Option "fbdev" "/dev/fb0"
    Option "SwapbuffersWait" "true"
EndSection
EOF

# Hardware - Create a fake HW clock and add rng-tools
apt-get -y install fake-hwclock fbset i2c-tools rng-tools

# Load sound module on boot and enable HW random number generator
cat << EOF > etc/modules-load.d/rpi2.conf
snd_bcm2835
bcm2708_rng
EOF

# Blacklist platform modules not applicable to the RPi2
cat << EOF > etc/modprobe.d/blacklist-rpi2.conf
blacklist snd_soc_pcm512x_i2c
blacklist snd_soc_pcm512x
blacklist snd_soc_tas5713
blacklist snd_soc_wm8804
EOF

# Disable TLP
if [ -f etc/default/tlp ]; then
  sed -i s'/TLP_ENABLE=1/TLP_ENABLE=0/' $R/etc/default/tlp
fi

# udev rules
printf 'SUBSYSTEM=="vchiq", GROUP="video", MODE="0660"\n' > etc/udev/rules.d/10-local-rpi.rules
printf "SUBSYSTEM==\"gpio*\", PROGRAM=\"/bin/sh -c 'chown -R root:gpio /sys/class/gpio && chmod -R 770 /sys/class/gpio; chown -R root:gpio /sys/devices/virtual/gpio && chmod -R 770 /sys/devices/virtual/gpio'\"\n" > etc/udev/rules.d/99-com.rules
printf 'SUBSYSTEM=="input", GROUP="input", MODE="0660"\n' >> etc/udev/rules.d/99-com.rules
printf 'SUBSYSTEM=="i2c-dev", GROUP="i2c", MODE="0660"\n' >> etc/udev/rules.d/99-com.rules
printf 'SUBSYSTEM=="spidev", GROUP="spi", MODE="0660"\n' >> etc/udev/rules.d/99-com.rules

cat << EOF > etc/udev/rules.d/40-scratch.rules
ATTRS{idVendor}=="0694", ATTRS{idProduct}=="0003", SUBSYSTEMS=="usb", ACTION=="add", MODE="0666", GROUP="plugdev"
EOF

# copies-and-fills
wget -c "${COFI}" -O tmp/cofi.deb
gdebi -n /tmp/cofi.deb
# Disabled cofi so it doesn't segfault when building via qemu-user-static
mv -v etc/ld.so.preload etc/ld.so.preload.disable

# Set up fstab
cat << EOF > etc/fstab
proc            /proc           proc    defaults          0       0
/dev/mmcblk0p2  /               ext4    defaults,noatime  0       1
/dev/mmcblk0p1  /boot/          vfat    defaults          0       2
EOF

# Set up firmware config
wget -c https://raw.githubusercontent.com/Evilpaul/RPi-config/master/config.txt -O boot/config.txt
echo "net.ifnames=0 biosdevname=0 dwc_otg.lpm_enable=0 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline rootwait quiet splash" > boot/cmdline.txt
sed -i 's/#framebuffer_depth=16/framebuffer_depth=32/' boot/config.txt
sed -i 's/#framebuffer_ignore_alpha=0/framebuffer_ignore_alpha=1/' boot/config.txt
sed -i 's/#arm_freq=700/arm_freq=1000/' boot/config.txt
sed -i 's/#sdram_freq=400/sdram_freq=500/' boot/config.txt
sed -i 's/#core_freq=250/core_freq=500/' boot/config.txt
sed -i 's/#sdram_freq=400/sdram_freq=500/' boot/config.txt
sed -i 's/#over_voltage=0/over_voltage=2/' boot/config.txt
sed -i 's/#gpu_mem=128/sdram_freq=256/' boot/config.txt

# Save the clock
fake-hwclock save