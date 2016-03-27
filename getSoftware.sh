#!/bin/bash -x

$R=$1

apt-add-repository -y ppa:ubuntu-pi-flavour-makers/ppa
apt-get update

# Python
apt-get -y install python-minimal python3-minimal python-dev python3-dev python-pip python3-pip idle idle3

# Python extras a Raspberry Pi hacker expects to have available ;-)
apt-get -y install raspi-gpio python-rpi.gpio python3-rpi.gpio python-serial python3-serial python-spidev \
python3-spidev python-codebug-tether python3-codebug-tether python-codebug-i2c-tether python3-codebug-i2c-tether \
python-picamera python3-picamera python-rtimulib python3-rtimulib python-pil python3-pil python-pygame

# Base packages
apt-get -y install screen mc openssh-server tighvncserver omxplayer \
bluetooth bluez-utils blueman bluez python-gobject python-gobject-2