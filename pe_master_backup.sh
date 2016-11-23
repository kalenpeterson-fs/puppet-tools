#!/bin/bash
#  Perform a backup of a PE Master
#  Process being followed
#   - Keep a copy of /etc/puppetlabs in $BACKUP_DIR
#   - Archive all config files, certificates, and keys
#   - Backup the PuppetDB
#  Backups can be restored with pe_master_restore.sh
#  Tested with the following PE versions
#   - 2016.2.1
#   - 2016.4.2
#  Usage: 
#  Written by: Kalen Peterson <kpeterson@forsythe.com> 
#  Created on: 11/23/2016

BACKUP_DIR=/var/puppet/backups
TIMESTAMP=`date +"%m%d%Y-%H%M%S"`
FILE_BACKUP="$BACKUP_DIR/pe_backup.$TIMESTAMP.tar.gz"
SQL_BACKUP="$BACKUP_DIR/pe_sql_backup.sql"

if [[ `id -u` -ne 0 ]]; then
  echo "You must be root!"
  exit 1
fi

if [[ ! -d "$BACKUP_DIR" ]]; then
  mkdir -p "$BACKUP_DIR"
fi

# Cleanup temp files
rm -f "$SQL_BACKUP"
function F_Exit {
  rm -f "$SQL_BACKUP"
}
trap F_Exit EXIT

# Keep a copy of /etc/puppetlabs in $BACKUP_DIR
echo
echo "Start raw copy of /etc/puppetlabs"
cp -rp /etc/puppetlabs "$BACKUP_DIR"

# Backup the PuppetDB
echo
echo "Starting DB Dump"
touch "$SQL_BACKUP"; chown pe-postgres: "$SQL_BACKUP"; chmod 640 "$SQL_BACKUP"
sudo -u pe-postgres /opt/puppetlabs/server/apps/postgresql/bin/pg_dumpall -c -f "$SQL_BACKUP"

# Archive Everything we need
echo
echo "Starting Archive of files"
tar -czf "$FILE_BACKUP" \
  /etc/puppetlabs \
  /opt/puppetlabs/server/data/console-services/certs \
  /opt/puppetlabs/server/data/postgresql/9.4/data/certs \
  "$SQL_BACKUP"
chmod 640 "$FILE_BACKUP"

echo
echo "PE Master backup Complete"
