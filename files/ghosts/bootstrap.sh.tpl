#!/bin/bash

set -e

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Start bootstrap script"

chown -R ubuntu /home/ubuntu

# Docker install
echo "Start Docker Install"
distro=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
sudo apt-get install -y apt-transport-https ca-certificates
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$${distro} $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce
sudo curl -SL https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64 -o /usr/bin/docker-compose
sudo chmod +x /usr/bin/docker-compose
echo "Docker Install complete"

# GHOSTS Grafana 
echo "Get Grafana config and dashboards"
mkdir /home/ubuntu/ghosts
mkdir -p /home/ubuntu/ghosts/config/grafana/datasources
mkdir -p /home/ubuntu/ghosts/config/grafana/dashboards
# Get datasources.yml
echo "Get datasources.yml"
file="datasources.yml"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /home/ubuntu/ghosts/config/grafana/datasources/datasources.yml

    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done

# Get dashboards.yml
echo "Get dashboards.yml"
file="dashboards.yml"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /home/ubuntu/ghosts/config/grafana/dashboards/dashboards.yml

    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done

# Get GHOSTS-5-default-Grafana-dashboard.json 
echo "Get GHOSTS-5-default-Grafana-dashboard.json"
file="GHOSTS-5-default-Grafana-dashboard.json"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /home/ubuntu/ghosts/config/grafana/dashboards/GHOSTS-5-default-Grafana-dashboard.json

    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done

# Get GHOSTS-5-group-default-Grafana-dashboard.json
echo "Get GHOSTS-5-group-default-Grafana-dashboard.json"
file="GHOSTS-5-group-default-Grafana-dashboard.json"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /home/ubuntu/ghosts/config/grafana/dashboards/GHOSTS-5-group-default-Grafana-dashboard.json

    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done


# GHOSTS API install
echo "Start GHOSTS Install"
cd /home/ubuntu/ghosts
file="docker-compose.yml"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl -O "$object_url"

    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done
docker-compose up -d
echo "GHOSTS Install complete"

# Install Ghosts Animator
echo "Install GHOSTS Animator"
cd /home/ubuntu
git clone https://github.com/cmu-sei/GHOSTS-ANIMATOR
cd GHOSTS-ANIMATOR/src
sudo docker build . -t ghosts/animator
# change listening port to be 5001
sed -i 's/5000:5000/5001:5001/g' docker-compose.yml
# download animator appsettings.json
file="appsettings.json"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl -O "$object_url"

    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done
docker compose up -d

echo "End of bootstrap script"
