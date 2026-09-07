#!/usr/bin/env bash
# ============================================================
#  list_clients.sh - Lister les clients connectés
#  Projet-Serveur-Carmel
#
#  Affiche : qui est connecté, depuis quand, et le trafic
#  échangé (utile pour justifier la qualité du service).
# ============================================================
set -euo pipefail

echo "===== Clients WireGuard - état du serveur ====="
echo ""

# Informations générales du tunnel
HANDSHAKE=$(wg show wg0 latest-handshakes 2>/dev/null | head -1) || true
echo "--- Résumé de l'interface wg0 ---"
wg show wg0 2>/dev/null | grep -E "interface|public key|listening port" || echo "wg0 non actif"

echo ""
echo "--- Clients enregistrés ---"
echo "Public key | IP autorisée | Dernier handshake | Trafic reçu/envoyé"
echo "------------------------------------------------------------------"

FOUND=0
for PUB in /etc/wireguard/*.pub; do
    [ -e "$PUB" ] || continue
    NAME=$(basename "$PUB" .pub)
    KEY=$(cat "$PUB")
    FOUND=1

    # Cherche le peer dans la sortie de wg show
    PEER_INFO=$(wg show wg0 dump 2>/dev/null | grep "$KEY" || true)
    if [ -z "$PEER_INFO" ]; then
        echo "  $NAME : non enregistré sur le serveur"
        continue
    fi

    # Format: iface pubkey preshared endpoint allowed-ips latest-handshake rx tx
    ALLOWED=$(echo "$PEER_INFO" | awk '{print $4}')
    LS_HAND=$(echo "$PEER_INFO" | awk '{print $5}')
    RX=$(echo "$PEER_INFO" | awk '{print $6}')
    TX=$(echo "$PEER_INFO" | awk '{print $7}')

    if [ "$LS_HAND" = "0" ]; then
        ETAT="jamais connecté"
    else
        NOW=$(date +%s)
        DIFF=$(( NOW - LS_HAND ))
        if [ "$DIFF" -lt 300 ]; then
            ETAT="connecté (il y a ${DIFF}s)"
        else
            ETAT="dernier contact il y a $(( DIFF / 60 )) min"
        fi
    fi

    # Formats lisible du trafic
    RX_H=$(numfmt --to=iec "$RX" 2>/dev/null || echo "$RX octets")
    TX_H=$(numfmt --to=iec "$TX" 2>/dev/null || echo "$TX octets")

    echo "  $NAME"
    echo "    $ALLOWED  $ETAT"
    echo "    Reçu: $RX_H | Émis: $TX_H"
    echo ""
done

if [ "$FOUND" -eq 0 ]; then
    echo "  (Aucun client créé pour le moment)"
fi

echo ""
echo "Pour créer un client :    ./create_client.sh <nom>"
echo "Pour couper un accès :    ./revoke_client.sh <nom>"
echo "==================================================="