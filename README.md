# Operator Lab 

Operator Lab is a security lab building framework for Red and Blue teams, with the goal of helping Red make Blue better. This documentation is a work in progress and will be updated further.

## Overview

Operator Lab framework works as a python script in which users pass parameters to the script, which dynamically builds different ```capabilities```.  The ```capabilities``` can be mixed and matched in myriad different combinations, allowing one to automate creating a unique enterprise security lab. The ```capabilities``` are terraform data templates that live in the ```terraform-templates``` directory as jinja templates.  The jinja terraform data templates can be customized for your unique requirements.  The python script does variable substitution to manipulate the terraform files.  Inside of each capability, there are also specific sub-directories for how the capabilities are built.  These are constructed as configuration files, bash, and powershell scripts.

## Capability Summary
* Windows, Linux, MacOS 
* Active Directory Domain Services (AD DS) with Domain Join & Auto Logon Domain User support
* Breach and Attack Simulation (Caldera, VECTR)
* Elastic Stack (ELK)
* CloudWatch, CloudTrail, SSM, and S3 bucket (Cloud Native SIEM automation)
* Velociraptor
* GHOSTS NPC
* Hashicorp Nomad
* Command and Control (C2) 

## Installation

Tested with:
* Mac OS 13.4, Ubuntu Linux 22.04
* python 3.9
* terraform 1.5.7

### Extra requirements (will include requirements.txt soon):

**Python 3:**
Requires Python 3.7 or later for the RandomDataGenerators module

**Faker:**  

```
pip3 install faker
```

**RandomDataGenerators:**

```
pip3 install RandomDataGenerators
```

Credentials Setup:
Generate an IAM programmatic access key that has permissions to build resources in your AWS account.  Setup your .env to load these environment variables.  You can also use the direnv tool to hook into your shell and populate the .envrc.  Should look something like this in your .env or .envrc:
```
export AWS_ACCESS_KEY_ID="VALUE"
export AWS_SECRET_ACCESS_KEY="VALUE"
```

## Usage 

### Basic Usage

The basic usage is like this:  
1. Run operator:  ```python3 operator.py <OPTIONS>```.  This will generate terraform files.  Then run terraform.
2. ```terraform init```
3. ```terraform apply -auto-approve```

**Destroy:** When you are finished and wish to destroy the resources:  ```terraform destroy -auto-approve```

## Capabilities:  Usage Examples

### Change AWS region

Changes the AWS region to ```eu-central-1```.  The default region is ```us-east-2```.
```
python3 operator.py --region eu-central-1
```
To make a permanent change to the default region, modify the variable ```default_region``` inside script.

### Build Linux, Mac, or Windows with Quantity Number of Systems Built

Build any number of Windows, Linux, or MacOS systems with exact quantities.  You do this with ```--winclient <count>```, ```--linux <count>```, and ```--macs <count>```.

**Build 3 Kali Linux systems in default region:**

```
python3 operator.py --linux 3 --linux-os kali
```

**Build 2 Red Hat systems in eu-west-1:**
```
python3 operator.py --linux 2 --linux-os redhat --region eu-west-1
```

Current Linux OS support:  ubuntu, debian, redhat, amazon,  kali

**Build MacOS:**
```
python3 operator.py --macs 1 --mac_instance intel
```

Builds 1 Mac instance with Intel architecture.  For detailed guidance on building Macs, please see the MacLab documentation.  Operator was used to create MacLab:
https://github.com/iknowjason/MacLab

**Build Windows Client Systems:**

All Windows client systems build by default with Red Teams tools (Atomic Red Team) and Sysmon.

```
python3 operator.py --winclient 1
```

Description:  Builds one Windows Server 2022 clients instrumented with Sysmon, Atomic Red Team, and PurpleSharp.

```
python3 operator.py --winclient 1 --region us-west-1
```

Description:  Same as above, but builds all resources in us-west-1 instead of default region (us-east-2)

```
python3 operator.py --winclient 2 --admin MyAdmin --password MyPassword
```

Description:  Builds to Windows client systems with a local administrator username and password that is user specified (instead of randomly generated).


### Active Directory Domain Services (AD DS)
Builds a domain controller with lots of parameters for options:

```
python3 operator.py --domain_controller --ad_domain rtcfingroup.com --admin RTCAdmin --password MyPassword012345 --ad_users 500 --winclients 2  --domain_join
```

**Description:** This will create a Domain Controller in dc.tf and install AD DS with forest name of rtcfingroup.com. This will create a custom local administrator account and password with 500 domain users. In this example, the domain users are randomly generated using the command line flag of --ad_users for a total of 500 users. The domain users will be written to ad_users.csv and will have the password specified in --password. Note that domain join is disabled by default for Windows clients but the domain_join parameter enables it for all Windows clients created. This will also create two Windows client terraform files (win1.tf, win2.tf) as well as a terraform file for the Domain Controller (dc.tf).

```
python3 operator.py --domain_controller --ad_domain rtcfingroup.com --admin RTCAdmin --password MyPassword012345 --csv users.csv --winclients 2  --domain_join
```

**Description:** Same capabilities as above, except it can import a custom list of Domain Users into active directory on the DC instance. The script checks to make sure that users are in the correct format. 

### Install Breach and Attack Simulation (Caldera, VECTR)
```python3 operator.py --winclient 1 --bas```

**Description:**  Installs a Breach and Attack Simulation Linux server.  The server installs Caldera, VECTR.  For each Windows client, the Caldera sandcat agent is installed and registers to BAS server automatically.  

Reference:  https://github.com/SecurityRiskAdvisors/VECTR

### Install SIEM (Elastic)

```
python3 operator.py --winclient 1 --siem [elk|splunk]
```

**Description:**  Installs either Elasticsearch with Kibana or a Splunk Enterprise linux server.  Each windows client automatically installs and ships elastic logs via winlogbeat.

Note:  The Splunk option can be removed.  The Splunk server implemenation is done, but stopped working on the clients to forward Universal Forwarder.  Decided that for Splunk, Attack Range is much more comprehensive and also unknown future with Cisco acquisition.  This Operator project can focus on ELK implementation.

### CloudWatch, CloudTrail, SSM, and S3 bucket (Cloud Native SIEM)

```
python3 operator.py --winclient 2 --s3_cloudtrail
```

**Description:** 
Adds two Windows client systems installed with Amazon cloudwatch agent.  The EC2 instance with cloudwatch has a special IAM instance profile with permissions allowing it to send logs to cloudwatch.  A customizable configuration for cloudwatch builds from ```files/windows/cloudwatch.config.json```.  The configuration builds sysmon, powershell logging configuration, and security logs.  All of these get sent to Cloudwatch.  A cloudtrail trail for auditing is also created with a logwatch group.  All of the logs get sent to an S3 bucket which is orchestrated through Amazon firehose.  All windows systems have a special SSM permission policy attached via Instance Profile.  The SSM configuration for System Manager is a realistic configuration for Amazon customers, and allows managing Windows and sending shell commands to the windows systems.  Will need to add the SSM cheat sheet of commands to run against Windows.

### Velociraptor

```
python3 operator.py --winclients 3 --velociraptor
```

**Description:** 
Builds a Velociraptor Linux server with PKI generated by terraform.  Builds three Windows client systems.  All Windows client systems automatically get correct TLS certificates and install Velociraptor client with configuration that registers to Velociraptor Linux server.

Reference:  https://docs.velociraptor.app/

### Ghosts NPC
```python3 operator.py --winclient 1 --ghosts```

Description:  Installs the Ghosts NPC (Non-player Character) framework.  This creates a GHOSTS server with Grafana dashboards and API.  For each Windows client, they automatically install the Ghosts client and register to the Ghosts API server.  

Reference:  https://github.com/cmu-sei/GHOSTS

### Nomad

```
python3 operator.py --winclient 1 --nomad
```

Description:  Installs a Nomad cluster and installs the nomad client on each windows client system.  Nomad jobs can be pushed to clients.  This allows red team automation and orchestration of chaining TTPs across nomad clients.  The ```jobs``` directory contains an example ping command that is pushed to all clients.  A library of different job files can be developed to automate Red Team TTPs.

Reference:  https://www.nomadproject.io/


### C2

```
python3 operator.py --csp [aws|azure|digitalocean] --c2 [empire|sliver|none]
```

Description:  Installs a command and control (C2) Linux server.  The --c2 option sets the C2 server software.  The options are sliver, empire, or none.  None is if you want to customize bash script.  The --csp option switches between cloud provider, either AWS, Azure, or Digital Ocean.  Ensure that you follow AWS Terms of Service because they don't allow hosting a C2 unless you have permission.

Reference Sliver:  https://github.com/BishopFox/sliver

Reference Empire (BC-Security):  https://github.com/BC-SECURITY/Empire

## Custom Lab Combinations

Mix and match the capabilities to your delight with myriad possibilities.  Here are some examples:

### Example 1:  Enterprise Windows AD Attack with Breach and Attack Simulation

```
python3 operator.py -dc --winclients 2 --domain_join --bas
```

### Example 2:  Enterprise Windows AD Attack with Breach and Attack Simulation and Velociraptor

```
python3 operator.py -dc --winclients 2  --domain_join --bas -vel
```

### Example 3:  Enterprise Windows AD Attack with Breach and Attack Simulation and GHOSTS

```
python3 operator.py -dc --winclients 2  --domain_join --bas --ghosts
```

### Example 4:  Enterprise Windows AD Attack with Breach and Attack Simulation and Elastic SIEM

```
python3 operator.py -dc --winclients 2  --domain_join --bas --siem elk
```


### Example 5:  Enterprise Windows AD Attack with Breach and Attack Simulation and Elastic SIEM

```
python3 operator.py -dc --winclients 2  --domain_join --bas --s3_cloudtrail
```

### Example 6:  Enterprise Windows AD Attack with Empire C2 hosted in Digital Ocean and one Kali

```
python3 operator.py -dc --winclients 2  --domain_join --linux 1 --linux-os kali --c2 empire --csp digitalocean
```



## To Do List History of Completion

- [x] Use jinja templates for terraform instrumented with python ✅ 2023-07-25
- [x] Test install_red script to get Atomic Red Team, PurpleSharp installed ✅ 2023-07-25
- [x] Test sysmon install scripts on windows ✅ 2023-07-25
- [x] Build DC and AD DS
- [x] Domain Join on Windows Clients
- [x] Auto logon domain users using domain credentials
- [x] Nomad cluster / orchestration of red teaming (Wed) ✅ 2023-07-27
- [x] BAS (Breach and Attack Simulation) box with Caldera Prelude Operator + VECTR ✅ 2023-08-25
- [x] SIEM support (ELK) + winlogbeat log forwarding ✅ 2023-08-25
- [x] Cloudtrail auditing and store in S3
- [x] CloudWatch agent ship logs to S3 bucket
- [x] Ship logs to S3 bucket instead of SIEM, using EC2 agent
- [x] Ghosts NPC User Simulation ✅ 2023-08-25
- [x] Prelude Operator headless C2 setup with pneuma
- [x] Velociraptor server and endpoints
- [x] C2 support
- [x] Mac system support
- [x] Linux system support (Ubuntu, Amazon Linux, Kali Linux, Debian, RHEL)


