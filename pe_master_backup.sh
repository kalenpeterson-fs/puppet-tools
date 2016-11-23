#!/bin/bash
# Perform a backup of a PE Master
#  Backups can be restored with pe_master_restore.sh
#  Tested with a standard install of PE 2016.2.1

BACKUP_DIR=/var/puppet/backups
TIMESTAMP=`date +"%m%d%Y-%H%M%S"`

if [[ `id -u` -ne 0 ]]; then
  echo "You must be root!"
  exit 1
fi

if [[ ! -d "$BACKUP_DIR" ]]; then
  mkdir -p "$BACKUP_DIR"
fi

# Keep a copy of /etc/puppetlabs in $BACKUP_DIR
echo
echo "Start raw copy of /etc/puppetlabs"
cp -rp /etc/puppetlabs "$BACKUP_DIR"

# Archive Everything we need
echo
echo "Starting Archive of files"
FILE_BACKUP="$BACKUP_DIR/file_backup.$TIMESTAMP.tar.gz"
tar -czf "$FILE_BACKUP" \
  /etc/puppetlabs \
  /opt/puppetlabs/server/data/console-services/certs \
  /opt/puppetlabs/server/data/postgresql/9.4/data/certs
chmod 640 "$FILE_BACKUP"

# Backup the PuppetDB
echo
echo "Starting DB Dump"
SQL_BACKUP="$BACKUP_DIR/sql_backup.$TIMESTAMP.sql"
cd /tmp
touch "$SQL_BACKUP"; chown pe-postgres: "$SQL_BACKUP"; chmod 640 "$SQL_BACKUP"
sudo -u pe-postgres /opt/puppetlabs/server/apps/postgresql/bin/pg_dumpall -c -f "$SQL_BACKUP"

echo
echo "PE Master backup Complete"
