#!/usr/bin/env bash
# ============================================================
#  health_check.sh - Surveillance du serveur et des connexions
#  Projet-Serveur-Carmel
#  À exécuter périodiquement (crontab) pour surveillance
# ============================================================
set -euo pipefail

LOG_FILE="/var/log/wireguard-health.log"
ALERT_EMAIL="${ALERT_EMAIL:-}"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Vérifier si WireGuard est actif
if ! wg show wg0 &>/dev/null; then
    log_msg "⚠️  ERREUR: WireGuard wg0 n'est pas actif!"
    log_msg "Tentative de redémarrage..."
    systemctl restart wg-quick@wg0
    sleep 5
    if wg show wg0 &>/dev/null; then
        log_msg "✅ WireGuard redémarré avec succès"
    else
        log_msg "❌ Échec du redémarrage de WireGuard"
    fi
    exit 1
fi

# Vérifier le nombre de clients connectés
CLIENT_COUNT=$(wg show wg0 peers 2>/dev/null | wc -l)
log_msg "📊 WireGuard actif - $CLIENT_COUNT clients enregistrés"

# Vérifier la bande passante totale
TOTAL_RX=0
TOTAL_TX=0
for peer in $(wg show wg0 dump | awk 'NR>1 {print $2}'); do
    PEER_STATS=$(wg show wg0 dump | grep "$peer")
    RX=$(echo "$PEER_STATS" | awk '{print $6}')
    TX=$(echo "$PEER_STATS" | awk '{print $7}')
    TOTAL_RX=$((TOTAL_RX + RX))
    TOTAL_TX=$((TX + TX))
done

log_msg "📈 Trafic total - RX: $TOTAL_RX octets, TX: $TOTAL_TX octets"

# Vérifier les handshakes récents (clients actifs)
RECENT_HANDSHAKE=0
NOW=$(date +%s)
for PEER in $(wg show wg0 latest-handshakes | awk '{print $2}'); do
    HS_TIME=$(wg show wg0 latest-handshakes | grep "$PEER" | awk '{print $3}')
    if [ "$HS_TIME" != "0" ] && [ $((NOW - HS_TIME)) -lt 180 ]; then
        RECENT_HANDSHAKE=$((RECENT_HANDSHAKE + 1))
    fi
done

log_msg "🔗 Clients actifs récemment: $RECENT_HANDSHAKE"

# Vérifier la connectivité Internet du serveur
if ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
    log_msg "🌐 Connectivité Internet: OK"
else
    log_msg "⚠️  ATTENTION: Perte de connectivité Internet!"
fi

# Vérifier le load average
LOAD=$(uptime | awk -F'load average:' '{print $2}')
log_msg "💻 Load average: $LOAD"

# Statistiques de mémoire
MEM_INFO=$(free -h | grep Mem)
log_msg "🧠 Mémoire: $MEM_INFO"

echo ""
log_msg "=== Fin de la vérification de santé ==="
echo ""
