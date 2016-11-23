#!/bin/bash
# Regenerates all certs on a Monolithic Puppet Master
# References: https://docs.puppet.com/pe/latest/trouble_regenerate_certs_monolithic.html

oldCertname=`puppet config print certname`
certname=`facter fqdn`
backupDir=/tmp

# Shutdown all PE Services
puppet resource service puppet ensure=stopped
puppet resource service pe-puppetserver ensure=stopped
puppet resource service pe-activemq ensure=stopped
puppet resource service mcollective ensure=stopped
puppet resource service pe-puppetdb ensure=stopped
puppet resource service pe-postgresql ensure=stopped
puppet resource service pe-console-services ensure=stopped
puppet resource service pe-nginx ensure=stopped
puppet resource service pe-orchestration-services ensure=stopped
puppet resource service pxp-agent ensure=stopped

# Backup CA
tar -czf $backupDir/$oldCertname.ca.backup.tar.gz \
  /etc/puppetlabs/puppet/ssl/ \
  /etc/puppetlabs/puppetdb/ssl/ \
  /opt/puppetlabs/server/data/console-services/certs/ \
  /opt/puppetlabs/server/data/postgresql/9.4/data/certs/ \
  /etc/puppetlabs/orchestration-services/ssl \

# Delete CA
rm -rf /etc/puppetlabs/puppet/ssl/*
rm -f /opt/puppetlabs/puppet/cache/client_data/catalog/$oldCertname.json

# Regenerate the CA and Certs
puppet cert list -a
puppet cert generate $certname --dns_alt_names=puppet
puppet cert generate pe-internal-classifier
puppet cert generate pe-internal-dashboard
puppet cert generate pe-internal-mcollective-servers
puppet cert generate pe-internal-peadmin-mcollective-client
puppet cert generate pe-internal-puppet-console-mcollective-client
puppet cert generate pe-internal-orchestrator
cp /etc/puppetlabs/puppet/ssl/ca/ca_crl.pem /etc/puppetlabs/puppet/ssl/crl.pem
chown -R pe-puppet:pe-puppet /etc/puppetlabs/puppet/ssl
rm -rf /etc/puppetlabs/puppetdb/ssl/*
cp /etc/puppetlabs/puppet/ssl/certs/$certname.pem /etc/puppetlabs/puppetdb/ssl/$certname.cert.pem
cp /etc/puppetlabs/puppet/ssl/public_keys/$certname.pem /etc/puppetlabs/puppetdb/ssl/$certname.public_key.pem
cp /etc/puppetlabs/puppet/ssl/private_keys/$certname.pem /etc/puppetlabs/puppetdb/ssl/$certname.private_key.pem
cd /etc/puppetlabs/puppetdb/ssl
openssl pkcs8 -topk8 -inform PEM -outform DER -in /etc/puppetlabs/puppetdb/ssl/$certname.private_key.pem -out /etc/puppetlabs/puppetdb/ssl/$certname.private_key.pk8 -nocrypt
chown -R pe-puppetdb:pe-puppetdb /etc/puppetlabs/puppetdb/ssl
rm -rf /opt/puppetlabs/server/data/postgresql/9.4/data/certs/*
cp /etc/puppetlabs/puppet/ssl/certs/$certname.pem /opt/puppetlabs/server/data/postgresql/9.4/data/certs/$certname.cert.pem
cp /etc/puppetlabs/puppet/ssl/public_keys/$certname.pem /opt/puppetlabs/server/data/postgresql/9.4/data/certs/$certname.public_key.pem
cp /etc/puppetlabs/puppet/ssl/private_keys/$certname.pem /opt/puppetlabs/server/data/postgresql/9.4/data/certs/$certname.private_key.pem
chmod 400 /opt/puppetlabs/server/data/postgresql/9.4/data/certs/*
chown pe-postgres:pe-postgres /opt/puppetlabs/server/data/postgresql/9.4/data/certs/*
rm -rf /etc/puppetlabs/orchestration-services/ssl/*
cp /etc/puppetlabs/puppet/ssl/certs/pe-internal-orchestrator.pem /etc/puppetlabs/orchestration-services/ssl/pe-internal-orchestrator.cert.pem
cp /etc/puppetlabs/puppet/ssl/public_keys/pe-internal-orchestrator.pem /etc/puppetlabs/orchestration-services/ssl/pe-internal-orchestrator.public_key.pem
cp /etc/puppetlabs/puppet/ssl/private_keys/pe-internal-orchestrator.pem /etc/puppetlabs/orchestration-services/ssl/pe-internal-orchestrator.private_key.pem
cp /etc/puppetlabs/puppet/ssl/certs/$certname.pem /etc/puppetlabs/orchestration-services/ssl/$certname.cert.pem
cp /etc/puppetlabs/puppet/ssl/public_keys/$certname.pem /etc/puppetlabs/orchestration-services/ssl/$certname.public_key.pem
cp /etc/puppetlabs/puppet/ssl/private_keys/$certname.pem /etc/puppetlabs/orchestration-services/ssl/$certname.private_key.pem
cd /etc/puppetlabs/orchestration-services/ssl
openssl pkcs8 -topk8 -inform PEM -outform DER -in /etc/puppetlabs/orchestration-services/ssl/$certname.private_key.pem -out /etc/puppetlabs/orchestration-services/ssl/$certname.private_key.pk8 -nocrypt
chown -R pe-orchestration-services:pe-orchestration-services /etc/puppetlabs/orchestration-services/ssl/
rm -rf /opt/puppetlabs/server/data/console-services/certs/*
cp /etc/puppetlabs/puppet/ssl/certs/pe-internal-classifier.pem /opt/puppetlabs/server/data/console-services/certs/pe-internal-classifier.cert.pem
cp /etc/puppetlabs/puppet/ssl/public_keys/pe-internal-classifier.pem /opt/puppetlabs/server/data/console-services/certs/pe-internal-classifier.public_key.pem
cp /etc/puppetlabs/puppet/ssl/private_keys/pe-internal-classifier.pem /opt/puppetlabs/server/data/console-services/certs/pe-internal-classifier.private_key.pem
cp /etc/puppetlabs/puppet/ssl/certs/$certname.pem /opt/puppetlabs/server/data/console-services/certs/$certname.cert.pem
cp /etc/puppetlabs/puppet/ssl/public_keys/$certname.pem /opt/puppetlabs/server/data/console-services/certs/$certname.public_key.pem
cp /etc/puppetlabs/puppet/ssl/private_keys/$certname.pem /opt/puppetlabs/server/data/console-services/certs/$certname.private_key.pem
cd /opt/puppetlabs/server/data/console-services/certs
openssl pkcs8 -topk8 -inform PEM -outform DER -in /opt/puppetlabs/server/data/console-services/certs/$certname.private_key.pem -out /opt/puppetlabs/server/data/console-services/certs/$certname.private_key.pk8 -nocrypt
chown -R pe-console-services:pe-console-services /opt/puppetlabs/server/data/console-services/certs/
cp /etc/puppetlabs/puppet/ssl/certs/pe-internal-dashboard.pem /opt/puppetlabs/server/data/console-services/certs/pe-internal-dashboard.cert.pem
cp /etc/puppetlabs/puppet/ssl/public_keys/pe-internal-dashboard.pem /opt/puppetlabs/server/data/console-services/certs/pe-internal-dashboard.public_key.pem
cp /etc/puppetlabs/puppet/ssl/private_keys/pe-internal-dashboard.pem /opt/puppetlabs/server/data/console-services/certs/pe-internal-dashboard.private_key.pem
chown -R pe-console-services:pe-console-services /opt/puppetlabs/server/data/console-services/certs

# Restart Services
puppet resource service pe-puppetserver ensure=running
puppet resource service pe-postgresql ensure=running
puppet resource service pe-puppetdb ensure=running
puppet resource service pe-console-services ensure=running
puppet resource service pe-nginx ensure=running
puppet resource service pe-activemq ensure=running
puppet resource service mcollective ensure=running
puppet resource service puppet ensure=running
puppet resource service pe-orchestration-services ensure=running
puppet resource service pxp-agent ensure=running

puppet agent -t
