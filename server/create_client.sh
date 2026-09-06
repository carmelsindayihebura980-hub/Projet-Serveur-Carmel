#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <nom_client>"
  exit 1
fi

CLIENT_NAME=$1

# Générer les clés du client
CLIENT_PRIV=$(wg genkey)
CLIENT_PUB=$(echo "$CLIENT_PRIV" | wg pubkey)

# Allouer la prochaine adresse IP du client (incrémentale)
NEXT_ID_FILE="/etc/wireguard/next_id"
if [[ -f "$NEXT_ID_FILE" ]]; then
  NEXT_ID=$(<"$NEXT_ID_FILE")
else
  NEXT_ID=0
  echo "$NEXT_ID" > "$NEXT_ID_FILE"
fi
NEXT_ID=$((NEXT_ID + 1))
echo "$NEXT_ID" > "$NEXT_ID_FILE"

CLIENT_IP="10.8.0.$((NEXT_ID + 1))"

# Créer la configuration client
cat <<EOF > "/etc/wireguard/${CLIENT_NAME}.conf"
[Interface]
PrivateKey = $CLIENT_PRIV
Address = $CLIENT_IP/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = $(cat /etc/wireguard/server_public.key)
Endpoint = $(curl -s ifconfig.me):51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

echo "Configuration client ${CLIENT_NAME} créée :"
echo "  Adresse : $CLIENT_IP"
echo "  Fichier : /etc/wireguard/${CLIENT_NAME}.conf"