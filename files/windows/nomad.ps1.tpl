
# Set logfile and function for writing logfile
$logfile = "C:\Terraform\nomad_log.log"
Function lwrite {
    Param ([string]$logstring)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logstring = "$timestamp $logstring"
    Add-Content $logfile -value $logstring
}
lwrite("Starting nomad.ps1")

if (Test-Path -Path "C:\tools") {
  lwrite("C:\tools exists")
} else {
  lwrite("Creating C:\tools")
  New-Item -Path "C:\tools" -ItemType Directory
}

if (Test-Path -Path "C:\tools\nomad") {
  lwrite("C:\tools\nomad exists")
} else {
  lwrite("Creating C:\tools\nomad")
  New-Item -Path "C:\tools\nomad" -ItemType Directory
}

if (Test-Path -Path "C:\tools\nomad\data") {
  lwrite("C:\tools\nomad\data exists")
} else {
  lwrite("Creating C:\tools\nomad\data")
  New-Item -Path "C:\tools\nomad\data" -ItemType Directory
}

# Download nomad binaries 
$filename = "nomad_1.6.1_windows_amd64.zip"
$outfile = "C:\Tools\nomad" + $filename 
$uri = "https://releases.hashicorp.com/nomad/1.6.1/" + $filename
$MaxAttempts = 5
$TimeoutSeconds = 30
$Attempt = 0
lwrite("Going to download from uri: $uri")

if (Test-Path -Path $outfile) {
  lwrite("Nomad binary exists")
} else {
  while ($Attempt -lt $MaxAttempts) {
    $Attempt += 1
    lwrite("Attempt: $Attempt")
    try {
        Invoke-WebRequest -Uri "$uri" -OutFile $outfile -TimeoutSec $TimeoutSeconds 
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
}
# Finished Download of Nomad binary 

# Expand the Nomad zip archive
if (Test-Path -Path $outfile) {
  lwrite("Expand the Nomad zip file")
  Expand-Archive -Force -LiteralPath $outfile -DestinationPath 'C:\Tools\nomad\' 
} else {
  lwrite("Something wrong - Nomad zip file doesn't exist")
}

# Download nomad_client.hcl
$config_file = "nomad_client.hcl"
$object_url = "https://" + "${s3_bucket}" + ".s3." + "${region}" + ".amazonaws.com/" + $config_file
$outfile = "C:\Tools\nomad\" + $config_file
$MaxAttempts = 5
$TimeoutSeconds = 30
$Attempt = 0
lwrite("Going to download from S3 bucket: ${s3_bucket}")
lwrite("object url: $object_url")

if (Test-Path -Path $outfile) {
  lwrite("nomad client exists")
} else {
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
}

# Get IP address of Ethernet network interface
$interface = Get-NetAdapter | Where-Object { $_.Name -like "Ethernet *" }
$ipAddress = Get-NetIPAddress -InterfaceIndex $interface.ifIndex | Where-Object { $_.AddressFamily -eq "IPv4" }
$myip = $ipAddress.IPAddress

# update the IP address in nomad_client.hcl
$content = Get-Content "C:\Tools\nomad\nomad_client.hcl"
$newContent = $content -replace "IP_ADDRESS", $myip
$newContent | Set-Content "C:\Tools\nomad\nomad_client.hcl"

# Install Nomad 
lwrite("Install Nomad as a Windows service")
sc.exe create "Nomad" binPath="C:\Tools\nomad\nomad.exe agent -config=C:\Tools\nomad" start= auto
sc.exe start "Nomad"

lwrite("End of Nomad.ps1")
