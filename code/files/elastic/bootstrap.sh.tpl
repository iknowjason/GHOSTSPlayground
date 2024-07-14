#!/bin/bash

set -e

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Start bootstrap script"
sudo hostnamectl set-hostname "${hostname}" 
sudo apt-get update -y
sudo apt-get install net-tools -y

# Golang 1.19 install
echo "Installing Golang 1.19"
sudo wget  https://go.dev/dl/go1.19.linux-amd64.tar.gz 
sudo tar -C /usr/local/ -xvf go1.19.linux-amd64.tar.gz  
echo "export GOROOT=/usr/local/go" >> /home/ubuntu/.profile
echo "export GOPATH=$HOME/go" >> /home/ubuntu/.profile 
echo "export PATH=$PATH:/usr/local/go/bin" >> /home/ubuntu/.profile

# Installing docker
echo "Installing Docker"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Elastic install
echo "Installing Elastic Stack"
# Elastic Search install
mkdir /opt/elastic
cd /opt/elastic
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.9.1-linux-x86_64.tar.gz
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.9.1-linux-x86_64.tar.gz.sha512
shasum -a 512 -c elasticsearch-8.9.1-linux-x86_64.tar.gz.sha512 
tar -xzf elasticsearch-8.9.1-linux-x86_64.tar.gz
# Get elasticsearch.yml
echo "Get elasticsearch.yml"
file="elasticsearch.yml"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /opt/elastic/elasticsearch-8.9.1/config/elasticsearch.yml.new

    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done

# change permissions for user ubuntu
chown -R ubuntu:ubuntu /opt/elastic/

# Get elasticsearch.service
echo "Get elasticsearch.service"
file="elasticsearch.service"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /opt/elastic/elasticsearch.service

    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done

# Install systemd elasticsearch service 
echo "Setting up elasticsearch service"
cp /opt/elastic/elasticsearch.service /etc/systemd/system/elasticsearch.service
sudo chmod 644 /etc/systemd/system/elasticsearch.service
sudo systemctl daemon-reload
sudo systemctl enable elasticsearch 

# set the bootstrap password
echo "Setting the elastic bootstrap password in keystore"
cd /opt/elastic/elasticsearch-8.9.1/bin
echo -e "y\n${elastic_password}" | ./elasticsearch-keystore add "bootstrap.password"
chown ubuntu:ubuntu /opt/elastic/elasticsearch-8.9.1/config/elasticsearch.keystore

# start service 
systemctl start elasticsearch

# Loop until elasticsearch is up on port 9200
url='https://127.0.0.1:9200'

# The service needs to be up before we use REST API to change elastic password
while true; do
  http_status=$(curl -Is -k $url | awk 'NR==1{print $2}')

  # Check if the HTTP status code is blank or non-numeric
  if [ -z "$http_status" ] || ! echo "$http_status" | grep -qE '^[0-9]+$'; then
    echo "Elasticsearch service did not respond. Waiting"
    sleep 5 
    continue
  fi

  if [ "$http_status" -eq 200 ] || [ "$http_status" -eq 401 ] || [ "$http_status" -eq 403 ]; then
    echo "Elasticsearch service responded with HTTP status code: $http_status"
    break
  else
    echo "Waiting for Elasticsearch service to respond"
    sleep 5
  fi
done

# Change the kibana_system password, now that elasticsearch is up
curl -k -u "${elastic_username}:${elastic_password}" -X POST "https://127.0.0.1:9200/_security/user/kibana_system/_password" -H "Content-Type: application/json" -d '{ "password": "${elastic_password}"}'

# Kibana install
echo "Installing Kibana"
cd /opt/elastic
echo "Downloading Kibana"
curl -O https://artifacts.elastic.co/downloads/kibana/kibana-8.9.1-linux-x86_64.tar.gz
curl https://artifacts.elastic.co/downloads/kibana/kibana-8.9.1-linux-x86_64.tar.gz.sha512 | shasum -a 512 -c - 
tar -xzf kibana-8.9.1-linux-x86_64.tar.gz
cd kibana-8.9.1/ 

# Get kibana.yml
echo "Get kibana.yml"
file="kibana.yml"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /opt/elastic/kibana-8.9.1/config/kibana.yml

    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done

# generate self-signed certificate for Kibana ssl
cd /opt/elastic/kibana-8.9.1/config
openssl genpkey -algorithm RSA -out kibana.key
openssl req -new -x509 -key kibana.key -out kibana.crt -days 365 \
-subj "/C=US/ST=NY/L=New York/O=Operator/OU=IT/CN=${hostname}"
chown -R ubuntu:ubuntu /opt/elastic/kibana-8.9.1/

# Get kibana.service
echo "Get kibana.service"
file="kibana.service"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do 
    echo "Download attempt: $i"
    curl "$object_url" -o /opt/elastic/kibana.service

    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done

# Install systemd kibana service
echo "Setting up kibana service"
cp /opt/elastic/kibana.service /etc/systemd/system/kibana.service
sudo chmod 644 /etc/systemd/system/kibana.service
sudo systemctl daemon-reload
sudo systemctl enable kibana
sudo systemctl start kibana

# Install logstash 
echo "Setting up logstash"
# Download logstash
echo "Downloading logstash"
cd /opt/elastic
wget https://artifacts.elastic.co/downloads/logstash/logstash-8.9.1-linux-x86_64.tar.gz
tar xfz logstash-8.9.1-linux-x86_64.tar.gz

# Get logstash.conf 
echo "Get logstash.conf"
file="logstash.conf"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /opt/elastic/logstash-8.9.1/config/logstash.conf

    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done

# Get logstash.service
echo "Get logstash.service"
file="logstash.service"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /opt/elastic/logstash.service

    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done

# Change permissions
chown -R ubuntu:ubuntu /opt/elastic/logstash-8.9.1

# Install systemd logstash service
echo "Setting up logstash service"
cp /opt/elastic/logstash.service /etc/systemd/system/logstash.service
sudo chmod 644 /etc/systemd/system/logstash.service
sudo systemctl daemon-reload
sudo systemctl enable logstash
#sudo systemctl start logstash 

echo "End of bootstrap script"
