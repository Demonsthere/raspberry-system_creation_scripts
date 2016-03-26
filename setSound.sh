#!/bin/bash -x

cat <<EOF > etc/modules-load.d/rpi2.conf
snd_bcm2835
bcm2708_rng
EOF