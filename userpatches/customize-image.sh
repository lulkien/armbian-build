#!/bin/bash
# Orange Pi Zero 3 Ultra Minimal - In-chroot customization
# Runs INSIDE the chroot environment after package installation
# Arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP $ARCH

set -euo pipefail

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4
ARCH=$5

log() {
    echo "[CUSTOMIZE] $*"
}

Main() {
    log "Starting Orange Pi Zero 3 Ultra Minimal customization..."

    # 1. Copy overlay files into place
    if [[ -d /tmp/overlay ]]; then
        log "Copying overlay files..."
        cp -r /tmp/overlay/* / 2>/dev/null || true
    fi

    # 2. Configure dropbear SSH (lightweight alternative to openssh)
    log "Configuring dropbear SSH..."
    mkdir -p /etc/dropbear
    cat > /etc/default/dropbear << 'DROPBEAR_EOF'
# Orange Pi Zero 3 Ultra Minimal - Dropbear config
NO_START=0
DROPBEAR_PORT=22
DROPBEAR_EXTRA_ARGS="-j -k"
# -j: Disable local port forwarding
# -k: Disable remote port forwarding
# Password authentication ENABLED for ALL users including root (no -w, -g, -s flags)
DROPBEAR_RSAKEYFILE="/etc/dropbear/dropbear_rsa_host_key"
DROPBEAR_DSSKEYFILE="/etc/dropbear/dropbear_dss_host_key"
DROPBEAR_ECDSAKEYFILE="/etc/dropbear/dropbear_ecdsa_host_key"
DROPBEAR_ED25519KEYFILE="/etc/dropbear/dropbear_ed25519_host_key"
DROPBEAR_RECEIVE_WINDOW=65536
DROPBEAR_EOF

    # Generate host keys if missing
    dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key 2>/dev/null || true
    dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key 2>/dev/null || true
    dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key 2>/dev/null || true
    dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key 2>/dev/null || true

    # Enable dropbear
    systemctl enable dropbear

    # 3. Configure iwd (iNet Wireless Daemon) - lightweight WiFi
    log "Configuring iwd..."
    mkdir -p /etc/iwd
    cat > /etc/iwd/main.conf << 'IWD_EOF'
[General]
EnableNetworkConfiguration=false
IWD_EOF

    # Enable iwd
    systemctl enable iwd

    # 4. Configure systemd-networkd for network management (lightweight)
    log "Configuring systemd-networkd..."
    mkdir -p /etc/systemd/network
    cat > /etc/systemd/network/20-wired.network << 'NET_EOF'
[Match]
Name=eth0

[Network]
DHCP=yes
IPv6AcceptRA=yes
NET_EOF

    cat > /etc/systemd/network/25-wireless.network << 'WIFI_EOF'
[Match]
Name=wlan0

[Network]
DHCP=yes
IPv6AcceptRA=yes
WIFI_EOF

    systemctl enable systemd-networkd
    systemctl enable systemd-resolved

    # 5. Enable essential services only
    log "Enabling essential services..."
    systemctl enable cron
    systemctl enable systemd-timesyncd
    systemctl enable nftables

    # 6. Configure nftables (allow SSH, deny all incoming by default)
    log "Configuring nftables firewall..."
    mkdir -p /etc/nftables
    cat > /etc/nftables.conf << 'NFT_EOF'
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iif "lo" accept
        ct state established,related accept
        tcp dport 22 accept
        icmp type echo-request accept
        ip6 nexthdr icmpv6 icmpv6 type { echo-request, nd-neighbor-solicit, nd-router-advert, nd-neighbor-advert } accept
    }
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
NFT_EOF

    systemctl enable nftables

    # 7. Configure unattended-upgrades for security only
    log "Configuring unattended-upgrades..."
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'UU_EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Package-Blacklist {
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::InstallOnShutdown "false";
Unattended-Upgrade::Mail "";
Unattended-Upgrade::MailReport "on-change";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
UU_EOF

    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'AU_EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
AU_EOF

    # 8. Configure timezone (Asia/Ho_Chi_Minh per user preference)
    log "Setting timezone to Asia/Ho_Chi_Minh..."
    echo "Asia/Ho_Chi_Minh" > /etc/timezone
    ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime

    # 9. Configure locales
    log "Configuring locales..."
    sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
    locale-gen
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

    # 10. Optimize for SD card / eMMC (reduce writes)
    log "Optimizing for flash storage..."
    # Disable atime on root filesystem
    sed -i 's/^\\(LABEL=ROOTFS.*\\)$/\\1,noatime,nodiratime/' /etc/fstab 2>/dev/null || true

    # 11. Disable swap (better for flash, use zram instead)
    log "Disabling swap, enabling zram..."
    systemctl disable dphys-swapfile 2>/dev/null || true
    # zram-config not in trixie, use armbian-zram-config instead (already enabled via Armbian services)

    # 12. Remove unnecessary systemd services to save memory
    log "Masking unnecessary services..."
    systemctl mask systemd-udev-settle.service 2>/dev/null || true
    systemctl mask systemd-update-utmp-runlevel.service 2>/dev/null || true
    systemctl mask console-setup.service 2>/dev/null || true
    systemctl mask keyboard-setup.service 2>/dev/null || true

    # 13. Clean up
    log "Cleaning up..."
    apt-get autoremove -y
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    rm -rf /tmp/* 2>/dev/null || true
    rm -rf /root/.cache
    rm -rf /var/cache/apt/archives/*

    log "Orange Pi Zero 3 Ultra Minimal customization complete!"
}

Main "$@"