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

# Set Initial Variables
BACKUP_DIR="$1"
TIMESTAMP=`date +"%m%d%Y-%H%M%S"`
ARCHIVE_FILE="pe_backup.$TIMESTAMP.tar.gz"
SQL_FILE="pe_sql_backup.sql"


#############
## Functions
#############
# Print Script Usage
F_Usage () {
  echo
  echo "Usage: pe_master_backup.sh /path/to/backup/dir"
  echo
  echo "This script will backup a PE Master to an archive"
  echo "from which it can be restored." 
  exit 2
}


##############
## Validation
##############
# Validate that we are root
if [[ `id -u` -ne 0 ]]; then
  echo
  echo "ERROR: You must be root!"
  F_Usage
fi

# Ensure we passed a backup directory
if [[ -z "$BACKUP_DIR" ]]; then
  echo
  echo "ERROR: No Backup Directory specified"
  F_Usage
fi

# Ensure the backup directory exists
if [[ ! -d "$BACKUP_DIR" ]]; then
  mkdir -p "$BACKUP_DIR"
fi

# Cleanup temp files
rm -f "$BACKUP_DIR/$SQL_FILE"
F_Exit () {
  rm -f "$BACKUP_DIR/$SQL_FILE"
}

##################
## Perform Backup
##################
# Keep a copy of /etc/puppetlabs in $BACKUP_DIR
echo
echo "Start raw copy of /etc/puppetlabs"
cp -rp /etc/puppetlabs "$BACKUP_DIR"

# Backup the PuppetDB
echo
echo "Starting DB Dump"
touch "$BACKUP_DIR/$SQL_FILE"
chown pe-postgres: "$BACKUP_DIR/$SQL_FILE"
chmod 640 "$BACKUP_DIR/$SQL_FILE"
sudo -u pe-postgres \
  /opt/puppetlabs/server/apps/postgresql/bin/pg_dumpall \
  -c -f "$BACKUP_DIR/$SQL_FILE"

# Create an archive file with..
#  - Configuration
#  - Puppet DB
#  - Certificates
#  - Keys
echo
echo "Starting Archive of files"
tar -czf "$BACKUP_DIR/$ARCHIVE_FILE" -C "$BACKUP_DIR" \
  /etc/puppetlabs \
  /opt/puppetlabs/server/data/console-services/certs \
  /opt/puppetlabs/server/data/postgresql/9.4/data/certs \
  "$SQL_FILE"
chmod 640 "$BACKUP_DIR/$ARCHIVE_FILE"

echo
echo "PE Master backup Complete"
exit 0
