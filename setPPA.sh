#!/bin/bash -x

cat <<EOF > etc/apt/preferences.d/rpi2-ppa
Package: *
Pin: release o=LP-PPA-fo0bar-rpi2
Pin-Priority: 990

Package: *
Pin: release o=LP-PPA-fo0bar-rpi2-staging
Pin-Priority: 990
EOF