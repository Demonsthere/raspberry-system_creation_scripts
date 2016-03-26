#!/bin/bash -x

printf 'SUBSYSTEM=="vchiq", GROUP="video", MODE="0660"\n' > etc/udev/rules.d/10-local-rpi.rules
printf "SUBSYSTEM==\"gpio*\", PROGRAM=\"/bin/sh -c 'chown -R root:gpio /sys/class/gpio && chmod -R 770 /sys/class/gpio; chown -R root:gpio /sys/devices/virtual/gpio && chmod -R 770 /sys/devices/virtual/gpio'\"\n" > etc/udev/rules.d/99-com.rules
printf 'SUBSYSTEM=="input", GROUP="input", MODE="0660"\n' >> etc/udev/rules.d/99-com.rules
printf 'SUBSYSTEM=="i2c-dev", GROUP="i2c", MODE="0660"\n' >> etc/udev/rules.d/99-com.rules
printf 'SUBSYSTEM=="spidev", GROUP="spi", MODE="0660"\n' >> etc/udev/rules.d/99-com.rules

cat << EOF > etc/udev/rules.d/40-scratch.rules
ATTRS{idVendor}=="0694", ATTRS{idProduct}=="0003", SUBSYSTEMS=="usb", ACTION=="add", MODE="0666", GROUP="plugdev"
EOF