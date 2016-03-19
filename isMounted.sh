#!/bin/bash -x
DIRECTORY=`pwd`
MOUNTS=`mount | grep ${DIRECTORY}`
if [ -z "$MOUNTS" ]; then
    echo "Nothing to unmount"
else
  sudo umount -l ${DIRECTORY}
fi
