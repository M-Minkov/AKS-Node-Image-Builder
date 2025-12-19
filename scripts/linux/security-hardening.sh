#!/bin/bash
set -e

echo "=== Security hardening ==="

# SSH hardening
sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config

# Disable unused filesystems
cat <<EOF | tee /etc/modprobe.d/hardening.conf
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
EOF

# Core dump restrictions
echo '* hard core 0' >> /etc/security/limits.conf
echo 'fs.suid_dumpable = 0' >> /etc/sysctl.d/security.conf

# Restrict dmesg
echo 'kernel.dmesg_restrict = 1' >> /etc/sysctl.d/security.conf

# Network hardening
cat <<EOF | tee -a /etc/sysctl.d/security.conf
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
EOF

# Automatic security updates
apt-get install -y unattended-upgrades
cat <<EOF | tee /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
};
Unattended-Upgrade::Automatic-Reboot "false";
EOF

echo "Security hardening done"
