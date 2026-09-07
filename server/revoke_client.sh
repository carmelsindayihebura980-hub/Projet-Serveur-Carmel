#!/usr/bin/env bash
# ============================================================
#  revoke_client.sh - Couper l'accès d'un client
#  Projet-Serveur-Carmel
#
#  Utilisation : ./revoke_client.sh <nom_client>
#    - Supprime le client du serveur WireGuard
#    - Utile quand l'abonnement payé en cash expire
# ============================================================
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <nom_client>"
    exit 1
fi

CLIENT_NAME="$1"
PUB_FILE="/etc/wireguard/${CLIENT_NAME}.pub"

if [ ! -f "$PUB_FILE" ]; then
    echo "ERREUR : aucun fichier ${CLIENT_NAME}.pub trouvé."
    echo "Vérifiez que ce client existe."
    exit 1
fi

CLIENT_PUB=$(cat "$PUB_FILE")
echo "===== Révocation du client : $CLIENT_NAME ====="

# 1. Retirer le peer du serveur
wg set wg0 peer "$CLIENT_PUB" remove
echo "✅ Client $CLIENT_NAME retiré du serveur."

# 2. Sauvegarde de la config avant suppression (archivage)
mkdir -p /root/revoked
if [ -f "/etc/wireguard/${CLIENT_NAME}.conf" ]; then
    mv "/etc/wireguard/${CLIENT_NAME}.conf" "/root/revoked/${CLIENT_NAME}.conf.$(date +%F)"
fi
mv "$PUB_FILE" "/root/revoked/${CLIENT_NAME}.pub.$(date +%F)" 2>/dev/null || true

# 3. Suppression du QR code
rm -f "/root/qr/${CLIENT_NAME}.png"

echo ""
echo "=========================================="
echo "  Accès de $CLIENT_NAME révoqué."
echo "  Le client ne peut plus se connecter."
echo "  Date : $(date)"
echo "=========================================="