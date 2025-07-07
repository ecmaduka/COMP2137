#!/bin/bash

echo "===== Assignment 2: System Modification Script ====="
echo "Running as: $(whoami)"
echo "-----------------------------------------------------"

# 1. Configure static IP with netplan
echo "[*] Checking and setting static IP (192.168.16.21)..."
NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
if [ -f "$NETPLAN_FILE" ] && grep -q "192.168.16.21" "$NETPLAN_FILE"; then
  echo "[OK] Static IP already set."
else
  sudo bash -c "cat > $NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      dhcp4: no
      addresses:
        - 192.168.16.21/24
EOF

  # Fix permissions (required to stop warnings)
  sudo chmod 600 "$NETPLAN_FILE"
  sudo chown root:root "$NETPLAN_FILE"

  echo "[+] Netplan config updated."
  sudo netplan apply
fi

# 2. Update /etc/hosts
echo "[*] Updating /etc/hosts..."
if grep -q "192.168.16.21 server1" /etc/hosts; then
  echo "[OK] /etc/hosts already contains the correct entry."
else
  sudo sed -i '/server1/d' /etc/hosts
  echo "192.168.16.21 server1" | sudo tee -a /etc/hosts
  echo "[+] /etc/hosts updated."
fi

# 3. Install apache2
echo "[*] Installing apache2..."
if dpkg -l | grep -q apache2; then
  echo "[OK] apache2 already installed."
else
  sudo apt update && sudo apt install -y apache2
  echo "[+] apache2 installed."
fi

# 4. Install squid
echo "[*] Installing squid..."
if dpkg -l | grep -q squid; then
  echo "[OK] squid already installed."
else
  sudo apt install -y squid
  echo "[+] squid installed."
fi

# 5. Create users and setup ssh
echo "[*] Creating user accounts and configuring ssh keys..."
USERS="dennis aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda"
EXTRA_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"

for USER in $USERS; do
  if id "$USER" &>/dev/null; then
    echo "[OK] User '$USER' already exists."
  else
    sudo useradd -m -s /bin/bash "$USER"
    echo "[+] Created user '$USER'."
  fi

  SSH_DIR="/home/$USER/.ssh"
  AUTH_KEYS="$SSH_DIR/authorized_keys"
  RSA_KEY="$SSH_DIR/id_rsa"
  ED_KEY="$SSH_DIR/id_ed25519"

  sudo -u "$USER" mkdir -p "$SSH_DIR"
  sudo -u "$USER" touch "$AUTH_KEYS"

  # Generate RSA key if not already there
  if sudo -u "$USER" [ ! -f "/home/$USER/.ssh/id_rsa" ]; then
    sudo -u "$USER" ssh-keygen -t rsa -N "" -f "/home/$USER/.ssh/id_rsa"
    echo "[+] Created RSA key for $USER."
  else
    echo "[OK] RSA key exists for $USER."
  fi

  # Generate Ed25519 key if not already there
  if sudo -u "$USER" [ ! -f "/home/$USER/.ssh/id_ed25519" ]; then
    sudo -u "$USER" ssh-keygen -t ed25519 -N "" -f "/home/$USER/.ssh/id_ed25519"
    echo "[+] Created Ed25519 key for $USER."
  else
    echo "[OK] Ed25519 key exists for $USER."
  fi

  # Add keys to authorized_keys if not already present
  for PUB in "/home/$USER/.ssh/id_rsa.pub" "/home/$USER/.ssh/id_ed25519.pub"; do
    PUB_CONTENT=$(sudo cat "$PUB")
    if ! grep -qF "$PUB_CONTENT" "$AUTH_KEYS"; then
      echo "$PUB_CONTENT" | sudo tee -a "$AUTH_KEYS" > /dev/null
      echo "[+] Added $(basename "$PUB") to authorized_keys for $USER."
    else
      echo "[OK] $(basename "$PUB") already in authorized_keys."
    fi
  done

  # Add extra key for dennis
  if [ "$USER" == "dennis" ]; then
    if ! grep -qF "$EXTRA_KEY" "$AUTH_KEYS"; then
      echo "$EXTRA_KEY" | sudo tee -a "$AUTH_KEYS" > /dev/null
      echo "[+] Added extra key for dennis."
    else
      echo "[OK] Extra key already present for dennis."
    fi
    sudo usermod -aG sudo dennis
    echo "[+] Ensured sudo access for 'dennis'."
  fi

  sudo chown -R "$USER:$USER" "$SSH_DIR"
  sudo chmod 700 "$SSH_DIR"
  sudo chmod 600 "$AUTH_KEYS"
done

echo "-----------------------------------------------------"
echo "✅ System configuration complete."

