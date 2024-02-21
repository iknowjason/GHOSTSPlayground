#!/bin/bash
# Custom bootstrap script for Ubuntu Linux

set -e
exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# any important variables
INSTALL_RECON=true
HOME=/home/ubuntu
echo "Setting HOME to $HOME"

echo "Start bootstrap script for Linux ${linux_os}"
echo "Installing initial packages"
sudo apt-get update -y
sudo apt-get install net-tools -y
sudo apt-get install unzip -y

# Golang 1.22 install
echo "Installing Golang 1.22"
sudo wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
sudo tar -C /usr/local/ -xvf go1.22.0.linux-amd64.tar.gz  
echo "export GOROOT=/usr/local/go" >> /home/ubuntu/.profile
echo "export GOPATH=$HOME/go" >> /home/ubuntu/.profile 
echo "export PATH=$PATH:/usr/local/go/bin" >> /home/ubuntu/.profile
echo "export GOCACHE=/home/ubuntu/go/cache" >> /home/ubuntu/.profile
echo "export HOME=/home/ubuntu" >> /home/ubuntu/.profile
echo "export HOME=/home/ubuntu" >> /home/ubuntu/.bashrc
source /home/ubuntu/.profile
source /home/ubuntu/.bashrc

# Install recon tools if true 
if [ "$INSTALL_RECON" = true ]; then
    echo "Installing recon tools"

    echo "Install Cloud Edge"
    cd $HOME
    git clone https://github.com/iknowjason/edge.git
    cd edge
    go build edge.go

    echo "Install Masscan and jq"
    sudo apt-get install masscan jq -y

    echo "Install Project Discovery"
    source ~/.bashrc
    go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest
    $HOME/go/bin/pdtm -install-all

else
    echo "Skipping recon tools install"
fi

echo "End of bootstrap script"
