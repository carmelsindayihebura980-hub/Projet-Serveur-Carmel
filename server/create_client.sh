#!/usr/bin/env bash
# ============================================================
#  create_client.sh - Création d'un client + génération QR code
#  Projet-Serveur-Carmel
#
#  Utilisation : ./create_client.sh <nom_client> [jours]
#    - nom_client : nom du client (ex. client1, alice, bob)
#    - jours      : durée de validité de l'accès (défaut 30)
#
#  Génère :
#    - /etc/wireguard/<nom>.conf  (configuration: configuration du client)
#    - /root/qr/<nom>.png         (QR code à imprimer / montrer)
#    - Affiche le QR code dans le terminal
# ============================================================
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <nom_client> [jours]"
    exit 1
fi

CLIENT_NAME="$1"
DAYS="${2:-30}"
DATE_EXPIRE=$(date -d "+${DAYS} days" +%Y-%m-%d)

echo "===== Création du client : $CLIENT_NAME (accès $DAYS jours, expire le $DATE_EXPIRE) ====="

# -----------------------------------------------------------
# 1. Vérifier que le serveur est configuré
# -----------------------------------------------------------
if [ ! -f /etc/wireguard/server_public.key ]; then
    echo "ERREUR : le serveur n'est pas configuré."
    echo "Exécutez d'abord : ./setup_wireguard.sh"
    exit 1
fi
if ! command -v qrencode &>/dev/null; then
    echo "Installation de qrencode pour le QR code..."
    apt-get install -y qrencode
fi

# -----------------------------------------------------------
# 2. Vérifier que le serveur WireGuard est actif
# -----------------------------------------------------------
if ! wg show wg0 &>/dev/null; then
    echo "ERREUR : WireGuard wg0 n'est pas actif."
    echo "Assurez-vous que setup_wireguard.sh a été exécuté avec succès."
    exit 1
fi

# -----------------------------------------------------------
# 3. Générer les clés du client
# -----------------------------------------------------------
echo "Génération des clés du client..."
CLIENT_PRIV=$(wg genkey)
CLIENT_PUB=$(echo "$CLIENT_PRIV" | wg pubkey)

# -----------------------------------------------------------
# 4. Attribuer la prochaine adresse IP disponible (10.8.0.x)
# -----------------------------------------------------------
NEXT_ID_FILE="/etc/wireguard/next_id"
if [ -f "$NEXT_ID_FILE" ]; then
    NEXT_ID=$(cat "$NEXT_ID_FILE")
else
    NEXT_ID=0
fi
NEXT_ID=$((NEXT_ID + 1))
echo "$NEXT_ID" > "$NEXT_ID_FILE"
CLIENT_IP="10.8.0.$((NEXT_ID + 1))"

# -----------------------------------------------------------
# 5. Détecter l'adresse IP publique du serveur
# -----------------------------------------------------------
SERVER_PUB=$(cat /etc/wireguard/server_public.key)
ENDPOINT=$(curl -s ifconfig.me || ip route get 1.1.1.1 | awk '{print $7; exit}')
if [ -z "$ENDPOINT" ]; then
    echo "ERREUR : impossible de détecter l'IP publique du serveur."
    exit 1
fi
echo "IP publique du serveur : $ENDPOINT"

# -----------------------------------------------------------
# 6. Créer la configuration du client
#    - MTU 1420 : cohérent avec le serveur, évite la fragmentation
#    - PersistentKeepalive 25 : maintient la connexion active en
#      permanence (essentiel contre les coupures au Burundi)
# -----------------------------------------------------------
CONF_FILE="/etc/wireguard/${CLIENT_NAME}.conf"
cat > "$CONF_FILE" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIV
Address = $CLIENT_IP/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1420

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $ENDPOINT:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

chmod 600 "$CONF_FILE"
echo "Configuration créée : $CONF_FILE"

# -----------------------------------------------------------
# 7. Enregistrer le client auprès du serveur
# -----------------------------------------------------------
wg set wg0 peer "$CLIENT_PUB" allowed-ips "$CLIENT_IP/32" persistent-keepalive 25
echo "Client enregistré sur le serveur (IP $CLIENT_IP)."

# Sauvegarde de la clé publique dans le fichier (pour gestion)
echo "$CLIENT_PUB" > "/etc/wireguard/${CLIENT_NAME}.pub"

# -----------------------------------------------------------
# 8. Générer le QR code
# -----------------------------------------------------------
echo "Génération du QR code..."
mkdir -p /root/qr
QR_PNG="/root/qr/${CLIENT_NAME}.png"
qrencode -t PNG -o "$QR_PNG" < "$CONF_FILE"
echo "QR code sauvegardé : $QR_PNG"

# -----------------------------------------------------------
# 9. Vérifier la connexion immédiatement après création
# -----------------------------------------------------------
echo "Test de connexion rapide..."
wg show wg0 | grep -q "$CLIENT_PUB" && echo "✅ Client visible sur le serveur" || echo "⚠️  Client non visible immédiatement (peut être normal)"

# -----------------------------------------------------------
# 10. Message final avec rappel paiement
# -----------------------------------------------------------
echo ""
echo "================ QR CODE DU CLIENT : $CLIENT_NAME ================"
qrencode -t ANSIUTF8 < "$CONF_FILE" || true
echo "=================================================================="
echo ""
echo "  ☑️  Le client scanne ce QR code avec l'application"
echo "     WireGuard officielle (Android/iOS/Windows/macOS/Linux)"
echo "  ☑️  Sa connexion est configurée instantanément,"
echo "     sans taper de mot de passe ni de paramètres."
echo ""
echo "  Fichier de config  : $CONF_FILE"
echo "  QR code imprimable : $QR_PNG"
echo "  Adresse client     : $CLIENT_IP"
echo "  Expire le          : $DATE_EXPIRE"
echo ""
echo "  💰 RAPPEL : encaissez le paiement AVANT de montrer le QR code !"
echo "  ⏰ L'accès expirera le $DATE_EXPIRE (dans $DAYS jours)"
echo ""
echo "  📊 Après connexion, utiliser './list_clients.sh' pour vérifier"
echo "     que le client est bien actif et consulte le trafic échangé."
echo ""
echo "  Pour révoquer l'accès avant expiration : ./revoke_client.sh $CLIENT_NAME"
echo ""
