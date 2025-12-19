#!/bin/bash
set -e

echo "=== Cleanup ==="

# Clear apt cache
apt-get clean
apt-get autoremove -y
rm -rf /var/lib/apt/lists/*

# Clear logs
find /var/log -type f -exec truncate -s 0 {} \;
rm -rf /var/log/*.gz
rm -rf /var/log/*.[0-9]

# Clear temp
rm -rf /tmp/*
rm -rf /var/tmp/*

# Clear bash history
unset HISTFILE
rm -f /root/.bash_history
rm -f /home/*/.bash_history

# Clear machine-id (will regenerate on first boot)
truncate -s 0 /etc/machine-id

# Clear SSH host keys (will regenerate on first boot)
rm -f /etc/ssh/ssh_host_*

# Sync
sync

echo "Cleanup done"
