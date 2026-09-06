# Projet-Serveur-Carmel

Ce projet contient :

- **Serveur VPN** (WireGuard) : un service de connexion sécurisée pour que les clients puissent accéder à votre réseau et scanner leurs cibles.
- **Site web** (Netlify) : présentation du service, téléchargement de la configuration client, et gestion de la facturation (abonnement mensuel).

## Structure

```
/server      - Scripts d'installation et de gestion du serveur VPN
/website     - Fichiers statiques du site web (HTML, CSS, JS)
```

## Prérequis

- Un VPS (Ubuntu 22.04 LTS recommandé) avec accès SSH.
- Un compte Netlify (déjà créé).
- Un compte Stripe (optionnel) pour les paiements.

## Mise en place

1. **Créer le VPS** (exemple DigitalOcean) et se connecter en SSH.  
   ```bash
   ssh root@<IP_PUBLIC_VPS>
   ```
2. **Copier les scripts** du répertoire `server` sur le VPS (ex. avec `scp -r server root@<IP_PUBLIC_VPS>:/home/root/`).
3. **Exécuter le script d'installation** :  
   ```bash
   cd /home/root/server
   chmod +x setup_wireguard.sh
   sudo ./setup_wireguard.sh
   ```
4. **Vérifier le VPN** : installer le client WireGuard, importer le fichier de configuration généré par `create_client.sh`, se connecter et tester la connexion Internet.
5. **Déployer le site sur Netlify** :  
   - Initialiser un dépôt Git dans le répertoire racine du projet.  
   - Committer tous les fichiers et pousser sur GitHub.  
   - Dans Netlify, créer un nouveau site depuis Git, sélectionner le repository, laisser le build command vide et définir le répertoire de publication comme `/`.  
   - Netlify déploie automatiquement et fournit une URL publique (ex. `https://vpn-scan-service.netlify.app`).
6. **Configurer le paiement** (optionnel) :  
   - Créez un produit Stripe “VPN Scan – Basic” à 5 USD / mois.  
   - Générer un lien Checkout et le remplacer dans `website/billing.html`.  
   - (Facultatif) Mettre en place un webhook Stripe pour envoyer le fichier de configuration par e‑mail après paiement.

## Licence

MIT – utilisation libre.