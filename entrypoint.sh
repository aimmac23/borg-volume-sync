#!/bin/bash

if [ "x$USER_UID" != "x" ] ; then

  id -u $USER_UID > /dev/null 2>&1

  if [ $? != 0 ] ; then
    adduser -u $USER_UID dummy
    if [ $? -ne 0 ] ; then
      echo "Failed to create borg backup user for ID: $USER_UID"
    fi

  fi
  sudo -E -u dummy /sync-files.sh
else
  /sync-files.sh
fi
