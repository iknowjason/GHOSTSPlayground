<powershell>
# Beginning of bootstrap script
# This script bootstraps the Windows system and runs
# extra scripts downloaded from the s3 bucket

$stagingdir = "C:\terraform"

if (-not (Test-Path -Path $stagingdir)) {
    New-Item -ItemType Directory -Path $stagingdir
    Write-Host "Directory created: $stagingdir"
} else {
    Write-Host "Directory already exists: $stagingdir"
}

# Set logfile and function for writing logfile
$logfile = "C:\Terraform\bootstrap_log.log"
Function lwrite {
    Param ([string]$logstring)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logstring = "$timestamp $logstring"
    Add-Content $logfile -value $logstring
}

lwrite("Starting bootstrap powershell script")

# add a local user and add them to Administrators
$admin_username = "${admin_username}"
$admin_password = "${admin_password}"
$op = Get-LocalUser | Where-Object {$_.Name -eq $admin_username}
if ( -not $op ) {
  $secure_string = ConvertTo-SecureString $admin_password -AsPlainText -Force
  New-LocalUser $admin_username -Password $secure_string
  Add-LocalGroupMember -Group "Administrators" -Member $admin_username
  lwrite("User created and added to the Administrators group: $admin_username")
} else {
  lwrite("User already exists: $admin_username")
}

# Set hostname
lwrite("Checking to rename computer to ${hostname}")

$current = $env:COMPUTERNAME

if ($current -ne "${hostname}") {
    Rename-Computer -NewName "${hostname}" -Force
    lwrite("Renaming computer and reboot")
    Restart-Computer -Force
} else {
    lwrite("Hostname already set correctly")
}

lwrite("Going to download from S3 bucket: ${s3_bucket}")
$scriptFilenames = "${script_files}".split(",")
foreach ($filename in $scriptFilenames) {
  lwrite("Processing script: $filename")
  $object_url = "https://" + "${s3_bucket}" + ".s3." + "${region}" + ".amazonaws.com/" + "$filename"
  lwrite("Downloading file: $object_url")
  # Download each file from s3 bucket and run them
  $outfile = "C:\terraform\" + "$filename"

  $MaxAttempts = 5
  $TimeoutSeconds = 30
  $Attempt = 0

  while ($Attempt -lt $MaxAttempts) {
    $Attempt += 1
    lwrite("Attempt: $Attempt")
    try {
        Invoke-WebRequest -Uri "$object_url" -OutFile $outfile -TimeoutSec $TimeoutSeconds
        lwrite("Successful")
        break
    } catch {
        if ($_.Exception.GetType().Name -eq "WebException" -and $_.Exception.Status -eq "Timeout") {
            lwrite("Connection timed out. Retrying...")
        } else {
            lwrite("An unexpected error occurred:")
            lwrite($_.Exception.Message)
            break
        }
    }
  }
  if ($Attempt -eq $MaxAttempts) {
    Write-Host "Reached maximum number of attempts. Continuing..."
  }

  # Run the script
  lwrite("Running $outfile")
  & $outfile
}

# ghosts client bootstrap processing for individual host
$ghosts = "${install_ghosts}"
if ($ghosts -ne "0") {
  lwrite("Download and start ghosts client script for ${hostname}")
  $filename = "ghosts-bootstrap-" + "${hostname}" + ".ps1"

  lwrite("Processing script: $filename")
  $object_url = "https://" + "${s3_bucket}" + ".s3." + "${region}" + ".amazonaws.com/" + "$filename"
  lwrite("Downloading file: $object_url")
  # Download each file from s3 bucket and run them
  $outfile = "C:\terraform\" + "$filename"

  $MaxAttempts = 5
  $TimeoutSeconds = 30
  $Attempt = 0


  while ($Attempt -lt $MaxAttempts) {
    $Attempt += 1
    lwrite("Attempt: $Attempt")
    try {
        Invoke-WebRequest -Uri "$object_url" -OutFile $outfile -TimeoutSec $TimeoutSeconds
        lwrite("Successful")
        break
    } catch {
        if ($_.Exception.GetType().Name -eq "WebException" -and $_.Exception.Status -eq "Timeout") {
            lwrite("Connection timed out. Retrying...")
        } else {
            lwrite("An unexpected error occurred:")
            lwrite($_.Exception.Message)
            break
        }
    }
  }
  if ($Attempt -eq $MaxAttempts) {
    Write-Host "Reached maximum number of attempts. Continuing..."
  }

  # Run the script
  lwrite("Running $outfile")
  & $outfile

} else {
  lwrite("ghosts is not true")
}

#WinRM Config
$ComputerName = "${hostname}"
$RemoteHostName = "${hostname}" + "." + "${ad_domain}"
lwrite("ComputerName: $ComputerName")
lwrite("RemoteHostName: $RemoteHostName")

# Setup WinRM remoting
### Force Enabling WinRM and skip profile check
$mtime = Get-Date
lwrite("Enabling PSRemoting SkipNetworkProfileCheck")
Enable-PSRemoting -SkipNetworkProfileCheck -Force

$mtime = Get-Date
lwrite("Set Execution Policy Unrestricted")
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force

$Cert = New-SelfSignedCertificate -DnsName $RemoteHostName, $ComputerName `
    -CertStoreLocation "cert:\LocalMachine\My" `
    -FriendlyName "Test WinRM Cert"

$Cert | Out-String

$Thumbprint = $Cert.Thumbprint

lwrite("Enable HTTPS in WinRM")
$WinRmHttps = "@{Hostname=`"$RemoteHostName`"; CertificateThumbprint=`"$Thumbprint`"}"
winrm create winrm/config/Listener?Address=*+Transport=HTTPS $WinRmHttps

lwrite("Set Basic Auth in WinRM")
$WinRmBasic = "@{Basic=`"true`"}"
winrm set winrm/config/service/Auth $WinRmBasic

lwrite("Open Firewall Ports")
netsh advfirewall firewall add rule name="Windows Remote Management (HTTP-In)" dir=in action=allow protocol=TCP localport=5985
netsh advfirewall firewall add rule name="Windows Remote Management (HTTPS-In)" dir=in action=allow protocol=TCP localport=5986

### Force Enabling WinRM and skip profile check
Enable-PSRemoting -SkipNetworkProfileCheck -Force

# Set Trusted Hosts * for WinRM HTTPS
Set-Item -Force wsman:\localhost\client\trustedhosts *

# Begin Domain Join Section
# Check the domain join variable passed in from Terraform
# If it is set to 1, then set a domain_join boolean to True
$jd = "${join_domain}"
$mtime = Get-Date
if ( $jd -eq 1 ) {
  lwrite("$mtime Join Domain is set to true")
  lwrite("$mtime WinRM username is ${winrm_username}")
  # Set the DNS to be the domain controller only if domain joined
  $myindex = Get-Netadapter -Name "Ethernet*" | Select-Object -ExpandProperty IfIndex
  Set-DNSClientServerAddress -InterfaceIndex $myindex -ServerAddresses "${dc_ip}"
  lwrite("$mtime Set DNS to be DC since attempting to domain join")

  # Test if actually joined to the domain
  if ((gwmi win32_computersystem).partofdomain -eq $true) {
    $mtime = Get-Date
    lwrite("$mtime Joined to a domain")

  } else {

    # In this case, we are not joined to the Domain
    # So we are going to use WinRM to join to the Domain
    $mtime = Get-Date
    lwrite("$mtime Not joined to AD Domain - attempting to join")

    ### set the WinRM DA password
    $userpassword = "${winrm_password}"

    ## this prefix
    $splits = "${ad_domain}".split(".")

    ## Get first part
    $prefix = $splits[0]

    ### Set the DA Username
    $username = $prefix.ToUpper() + "\" + "${winrm_username}"
    lwrite("$mtime Testing WinRM with AD credentials before domain join")
    lwrite("$mtime WinRM DA username: $username")
    lwrite("$mtime WinRM DA password: $userpassword")

    # set the secure string password
    $secstringpassword = ConvertTo-SecureString $userpassword -AsPlainText -Force

    # Create a credential object
    $credObject = New-Object System.Management.Automation.PSCredential ($username, $secstringpassword)

    # Domain Controller IP
    $ad_ip = "${dc_ip}"
    lwrite("$mtime DC: $ad_ip")

    # The remote WinRM username for checking DA ability to authenticate
    $winrm_check = $username

    # Current hostname
    $chostname = $env:COMPUTERNAME

    $mtime = Get-Date

    lwrite("$mtime Testing WinRM Authentication for Invoke-Command of whoami")
    $success = $false

    # The AD Domain to join to
    $mydomain = "${ad_domain}"

    while (-not $success) {
      # Invoke a remote command using WinRM
      $op = Invoke-Command -ComputerName $ad_ip -ScriptBlock { try { whoami} catch { return $_ } } -credential $credObject

      lwrite("op returns: $op")
      lwrite("winrm_check: $winrm_check")

      if ($op -contains $winrm_check) {
        $mtime = Get-Date
        $success = $true
        lwrite("$mtime Successful WinRM Invoke-Command for Domain Join section!")

        # Join this computer to the domain
        $mtime = Get-Date
        lwrite("$mtime Attempting to join the computer to the domain")
        lwrite("$mtime Computer:  $chostname")
        lwrite("$mtime Domain:  $mydomain")

        # Join domain over PSCredential object
        Add-Computer -ComputerName $chostname -DomainName $mydomain -Credential $credObject -Restart -Force
        $mtime = Get-Date
        lwrite("$mtime Joined to the domain and now rebooting")
      } else {
        $mtime = Get-Date
        lwrite("$mtime WinRM to DC not successful, sleeping")
        Start-Sleep -Seconds 60
      }
    }
  }
} else {
  lwrite("$mtime Join Domain is set to false")
} 


</powershell>
<persist>true</persist>
