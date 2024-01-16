
# Set logfile and function for writing logfile
$logfile = "C:\Terraform\cloudwatch_log.log"
Function lwrite {
    Param ([string]$logstring)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logstring = "$timestamp $logstring"
    Add-Content $logfile -value $logstring
}
lwrite("Starting cloudwatch.ps1")

lwrite("Download and start cloudwatch")
$filename = "amazon-cloudwatch-agent.msi"

lwrite("Downloading: $filename")
$object_url = "https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi"
lwrite("Downloading file: $object_url")

# Download file from remote url
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
  lwrite("Reached maximum number of attempts")
}

# Install the agent
lwrite("Install cloudwatch agent")
msiexec /i "c:\terraform\amazon-cloudwatch-agent.msi"

# Download the cloudwatch.config.json file from s3
lwrite("Download cloudwatch.config.json")
$filename = "cloudwatch.config.json"

lwrite("Downloading file: $filename")
$object_url = "https://" + "${s3_bucket}" + ".s3." + "${region}" + ".amazonaws.com/" + "$filename"
lwrite("Downloading file: $object_url")
$outfile = "C:\terraform\" + "config.json"

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
  lwrite("Reached maximum number of attempts. Continuing...")
}

$source = "C:\terraform\config.json"
$destination = "C:\Program Files\Amazon\AmazonCloudWatchAgent\config.json"
$attempts = 0

while ($attempts -lt 5) {
    try {
        lwrite("Attempt: $attempts")
        Copy-Item -Path $source -Destination $destination -ErrorAction Stop
        if (Test-Path -Path $destination) {
            lwrite("File copied successfully attempt: $attempts")
            break
        }
    } catch {
        lwrite("Attempt failed: $attempts")
    }
    $attempts++
    Start-Sleep -Seconds 5
}

if ($attempts -eq 5) {
    lwrite("Failed to copy file after 5 attempts")
}

# Run command to fetch logs and config
lwrite("Run command to fetch logs and config")
cd "C:\Program Files\Amazon\AmazonCloudWatchAgent\"
& .\amazon-cloudwatch-agent-ctl.ps1 -a fetch-config -m ec2 -c file:config.json -s


lwrite("End of cloudwatch.ps1")
