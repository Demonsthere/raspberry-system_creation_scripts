#!/bin/bash -x

rm -f etc/apt/sources.list.save
rm -f etc/resolvconf/resolv.conf.d/original
rm -rf run
mkdir -p run
rm -f etc/*-
rm -f root/.bash_history
rm -rf tmp/*
rm -f var/lib/urandom/random-seed
[ -L var/lib/dbus/machine-id ] || rm -f var/lib/dbus/machine-id
rm -f etc/machine-id
rm -f etc/apt/*.save || true
rm -f var/crash/*
rm -f $var/lib/urandom/random-seed

# Clean up old Raspberry Pi firmware and modules
rm -f boot/.firmware_revision || true
rm -rf boot.bak || true
rm -rf lib/modules/4.1.7* || true
rm -rf lib/modules.bak || true

# Potentially sensitive.
rm -f root/.bash_history
rm -f root/.ssh/known_hosts

# Machine-specific, so remove in case this system is going to be cloned. These will be regenerated on the first boot.
rm -f etc/udev/rules.d/70-persistent-cd.rules
rm -f etc/udev/rules.d/70-persistent-net.rules
rm -f etc/NetworkManager/system-connections/*
[ -L $R/var/lib/dbus/machine-id ] || rm -f $R/var/lib/dbus/machine-id
