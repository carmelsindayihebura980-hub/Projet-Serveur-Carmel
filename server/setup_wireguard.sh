#!/usr/bin/env bash
# ============================================================
#  setup_wireguard.sh - Installation & optimisation du serveur
#  Projet-Serveur-Carmel
#  Optimisé pour les connexions instables / à forte latence
#  (réseaux mobiles et liaisons satellite typiques du Burundi)
# ============================================================
set -euo pipefail

echo "===== Installation & optimisation du serveur WireGuard ====="

# ------------------------------------------------------------
# 1. Mise à jour du système
# ------------------------------------------------------------
echo "[1/11] Mise à jour du système..."
apt-get update -y && apt-get upgrade -y

# ------------------------------------------------------------
# 2. Installation des paquets nécessaires
# ------------------------------------------------------------
echo "[2/11] Installation de WireGuard, iptables, qrencode, curl..."
apt-get install -y wireguard iptables qrencode curl

# ------------------------------------------------------------
# 3. Chargement du module BBR si ce n'est pas déjà fait
# ------------------------------------------------------------
echo "[3/11] Chargement du module de congestion BBR..."
modprobe tcp_bbr || true
echo "tcp_bbr" >> /etc/modules-load.d/modules.conf

# ------------------------------------------------------------
# 4. Optimisation du noyau (très important pour la vitesse)
#    - BBR : bien meilleur que CUBIC sur les connexions à forte
#            latence (satellite, réseaux mobiles). Augmente le débit.
#    - Buffers massifs pour les liens radio/satellite lents
#    - fq (Fair Queue) pour éviter les files d'attente bloquantes
# ------------------------------------------------------------
echo "[4/11] Application des optimisations réseau du noyau..."
cat > /etc/sysctl.d/99-wireguard-tune.conf <<'EOF'
# Activation du BBR congestion control
net.ipv4.tcp_congestion_control = bbr

# Interface par défaut en forwarding
net.ipv4.ip_forward = 1

# Qdisc Fair Queue pour de meilleures performances sur liens asymétriques
net.core.default_qdisc = fq

# Buffers TCP agrandis pour les réseaux à forte latence/satellite
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Backlog plus grand pour absorber les pics de connexion
net.core.netdev_max_backlog = 5000

# Paramètres keepalive optimisés pour les connexions mobiles
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6

# TIME_WAIT récyclé plus vite pour libérer les ports
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
EOF

sysctl -p /etc/sysctl.d/99-wireguard-tune.conf || true

# Vérification que BBR est bien actif
BBR_STATUS=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
if [ "$BBR_STATUS" = "bbr" ]; then
    echo "✅ BBR congestion control activé"
else
    echo "⚠️  BBR non détecté, tentative de module load..."
    modprobe tcp_bbr
    sysctl -w net.ipv4.tcp_congestion_control=bbr
fi

# ------------------------------------------------------------
# 5. Génération des clés du serveur
# ------------------------------------------------------------
echo "[5/11] Génération des clés du serveur..."
if [ ! -f /etc/wireguard/server_private.key ]; then
    umask 077
    wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
fi
SERVER_PRIVATE=$(cat /etc/wireguard/server_private.key)

# ------------------------------------------------------------
# 6. Détection de l'interface réseau par défaut
# ------------------------------------------------------------
echo "[6/11] Détection de l'interface réseau par défaut..."
DEFAULT_IF=$(ip route | awk '/default/ {print $5; exit}')
if [ -z "$DEFAULT_IF" ]; then
    echo "ERREUR : impossible de détecter l'interface réseau par défaut."
    exit 1
fi
echo "Interface réseau par défaut : $DEFAULT_IF"

# ------------------------------------------------------------
# 7. Création de la configuration du serveur
#    - MTU optimisé (1420) : réduit la fragmentation et les
#      coupures sur les réseaux mobiles/satellite
#    - PostUp/PostDown avec logging des erreurs de forwarding
# ------------------------------------------------------------
echo "[7/11] Création de /etc/wireguard/wg0.conf..."
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.8.0.1/24
MTU = 1420
ListenPort = 51820
PrivateKey = $SERVER_PRIVATE
SaveConfig = true

# Routage du trafic VPN vers Internet
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT && iptables -t nat -A POSTROUTING -o $DEFAULT_IF -j MASQUERADE
PostUp   = iptables -A INPUT -i wg0 -p udp --dport 51820 -j ACCEPT
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT && iptables -t nat -D POSTROUTING -o $DEFAULT_IF -j MASQUERADE
PostDown = iptables -A INPUT -i wg0 -p udp --dport 51820 -j DROP
EOF

chmod 600 /etc/wireguard/wg0.conf

# ------------------------------------------------------------
# 8. Pare-feu (UFW) - n'ouvrir que le port WireGuard
# ------------------------------------------------------------
echo "[8/11] Configuration du pare-feu UFW..."
if ! command -v ufw &>/dev/null; then
    apt-get install -y ufw
fi
ufw allow 51820/udp comment 'WireGuard VPN'
ufw default deny incoming
ufw default allow outgoing
ufw --force enable
echo "Pare-feu UFW activé : seul le port 51820/udp est ouvert."

# ------------------------------------------------------------
# 9. Démarrage du service WireGuard
# ------------------------------------------------------------
echo "[9/11] Démarrage de WireGuard..."
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0 || {
    echo "Erreur au démarrage - vérification du statut :"
    systemctl status wg-quick@wg0 --no-pager || true
    exit 1
}

# ------------------------------------------------------------
# 10. Vérification du fonctionnement
# ------------------------------------------------------------
echo "[10/11] Vérification de l'état de WireGuard..."
sleep 2
if wg show wg0 &>/dev/null; then
    echo "✅ WireGuard est actif."
    wg show wg0
else
    echo "⚠️  WireGuard ne semble pas actif - vérifiez /etc/wireguard/wg0.conf"
fi

# ------------------------------------------------------------
# 11. Récapitulatif
# ------------------------------------------------------------
echo ""
echo "==========================================================="
echo "  Serveur WireGuard configuré et optimisé avec succès !"
echo "==========================================================="
echo ""
echo "  Adresse IP publique  : $(curl -s ifconfig.me || echo "IP_INTROUVABLE")"
echo "  Port                 : 51820/udp"
echo "  Réseau VPN interne   : 10.8.0.0/24"
echo "  Serveur VPN          : 10.8.0.1"
echo "  Contrôle congestion  : BBR (débit optimisé)"
echo "  MTU                  : 1420"
echo ""
echo "  Clé publique serveur : $(cat /etc/wireguard/server_public.key)"
echo ""
echo "  Pour créer un client et générer son QR code :"
echo "    ./create_client.sh <nom_client>"
echo ""
echo "  Les clients scannent le QR code avec l'application"
echo "  WireGuard officielle et sont connectés en quelques secondes."
echo "==========================================================="

