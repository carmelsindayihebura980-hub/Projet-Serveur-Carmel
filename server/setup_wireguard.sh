#!/usr/bin/env bash
set -euo pipefail

# 1. Update system
apt-get update && apt-get upgrade -y

# 2. Install WireGuard and iptables
apt-get install -y wireguard iptables

# 3. Generate server keys
wg genkey | tee server_private.key | wg pubkey > server_public.key

# 4. Create wg0.conf
cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
Address = 10.8.0.1/24
SaveConfig = true
PrivateKey = $(cat server_private.key)
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o $(ip route | awk '/default/ {print $5}') -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o $(ip route | awk '/default/ {print $5}') -j MASQUERADE
EOF

# 5. Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1

# 6. Start WireGuard
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# 7. Open UDP port in UFW (if UFW is installed)
if command -v ufw &> /dev/null; then
    ufw allow 51820/udp
    ufw --force enable
fi

echo "WireGuard serveur configuré avec succès."