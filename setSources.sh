#!/bin/bash -x
RELEASE=$1
REPOSITORY=$2
cat << EOF > etc/apt/sources.list
deb ${REPOSITORY} ${RELEASE} main contrib non-free
# deb-src ${REPOSITORY} ${RELEASE} main contrib non-free

deb ${REPOSITORY} ${RELEASE}-updates main contrib non-free
# deb-src ${REPOSITORY} ${RELEASE}-updates main contrib non-free

deb ${REPOSITORY} ${RELEASE}-proposed-updates main contrib non-free
# deb-src ${REPOSITORY} ${RELEASE}-proposed-updates main contrib non-free

deb ${REPOSITORY} ${RELEASE}-backports main contrib non-free
# deb-src ${REPOSITORY} ${RELEASE}-backports main contrib non-free
EOF