#!/bin/bash
PATH='/bin:/usr/bin'

# Script d'installation d'icinga 2. Cela inclus également l'ajout des dépôts nécessaires 

echo """
/!\ WARNING: the installation is a test, for personal use, and doesn't implement all security configurations. It may also not fit your system/infrastructure. /!\ 
Must be used by root, and disitribution must be Debian 12 Bookworm.
"""

# Vérifier que le script est bien exécuté en mode root
if [ "$(id -u)" != "0" ]; then
   echo "Ce script doit être exécuté en tant que root" 1>&2
   exit 1
fi

# Vérifier que la distribution est bien Debian 12 Bookworm
if [ ! -f /etc/debian_version ] || ! grep -q '^12' /etc/debian_version; then
   echo "Ce script est conçu pour Debian 12 Bookworm" 1>&2
   exit 1
fi

while true
do
    echo "Proceed to installation? (Y/n)"
    read -r response1
    
    case ${response1:0:1} in
        y|Y)
            echo "Proceeding with installation..."
            break
            ;;
        n|N)
            echo "Installation cancelled."
            exit 0
            ;;
        *)
            echo "Invalid input. Please enter Y or N."
            ;;
    esac
done

echo "Adding Icinga repository..."

nom_fichier_gpg="icinga-archive-keyring"
apt update
apt -y install apt-transport-https wget gnupg
wget -O - https://packages.icinga.com/icinga.key | gpg --dearmor -o /usr/share/keyrings/${nom_fichier_gpg}.gpg
DIST=$(awk -F"[)(]+" '/VERSION=/ {print $2}' /etc/os-release); \
echo "deb [signed-by=/usr/share/keyrings/${nom_fichier_gpg}.gpg] https://packages.icinga.com/debian icinga-${DIST} main" > \
/etc/apt/sources.list.d/${DIST}-icinga.list
echo "deb-src [signed-by=/usr/share/keyrings/${nom_fichier_gpg}.gpg] https://packages.icinga.com/debian icinga-${DIST} main" >> \
/etc/apt/sources.list.d/${DIST}-icinga.list
apt update

fichier_gpg_2="icinga"

install -d -o root -g root -m 0755 /etc/apt/keyrings

echo "Adding Icingaweb repository..."
wget -O - https://packages.icinga.com/icinga.key | gpg --dearmor -o /etc/apt/keyrings/${fichier_gpg_2}.gpg
DIST=$(awk -F"[)(]+" '/VERSION=/ {print $2}' /etc/os-release); \
 echo "deb [signed-by=/etc/apt/keyrings/${fichier_gpg_2}.gpg] https://packages.icinga.com/debian icinga-${DIST} main" > \
 /etc/apt/sources.list.d/${DIST}-icinga.list
 echo "deb-src [signed-by=/etc/apt/keyrings/${fichier_gpg_2}.gpg] https://packages.icinga.com/debian icinga-${DIST} main" >> \
 /etc/apt/sources.list.d/${DIST}-icinga.list

apt update

# Installation de tous les paquets nécessaires pour la suite
apt install -y icinga2 monitoring-plugins icingadb icingadb-redis apache2 mariadb-server php php-cli libapache2-mod-php php-{curl,gd,intl,memcache,xml,zip,mbstring,json,mysql} icingadb-web icingaweb2 icingacli

# Installation de l'API
icinga2 api setup
systemctl restart icinga2

# SETUP ICINGADB

#Setup Redis Server
systemctl enable --now icingadb-redis.service
systemctl restart icingadb-redis

# Modifications nécessaires dans le fichier de configuration
# Définir la ligne à modifier /!\ VERIFIER LE NUMERO DE LIGNE, EN CAS DE MàJ de ICINGADB-REDIS DEPUIS LA CONFECTION DU SCRIPT /!\
line_to_modify="111"
line_to_modify2="87"

# Définir le nouveau contenu de la ligne
new_content="protected-mode no"
new_content2="bind 0.0.0.0"

# Modifier la ligne spécifiée dans le fichier
sed -i "${line_to_modify}s/.*/$new_content/" /etc/icingadb-redis/icingadb-redis.conf
sed -i "${line_to_modify2}s/.*/$new_content2/" /etc/icingadb-redis/icingadb-redis.conf

systemctl restart icingadb-redis

# Activer le service icingadb et redémarrer icinga2
icinga2 feature enable icingadb
systemctl restart icinga2

systemctl enable apache2

# SETUP WEB SERVER

# Remplacement de la page par défaut par "site en maintenance"

echo """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Site Under Maintenance</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            margin-top: 50px;
        }
        h1 {
            color: #333;
        }
        p {
            color: #666;
        }
    </style>
</head>
<body>
    <h1>Site Under Maintenance</h1>
    <p>We apologize for the inconvenience, but our site is currently undergoing maintenance.</p>
    <p>Please check back later.</p>
</body>
</html>
""" > /var/www/html/index.html

systemctl reload apache2

# Installer les bases de données (mariadb)

mysql_secure_installation

echo " "
echo "The 'icingadb' database needs a new user and a password."

# icingadb username & password: 
validate_1=0

while [[ $validate_1 -eq 0 ]]
do
    printf "Please choose a username: (To avoid issues, avoid these characters: [\", ', \\])\n"
    read -r icingadb_username
    echo "Username = ${icingadb_username}. Are you OK with it? (Y/N)"
    read -r yes_no_1
    if [[ "$yes_no_1" == "Y" || "$yes_no_1" == "y" ]]
    then
        validate_1=1
    fi
done

escaped_icingadb_username=$(printf '%q' "$icingadb_username")

while true; do
    printf "Please choose a password: (To avoid issues, avoid these characters: [\", ', \\])\n"
    read -rs icingadb_pswd
    echo "Please type your password again: "
    read -rs icingadb_pswd_2

    if [[ "$icingadb_pswd" == "$icingadb_pswd_2" ]]; then
        echo "Passwords match."
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done

escaped_icingadb_pswd=$(printf '%q' "$icingadb_pswd")

# icingaweb2 username & password:

echo " "
echo "The 'icingaweb2' database also needs a new user and a password."

validate_2=0

while [[ $validate_2 -eq 0 ]]
do
    printf "Please choose a username: (To avoid issues, avoid these characters: [\", ', \\])\n"
    read -r icingaweb2_username
    echo "Username = ${icingaweb2_username}. Are you OK with it? (Y/N)"
    read -r yes_no_2
    if [[ "$yes_no_2" == "Y" || "$yes_no_2" == "y" ]]
    then
        validate_2=1
    fi
done

escaped_icingaweb2_username=$(printf '%q' "$icingaweb2_username")

while true; do
    printf "Please choose a password: (To avoid issues, avoid these characters: [\", ', \\])\n"
    read -rs icingaweb2_pswd
    echo "Please type your password again: "
    read -rs icingaweb2_pswd_2

    if [[ "$icingaweb2_pswd" == "$icingaweb2_pswd_2" ]]; then
        echo "Passwords match."
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done

escaped_icingaweb2_pswd=$(printf '%q' "$icingaweb2_pswd")

echo " "
echo "For security purposes, an admin user will be created to replace 'root' in mariadb (if you deactivate the possiblity of logging with root, that is strongly recommanded)"

validate_3=0

while [[ $validate_3 -eq 0 ]]
do
    echo " "
    printf "Please choose an admin username: (To avoid issues, avoid these characters: [\", ', \\])\n"
    read -r admin_username
    echo "Admin = ${admin_username}. Are you OK with it? (Y/N)"
    read -r yes_no_3
    if [[ "$yes_no_3" == "Y" || "$yes_no_3" == "y" ]]
    then
        validate_3=1
    fi
done

escaped_admin_username=$(printf '%q' "$admin_username")

while true; do
    printf "Please choose a password: (To avoid issues, avoid these characters: [\", ', \\])\n"
    read -rs admin_pswd
    echo "Please type your password again: "
    read -rs admin_pswd_2

    if [[ "$admin_pswd" == "$admin_pswd_2" ]]; then
        echo "Passwords match."
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done

escaped_admin_pswd=$(printf '%q' "$admin_pswd")

# Création d'un compte admin pour la database (utile si on désactive la possibilité d'utiliser root en remote)
echo "CREATE USER '${escaped_admin_username}'@'localhost' IDENTIFIED BY '${escaped_admin_pswd}'; GRANT ALL PRIVILEGES ON *.* TO '${escaped_admin_username}'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;" | mysql -u root -p
systemctl enable mariadb

# Création d'une db "icingadb" et d'un compte admin "icingadb"
echo "CREATE DATABASE icingadb; CREATE USER '${escaped_icingadb_username}'@'localhost' IDENTIFIED BY '${escaped_icingadb_pswd}'; GRANT ALL ON icingadb.* TO '${escaped_icingadb_username}'@'localhost';" | mysql -u root -p

# Importation du schéma dans la base de données icingadb
if mysql -u root -p icingadb < /usr/share/icingadb/schema/mysql/schema.sql; then
    echo "Le schéma a été importé avec succès dans la base de données icingadb."
else
    echo "Erreur lors de l'importation du schéma dans la base de données icingadb."
    exit 1
fi

# /!\ Configuration personnalisée de Redis non implémentée (/etc/icingadb/config.yml) !!!

systemctl enable --now icingadb

# Installer icinga web 2
echo "Configuration d'icinga web 2..."
icingacli setup config webserver apache --document-root /usr/share/icingaweb2/public

echo "Création du token..."
icingacli setup token create

echo "To check your token, use the following command:"
echo "icingacli setup token show"

echo "CREATE DATABASE icingaweb2; CREATE USER '${escaped_icingaweb2_username}'@'localhost' IDENTIFIED BY '${escaped_icingaweb2_pswd}'; GRANT ALL ON icingaweb2.* TO '${escaped_icingaweb2_username}'@'localhost';" | mysql -u root -p

# Modifications du username et password dans /etc/icingadb/config.yml

# Lignes à modifier
line_to_modify3="21"
line_to_modify4="24"

# Définir le nouveau contenu de la ligne
new_content3="  user: ${icingadb_username}"
new_content4="  password: ${icingadb_pswd}"

# Modifier la ligne spécifiée dans le fichier
sed -i "${line_to_modify3}s/.*/$new_content3/" /etc/icingadb/config.yml
sed -i "${line_to_modify4}s/.*/$new_content4/" /etc/icingadb/config.yml

systemctl restart icingadb.service

echo """
Installation finished. To finish configuring your icingaweb server, please continue in a browser.
(Visit '<this hostname/IP address>/icingaweb2/setup')"""

echo """ Guide to icingaweb2 setup

1st database to provide = icingaweb2

2nd database to provide = icingadb

For the redis-server name, you can just provide the IP address of the server.

Iicinga2 API username and password can be found in /etc/icinga2/conf.d/api-users.conf

If you want to use the PDF export Module, you'll need to install the PHP module Imagick on this server. 
""" > setup_help.txt
