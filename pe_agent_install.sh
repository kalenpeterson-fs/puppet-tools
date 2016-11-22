#!/bin/bash
# Install PE Agents on one or more hosts
#  Requires root SSH keys to be exchanged beforehand

HOST_LIST="$1"
PUPPET_MASTER=master.puppet.lan
LOG_DIR=./

if [[ ! -s "$HOST_LIST" ]]; then
  echo "Please provide a list of hosts"
  exit 1
fi

for host in `cat "$HOST_LIST"`
do

  LOG="$LOG_DIR/$host.peinstall.log"

  echo "Checking SSH connection to $host"
  ssh -o ConnectTimeout=2 -o ConnectionAttempts=2 -o StrictHostKeyChecking=no \
  $host "echo >/dev/null" >/dev/null
  if [[ $? -eq 0 ]]; then
    echo
    echo "Starting PE Agent install on $host"
    echo "Check $LOG for status"
    ssh -n $host \
    "curl -k https://$PUPPET_MASTER:8140/packages/current/install.bash |bash" \
    >$LOG 2>&1 &
  else
    echo
    echo "SSH Connection to $host failed"
  fi
done
