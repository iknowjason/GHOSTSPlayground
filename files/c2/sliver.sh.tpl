#!/bin/bash
# Custom bootstrap script for Sliver C2 

set -e
exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Variables

# Start
echo "Start bootstrap script for Sliver C2"

# Initial packages
echo "Installing initial packages"
sudo apt-get update -y
sudo apt-get install net-tools -y
sudo apt-get install unzip -y

# Install Sliver
curl https://sliver.sh/install|sudo bash
 

echo "End of bootstrap script"
