# Install Active Directory on DC 


$logfile = "C:\Terraform\ad_install.log"
Function lwrite {
    Param ([string]$logstring)
    Add-Content $logfile -value $logstring
}
$mtime = Get-Date
lwrite("$mtime Starting script")

$forest = "${ad_domain}"
$forest_elements = $forest.split(".")
$ParentOU = "DC=" + $forest_elements[0] + ",DC=" + $forest_elements[1]
$s3_bucket = "${s3_bucket}"
$region    = "${region}"
$users_file = "${users_file}"
$admin_username = "${admin_username}"
$admin_password = "${admin_password}"
# Set secure string password
$secure_string = ConvertTo-SecureString $admin_password -AsPlainText -Force

# Install ADDSDeployment module
if (-not (Get-Module -ListAvailable -Name ADDSDeployment)) {
    Import-Module ADDSDeployment
    $mtime = Get-Date
    lwrite("$mtime ADDSDeployment module imported successfully")
} else {
    lwrite("$mtime ADDSDeployment module is already installed")
}

lwrite ("$mtime Starting to verify AD forest for AD DS install")
$op = Get-WMIObject Win32_NTDomain | Select -ExpandProperty DnsForestName

# Check if forest is verified
if ( $op -Contains $forest ){

  $mtime = Get-Date
  lwrite ("$mtime Verified AD forest is already set to $forest")

} else {
  # Install AD
  lwrite ("$mtime Add Windows feature AD Domain Services")
  Add-WindowsFeature -name ad-domain-services -IncludeManagementTools

  lwrite ("$mtime Run Install-ADDSForest")
  Install-ADDSForest -DomainName $forest -InstallDns -SafeModeAdministratorPassword $secure_string -Force:$true
  lwrite ("$mtime Run shutdown")
  shutdown -r -t 10
}

lwrite("$mtime users file: $users_file")
$mtime = Get-Date
lwrite ("$mtime Starting to verify AD forest for AD users")
$op = Get-WMIObject Win32_NTDomain | Select -ExpandProperty DnsForestName

# Check if forest is verified
if ( $op -Contains $forest ){

  $mtime = Get-Date
  lwrite ("$mtime Verified AD forest is set to $forest")

  $mtime = Get-Date
  lwrite ("$mtime Checking to add Domain Users to $forest AD Domain")

  $dst = "C:\terraform\${users_file}"
  $filename = "${users_file}"
  if ( Test-Path $dst ) {
    lwrite("$mtime File already exists: $dst")
  } else {
    lwrite ("$mtime Downloading ad users list from staging S3 bucket")
    $uri = "https://" + "${s3_bucket}" + ".s3." + "${region}" + ".amazonaws.com/" + "$filename"
    lwrite ("$mtime Uri: $uri")
    Invoke-WebRequest -Uri $uri -OutFile $dst
  } 

  # Active Directory users array/collection to be imported into AD 
  $ADUsers = @()

  # Parse the CSV
  if ( Test-Path $dst ) {
    lwrite ("$mtime Importing AD users from csv: $dst")
    $ADUsers = Import-Csv -Path $dst 
  }

  # Get the unique Active Directory Groups in the array
  $adgroups = @()
  foreach($item in $ADUsers){
    $group = $item.Groups
    $adgroups += $group
  }

  # get unique AD groups
  $sorted_groups = $adgroups | Sort-Object | Get-Unique 

  # Loop through the unique AD groups and add OUs and Groups
  foreach($group in $sorted_groups) {

    # Get unique AD Group from list
    $gr = $group

    # Checking on adding this Group and OU for name below
    lwrite("$mtime Checking to add new OU and AD Group:  $gr")

    # Create new OU string 
    $newOU = "OU=$gr,$ParentOU"
    lwrite("$mtime New OU:  $newOU")
    
    try {
      $retval = Get-ADOrganizationalUnit -Identity $newOU | Out-Null
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
      lwrite("$mtime Adding $newOU")
      New-ADOrganizationalUnit -Name $gr -Path $parentOU
    }
 
    # check to add the AD Group
    $exists = Get-ADGroup -Filter {SamAccountName -eq $gr}
    If ($exists) {
      lwrite("$mtime AD Group already exists: $gr")
    } else {
      lwrite("$mtime Creating AD Group: $gr")
      New-ADGroup -Name $gr -SamAccountName $gr -GroupCategory Security -GroupScope Global -DisplayName $gr -Path $newOU -Description "Members of the $gr team"
    }
    
  }

  foreach ($User in $ADUsers) {

      # Get name
      $name = $User.name
      lwrite("$mtime Adding AD User $name")

      # Split the names
      $names = $name.Split(" ")

      # First Name
      $first = $names[0]

      # Last Name
      $last = $names[1]

      # Set username
      $Username = $first.ToLower() + $last.ToLower() 

      # Set password
      $Pass = $User.password
      lwrite("$mtime With password $Pass")

      # Set ou
      $OU = $User.oupath
    
      # Get the Group
      $Group = $User.groups

      # Set the path for this AD User 
      $path = "OU=$Group,$ParentOU"

      # set sam name username
      $Sam = $Username

      # set UPN
      $UPN = $Username + "@" + "${ad_domain}"

      # Set password
      $Password = $Pass | ConvertTo-SecureString -AsPlainText -Force

      # Set domain_admin property
      $DA = $User.domain_admin 
      lwrite ("$mtime DA Setting $DA")

      #Check to see if the user already exists in AD
      if (Get-ADUser -F {SamAccountName -eq $Username}) {
        Write-Warning "A user account with username $Username already exists in AD."
      } else {
        New-AdUser -SamAccountName $Username -UserPrincipalName $UPN -Name $name -GivenName $first -Surname $last -Path $path -AccountPassword $Password -ChangePasswordAtLogon $False -Enabled $True
        $mtime = Get-Date
        lwrite ("$mtime Username added: $Username to OUPath $path")

        # Add user to their mapped AD Group
        lwrite ("$mtime Username added to AD Group: $Group")
        Add-ADGroupMember -Identity $Group -Members $Sam 

        if ($DA -eq "True") {
          lwrite ("$mtime Username added to Domain Admins Group: $Username")
          Add-ADGroupMember -Identity "Domain Admins" -Members $Sam 

        }
      }
  }

} else {
    $mtime = Get-Date
    lwrite ("$mtime Could not verify AD forest is set to $forest")
}

$mtime = Get-Date
lwrite ("$mtime Download Azure AD Connect msi")
# Download the Azure AD Connect msi
$path = "C:\Users\${admin_username}\Desktop\AzureADConnect.msi"a
$uri = "https://download.microsoft.com/download/B/0/0/B00291D0-5A83-4DE7-86F5-980BC00DE05A/AzureADConnect.msi"
if ( Test-Path $path ) {
  lwrite("$mtime File already exists: $path")
} else {
  lwrite ("$mtime Downloading Azure AD Connect msi from staging container")
  lwrite ("$mtime Uri: $uri")
  Invoke-WebRequest -Uri $uri -OutFile $path
}

$mtime = Get-Date
lwrite ("$mtime End of bootstrap script")
