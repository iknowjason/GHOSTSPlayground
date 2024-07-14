
# Set logfile and function for writing logfile
$logfile = "C:\Terraform\winlogbeat_log.log"
Function lwrite {
    Param ([string]$logstring)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logstring = "$timestamp $logstring"
    Add-Content $logfile -value $logstring
}
lwrite("Starting winlogbeat.ps1")

# Set DNS resolver to google
lwrite("Setting DNS resolver to public DNS")
$myindex = Get-Netadapter -Name "Ethernet" | Select-Object -ExpandProperty IfIndex
  Set-DNSClientServerAddress -InterfaceIndex $myindex -ServerAddresses "8.8.8.8"

# Download winlogbeat yml configuration 
$object_url = "https://" + "${s3_bucket}" + ".s3." + "${region}" + ".amazonaws.com/" + "${winlogbeat_config}"
$outfile = "C:\terraform\" + "${winlogbeat_config}"
$MaxAttempts = 5
$TimeoutSeconds = 30
$Attempt = 0
lwrite("Going to download from S3 bucket: ${s3_bucket}")
lwrite("object url: $object_url")

if (Test-Path -Path "C:\Terraform\${winlogbeat_config}") {
  lwrite("winlogbeat yml config exists")
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
# Finished Download of winlogbeat config yml 


# Download Winlogbeat zip 
$object_url = "https://" + "${s3_bucket}" + ".s3." + "${region}" + ".amazonaws.com/" + "${winlogbeat_zip}"
$outfile = "C:\terraform\" + "${winlogbeat_zip}"
$MaxAttempts = 5
$TimeoutSeconds = 30
$Attempt = 0
lwrite("Going to download from S3 bucket: ${s3_bucket}")
lwrite("object url: $object_url")

if (Test-Path -Path "C:\Terraform\${winlogbeat_zip}") {
  lwrite("sysmon zip exists")
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
# Finished Download of Winlogbeat zip

# Expand the Sysmon zip archive
if (Test-Path -Path "C:\Terraform\${winlogbeat_zip}") {
  lwrite("Expand the winlogbeat zip file")
  Expand-Archive -Force -LiteralPath 'C:\terraform\${winlogbeat_zip}' -DestinationPath 'C:\terraform\winlogbeat' 
} else {
  lwrite("Something wrong - winlogbeat zip file doesn't exist")
}

# Copy the winlogbeat yml configuration file to destination winlogbeat folder 
lwrite("Copy the Winlogbeat configuration to destination Winlogbeat folder")
Copy-Item "C:\terraform\winlogbeat.yml" -Destination "C:\terraform\winlogbeat\winlogbeat-8.9.1-windows-x86_64"

# Copy the Winlogbeat folder to C:\ProgramData
lwrite("Copy the Winlogbeat folder to C:\ProgramData")
Copy-Item "C:\terraform\winlogbeat\winlogbeat-8.9.1-windows-x86_64" -Destination "C:\ProgramData\Winlogbeat" -Recurse

# Install the Winlogbeat service
lwrite("Install the Winlogbeat service using included powershell script")
C:\ProgramData\Winlogbeat\install-service-winlogbeat.ps1

# In the section below, check to see if elastisearch port 9200 and kibana 5601 are open
# Import required namespace for TCP Client
Add-Type -TypeDefinition @"
    using System;
    using System.Net;
    using System.Net.Sockets;
    using System.Security.Cryptography.X509Certificates;
    using System.Net.Security;
    using System.Text;

    public class TcpChecker {
        public static bool CheckPort(string ip, int port) {
            using (TcpClient client = new TcpClient()) {
                try {
                    client.Connect(ip, port);
                    using (SslStream sslStream = new SslStream(client.GetStream(), false, new RemoteCertificateValidationCallback((sender, certificate, chain, errors) => { return true; }))) {
                        sslStream.AuthenticateAsClient(ip);
                        return true;
                    }
                } catch (Exception) {
                    return false;
                }
            }
        }
    }
"@

$ipAddress = "${ip_address}"

# Loop to check if elasticsearch port 9200 is open 
$port = 9200
while ($true) {
    lwrite("Checking elasticsearch port $port on $ipAddress")
    $portOpen = [TcpChecker]::CheckPort($ipAddress, $port)
    if ($portOpen) {
        lwrite("Port $port is open on $ipAddress")
        break
    }
    lwrite("Port $port is not open on $ipAddress. Retrying in 10 seconds")
    Start-Sleep -Seconds 10
}

# Loop to check if kibana port 5601 is open
$port = 5601 
while ($true) {
    lwrite("Checking kibana port $port on $ipAddress")
    $portOpen = [TcpChecker]::CheckPort($ipAddress, $port)
    if ($portOpen) {
        lwrite("Port $port is open on $ipAddress")
        break
    }
    lwrite("Port $port is not open on $ipAddress. Retrying in 10 seconds")
    Start-Sleep -Seconds 10
}

# Start the Winlogbeat service
lwrite("Setup pipelines and dashboards")
cd "C:\ProgramData\winlogbeat"
C:\ProgramData\Winlogbeat\winlogbeat.exe setup --pipelines
C:\ProgramData\Winlogbeat\winlogbeat.exe setup --dashboards
lwrite("Start the Winlogbeat service")
start-service winlogbeat

lwrite("End of winlogbeat.ps1")
