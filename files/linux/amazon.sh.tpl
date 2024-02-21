#!/bin/bash
# Custom bootstrap script for Amazon Linux

set -e
exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# any important variables
INSTALL_RECON=true

echo "Start bootstrap script for Linux ${linux_os}"
echo "Installing initial packages"
#yum update -y


# Golang 1.22 install
echo "Installing Golang 1.22"
sudo wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
sudo tar -C /usr/local/ -xvf go1.22.0.linux-amd64.tar.gz  
echo "export GOROOT=/usr/local/go" >> /home/ubuntu/.profile
#echo "export GOROOT=/usr/local/go" >> /home/ubuntu/.bashrc
echo "export GOPATH=$HOME/go" >> /home/ubuntu/.profile 
#echo "export GOPATH=$HOME/go" >> /home/ubuntu/.bashrc 
echo "export PATH=$PATH:/usr/local/go/bin" >> /home/ubuntu/.profile
#echo "export PATH=$PATH:/usr/local/go/bin" >> /home/ubuntu/.bashrc
echo "export GOCACHE=/home/ubuntu/go/cache" >> /home/ubuntu/.profile
source /home/ubuntu/.profile
#source /home/ubuntu/.bashrc

# install recon tools if true 
if [ "$INSTALL_RECON" = true ]; then
    echo "Installing recon tools"
    go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest
    pdtm -install-all
    #source ~/.bashrc
    source /home/ubuntu/.profile 
else
    echo "Skipping recon tools install"
fi

echo "End of bootstrap script"
