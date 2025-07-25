#!/bin/bash

# 		Lab 3 Script (lab3.sh)
# Automates:
#   - SSH key generation (if needed)
#   - SSH key injection into Incus containers
#   - Deploying and running configure-host.sh in each container
#   - Local /etc/hosts updates
# ✅ Designed for automation and repeatability

trap '' TERM HUP INT
VERBOSE=0
[[ "$1" == "-verbose" ]] && VERBOSE=1

# Logs messages to screen (if verbose) and system log

log() {
    [[ $VERBOSE -eq 1 ]] && echo "[lab3.sh] $1"
    logger "[lab3.sh] $1"
}

# # Host configuration list (mgmt hostname, role, static IP, container name)
# Format: "MGMT_HOSTNAME SYSTEM_HOSTNAME STATIC_IP CONTAINER_NAME"
HOSTS=(
    "server1-mgmt loghost 192.168.16.3 server1"
    "server2-mgmt webhost 192.168.16.4 server2"
)

# 1. Generate SSH key if missing
if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
    log "SSH key not found. Generating..."
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
fi

# 2. Inject SSH key into containers
inject_ssh_key() {
    local container_name=$1
    log "Injecting SSH key into $container_name"

    incus exec "$container_name" -- mkdir -p /home/remoteadmin/.ssh
    cat ~/.ssh/id_rsa.pub | incus exec "$container_name" -- tee -a /home/remoteadmin/.ssh/authorized_keys > /dev/null
    incus exec "$container_name" -- chown -R remoteadmin:remoteadmin /home/remoteadmin/.ssh
    incus exec "$container_name" -- chmod 700 /home/remoteadmin/.ssh
    incus exec "$container_name" -- chmod 600 /home/remoteadmin/.ssh/authorized_keys
}

# 3. Deploy and execute configure-host.sh
deploy_host() {
    local mgmt_name=$1
    local hostname=$2
    local ip=$3
    local peer_hostname=$4
    local peer_ip=$5

    log "Deploying to $mgmt_name ($hostname)..."
    local verbose_flag=""
    [[ $VERBOSE -eq 1 ]] && verbose_flag="-verbose"

    # Transfer script
    scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null configure-host.sh remoteadmin@"$mgmt_name":/home/remoteadmin
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null remoteadmin@"$mgmt_name" "chmod +x /home/remoteadmin/configure-host.sh"

    # Run script with sudo
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null remoteadmin@"$mgmt_name" \
        "sudo /home/remoteadmin/configure-host.sh $verbose_flag -name $hostname -ip $ip -hostentry $peer_hostname $peer_ip"

    if [[ $? -ne 0 ]]; then
        echo "❌ SSH execution failed on $mgmt_name"
        return 1
    fi

    log "✔️ Done with $mgmt_name"
}

# Loop through all host configs and deploy changes
for i in "${!HOSTS[@]}"; do
    IFS=' ' read -r mgmt_name hostname ip container <<< "${HOSTS[i]}"
    peer_index=$((1 - i))
    IFS=' ' read -r _ peer_hostname peer_ip _ <<< "${HOSTS[$peer_index]}"

    inject_ssh_key "$container"
    deploy_host "$mgmt_name" "$hostname" "$ip" "$peer_hostname" "$peer_ip"
done

# Update the local machine's /etc/hosts so it can reach loghost and webhost
./configure-host.sh $([[ $VERBOSE -eq 1 ]] && echo "-verbose") -hostentry loghost 192.168.16.3
./configure-host.sh $([[ $VERBOSE -eq 1 ]] && echo "-verbose") -hostentry webhost 192.168.16.4

