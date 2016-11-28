#!/bin/bash
# Perform a restore of a PE Master
#  Should be used to perform a restore from files created by pe_master_backup.sh
#  Must be run on the PE Master (or Master of Masters)
#
# Prerequisites
#  You must perform the following actions before restoring
#   - Uninstall PE on the Master with:
#       ./puppet-enterprise-uninstaller -d -p
#   - Re-Install PE with the original pe.conf file
#       ./puppet-enterprise-installer -c /etc/puppetlabs/enterprise/conf.d/pe.conf
#   - Execute this resotore script
#
#  Process being followed:
#   - Stop Puppet Services
#   - Restore Database
#   - Clear install files
#   - Restore required files from archive
#   - Clear Catalog Cache
#   - Chown restored files
#   - Restart Puppet Services
#
#  Tested with the following PE versions
#   - 2016.2.1
#   - 2016.4.2
#
#  Usage: See F_Usage
#
#  Written by: Kalen Peterson <kpeterson@forsythe.com>
#  Created on: 11/23/2016

# Set the expected name of the PE DB Backup file in the archive.
# *NOTE* Do NOT modify this unless you have also changed it in the pe_master_backup.sh script
TMP_SQL_FILE="pe_sql_backup.sql"

#############
## Functions
#############
# Print Script Usage
F_Usage () {
  echo
  echo "Usage: pe_master_restore.sh -f FILE [-d DIRECTORY] -h"
  echo
  echo "Options:"
  echo "  -f    *Required* Specify the pe_backup archive file to restore"
  echo "  -d    *Optional* Specity the temporary working directory to extract the sql backup"
  echo "  -h    Print this usage info"
  echo 
  echo "This script will restore a PE Master Backup archive created with the pe_master_backup.sh script."
  echo
  echo "It must be run on the PE Master or Master of Masters."
  echo
  echo "If a temporary directory is not specified, /tmp will be used to extract the sql backup for restore."
  exit 2
}

# Perform cleanup on script exit
F_Exit () {
  rm -f "$TMP_RESTORE_DIR/$TMP_SQL_FILE"
}



#############
## Arguments
#############
# Manage Options
while getopts :f:d:h FLAG; do
  case $FLAG in
    f)  # Set the Restore File Location
        ARCHIVE_FILE=$OPTARG
        ;;
    d)  # Set the temporary working dir
        TMP_RESTORE_DIR=$OPTARG
        ;;
    h)  # Show Usage
        F_Usage
        ;;
   /?)  # Unknown Option, show usage
        echo "ERROR: Unknown option '$FLAG $OPTARG'"
        F_Usage
        ;;
  esac
done



##############
## Validation
##############
# Validate that we are root
if [[ `id -u` -ne 0 ]]; then
  echo "You must be root!"
  exit 1
fi

# Validate that an archive file was provided
if [[ -z "$ARCHIVE_FILE" ]]; then
  echo
  echo "ERROR: No archive file provided!"
  F_Usage
fi

# Warn the user if they did not provide a temp directory
if [[ -z "$TMP_RESTORE_DIR" ]]; then
  echo "WARN: No temp directory provided, using /tmp!"
  TMP_RESTORE_DIR=/tmp
fi

# Validate that the archive exists
if [[ ! -s "$ARCHIVE_FILE" ]]; then
  echo
  echo "ERROR: Archive file '$ARCHIVE_FILE' does not exist or is empty!"
  F_Usage
fi

# Validate that that temp directory exists
if [[ ! -d "$TMP_RESTORE_DIR" ]]; then
  echo
  echo "ERROR: Temp directory '$TMP_RESTORE_DIR' does not exist!"
  F_Usage
fi



########
## Main
########
# Cleanup temp files
trap F_Exit EXIT

echo
echo "Starting PE Master Restore"
echo "SQL File is: $TMP_RESTORE_DIR/$TMP_SQL_FILE"
echo "TAR File is: $ARCHIVE_FILE"

# Stop Puppet Services
echo
echo "Stopping PE Services"
puppet resource service puppet ensure=stopped
puppet resource service pe-puppetserver ensure=stopped
puppet resource service pe-orchestration-services ensure=stopped
puppet resource service pe-nginx ensure=stopped
puppet resource service pe-puppetdb ensure=stopped
puppet resource service pe-console-services ensure=stopped

# Restore Database
echo
echo "Restoring Database"
tar -xzf "$ARCHIVE_FILE" -C "$TMP_RESTORE_DIR" "$TMP_SQL_FILE"
sudo -u pe-postgres /opt/puppetlabs/server/apps/postgresql/bin/psql < \
  "$TMP_RESTORE_DIR/$TMP_SQL_FILE"

# Clear install files
echo
echo "Deleting install files"
rm -rf /etc/puppetlabs/puppet/ssl/*
rm -rf /etc/puppetlabs/puppetdb/ssl/*
rm -rf /opt/puppetlabs/server/data/postgresql/9.4/data/certs/*
rm -rf /opt/puppetlabs/server/data/console-services/certs/*

# Restore required files from archive
echo
echo "Restoring files from archive"
tar -xzf "$ARCHIVE_FILE" -C / etc/puppetlabs/puppet/puppet.conf
tar -xzf "$ARCHIVE_FILE" -C / etc/puppetlabs/puppet/ssl
tar -xzf "$ARCHIVE_FILE" -C / etc/puppetlabs/puppetdb/ssl
tar -xzf "$ARCHIVE_FILE" -C / opt/puppetlabs/server/data/postgresql/9.4/data/certs
tar -xzf "$ARCHIVE_FILE" -C / opt/puppetlabs/server/data/console-services/certs

# Clear Cache
echo
echo "Removing cached catalog"
rm -f /opt/puppetlabs/puppet/cache/client_data/catalog/`hostname`.json

# Chown restored files
echo
echo "Chowning Restored files"
chown pe-puppet:pe-puppet /etc/puppetlabs/puppet/puppet.conf
chown -R pe-puppet:pe-puppet /etc/puppetlabs/puppet/ssl/
chown -R pe-console-services /opt/puppetlabs/server/data/console-services/certs/
chown -R pe-postgres:pe-postgres /opt/puppetlabs/server/data/postgresql/9.4/data/certs/
chown -R pe-puppetdb:pe-puppetdb /etc/puppetlabs/puppetdb/ssl/

# Restart Puppet Services
echo
echo "Starting PE Services"
puppet resource service pe-puppetserver ensure=running
puppet resource service pe-orchestration-services ensure=running
puppet resource service pe-nginx ensure=running
puppet resource service pe-postgresql ensure=stopped
puppet resource service pe-postgresql ensure=running
puppet resource service pe-puppetdb ensure=running
puppet resource service pe-console-services ensure=running
puppet resource service puppet ensure=running

echo
echo "PE Master Restore complete"
exit 0
