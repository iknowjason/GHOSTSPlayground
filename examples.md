# Example Images

### GHOSTS API Server after boot 
![GHOSTS API](images/ghosts1.png "GHOSTS API")

### GHOSTS Grafana Dashboard after boot
![GHOSTS API](images/ghosts2.png "GHOSTS API")

### On Win1 Client, monitoring the bootstrap powershell script logfile
![GHOSTS API](images/ghosts3.png "GHOSTS API")

### Run the npc.sh script to sync a new NPC with registered GHOSTS machines
SSH into the GHOSTS Linux server and run the script: ```/home/ubuntu/npc.sh```
![GHOSTS API](images/ghosts4.png "GHOSTS API")

### Run the remote npc.sh script to sync a new NPC with registered GHOSTS machines
Run the rendered script from the output directory.  This script makes an API connection to the remote public IP address of GHOSTS server.
![GHOSTS API](images/ghosts14.png "GHOSTS API")

### On the DC, showing the Domain Join of Win1 
![GHOSTS API](images/ghosts6.png "GHOSTS API")

### On the DC, the ad_users.csv loads all Domain Users, OUs, and Groups.  This shows the Engineering OU and one of the users who is added through ad_users.csv
You can edit and customize the ad_users.csv.  It is uploaded to S3 bucket and then downloaded and processed through ad_install.ps1 script on the DC.
![GHOSTS API](images/ghosts7.png "GHOSTS API")

### Kibana Server:  Showing the Symon logs
![GHOSTS API](images/ghosts8.png "GHOSTS API")

### Kibana Server:  Showing the Winlogbeat Overview dashboard that is automatically created
![GHOSTS API](images/ghosts9.png "GHOSTS API")

### On Win1 Client, launching ghosts.exe manually
![GHOSTS API](images/ghosts12.png "GHOSTS API")

### On Win1 Client, ghosts is starting
![GHOSTS API](images/ghosts13.png "GHOSTS API")

### On Win1 Client, ghosts connects to the API server
It connects to the API server and streams its timeline logs as controlled by configuration
![GHOSTS API](images/ghosts11.png "GHOSTS API")

### A view of the GHOSTS API Server after the machine has registered
The NPC count has incremented by 1.  The API change now synchronizes new NPCs with registered machines.
![GHOSTS API](images/ghosts5.png "GHOSTS API")

### GHOSTS Grafana dashboard after the machine has registered
The machine starts to send timeline data showing application usage.
![GHOSTS API](images/ghosts10.png "GHOSTS API")




