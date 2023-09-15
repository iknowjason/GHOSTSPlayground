# Create an AWS Security lab
# This script helps you to automatically and quickly write terraform
# From there you can customize your terraform further and create your own templates!
# Author:  Jason Ostrom

import random
import argparse
import os
import subprocess
import urllib.request
import secrets
import string
import logging
from csv import reader
import os.path
import linecache
from jinja2 import Environment, FileSystemLoader
from faker import Faker

### Parse arguments first
# argparser stuff
parser = argparse.ArgumentParser(description='A script to create an AWS security lab')

# Add argument for count of Windows clients
parser.add_argument('-wc', '--winclients', dest='winclients_count')

# Add argument for aws region
parser.add_argument('-r', '--region', dest='region')

# Add argument for enabling a SIEM server, either elk or splunk
parser.add_argument('-si', '--siem', dest='siem_enable')

# Add argument for enabling Domain Controller
parser.add_argument('-dc', '--domain_controller', dest='dc_enable', action='store_true')

# Add argument for Active Directory Domain
parser.add_argument('-ad', '--ad_domain', dest='ad_domain')

# Add argument for Active Directory Users count
parser.add_argument('-au', '--ad_users', dest='user_count')

# Add argument for user supplied CSV to load Active Directory
parser.add_argument('-cs', '--csv', dest='user_csv')

# Add argument for  Local Administrator
parser.add_argument('-u', '--admin', dest='admin_set')

# Add argument for password
parser.add_argument('-p', '--password', dest='password_set')

# Add argument for domain_join
parser.add_argument('-dj', '--domain_join', dest='domain_join', action='store_true')

# Add argument for auto logon
parser.add_argument('-al', '--auto_logon', dest='auto_logon', action='store_true')

# Add argument for enabling Nomad orchestration
parser.add_argument('-no', '--nomad', dest='nomad_enable', action='store_true')

# Add argument for enabling Ghosts NPC
parser.add_argument('-gh', '--ghosts', dest='ghosts_enable', action='store_true')

# Add argument for enabling Breach and Attack Simulation (Caldera, VECTR, Prelude Operator
parser.add_argument('-b', '--bas', dest='bas_enable', action='store_true')

# parse arguments
args = parser.parse_args()

# Load the Jinja templates
env = Environment(loader=FileSystemLoader('terraform-templates'))

# Define this because it is needed for default passwords
#default_input_password = ""

####
# Functions
####

def check_cidr_subnet(subnet_cidr_str):
    # Check the cidr or subnet to make sure it looks correct
    elements = subnet_cidr_str.split('.')
    if len(elements) != 4:
        print("[-] The subnet or CIDR is not in correct format:",subnet_cidr_str)
        print("[-] Correct examples include: 10.100.30.0/24")
        print("[-] Correct examples include: 10.100.0.0/16")
        return False

    octet1 = int(elements[0])
    if ((octet1 >= 0) and (octet1 <= 255)):
        pass
    else:
        print("[-] Error parsing the subnet or CIDR ~ not in correct format:", subnet_cidr_str)
        print("[-] Problem: ",octet1)
        return False

    octet2 = int(elements[1])
    if ((octet2 >= 0) and (octet2 <= 255)):
        pass
    else:
        print("[-] Error parsing the subnet or CIDR ~ not in correct format:", subnet_cidr_str)
        print("[-] Problem: ",octet2)
        return False

    octet3 = int(elements[2])
    if ((octet3 >= 0) and (octet3 <= 255)):
        pass
    else:
        print("[-] Error parsing the subnet or CIDR ~ not in correct format:", subnet_cidr_str)
        print("[-] Problem: ",octet3)
        return False

    last = elements[3]
    split_last = last.split('/')
    if len(split_last) != 2:
        print("[-] Error parsing the subnet or CIDR ~ not in correct format:", subnet_cidr_str)
        return False
    octet4 = int(split_last[0])
    if ((octet4 >= 0) and (octet4 <= 255)):
        pass
    else:
        print("[-] Error parsing the subnet or CIDR ~ not in correct format:", subnet_cidr_str)
        print("[-] Problem: ",octet4)
        return False

    octet5 = int(split_last[1])
    if ((octet5 >= 0) and (octet5 <= 32)):
        pass
    else:
        print("[-] Error parsing the subnet or CIDR ~ not in correct format:", subnet_cidr_str)
        print("[-] Problem: ",octet5)
        return False

    return True

def get_password(args):

    #length of password
    length = 10

    lower = string.ascii_lowercase
    upper = string.ascii_uppercase
    num = string.digits
    all = lower + upper + num

    # create blank password string / array
    password = []
    # at least one lower
    password.append(random.choice(lower))
    # at least one upper
    password.append(random.choice(upper))
    # at least one number
    password.append(random.choice(num))
    for i in range(1, length - 2):
        if len(password) < length:
            password.append(random.choice(all))

    random.shuffle(password)

    final_random_password = ''.join(password)

    if args.password_set:
        return args.password_set
    else:
        return final_random_password

def get_random_user(csv_file):

    # get line count
    with open(csv_file, 'r') as fp:
        for count, line in enumerate(fp):
            pass

    random_choice = random.randint(2, count)

    myline = linecache.getline(csv_file, random_choice, module_globals=None)
    elements = myline.split(",")
    full_name = elements[0]
    username = elements[1].split("@")[0]
    password = elements[2]
    return (full_name, username, password)

    csv_file.close()

def get_winrm_user(csv_file):

    with open(csv_file, 'r') as csv_object:
        csv_reader = reader(csv_object)
        header = next(csv_reader)

        if header != None:
            for row in csv_reader:

                da_value = row[5]
                ## get the first domain admin where da is set to True
                if da_value.upper() == "TRUE":

                    username = row[1].split("@")[0]
                    password = row[2]
                    return(username, password)

    return False


# Check the user supplied csv file for correctness
def check_ad_csv(csv_file):
    retval = True
    da_set = False

    if not os.path.exists(csv_file):
        print("[-] File doesn't exist: ", csv_file)
        print("[-] Going to exit")
        return False

    with open(csv_file, 'r') as csv_object:
        csv_reader = reader(csv_object)
        header = next(csv_reader)
        # Check 1: Check the header
        if len(header) == 6 and header[0] == 'name' and header[1] == 'upn' and header[2] == 'password' and header[
            3] == 'groups' and header[4] == 'oupath' and header[5] == 'domain_admin':
            # All good - do nothing
            pass
        else:
            print("    [-] Incorrect CSV header")
            print("    [-] This is the parsed header: ", header)
            print("    [-] Example of a good header:  name,upn,password,groups,oupath,domain_admin")
            return False
        example_row = "Olivia Odinsdottir,oliviaodinsdottir@rtcfingroup.com,MyPassword012345,IT,OU=IT;DC=rtcfingroup;DC=com,True"
        count = 1
        if header != None:
            for row in csv_reader:
                count += 1
                # Check 1: 6 fields in each row
                row_length = len(row)
                if row_length != 6:
                    print("    [-] Error: The row must have 6 fields")
                    print("    [-] Error: Actual fields: ", row_length)
                    print("    [-] Error found at line ", count)
                    print("    [-] Bad parsed row: ", row)
                    print("    [-] Example good row: ", example_row)
                    print("    [-] Going to exit")
                    return False

                # Check 2: No blank data fields
                for element in row:
                    if element == "":
                        print("    [-] Error: Blank data field found!")
                        print("    [-] Error found at line ", count)
                        print("    [-] Bad parsed row: ", row)
                        print("    [-] Example good row: ", example_row)
                        print("    [-] Going to exit")
                        return False

                # Check 3: Check oupath to be proper
                # Check 3: Check that AD Group is included in oupath
                oupath_string = row[4]
                oupath = oupath_string.split(";")
                if len(oupath) == 3:
                    pass
                else:
                    print("    [-] Error found at line ", count)
                    print("    [-] Error:  OUPath will cause errors loading AD")
                    print("    [-] Error:  Expected three ; delimited fields")
                    print("    [-] Error:  Invalid: ", oupath_string)
                    print("    [-] Error:  Valid example: OU=IT;DC=rtcfingroup;DC=com")
                    print("    [-] Going to exit")
                    return False
                ad_group = row[3]
                ou_ad_group = ""
                oustring = oupath_string.split(";")[0]
                if "OU=" not in oustring:
                    print("    [-] Error in OU field")
                    print("    [-] Error found at line ", count)
                    print("    [-] Error: didn't find 'OU='")
                    print("    [-] Error:  Invalid: ", oustring)
                    print("    [-] Error:  Valid example: OU=IT")
                    print("    [-] Going to exit")
                    return False
                else:
                    ou_parsed = oustring.split("=")
                    if len(ou_parsed) == 2:
                        ou_ad_group = ou_parsed[1]
                    else:
                        print("    [-] Error in OU field")
                        print("    [-] Error found at line ", count)
                        print("    [-] Error:  Invalid: ", oustring)
                        print("    [-] Error:  Valid example: OU=IT")
                        print("    [-] Going to exit")
                        return False

                if ad_group == ou_ad_group:
                    pass
                else:
                    print("    [-] Error matching AD group with oupath")
                    print("    [-] Error found at line ", count)
                    print("    [-] AD will not correctly build with users, groups, and OU")
                    print(
                        "    [-] The AD group value and OU= must match for user to be correctly placed into AD Group and OU")
                    print("    [-] AD Group: ", ad_group)
                    print("    [-] OUPath AD group: ", ou_ad_group)
                    print("    [-] oupath: ", oupath_string)
                    print(
                        "    [-] Valid example:  Regina Perkins,reginaperkins@rtcfingroup.com,MyPassword012345,Marketing,OU=Marketing;DC=rtcfingroup;DC=com,False")
                    print("    [-] To bypass this strict check, you can set retval to True in script")
                    retval = False

                    # Check 4: OUPath doesn't match for AD Domain you are going to build
                # only check if the ad_domain is set
                if args.ad_domain:
                    dc1_splits = oupath[1].split("=")
                    dc1 = dc1_splits[1]
                    dc2_splits = oupath[2].split("=")
                    dc2 = dc2_splits[1]
                    dc_domain = dc1 + "." + dc2
                    if args.ad_domain == dc_domain:
                        # we are good, they match
                        pass
                    else:
                        print("    [-] Error matching oupath domain with --ad_domain value")
                        print("    [-] AD users, groups, or OUs will not be correctly built unless this matches")
                        print("    [-] Error found at line ", count)
                        print("    [-] ad_domain value: ", args.ad_domain)
                        print("    [-] domain from oupath: ", dc_domain)
                        print("    [-] oupath value: ", oupath)
                        print("    [-] To bypass this strict check, you can set retval to True in script")
                        retval = False

                        # Check 5: At least one DA is set
                if da_set:
                    pass
                else:
                    da_value = row[5]
                    if da_value.upper() == "TRUE":
                        da_set = True

                # Check 6: Either True or False for domain admin
                da_value = row[5]
                if not da_value.upper() == "TRUE" and not da_value.upper() == "FALSE":
                    print("    [-] Error domain admin value must be True or False")
                    print("    [-] Error found at line ", count)
                    print("    [-] Value: ", da_value)
                    print(
                        "    [-] Example: Olivia Odinsdottir,oliviaodinsdottir@rtcfingroup.com,MyPassword012345,IT,OU=IT;DC=rtcfingroup;DC=com,True")
                    return False

                # Check 7: upn for each user matches domain
                if args.ad_domain:
                    upn_domain = row[1].split("@")[1]
                    if upn_domain == args.ad_domain:
                        pass
                    else:
                        print("    [-] Error: upn domain doesn't match --ad_domain value")
                        print("    [-] Error: This will prevent users from being added to AD")
                        print("    [-] Error found at line ", count)
                        print("    [-] upn domain value:", upn_domain)
                        print("    [-] --ad_domain value:", args.ad_domain)
                        print("    [-] To bypass this strict check, you can set retval to True in script")
                        retval = False

    # check if at least one Domain Admin is set
    if da_set:
        pass
    else:
        print("    [-] Error:  At least one domain admin is required for Domain Join")
        print("    [-] Error:  This is set in the CSV at the last field")
        print("    [-] Error:  Set at least one user to True")
        print(
            "    [-] Example: Olivia Odinsdottir,oliviaodinsdottir@rtcfingroup.com,MyPassword012345,IT,OU=IT;DC=rtcfingroup;DC=com,True")
        print("    [-] To bypass this strict check, you can set retval to True in script")
        retval = False

    # final return
    return retval

# Start of Variables

# counter to track for extra users added
users_added = 0

#### ACTIVE DIRECTORY CONFIGURATION
### Default Domain / Default AD Domain
ad_users_csv = "ad_users.csv"
default_aduser_password = get_password(args)
default_domain = "rtc.local"
default_winrm_username = ""
default_winrm_password = get_password(args)
default_admin_username = "RTCAdmin"
default_admin_password = get_password(args)
default_da_password = get_password(args)
ad_groups = ["Marketing", "IT", "Legal", "Sales", "Executive", "Engineering"]

# duplicate count for created AD users
duplicate_count = 0

# Extra AD users beyond the default in default_ad_users
extra_users_list = []
all_ad_users = []

# The default AD Users
# The groups field is the AD Group that will be automatically created
# An OU will be auto-created based on the AD Group name, and the Group will have OU path set to it
default_ad_users = [
    {
        "name":"Lars Borgerson",
        "ou": "CN=users,DC=rtc,DC=local",
        "password": get_password(args),
        "domain_admin":"",
        "groups":"IT"
    },
    {
        "name":"Olivia Odinsdottir",
        "ou": "CN=users,DC=rtc,DC=local",
        "password": get_password(args),
        "domain_admin":"True",
        "groups":"IT"
    },
    {
        "name":"Liem Anderson",
        "ou": "CN=users,DC=rtc,DC=local",
        "password": get_password(args),
        "domain_admin":"",
        "groups":"IT"
    },
    {
        "name":"John Nilsson",
        "ou": "CN=users,DC=rtc,DC=local",
        "password": get_password(args),
        "domain_admin":"",
        "groups":"IT"
    },
    {
        "name":"Jason Lindqvist",
        "ou": "CN=users,DC=rtc,DC=local",
        "password": get_password(args),
        "domain_admin":"True",
        "groups":"IT"
    },
]

# Install sysmon
install_sysmon_enabled = True

# Install red team tools
install_red = True

# Names of the terraform files
tmain_file = "main.tf"
tproviders_file = "providers.tf"
tnet_file = "network.tf"
tsg_file = "sg.tf"
tsiem_file = "siem.tf"
tdc_file = "dc.tf"
tsysmon_file = "sysmon.tf"
ts3_file = "s3.tf"
tscripts_file = "scripts.tf"
tnomad_file = "nomad.tf"
tghosts_file = "ghosts.tf"
tbas_file = "bas.tf"
telk_file = "elastic.tf"
twinlogbeat_file = "winlogbeat.tf"
tsplunk_file = "splunk.tf"


# This is the base windows system client file name.  Will be replaced with the number of windows clients:  win1.tf, win2.tf
# Each Windows client system will have its own dedicated terraform file ~ Easier to use and understand
twin_file = "win.tf"

### Configuration for Subnets
config_subnets = [
    {
        "name":"ad_subnet",
        "prefix":"10.100.10.0/24",
        "type":"ad_vlan"
    },
    {
        "name":"user_subnet",
        "prefix":"10.100.20.0/24",
        "type":"user_vlan"
    },
    {
        "name":"siem_subnet",
        "prefix":"10.100.30.0/24",
        "type":"siem_vlan"
    },
    {
        "name":"attack_subnet",
        "prefix":"10.100.40.0/24",
        "type":""
    }
]

### WINDOWS SYSTEM CLIENT CONFIGURATION
### The Default Configuration for all of the Windows Client Systems
config_win_endpoint = {
    "hostname_base":"win",
    "join_domain":"false",
    "auto_logon_domain_user":"false",
    "install_sysmon":install_sysmon_enabled,
    "install_red":install_red,
}

# subnet variables and information
subnet_names = []
subnet_prefixes = []
user_vlan_count = 0
ad_vlan_count = 0
siem_vlan_count = 0
siem_subnet_prefix = ""
siem_subnet_name = ""
ad_subnet_name = ""
ad_subnet_prefix = ""
helk_ip = ""
user_subnet_name = ""
user_subnet_prefix = ""

# user_subnet start IP address
# If the user subnet is 10.100.30.0/24:
# start the workstations at 10.100.30.x where x is first_ip_user_subnet variable
first_ip_user_subnet = "10"

# The instance size for each system
size_win = "Standard_D2as_v4"
size_dc = "Standard_D2as_v4"
# Note:  Hunting ELK install options #4 requires 8 GB available memory
size_helk  = "Standard_D4s_v3"

# End of Variables

# logfile configuration
logging.basicConfig(format='%(asctime)s %(message)s', filename='ranges.log', level=logging.INFO)

if __name__ == '__main__':

    print("Starting RedCloud")

    # get Local Admin
    default_input_admin = ""
    if args.admin_set:
        default_input_admin = args.admin_set
        print("[+] Local Admin account name:  ", default_input_admin)
        logging.info('[+] Local Admin account name: %s', default_input_admin)

    # get input password
    #default_input_password = ""
    if args.password_set:
        default_input_password = args.password_set
        print("[+] Password desired for all users:  ", default_input_password)
        logging.info('[+] Password desired for all users: %s', default_input_password)

    # Get the default domain if specified
    if args.ad_domain:
        default_domain = args.ad_domain
        print("[+] Setting AD Domain to build AD DS:",default_domain)
        logging.info('[+] Setting AD Domain to build AD DS: %s', default_domain)

    # Get the Admin account if specified
    if args.admin_set:
        default_admin_username = args.admin_set

    if args.user_count and args.user_csv:
        print("[-] Both --ad_users and --csv are enabled ~ Please choose one")
        exit()

    if args.user_count:
        duser_count = int(args.user_count)

        ### Generate a user's name using Faker
        ### Insert the user into a list only if unique
        ### Loop until the users_added equals desired users
        print("[+] Creating unique user list")
        logging.info('[+] Creating unique user list')
        while users_added < duser_count:
            faker = faker()
            first = faker.unique.first_name()
            last = faker.unique.last_name()
            display_name = first + " " + last
            if display_name in extra_users_list:
                print("    [-] Duplicate user %s ~ not adding to users list" % (display_name))
                logging.info('[-] Duplicate user %s', display_name)
                duplicate_count += 1
            else:
                extra_users_list.append(display_name)
                user_dict = {"name": "", "pass": ""}
                user_dict['name'] = display_name
                user_dict['pass'] = default_aduser_password
                all_ad_users.append(user_dict)
                users_added += 1
                # DEBUGprint("[+] Generated AD user:", display_name)

        print("[+] Number of users added into list: ", len(extra_users_list))
        logging.info('[+] Number of users added into list %d', len(extra_users_list))
        print("[+] Number of duplicate users filtered out: ", duplicate_count)
        logging.info('[+] Number of duplicate users filtered out: %s', duplicate_count)
    ### End of extra AD Users

    ### Check the user supplied CSV for issues
    ### Check the file that is going to load Active Directory users, groups, OUs
    if args.user_csv:
        print("[+] User supplied CSV file for Active Directory users: ", args.user_csv)
        print("[+] Checking the file to make sure users will load into AD")
        # Check the user supplied AD csv file to make sure it is properly built to work
        retval = check_ad_csv(args.user_csv)
        if retval:
            print("    [+] The file looks good")
        else:
            print("    [+] Exit due to csv file not looking good")
            exit()

    # Parsing the Windows client systems
    if not args.winclients_count:
        print("[+] Windows Client System: 0")
        logging.info('[+] Windows Client Systems: 0')
        args.winclients_count = 0
    else:
        print("[+] Number of Windows Client Systems desired: ", args.winclients_count)
        logging.info('[+] Number of Windows Client Systems desired: %s', args.winclients_count)

    # how many client systems to build
    win_count = int(args.winclients_count)

    # parse the AWS regions if specified
    supported_aws_regions = ['us-east-1', 'us-east-2', 'us-west-1', 'us-west-2', 'ap-south-1', 'ap-northeast-1',
                                 'ap-northeast-2', 'ap-northeast-3', 'ap-southeast-1', 'ap-southeast-2', 'ca-central-1', 'eu-central-1',
                                 'eu-west-1', 'eu-west-2', 'eu-west-3', 'eu-north-1', 'sa-east-1', 'af-south-1',
                                 'ap-southeast-4', 'ap-east-1', 'ap-south-2', 'ap-southeast-3', 'eu-south-1',
                                 'eu-south-2', 'eu-central-2', 'me-south-1', 'me-central-1'
                            ]
    default_region = "us-east-2"
    if not args.region:
        print("[+] Using default region: ", default_region)
        logging.info('[+] Using default location: %s', default_region)
    else:
        default_region = args.region
        if default_region in supported_aws_regions:
            # this is a supported AWS region
            print("[+] Using AWS region: ", default_region)
            logging.info('[+] Using AWS region: %s', default_region)
        else:
            print("[-] This is not a supported AWS region:", default_region)
            print("[-] Check the supported_aws_regions if you need to add a new official AWS region")
            exit()

    # Parse the AD users to get one Domain Admin for bootstrapping systems
    if args.dc_enable:
        da_count = 0
        for user in default_ad_users:

            # Set up a dictionary to store name and password
            user_dict = {'name': '', 'pass': ''}
            user_dict['name'] = user['name']

            if user['domain_admin'].lower() == 'true':
                da_count += 1
                names = user['name'].split()
                default_winrm_username = names[0].lower() + names[1].lower()
                default_winrm_password = user['password']

                # set password to default domain admin password
                user_dict['pass'] = default_da_password
            else:
                # set password to default ad user password
                user_dict['pass'] = default_aduser_password

            # Append to all_ad_users
            all_ad_users.append(user_dict)

        if da_count >= 1:
            pass
        else:
            print("[-] At least one Domain Admin in default_ad_users must be enabled")
            exit()

    if install_sysmon_enabled == True:
        sysmon_endpoint_config = "true"
    else:
        sysmon_endpoint_config = "false"

    ## Check if domain_join argument is enabled
    if args.domain_join:
        print("[+] Domain Join is set to true")
        logging.info('[+] Domain Join is set to true')
        config_win_endpoint['join_domain'] = "true"

    ## Check if auto_logon argument is enabled
    ## If it is, set the configuration above
    if args.auto_logon:
        print("[+] Auto Logon is set to true")
        logging.info('[+] Auto Logon is set to true')
        config_win_endpoint['auto_logon_domain_user'] = "true"

    ## Can only join the domain or auto logon domain users if dc enable
    if config_win_endpoint['join_domain'].lower() == 'true' or config_win_endpoint['auto_logon_domain_user'].lower == 'true':
        if args.dc_enable:
            pass
        else:
            print("[-] The Domain controller option must be enabled for Domain Join or Auto Logon Domain Users")
            print("[-] Current setting for join_domain: ", config_win_endpoint['join_domain'])
            print("[-] Current setting for auto_logon_domain_user: ", config_win_endpoint['auto_logon_domain_user'])
            exit()

    # check to make sure config_win_endpoint is correct for true or false values
    if config_win_endpoint['join_domain'].lower() != 'false' and config_win_endpoint[
        'join_domain'].lower() != 'true':
        print("[-] Setting join_domain must be true or false")
        exit()
    if config_win_endpoint['auto_logon_domain_user'].lower() != 'false' and config_win_endpoint[
        'auto_logon_domain_user'].lower() != 'true':
        print("[-] Setting auto_logon_domain_user must be true or false")
        exit()
    if config_win_endpoint['install_sysmon'] != False and config_win_endpoint['install_sysmon'] != True:
        print(config_win_endpoint['install_sysmon'])
        print("[-] Setting install_sysmon must be true or false")
        exit()
    if config_win_endpoint['install_red'] != False and config_win_endpoint['install_red'] != True:
        print("[-] Setting install_red must be true or false")
        exit()

    ### Do some inspection of the subnets to make sure no duplicates
    for subnet in config_subnets:

        # network name
        net_name = subnet['name']
        subnet_names.append(net_name)

        # prefix
        prefix = subnet['prefix']
        subnet_prefixes.append(prefix)

        # type
        type = subnet['type']
        if type == 'user_vlan':
            ## assign the user vlan name variable for later users
            user_subnet_name = net_name
            user_subnet_prefix = prefix
            user_vlan_count += 1
        elif (type == 'ad_vlan'):
            ad_subnet_prefix = prefix
            ad_subnet_name = net_name
            ad_vlan_count += 1
        elif (type == 'siem_vlan'):
            siem_subnet_prefix = prefix
            siem_subnet_name = net_name
            siem_vlan_count += 1
        else:
            pass

    ## Check for duplicate subnet names in config_subnets
    if len(subnet_names) == len(set(subnet_names)):
        # No duplicate subnet names found
        pass
    else:
        print("[-] Duplicate subnet names found")
        print("[-] Please ensure that each subnet name is unique in config_subnets")
        exit()

    ## Check for duplicate subnet prefixes in config_subnets
    if len(subnet_prefixes) == len(set(subnet_prefixes)):
        # No duplicate subnet names found
        pass
    else:
        print("[-] Duplicate subnet prefixes found")
        print("[-] Please ensure that each subnet prefix is unique in config_subnets")
        exit()

    # Check to make sure more than one user_vlan is not enabled
    if user_vlan_count > 1:
        print("[-] user vlans greater than 1.  Please specify one only one user vlan")

    # Check to make sure more than one ad_vlan is not enabled
    if ad_vlan_count > 1:
        print("[-] ad vlans greater than 1.  Please specify one only one ad vlan")

    for prefix in subnet_prefixes:
        retval = check_cidr_subnet(prefix)
        if retval:
            pass
        else:
            print("[-] Invalid CIDR or subnet, exit")
            print("[-] Correct examples include: 10.100.30.0/24")
            print("[-] Correct examples include: 10.100.0.0/16")
            exit()

    ## Get siem_ip if siem is enabled
    if args.siem_enable:
        if siem_vlan_count == 1:
            # This is the last octet of the siem_ip
            last_octet = "4"
            elements = siem_subnet_prefix.split('.')
            siem_ip = elements[0] + "." + elements[1] + "." + elements[2] + "." + last_octet
        else:
            print("[-] siem is enabled without a subnet assignment")
            print("[-] Set a type of siem_vlan to one of the subnets")
            exit()

        if args.siem_enable.lower() != 'elk' and args.siem_enable.lower() != 'splunk':
            print("[-] For SIEM option please select either elk (--siem elk) or splunk (--siem splunk)")
            exit()
        else:
            print("[+] User specified %s SIEM server with IP: %s" % (args.siem_enable, siem_ip))
            logging.info('[+] SIEM server enabled: %s', helk_ip)

    ## Get dc_ip if dc is enabled
    if args.dc_enable:
        if ad_vlan_count == 1:
            # This is the last octet of the helk_ip
            last_octet = "4"
            elements = ad_subnet_prefix.split('.')
            dc_ip = elements[0] + "." + elements[1] + "." + elements[2] + "." + last_octet
        else:
            print("[-] DC is enabled without a subnet assignment")
            print("[-] Set a type of ad_vlan to one of the subnets")
            exit()

    # Nomad orchestration
    if args.nomad_enable:
        print("[+] Nomad orchestration is enabled")
        logging.info('[+] Nomad orchestration is enabled')

    # Ghosts NPC
    if args.ghosts_enable:
        print("[+] Ghosts NPC is enabled")
        logging.info('[+] Ghosts NPC is enabled')

    # Breach and Attack Simulation
    if args.bas_enable:
        print("[+] Breach and Attack Simulation is enabled")
        logging.info('[+] Breach and Attack Simulation is enabled')

    # Get the providers jinja template
    ptemplate = env.get_template('providers.jinja')

    # render the template
    prendered_template = ptemplate.render()

    # Write the providers.tf
    providers_text_file = open(tproviders_file, "w")
    n = providers_text_file.write(prendered_template)
    print("[+] Creating the providers terraform file: ", tproviders_file)
    logging.info('[+] Creating the providers terraform file: %s', tproviders_file)
    providers_text_file.close()
    # Done Building and writing the providers terraform file

    # Build and write the main.tf file

    # Get the jinja main template
    mtemplate = env.get_template('main.jinja')

    # render the template
    mrendered_template = mtemplate.render(region=default_region)

    # Write the main.tf
    main_text_file = open(tmain_file, "w")
    n = main_text_file.write(mrendered_template)
    print("[+] Creating the main terraform file: ", tmain_file)
    logging.info('[+] Creating the main terraform file: %s', tmain_file)
    main_text_file.close()
    # Done Building and writing the main.tf terraform file

    # Build and write the network.tf file

    # Get the network jinja template
    ntemplate = env.get_template('network.jinja')

    # render the template
    nrendered_template = ntemplate.render()

    # open the network.tf
    net_text_file = open(tnet_file, "w")

    # Write network template to networks file
    n = net_text_file.write(nrendered_template)

    ### Loop and write out all subnets
    for subnet in config_subnets:
        # get subnet template
        default_subnet_template = env.get_template('subnet.jinja')

        # network name
        net_name = subnet['name']

        # prefix
        prefix = subnet['prefix']

        # render the subnet template
        subnet_rendered_template = default_subnet_template.render(subnet_name_variable=net_name, subnet_prefix_value=prefix)

        # Write this subnet to networks file
        n= net_text_file.write(subnet_rendered_template)

    print("[+] Creating the network terraform file: ", tnet_file)
    logging.info('[+] Creating the main terraform file: %s', tnet_file)
    net_text_file.close()
    # Done Building and writing the network.tf terraform file

    ### sg.tf - Begin the AWS Security Groups
    # open sg.tf
    sg_text_file = open(tsg_file, "w")

    # get the sg jinja template
    sg_template = env.get_template('sg.jinja')

    # render the sg template
    sg_rendered_template = sg_template.render()

    # Write the sg.tf
    n = sg_text_file.write(sg_rendered_template)
    print("[+] Creating the sg terraform file: ", tsg_file)
    logging.info('[+] Creating the sg terraform file: %s', tsg_file)

    ### sysmon section - If install_sysmon is true, write out a separate terraform file
    ### This allows sysmon to be installed on clients independent of any SIEM configuration
    if install_sysmon_enabled:
        print("[+] Sysmon enabled - Creating sysmon configuration for clients to use",tsysmon_file)

        # get sysmon jinja template
        sysmon_template = env.get_template('sysmon.jinja')

        # render the sysmon template
        sysmon_rendered_template = sysmon_template.render()

        # open sysmon.tf
        sysmon_text_file = open(tsysmon_file, "w")
        n = sysmon_text_file.write(sysmon_rendered_template)
        sysmon_text_file.close()

    # client systems or "endpoints"

    # Get the clients jinja template
    client_template = env.get_template('client.jinja')

    print("[+] Building Windows Client System")
    logging.info('[+] Building the Windows Client System')
    print("  [+] Number of systems to build: ", win_count)
    logging.info('[+] Number of systems to build: %s', win_count)
    if (win_count > 0):
        print("    [+] Getting default configuration template for Windows Client System")
        logging.info('[+] Getting default configuration template for Windows Client System')
        hostname_base = config_win_endpoint['hostname_base']
        print("    [+] Base Hostname:", hostname_base)
        logging.info('[+] Base Hostname: %s', hostname_base)
        admin_username = default_admin_username
        print("    [+] Administrator Username:", admin_username)
        logging.info('[+] Administrator Username: %s', admin_username)
        admin_password = default_admin_password
        print("    [+] Administrator Password:", admin_password)
        logging.info('[+] Administrator Password: %s', admin_password)
        join_domain = config_win_endpoint['join_domain'].lower()
        print("    [+] Join Domain:", join_domain)
        logging.info('[+] Join Domain: %s', join_domain)
        auto_logon_domain_user = config_win_endpoint['auto_logon_domain_user']
        print("    [+] Auto Logon Domain User:", auto_logon_domain_user)
        logging.info('[+] Auto Logon Domain User: %s', auto_logon_domain_user)
        print("    [+] Install Sysmon:", config_win_endpoint['install_sysmon'])
        logging.info('[+] Install Sysmon: %s', config_win_endpoint['install_sysmon'])
        install_red = config_win_endpoint['install_red']
        print("    [+] Install Red Team Tools:", install_red)
        logging.info('[+] Install Red Team Tools: %s', install_red)
        print("    [+] Subnet Association:", user_subnet_name)
        logging.info('[+] Subnet Association: %s', user_subnet_name)

        i = 0
        last_octet_int = int(first_ip_user_subnet)

    for i in range(win_count):

        # number suffix for unique host variable naming
        num_suffix = i + 1

        print("  [+] Building Windows Client System", num_suffix)
        logging.info('[+] Building Windows Client System: %s', num_suffix)
        this_hostname = hostname_base + str(num_suffix)

        print("    [+] Hostname:", this_hostname)
        logging.info('[+] Hostname: %s', this_hostname)
        last_octet_str = str(last_octet_int)
        this_ipaddr = user_subnet_prefix.replace("0/24", last_octet_str)

        print("    [+] IP address:", this_ipaddr)
        logging.info('[+] IP address: %s', this_ipaddr)

        # Get the clients jinja template
        client_template = env.get_template('client.jinja')

        # Initialize a dictionary to store all the template variables
        template_vars = {}

        # render the client template, replacing variables
        new_ip_var_name = "endpoint-ip-" + this_hostname
        template_vars['endpoint_ip_var_name'] = new_ip_var_name
        template_vars['endpoint_ip_default'] = this_ipaddr

        # replace for install_sysmon_enabled
        if install_sysmon_enabled:

            # replace install_sysmon_enabled
            template_vars['install_sysmon'] = "true"

            # replace sysmon config
            template_vars['sysmon_config'] = "local.sysmon_config"

            # replace sysmon zipa
            template_vars['sysmon_zip'] = "local.sysmon_zip"

        else:
            template_vars['install_sysmon'] = "false"
            template_vars['sysmon_config'] = '""'
            template_vars['sysmon_zip'] = '""'

        # ghosts client - writing out custom files for each winclient
        if args.ghosts_enable:
            template_vars['install_ghosts'] = "true"

            # custom timeline.json for each winclient
            template_path = "files/ghosts/timeline.json.tpl"
            data = ""
            with open(template_path) as file:
                data = file.read()

            client_path = "files/ghosts/clients" + "/timeline-" + this_hostname + ".json"
            with open(client_path, 'w') as file:
                file.write(data)
            print("    [+] Creating a Ghosts app config: ", client_path)
            logging.info('[+] Creating a Ghosts app config: %s', client_path)

            # custom bootstrap ps script for each winclient

        else:
            template_vars['install_ghosts'] = "false"

        # replace for siem_enable
        if args.siem_enable:

            # replace windows msi for velociraptor client install
            #template_vars['setting_windows_msi'] = "local.velociraptor_win_zip"
            # Temporary until we get to velociraptor working
            template_vars['setting_windows_msi'] = '""'
            template_vars['setting_vclient_config'] = '""'

            # replace velociraptor client config
            #template_vars['setting_vclient_config'] = "local.vclient_config"

            # replace winlogbeat zip
            template_vars['setting_winlogbeat_zip'] = "var.winlogbeat_zip"

            # replace winlogbeat config
            template_vars['setting_winlogbeat_config'] = "var.winlogbeat_config"

        else:
            template_vars['setting_windows_msi'] = '""'
            template_vars['setting_vclient_config'] = '""'
            template_vars['setting_winlogbeat_zip'] = '""'
            template_vars['setting_winlogbeat_config'] = '""'

        # If auto_logon_domain_user is True, get the default ad user and password
        if auto_logon_domain_user.lower() == 'true':
            print("    [+] Auto Logon Domain user")
            logging.info('[+] Auto Logon Domain user')
            print("      [+] Getting the default ad user and password")
            logging.info('[+] Getting the default ad user and password')
            full_name = ""
            username = ""
            password = ""

            if args.user_csv:
                data = get_random_user(args.user_csv)

                full_name = data[0]
                username = data[1]
                password = data[2]
            else:
                user_dict = random.choice(all_ad_users)
                full_name = user_dict['name']
                password = user_dict['pass']
                names = full_name.split(' ')
                first = names[0]
                last = names[1]
                username = first.lower() + last.lower()

            print("      [+] Auto Logon this Windows client to AD User: ", full_name)
            logging.info('[+] Auto Logon this Windows client to AD User: %s', full_name)
            print("      [+] Username: ", username)
            logging.info('[+] Username: %s', username)
            print("      [+] Password: ", password)
            logging.info('[+] Password: %s', password)

            # replace the ad user / domain user for auto logon
            template_vars['endpoint_ad_user'] = username

            # replace the ad password for auto logon
            template_vars['endpoint_ad_password'] = password


        # replace the variable admin_username
        admin_user_var = "admin-username-" + this_hostname
        template_vars['admin_username_var_name'] = admin_user_var
        template_vars['admin_username_default'] = admin_username

        # replace the variable admin_password
        admin_pass_var = "admin-password-" + this_hostname
        template_vars['admin_password_var_name'] = admin_pass_var
        template_vars['admin_password_default'] = admin_password

        # replace the variable join_domain for this Windows Client System
        template_vars['join_domain_var_name'] = "join-domain-" + this_hostname
        template_vars['join_domain_default'] = join_domain

        # replace the variable endpoint_hostname for this Windows Client System
        template_vars['endpoint_hostname_var_name'] = "endpoint_hostname-" + this_hostname
        template_vars['endpoint_hostname_default'] = this_hostname

        # replace the ps template name for this Windows Client
        template_vars['ps_template_var_name'] = "ps_template_" + this_hostname

        # replace the debug bootstrap script name for this Windows Client
        template_vars['debug_bootstrap_script_var_name'] = "debug-bootstrap-script-" + this_hostname

        # replace the resource name for this Windows Client System
        template_vars['ec2_windows_virtual_machine_var_name'] = this_hostname

        # replace install_red if applicable
        if install_red:
            template_vars['install_red'] = "true"
        else:
            template_vars['install_red'] = "false"

        # replace install_prelude for Prelude Operator for Windows
        if args.bas_enable:
            template_vars['install_prelude'] = "true"
        else:
            template_vars['install_prelude'] = "false"

        # replace DC_IP WinRM, AD Domain if applicable
        if args.dc_enable and config_win_endpoint['join_domain'].lower() == 'true':
            template_vars['dc_ip'] = dc_ip
            print("    [+] Setting Domain Controller for this endpoint to join domain: ", dc_ip)
            logging.info('[+] Setting Domain Controller fore this endpoint to join domain: %s', dc_ip)

            # Replace WinRM Username and password, if applicable
            winrm_user = []
            if args.user_csv:
                winrm_user = get_winrm_user(args.user_csv)
                winrm_username = winrm_user[0]
                template_vars['winrm_username'] = winrm_username

                winrm_password = winrm_user[1]
                template_vars['winrm_password'] = winrm_password

            else:
                template_vars['winrm_username'] = default_winrm_username
                template_vars['winrm_password'] = default_winrm_password

            # Replace the AD Domain
            template_vars['ad_domain'] = default_domain

        else:
            # Replace the Default Domain in locals, for AWS domain configuration for non-domain joined
            template_vars['ad_domain'] = default_domain

        # evaluate the auto_logon setting
        if config_win_endpoint['auto_logon_domain_user'].lower() == "true":
            template_vars['auto_logon_setting'] = "true"
        else:
            template_vars['auto_logon_setting'] = "false"

        this_file = this_hostname + ".tf"
        endpoint_text_file = open(this_file, "w")
        # render the template from dictionary of var templates
        rendered_client_template = client_template.render(template_vars)
        n = endpoint_text_file.write(rendered_client_template)
        print("    [+] Created terraform:", this_file)
        logging.info('[+] Created terraform: %s', this_file)
        endpoint_text_file.close()

        # increment the last octet for each new Windows Client
        last_octet_int += 1
        ### End of build the Windows 10 Pro systems

    # create the terraform for ghosts clients s3
    if win_count > 0:
        if args.ghosts_enable:
            s3_ghosts_client = env.get_template('s3-ghost-clients.jinja')
            s3_ghosts_client_rendered = s3_ghosts_client.render(win_client_count=win_count)
            tf_file = "s3-ghosts.tf"
            s3_ghosts_text_file = open(tf_file, "w")
            n = s3_ghosts_text_file.write(s3_ghosts_client_rendered)
            print("[+] Creating the s3 ghosts terraform file: ", tf_file)
            logging.info('[+] Creating the s3 ghosts terraform file: %s', tf_file)
            s3_ghosts_text_file.close()

    # Build and write s3.tf file
    # Get the s3 jinja template
    s3_template = env.get_template('s3.jinja')

    # s3 rendered template
    s3_rendered_template = s3_template.render()

    # Write the s3.tf
    s3_text_file = open(ts3_file, "w")
    n = s3_text_file.write(s3_rendered_template)
    print("[+] Creating the s3 terraform file: ", ts3_file)
    logging.info('[+] Creating the s3 terraform file: %s', ts3_file)
    s3_text_file.close()
    # Done Building and writing the s3 terraform file

    # Build and write scripts.tf file
    # Get the scripts jinja template
    scripts_template = env.get_template('scripts.jinja')

    # template variables
    template_vars = {}

    # check for install Red, temporary
    install_red_template = '''
    {
      name = "${path.module}/files/windows/red.ps1.tpl"
      variables = {
        s3_bucket = "${aws_s3_bucket.staging.id}"
      }
    },
    '''
    if install_red:
        template_vars['install_red'] = install_red_template
        print("    [+] Adding red.ps1 as s3 object upload")
    else:
        template_vars['install_red'] = ""

    # check for install sysmon
    domain_join = config_win_endpoint['join_domain'].lower()
    #temporary until building DC
    dc_ip = '""'
    install_sysmon_template = env.get_template('install-sysmon.jinja')
    rendered_sysmon_template = install_sysmon_template.render(dc_ip=dc_ip,domain_join=domain_join)

    if install_sysmon_enabled:
        template_vars['install_sysmon'] = rendered_sysmon_template
        print("    [+] Adding sysmon.ps1 as s3 object upload")
    else:
        template_vars['install_sysmon'] = ""

    # install_winlogbeat
    if args.siem_enable:
        if args.siem_enable.lower() == 'elk':
            install_winlogbeat_template = env.get_template('install-winlogbeat.jinja')
            rendered_winlogbeat_template = install_winlogbeat_template.render()
            template_vars['install_winlogbeat'] = rendered_winlogbeat_template
            print("    [+] Adding winlogbeat.ps1 as s3 object upload")
    else:
        template_vars['install_winlogbeat'] = ""

    if args.nomad_enable:
        install_nomad_template = env.get_template('nomad-client.jinja')
        rendered_nomad_template = install_nomad_template.render()
        template_vars['install_nomad'] = rendered_nomad_template
        print("    [+] Adding nomad.ps1 as s3 object upload")
    else:
        template_vars['install_nomad'] = ""

    if args.bas_enable:
        install_prelude_template = env.get_template('prelude-client.jinja')
        rendered_prelude_template = install_prelude_template.render()
        template_vars['install_prelude'] = rendered_prelude_template
        print("    [+] Adding prelude.ps1 as s3 object upload")
    else:
        template_vars['install_prelude'] = ""

    # render from the template_vars dictionary
    rendered_scripts_template = scripts_template.render(template_vars)

    # Write the scripts.tf
    scripts_text_file = open(tscripts_file, "w")
    n = scripts_text_file.write(rendered_scripts_template)
    print("[+] Creating the scripts terraform file: ", tscripts_file)
    logging.info('[+] Creating the scripts terraform file: %s', tscripts_file)
    scripts_text_file.close()
    # Done Building and writing the scripts terraform file

    # Create the nomad server
    if args.nomad_enable:
        nomad_text_file = open(tnomad_file, "w")
        nomad_server_template = env.get_template('nomad-server.jinja')
        rendered_nomad_server_template = nomad_server_template.render()
        n = nomad_text_file.write(rendered_nomad_server_template)
        print("[+] Creating the nomad server terraform file: ", tnomad_file)
        logging.info('[+] Creating the nomad server terraform file: %s', tnomad_file)
        nomad_text_file.close()

    # Create the ghosts server
    if args.ghosts_enable:
        ghosts_text_file = open(tghosts_file, "w")
        ghosts_server_template = env.get_template('ghosts.jinja')
        rendered_ghosts_template = ghosts_server_template.render()
        n = ghosts_text_file.write(rendered_ghosts_template)
        print("[+] Creating the ghosts server terraform file: ", tghosts_file)
        logging.info('[+] Creating the ghosts server terraform file: %s', tghosts_file)
        ghosts_text_file.close()

    # Create the Breach and Attack Simulation System
    # Currently includes Caldera and VECTR
    if args.bas_enable:
        bas_text_file = open(tbas_file, "w")
        bas_server_template = env.get_template('bas.jinja')
        rendered_bas_template = bas_server_template.render()
        n = bas_text_file.write(rendered_bas_template)
        print("[+] Creating the bas server terraform file: ", tbas_file)
        logging.info('[+] Creating the bas server terraform file: %s', tbas_file)
        bas_text_file.close()

    ## Build the siem server config if enabled
    if args.siem_enable:
        if args.siem_enable.lower() == 'elk':
            elk_text_file = open(telk_file, "w")
            elk_server_template = env.get_template('elastic.jinja')
            rendered_elk_template = elk_server_template.render()
            n = elk_text_file.write(rendered_elk_template)
            print("[+] Building terraform for elastic server: ", telk_file)
            elk_text_file.close()

            # render the winlogbeat configuration if there are windows clients
            if win_count > 0:
                winlogbeat_template = env.get_template('winlogbeat.jinja')
                rendered_winlogbeat_template = winlogbeat_template.render()
                winlogbeat_text_file = open(twinlogbeat_file, "w")
                n = winlogbeat_text_file.write(rendered_winlogbeat_template)
                print("[+] Building terraform for winlogbeat: ", twinlogbeat_file)
                winlogbeat_text_file.close()

        elif args.siem_enable.lower() == 'splunk':
            print("[+] Building terraform for splunk server: ", tsplunk_file)
            splunk_text_file = open(tsplunk_file, "w")
            splunk_server_template = env.get_template('splunk.jinja')
            rendered_splunk_template = splunk_server_template.render()
            n = splunk_text_file.write(rendered_splunk_template)
            splunk_text_file.close()

