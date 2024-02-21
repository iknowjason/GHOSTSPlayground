#!/bin/bash

set -e

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Velociraptor install
echo "Start bootstrap script for installing Velociraptor"
sudo apt-get update -y
sudo apt-get install net-tools -y
sudo apt-get install unzip -y

# Downloading Velociraptor 
echo "Downloading Velociraptor"
echo "URL: ${vdownload_url}"
wget ${vdownload_url} -O /home/ubuntu/velociraptor

# Make the binary executable and copy it
chmod +x /home/ubuntu/velociraptor
echo "copy velociraptor to /usr/sbin"
cp /home/ubuntu/velociraptor /usr/sbin/.

# Get server config 
echo "Get server config"
file="${server_config}"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /home/ubuntu/${server_config}

    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Sleep and retry"
        sleep 30
    fi
done

# Build velociraptor deb package
echo "Build velociraptor deb package"
cd /home/ubuntu
velociraptor --config /home/ubuntu/vel_server_config.yml debian server

# Install deb package and service
echo "Install deb package and service"
dpkg -i /home/ubuntu/*.deb

# Add admin in config
echo "Add velociraptor administrator in config"
sudo -u velociraptor bash -c 'velociraptor --config /etc/velociraptor/server.config.yaml user add ${vadmin_username} ${vadmin_password} --role administrator'

echo "End of bootstrap script"
