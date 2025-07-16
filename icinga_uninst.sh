#!/bin/bash

# Arrêter les services Icinga
systemctl stop icinga2
systemctl stop icingadb-redis
systemctl stop icingadb
systemctl stop apache2
systemctl stop mariadb

# Supprimer les packages Icinga et leurs dépendances
apt purge -y icinga2 monitoring-plugins icingadb icingadb-web icingadb-redis icingaweb2 icingacli apache2 mariadb-server php php-cli libapache2-mod-php php-{curl,gd,intl,memcache,xml,zip,mbstring,json,mysql}

# Supprimer le dépôt Icinga
rm -f /etc/apt/sources.list.d/*icinga*.list
rm -f /usr/share/keyrings/icinga-archive-keyring.gpg

# Mettre à jour la liste des paquets
apt update

# Supprimer les fichiers de configuration et les données
rm -rf /etc/icinga2 /etc/icingadb /etc/icingaweb2 /usr/share/icinga2 /usr/share/icingadb /usr/share/icingaweb2 /var/lib/icinga2 /var/lib/icingadb /var/lib/mysql /var/www/html/index.html

# Réinitialiser la configuration de MariaDB
apt purge -y mariadb-server
apt autoremove --purge -y

# Supprimer les utilisateurs et groupes créés par Icinga
deluser --remove-home nagios
deluser --remove-home icinga
delgroup nagios
delgroup icinga

# Nettoyer les fichiers de logs
rm -rf /var/log/icinga2
rm -rf /var/log/icingaweb2

# Supprimer les tâches cron potentiellement ajoutées
rm -f /etc/cron.d/icinga2

# Nettoyer les fichiers temporaires
rm -rf /tmp/icinga*

# Supprimer les sauvegardes potentielles
rm -rf /var/backups/icinga*

echo "Icinga successfully uninstalled and purged."

