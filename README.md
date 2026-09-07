# Projet-Serveur-Carmel

## 🚀 Serveur VPN optimisé pour le Burundi

Ce projet fournit un service VPN **WireGuard** hautement optimisé pour les connexions instables, à forte latence, et les coupures fréquentes — typiques des réseaux mobiles et satellite au Burundi.

### 🇧🇮 Notre mission

Fournir une connexion **stable, rapide et sans coupure** aux utilisateurs du Burundi, même dans les zones où la connexion est mauvaise. Notre serveur utilise des technologies de pointe (BBR, MTU optimisé, keepalive agressif) pour surmonter les limitations des réseaux locaux.

---

## 📦 Contenu du projet

- **Serveur VPN** (`/server`) : Scripts d'installation, de gestion et de surveillance du serveur WireGuard.
- **Site web** (`/website`) : Pages de présentation, de souscription et de paiement (Netlify-ready).

---

## ⚡ Optimisations techniques (pour une connexion maximale)

| Optimisation | Valeur | Avantage |
|-------------|--------|----------|
| Contrôle de congestion | **BBR** | 2 à 10× plus rapide que CUBIC sur réseaux lents |
| MTU | **1420** | Évite la fragmentation sur réseaux mobiles/satellite |
| PersistentKeepalive | **25 secondes** | Maintient la connexion active en permanence |
| Buffers TCP | **67 MB** | Absorbe les pertes de paquets et la latence |
| Qdisc | **fq** | Évite les files d'attente bloquantes |
| IP Forwarding | Activé | Routage du trafic VPN vers Internet |

---

## 📁 Structure

```
/server
  setup_wireguard.sh      - Installation & optimisation du serveur
  create_client.sh        - Création d'un client + génération QR code
  revoke_client.sh        - Révocation d'un client
  list_clients.sh         - Lister les clients connectés
  health_check.sh         - Surveillance automatique (crontab)
/website
  index.html              - Page d'accueil (hero, forfaits, FAQ)
  billing.html            - Page de paiement (cash, Mobile Money, Stripe)
```

---

## 🚀 Mise en place

### 1. Créer le VPS (DigitalOcean, Hetzner, etc.)

Se connecter en SSH :
```bash
ssh root@<IP_PUBLIC_VPS>
```

### 2. Copier les scripts sur le VPS

```bash
scp -r server root@<IP_PUBLIC_VPS>:/home/root/
```

### 3. Exécuter le script d'installation

```bash
cd /home/root/server
chmod +x setup_wireguard.sh
sudo ./setup_wireguard.sh
```

### 4. Créer un client (génère un QR code)

```bash
./create_client.sh <nom_client> [jours]
# Exemple : ./create_client.sh alice 30
```

### 5. Scanner le QR code

Le client scanne le QR code avec l'application **WireGuard officielle** (Android/iOS/Windows/macOS/Linux) et se connecte instantanément.

### 6. Surveillance (optionnel)

```bash
# Exécuter régulièrement (ex: crontab)
./health_check.sh
```

---

## 🌐 Déployer le site web

- Initialiser un dépôt Git dans le répertoire racine.
- Commiter tous les fichiers et pousser sur GitHub.
- Dans **Netlify**, créer un nouveau site depuis Git, sélectionner le repository, laisser le build command vide et définir le répertoire de publication comme `/`.
- Netlify déploie automatiquement et fournit une URL publique (ex. `https://vpn-carmel.netlify.app`).

---

## 💰 Paiement (cash au Burundi)

1. Le client paie en cash (à Bujumbura) ou par Mobile Money.
2. Vous exécutez `./create_client.sh <nom> [jours]`.
3. Vous montrez le QR code au client.
4. Le client scanne le QR code et est connecté.

---

## 📊 Surveillance

- `./list_clients.sh` : voir les clients connectés et le trafic échangé.
- `./health_check.sh` : vérifier la santé du serveur (WireGuard, connectivité, load).

---

## 📞 Support

WhatsApp : +257 XX XX XX XX  
Email : contact@carmel-vpn.bi  
Site : https://vpn-carmel.netlify.app

---

## Licence

MIT – utilisation libre.
