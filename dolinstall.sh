#!/bin/bash

echo "██████╗  ██████╗ ██╗     ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗"
echo "██╔══██╗██╔═══██╗██║     ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║"
echo "██║  ██║██║   ██║██║     ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║"
echo "██║  ██║██║   ██║██║     ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║"
echo "██████╔╝╚██████╔╝███████╗██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗"
echo "╚═════╝  ╚═════╝ ╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝"

#!/bin/bash

# Function to check the operating system
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "Unable to detect the operating system."
        exit 1
    fi

    if [ "$OS" != "ubuntu" ] && [ "$OS" != "debian" ]; then
        echo "This script only supports Ubuntu and Debian."
        exit 1
    fi
}

# Function to check if the script is run as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run this script as root."
        exit 1
    fi
}

# Function to prompt user to continue
ask_continue() {
    while true; do
        read -p "Do you want to continue the installation of Dolibarr? (Y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo "Installation cancelled."; exit;;
            * ) echo "Please answer Y or N.";;
        esac
    done
}

# Function to generate a secure password
generate_password() {
    USER=$(whoami)
    NUMBER=$(shuf -i 100-999 -n 1)
    SPECIAL_CHAR=$(echo '!@#$%&*()_+=' | fold -w1 | shuf | head -n1)
    PASSWORD="${USER}:${NUMBER}${SPECIAL_CHAR}"
    echo "$PASSWORD"
}

# Function to choose user directory
choose_user_directory() {
    if [ -d /home ]; then
        USERS=($(ls /home))
        if [ ${#USERS[@]} -eq 1 ]; then
            USER_CHOICE=${USERS[0]}
        else
            echo "Please choose a user from the following list:"
            select USER_CHOICE in "${USERS[@]}"; do
                if [ -n "$USER_CHOICE" ]; then
                    break
                else
                    echo "Invalid choice. Please try again."
                fi
            done
        fi
        echo "Selected user: $USER_CHOICE"

        DOCUMENTS_PATH="/home/$USER_CHOICE/Documents"
        if [ ! -d "$DOCUMENTS_PATH" ]; then
            echo "Documents directory does not exist for user $USER_CHOICE, creating..."
            mkdir -p "$DOCUMENTS_PATH"
        fi
        echo "Selected Documents directory: $DOCUMENTS_PATH"
    else
        echo "/home directory does not exist."
        exit 1
    fi
}

# Function to configure MariaDB securely
configure_mariadb() {
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
}

# Function to check if a specific UFW rule exists
check_ufw_rule() {
    sudo ufw status | grep -q "$1"
}

# Function to configure UFW
configure_ufw() {
    if ! command -v ufw &> /dev/null; then
        echo "UFW is not installed. Updating package list..."
        sudo apt update
        echo "Installing UFW..."
        sudo apt install -y ufw
        echo "UFW installed successfully."
        
        echo "Enabling UFW..."
        sudo ufw enable
        
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        echo "Ports 80/tcp and 443/tcp are now allowed."
    else
        echo "UFW is already installed."
        if ! check_ufw_rule "80/tcp"; then
            echo "Allowing port 80/tcp..."
            sudo ufw allow 80/tcp
        else
            echo "Port 80/tcp is already allowed."
        fi

        if ! check_ufw_rule "443/tcp"; then
            echo "Allowing port 443/tcp..."
            sudo ufw allow 443/tcp
        else
            echo "Port 443/tcp is already allowed."
        fi
    fi

    echo "Checking UFW status..."
    sudo ufw status
    
    echo "Printing LAN IP address..."
    ip a | grep -oP 'inet \K[\d.]+'
}

# Function to install specific versions
install_specific_versions() {
    # Install dependencies for building PHP and NGINX
    apt update
    apt install -y build-essential libxml2-dev libssl-dev libcurl4-openssl-dev pkg-config libjpeg-dev libpng-dev libwebp-dev libfreetype6-dev libonig-dev libzip-dev zlib1g-dev

    # Download and install PHP 8.2.20
    cd /usr/local/src
    wget https://www.php.net/distributions/php-8.2.20.tar.gz
    tar -xzvf php-8.2.20.tar.gz
    cd php-8.2.20
    ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data --with-mysqli --with-pdo-mysql --with-zlib --with-curl --with-openssl --enable-mbstring --with-gd --with-jpeg --with-webp --with-freetype
    make
    make install

    # Create a symbolic link to make PHP command available
    ln -s /usr/local/php/bin/php /usr/bin/php
    ln -s /usr/local/php/sbin/php-fpm /usr/sbin/php-fpm

    # Configure PHP-FPM
    cp sapi/fpm/php-fpm.conf /usr/local/php/etc/php-fpm.conf
    cp sapi/fpm/www.conf /usr/local/php/etc/php-fpm.d/www.conf

    # Download and install MariaDB 11.4.2
    cd /usr/local/src
    wget https://mirrors.ircam.fr/pub/mariadb/mariadb-11.2.4/bintar-linux-systemd-x86_64/mariadb-11.2.4-linux-systemd-x86_64.tar.gz
    tar -xzvf mariadb-11.2.4-linux-systemd-x86_64.tar.gz
    mv mariadb-11.2.4-linux-systemd-x86_64 /usr/local/mariadb
    cd /usr/local/mariadb
    scripts/mysql_install_db --user=mysql --basedir=/usr/local/mariadb --datadir=/usr/local/mariadb/data
    cp support-files/mysql.server /etc/init.d/mysql
    update-rc.d mysql defaults

    # Start MariaDB
    /etc/init.d/mysql start

    # Install dependencies for building NGINX
    apt install -y libpcre3 libpcre3-dev zlib1g zlib1g-dev

    # Download and install NGINX 1.22.1
    cd /usr/local/src
    wget https://nginx.org/download/nginx-1.22.1.tar.gz
    tar -xzvf nginx-1.22.1.tar.gz
    cd nginx-1.22.1
    ./configure
    make
    make install

    # Create a symbolic link to make nginx command available
    ln -s /usr/local/nginx/sbin/nginx /usr/bin/nginx

    # Start NGINX
    /usr/local/nginx/sbin/nginx
}

# Main script execution
check_os
check_root

echo "Choose an option:"
echo "1 - Dolibarr Install (Full)"
echo "2 - Opening Dolibarr on LAN (as a server)"
read -p "Enter the number of your choice: " choice

case $choice in
    1)
        ask_continue

        read -p "Enter the username for Dolibarr (this will be the admin account): " DOLIBARR_USER
        read -sp "Enter the password for Dolibarr user: " DOLIBARR_PASSWORD
        echo

        echo "Configuring MariaDB..."
        install_specific_versions

        ROOT_PASSWORD=$(generate_password)
        choose_user_directory
        PASSWORD_FILE="$DOCUMENTS_PATH/root_mariadb_password.txt"

        touch "$PASSWORD_FILE"
        chmod 600 "$PASSWORD_FILE"
        echo "MariaDB root password: $ROOT_PASSWORD" > "$PASSWORD_FILE"

        configure_mariadb

        echo "MariaDB root password has been changed."
        echo "The new password is saved in: $PASSWORD_FILE"

        /usr/local/mariadb/bin/mysql -u root -p"$ROOT_PASSWORD" <<EOF
CREATE DATABASE dolibarr CHARACTER SET utf8 COLLATE utf8_unicode_ci;
CREATE USER '$DOLIBARR_USER'@'localhost' IDENTIFIED BY '$DOLIBARR_PASSWORD';
GRANT ALL PRIVILEGES ON dolibarr.* TO '$DOLIBARR_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

        echo "MariaDB configuration complete."

        echo "Installing Dolibarr and configuring NGINX..."
        apt install -y php-fpm php-curl php-intl php-mbstring php-gd php-zip php-xml php-mysql php-soap php-imap

        cd /var/www
        wget https://sourceforge.net/projects/dolibarr/files/Dolibarr%20ERP-CRM/19.0.2/dolibarr-19.0.2.tgz
        tar xvf dolibarr-19.0.2.tgz

        chown www-data:www-data -R dolibarr-19.0.2
        chmod 755 -R dolibarr-19.0.2

        mv /usr/local/nginx/conf/nginx.conf /usr/local/nginx/conf/nginx.conf.old

        cat << EOF | tee /usr/local/nginx/conf/nginx.conf
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/dolibarr-19.0.2/htdocs;
    index index.php index.html index.htm;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF

        nginx -s reload

        rm /var/www/dolibarr-19.0.2.tgz

        echo "Dolibarr installation complete."
        echo "You can now access Dolibarr at http://localhost/, if it doesn't work, try http://localhost/install"

        echo "! WARNING !"
        echo "- Dolibarr username: $DOLIBARR_USER"
        echo "- Dolibarr password: $DOLIBARR_PASSWORD"
        echo "- MariaDB root password is saved in: $PASSWORD_FILE"
        ;;
    2)
        configure_ufw
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac
