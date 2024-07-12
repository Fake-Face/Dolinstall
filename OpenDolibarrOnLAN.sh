#!/bin/bash

# Function to check if a specific UFW rule exists
check_ufw_rule() {
    sudo ufw status | grep -q "$1"
}

# Check if UFW is installed
if ! command -v ufw &> /dev/null; then
    echo "UFW is not installed. Updating package list..."
    
    sudo apt update
    echo "Installing UFW..."
    
    sudo apt install -y ufw
    echo "UFW installed successfully."

    # Enable UFW
    echo "Enabling UFW..."
    sudo ufw enable

    # Allow ports 80 and 443
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    echo "Ports 80/tcp and 443/tcp are now allowed."

else
    echo "UFW is already installed."

    # Check if the rules for ports 80 and 443 are already set
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

# Check UFW status
echo "Checking UFW status..."
sudo ufw status

# Extract and print the LAN IP address
echo "Printing LAN IP address..."
ip a | grep -oP 'inet \K[\d.]+'
