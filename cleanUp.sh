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
