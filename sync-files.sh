#!/bin/bash

#set -e

#REPO_BASE=...
#ARCHIVE_NAME=...
#BORG_PASSPHRASE=...
RSH_FRAGMENT="\"ssh -i /tmp/my-privatekey -o BatchMode=true -o StrictHostKeyChecking=no\""
SHOULD_EXIT=0

exit_hook() {
  echo "Exit hook - attempting backup"
  SHOULD_EXIT=1
  NOW=`date +%s`
  borg --rsh "\"$RSH_FRAGMENT\"" create $REPO_BASE/$ARCHIVE_NAME::$NOW"-exit" .

  echo "Exit hook backup completed"
}

if [ "$REPO_BASE" =  "" ] ; then
  echo "No REPO_BASE environment variable specified (should be in the format of user@host:/path/to/borg/backups), exiting."
  exit 1
fi

if [ "$ARCHIVE_NAME" =  "" ] ; then
  echo "No ARCHIVE_NAME environment variable specified, exiting."
  exit 1
fi

# So we don't have trouble with file permission issues (too permissive is rejected)
cp /ssh-key/ssh-privatekey /tmp/my-privatekey
chmod 0400 /tmp/my-privatekey

if [ "$BORG_PASSPHRASE" =  "" ] ; then
  echo "No BORG_PASSPHRASE environment variable passed - attempting to use repository as unencrypted. This may fail later."
  # We haven't accepted the host key yet, and the repo is currently unencrypted - disable borg security check for that.
  export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes
fi

LATEST_BACKUP=`borg list --rsh "\"$RSH_FRAGMENT\"" --format '{archive}' --last 1 $REPO_BASE/$ARCHIVE_NAME`

if [ $? -ne 0 ] ; then
  echo "Error fetching last backup - exiting"
  exit 1
fi

cd /data

if [ "$LATEST_BACKUP" !=  "" ] ; then
  if test -f /tmp/READY ; then
    echo "Backup archive found, but script already run - not restoring again to prevent clobbering"
  else
    echo "Restoring backup: $LATEST_BACKUP for $ARCHIVE_NAME"
    borg --rsh "\"$RSH_FRAGMENT\"" -v extract --numeric-ids -e "." $REPO_BASE/$ARCHIVE_NAME::$LATEST_BACKUP || exit 1

    echo "Finished restoring backup"
  fi
else
  echo "No backup found - borg archive suspected to be empty. Proceeding anyway, assuming the application will init some default values"
fi

trap exit_hook TERM

touch /tmp/READY

sleep 60

MY_PRUNE_FLAGS=${PRUNE_FLAGS:="--keep-minutely 4 -H 4 -d 7 -w 4 -m 2"}

while true; do
  NOW=`date +%s`
  echo "Creating backup: $NOW"
  borg --rsh "\"$RSH_FRAGMENT\"" create $REPO_BASE/$ARCHIVE_NAME::$NOW .
  echo "Finished creating backup $NOW"
  borg --rsh "\"$RSH_FRAGMENT\"" prune $MY_PRUNE_FLAGS $REPO_BASE/$ARCHIVE_NAME
  for i in $(seq 1 600); do
    # Sleep for 1 second at a time, so the exit hook works properly
    sleep 1
    if [ $SHOULD_EXIT -eq 1 ] ; then
      exit 0
    fi
    done
done
