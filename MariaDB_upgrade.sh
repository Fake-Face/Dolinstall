
# Télécharger et ajouter la clé GPG de MariaDB
sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'

# Créer un répertoire pour les clés et ajouter la clé
sudo mkdir -p /etc/apt/keyrings
wget -O- https://mariadb.org/mariadb_release_signing_key.asc | sudo gpg --dearmor -o /etc/apt/keyrings/mariadb.gpg

# Vérifier et ajouter le dépôt MariaDB pour Debian 12 (Bookworm)
echo 'deb [arch=amd64,arm64,ppc64el signed-by=/etc/apt/keyrings/mariadb.gpg] http://mirrors.xtom.de/mariadb/repo/11.4.2/debian bookworm main' | sudo tee /etc/apt/sources.list.d/mariadb.list

# Mettre à jour la liste des paquets
sudo apt update

# Installer MariaDB 
sudo apt install mariadb-server mariadb-client

# Mettre à jour la base de données :
sudo mysql_upgrade -u root -p

# Redémarrer MariaDB
sudo systemctl start mariadb

# Vérifier la version de MariaDB
mysql -V

# Vérifier les bases de données
mysql -u root -p
SHOW DATABASES;

# Nettoyer les paquets inutilisés
sudo apt autoremove
