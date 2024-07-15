#!/bin/bash

# Function to display the menu
display_menu() {

    echo "██████╗  ██████╗ ██╗     ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗"
    echo "██╔══██╗██╔═══██╗██║     ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║"
    echo "██║  ██║██║   ██║██║     ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║"
    echo "██║  ██║██║   ██║██║     ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║"
    echo "██████╔╝╚██████╔╝███████╗██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗"
    echo "╚═════╝  ╚═════╝ ╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝"
    echo ""

    echo "Please choose an option:"
    echo "╔══════════════════════════════╗"
    echo "║ 1. Full install (All in One) ║"
    echo "║ 2. Dolibarr (ERP /CRM)       ║"   
    echo "║ 3. PHP                       ║"
    echo "║ 4. Web Server (Nginx)        ║"
    echo "║ 5. MySQL (MariaDB)           ║"
    echo "║ 6. Help                      ║"
    echo "║ 7. Exit                      ║"
    echo "╚══════════════════════════════╝"
    echo ""
}

# Function to handle each choice
handle_choice() {
    case $1 in
        1)
            echo "Starting full install (All in One)..."
            # Add your installation commands here
            ;;
        2)
            echo "Installing Dolibarr (ERP /CRM)..."
            # Add your Dolibarr installation commands here
            ;;
        3)
            echo "Installing PHP..."
            # Add your PHP installation commands here
            ;;
        4)
            echo "Installing Web Server (Nginx)..."
            # Add your Nginx installation commands here
            ;;
        5)
            echo "Installing MySQL (MariaDB)..."
            # Add your MySQL/MariaDB installation commands here
            ;;
        6)
            clear
            echo "Help:"
            echo "1. Full install: Installs everything."
            echo "2. Dolibarr: Installs Dolibarr ERP/CRM."
            echo "3. PHP: Installs PHP."
            echo "4. Web Server: Installs Nginx web server."
            echo "5. MySQL: Installs MySQL (MariaDB) database."
            echo "6. Help: Displays this help message."
            echo "7. Exit: Exits the script."
            echo ""
            ;;
        7)
            echo "Exiting..."
            exit 0
            ;;
        *)
            clear
            echo "Invalid choice, please try again."
            ;;
    esac
}

# Main script loop
while true; do
    display_menu
    read -p "Enter your choice: " choice
    handle_choice $choice
done
