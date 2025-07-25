#!/bin/bash

# 			PURPOSE:
#   This script configures a Linux container or host by:
#   - Changing the hostname (if requested)
#   - Setting a static IP address via Netplan
#   - Adding or updating a host entry in /etc/hosts
#
#   Designed for automation:
#   - Can be run remotely over SSH without prompting
#   - Idempotent: won’t apply changes unnecessarily
#   - Safe to run multiple times with the same input


# Ignore termination signals to avoid interruption during execution
trap '' TERM HUP INT
VERBOSE=0
HOSTNAME_CHANGE=""
IP_CHANGE=""
HOSTENTRY_NAME=""
HOSTENTRY_IP=""

# Log to system log and optionally print to screen
log_msg() {
    logger "[configure-host.sh] $1"
    [[ $VERBOSE -eq 1 ]] && echo "$1"
}

print_usage() {
    echo "Usage: $0 [-verbose] [-name newname] [-ip newip] [-hostentry name ip]"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -verbose)
            VERBOSE=1
            shift
            ;;
        -name)
            HOSTNAME_CHANGE="$2"
            shift 2
            ;;
        -ip)
            IP_CHANGE="$2"
            shift 2
            ;;
        -hostentry)
            HOSTENTRY_NAME="$2"
            HOSTENTRY_IP="$3"
            shift 3
            ;;
        *)
            print_usage
            ;;
    esac
done

# Hostname update
if [[ -n "$HOSTNAME_CHANGE" ]]; then
    CURRENT_HOSTNAME=$(hostname)
    if [[ "$CURRENT_HOSTNAME" != "$HOSTNAME_CHANGE" ]]; then
        echo "$HOSTNAME_CHANGE" > /etc/hostname
        hostnamectl set-hostname "$HOSTNAME_CHANGE"
        sed -i "s/127.0.1.1.*/127.0.1.1 $HOSTNAME_CHANGE/" /etc/hosts
        log_msg "Hostname changed from $CURRENT_HOSTNAME to $HOSTNAME_CHANGE"
    else
        log_msg "Hostname already set to $HOSTNAME_CHANGE"
    fi
fi

# IP address update using full YAML rewrite & fixed permissions
if [[ -n "$IP_CHANGE" ]]; then
    IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [[ -z "$IFACE" ]]; then
        echo "⚠️ No default network interface found."
        exit 1
    fi

    CURRENT_IP=$(ip -4 addr show "$IFACE" | grep -oP 'inet \K[\d.]+')

    if [[ "$CURRENT_IP" != "$IP_CHANGE" ]]; then
        NETPLAN_FILE="/etc/netplan/10-lxc.yaml"

        cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  ethernets:
    $IFACE:
      dhcp4: no
      addresses: [$IP_CHANGE/24]
      routes:
        - to: default
          via: 192.168.16.1
          on-link: true
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
EOF

        chmod 600 "$NETPLAN_FILE"

        # Automatically accept netplan try prompt
        echo | netplan try --timeout 5 && netplan apply

        if [[ $? -eq 0 ]]; then
            log_msg "IP address updated to $IP_CHANGE"
            grep -q "$IP_CHANGE" /etc/hosts || echo "$IP_CHANGE $(hostname)" >> /etc/hosts
        else
            echo "⚠️ Netplan config failed. Manual recovery may be required."
            exit 1
        fi
    else
        log_msg "IP already set to $IP_CHANGE"
    fi
fi

# /etc/hosts entry update
if [[ -n "$HOSTENTRY_NAME" && -n "$HOSTENTRY_IP" ]]; then

# Check if correct entry already exists
    grep -w "$HOSTENTRY_NAME" /etc/hosts | grep -q "$HOSTENTRY_IP"
    if [[ $? -ne 0 ]]; then
    
# Remove any old entry for the name    
        sed -i "/\s$HOSTENTRY_NAME$/d" /etc/hosts
        
# Add updated entry        
        echo "$HOSTENTRY_IP $HOSTENTRY_NAME" >> /etc/hosts
        log_msg "Updated /etc/hosts: $HOSTENTRY_IP $HOSTENTRY_NAME"
    else
        log_msg "/etc/hosts already correct for $HOSTENTRY_NAME"
    fi
fi

exit 0

