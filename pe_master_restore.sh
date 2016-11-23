#!/bin/bash
# Perform a restore of a PE Master
#  Should be used to perform a restore from files created by pe_master_backup.sh
#  Tested with a standard install of PE 2016.2.1

FILE_RESTORE=$1
SQL_RESTORE_DIR="/tmp"
SQL_RESTORE_FILE="pe_sql_backup.sql"

if [[ `id -u` -ne 0 ]]; then
  echo "You must be root!"
  exit 1
fi

if [[ ! -s "$SQL_RESTORE" ]]; then
  echo "SQL File '$SQL_RESTORE' not provided or is empty"
  exit 1
elif [[ ! -s "$FILE_RESTORE" ]]; then
  echo "TAR File '$FILE_RESTORE' not provided or is empty"
  exit 1
fi

# Cleanup temp files
rm -f "$SQL_RESTORE_DIR/$SQL_RESTORE_FILE"
function F_Exit {
  rm -f "$SQL_RESTORE_DIR/$SQL_RESTORE_FILE"
}
trap F_Exit EXIT

echo
echo "Starting PE Master Restore"
echo "SQL File is: $SQL_RESTORE"
echo "TAR File is: $FILE_RESTORE"

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
tar -xzf "$FILE_RESTORE" -C "$SQL_RESTORE_DIR" "$SQL_RESTORE_FILE"
sudo -u pe-postgres /opt/puppetlabs/server/apps/postgresql/bin/psql < "$SQL_RESTORE_DIR/$SQL_RESTORE_FILE"

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
tar -xzf "$FILE_RESTORE" -C / etc/puppetlabs/puppet/puppet.conf
tar -xzf "$FILE_RESTORE" -C / etc/puppetlabs/puppet/ssl
tar -xzf "$FILE_RESTORE" -C / etc/puppetlabs/puppetdb/ssl
tar -xzf "$FILE_RESTORE" -C / opt/puppetlabs/server/data/postgresql/9.4/data/certs
tar -xzf "$FILE_RESTORE" -C / opt/puppetlabs/server/data/console-services/certs

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
