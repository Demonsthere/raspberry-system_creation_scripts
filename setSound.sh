#!/bin/bash -x
mkdir -p lib/modules-load.d/
cat <<EOF > lib/modules-load.d/rpi2.conf
snd_bcm2835
bcm2708_rng
EOF