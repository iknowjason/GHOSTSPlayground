#!/bin/bash
# Custom bootstrap script for Empire C2 

set -e
exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Start script
echo "Start bootstrap script for Empire C2"

# Set variables
echo "export HOME=/home/ubuntu" >> /etc/environment
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> /etc/environment 
source ~/.bashrc

# Set them in this shell
export HOME=/home/ubuntu
export PYENV_ROOT="$HOME/.pyenv"

# Verify
echo "HOME is $HOME"

# Initial packages
echo "Installing initial packages"
sudo apt-get update -y
sudo apt-get install net-tools -y
sudo apt-get install unzip -y

################
# Begin - Install Empire
################
echo "Installing Empire C2"
# Set install location
EMPIRE_INSTALL=/home/ubuntu
cd $EMPIRE_INSTALL 

# Git Clone
echo "git clone"
git clone --recursive https://github.com/BC-SECURITY/Empire.git

# About to install, change dir
cd $EMPIRE_INSTALL/Empire/setup

# Run checkout-latest-tag.sh
echo "Run checkout-latest-tag.sh"
./checkout-latest-tag.sh

# Backup the install script
echo "Backup install.sh script"
cp install.sh install.sh.bak

# Comment out the root check, so that cloud-init can run as root and do the install non-interactive
# Note:  Hate to do this for security.  Hopefully this is temporary. 
# Note:  Running into problems getting the install to work non-interactive as user ubuntu
echo "Comment out root check, so install runs as root"
sed -i 's/if \[ "\$EUID" -eq 0 \]; then/if \[ "\$EUID" -eq 0 \]; then #/' /home/ubuntu/Empire/setup/install.sh
sed -i 's/    exit 1/    #exit 1/' /home/ubuntu/Empire/setup/install.sh

# Run the install script
echo "Running install.sh -y"
./install.sh -y

################
# End - Install Empire
################

# Run Empire
echo "Starting Empire"
cd $EMPIRE_INSTALL/Empire
./ps-empire server &

echo "End of bootstrap script"
