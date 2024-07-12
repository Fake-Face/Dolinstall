#!/bin/bash

# Fonction pour vérifier le système d'exploitation
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "Impossible de détecter le système d'exploitation."
        exit 1
    fi

    if [ "$OS" != "ubuntu" ] && [ "$OS" != "debian" ]; then
        echo "Ce script ne prend en charge que Ubuntu et Debian."
        exit 1
    fi
}

# Vérification du système d'exploitation
check_os

# Vérifier si le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
  echo "Veuillez exécuter ce script en tant que root."
  exit 1
fi

# Fonction pour demander à l'utilisateur s'il souhaite continuer
ask_continue() {
    while true; do
        read -p "Souhaitez-vous continuer l'installation de Dolibarr? (Y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo "Installation annulée."; exit;;
            * ) echo "Veuillez répondre par Y ou N.";;
        esac
    done
}

# Fonction pour générer un mot de passe sécurisé
generate_password() {
    USER=$(whoami)
    NUMBER=$(shuf -i 100-999 -n 1)
    SPECIAL_CHAR=$(echo '!@#$%&*()_+=' | fold -w1 | shuf | head -n1)
    PASSWORD="${USER}:${NUMBER}${SPECIAL_CHAR}"
    echo "$PASSWORD"
}

# Fonction pour choisir le répertoire utilisateur
choose_user_directory() {
    if [ -d /home ]; then
        USERS=($(ls /home))
        if [ ${#USERS[@]} -eq 1 ]; then
            USER_CHOICE=${USERS[0]}
        else
            echo "Veuillez choisir un utilisateur dans la liste suivante :"
            select USER_CHOICE in "${USERS[@]}"; do
                if [ -n "$USER_CHOICE" ]; then
                    break
                else
                    echo "Choix invalide. Veuillez réessayer."
                fi
            done
        fi
        echo "Utilisateur sélectionné : $USER_CHOICE"

        DOCUMENTS_PATH="/home/$USER_CHOICE/Documents"
        if [ ! -d "$DOCUMENTS_PATH" ]; then
            echo "Le répertoire Documents n'existe pas pour l'utilisateur $USER_CHOICE, création en cours..."
            mkdir -p "$DOCUMENTS_PATH"
        fi
        echo "Répertoire Documents sélectionné : $DOCUMENTS_PATH"
    else
        echo "Le répertoire /home n'existe pas."
        exit 1
    fi
}

# Demande à l'utilisateur de continuer ou non
ask_continue

# Demander à l'utilisateur de saisir le nom d'utilisateur et le mot de passe pour Dolibarr
read -p "Entrez le nom d'utilisateur pour Dolibarr (ce sera le compte admin) : " DOLIBARR_USER
read -sp "Entrez le mot de passe pour l'utilisateur Dolibarr : " DOLIBARR_PASSWORD
echo

# Installation de MariaDB et expect
echo "Configuration de MariaDB en cours..."

# Mise à jour des paquets
apt update

# Installation des dépendances nécessaires
apt install -y mariadb-server expect

# Génération d'un mot de passe sécurisé pour l'utilisateur root
ROOT_PASSWORD=$(generate_password)

# Choisir le répertoire utilisateur
choose_user_directory

PASSWORD_FILE="$DOCUMENTS_PATH/root_mariadb_password.txt"

# Créer le fichier et définir les permissions
touch "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

# Sauvegarde du mot de passe sur le répertoire Documents
echo "Le mot de passe root de MariaDB est : $ROOT_PASSWORD" > "$PASSWORD_FILE"

# Configuration sécurisée de MariaDB
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation

expect \"Enter current password for root (enter for none):\"
send \"\r\"

expect \"Change the root password?\"
send \"Y\r\"

expect \"New password:\"
send \"$ROOT_PASSWORD\r\"

expect \"Re-enter new password:\"
send \"$ROOT_PASSWORD\r\"

expect \"Remove anonymous users?\"
send \"Y\r\"

expect \"Disallow root login remotely?\"
send \"Y\r\"

expect \"Remove test database and access to it?\"
send \"Y\r\"

expect \"Reload privilege tables now?\"
send \"Y\r\"

expect eof
")

echo "$SECURE_MYSQL"

# Affichage du message de fin avec les détails
echo "Mot de passe root de MariaDB changé."
echo "Le nouveau mot de passe est sauvegardé dans le fichier : $PASSWORD_FILE"

# Création de la base de données et de l'utilisateur Dolibarr
mysql -u root -p"$ROOT_PASSWORD" <<EOF
CREATE DATABASE dolibarr CHARACTER SET utf8 COLLATE utf8_unicode_ci;
CREATE USER '$DOLIBARR_USER'@'localhost' IDENTIFIED BY '$DOLIBARR_PASSWORD';
GRANT ALL PRIVILEGES ON dolibarr.* TO '$DOLIBARR_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "Configuration de MariaDB terminée."

# Installation de Dolibarr avec NGINX
echo "Installation de Dolibarr et configuration de NGINX en cours..."

# Installation des dépendances nécessaires pour NGINX et PHP
apt install -y nginx php-fpm php-curl php-intl php-mbstring php-gd php-zip php-xml php-mysql php-soap php-imap

# Se placer dans le répertoire /var/www
cd /var/www

# Téléchargement de Dolibarr
wget https://sourceforge.net/projects/dolibarr/files/Dolibarr%20ERP-CRM/19.0.2/dolibarr-19.0.2.tgz

# Extraction de Dolibarr
tar xvf dolibarr-19.0.2.tgz

# Changement des permissions et du propriétaire
chown www-data:www-data -R dolibarr-19.0.2
chmod 755 -R dolibarr-19.0.2

# Sauvegarder l'ancien fichier de configuration NGINX par défaut
mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.old

# Créer un nouveau fichier de configuration NGINX par défaut pour Dolibarr
cat << EOF | tee /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/dolibarr-19.0.2/htdocs;
    index index.php index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }
}
EOF

# Test de la configuration NGINX
sudo nginx -t
sudo nginx -v

# Redémarrage de NGINX
systemctl restart nginx

# Suppression de l'archive Dolibarr
rm /var/www/dolibarr-19.0.2.tgz

# Message de fin
echo "Installation de Dolibarr terminée."
echo "Vous pouvez maintenant accéder à Dolibarr via http://localhost/, si cela ne marche pas, essayez http://localhost/install"

echo "! WARNING !"

# Affichage des détails de connexion Dolibarr
echo "- Le nom d'utilisateur pour Dolibarr est : $DOLIBARR_USER"
echo "- Le mot de passe pour Dolibarr est : $DOLIBARR_PASSWORD"

# Affichage des détails de connexion MariaDB
echo "- Le mot de passe root de MariaDB est sauvegardé dans le fichier : $PASSWORD_FILE"