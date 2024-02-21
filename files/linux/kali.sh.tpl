#!/bin/bash
# Custom bootstrap script for Kali Linux
# Note: Building Kali requires a subscription agreement in AWS marketplace

set -e
exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# any important variables
INSTALL_RECON=true

echo "Start bootstrap script for Linux ${linux_os}"
echo "Installing initial packages"
sudo apt-get update -y
sudo apt-get install net-tools -y
sudo apt-get install unzip -y

# Golang 1.22 install
echo "Installing Golang 1.22"
sudo wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
sudo tar -C /usr/local/ -xvf go1.22.0.linux-amd64.tar.gz  
echo "export GOROOT=/usr/local/go" >> /home/admin/.bashrc
echo "export GOPATH=$HOME/go" >> /home/admin/.bashrc 
echo "export PATH=$PATH:/usr/local/go/bin" >> /home/admin/.bashrc
echo "export GOCACHE=/home/ubuntu/go/cache" >> /home/admin/.bashrc
source /home/admin/.bashrc

# install recon tools if true 
if [ "$INSTALL_RECON" = true ]; then
    echo "Installing recon tools"
    go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest
    pdtm -install-all
    source /home/admin/.bashrc
else
    echo "Skipping recon tools install"
fi

echo "End of bootstrap script"
