

# Set logfile and function for writing logfile
$logfile = "C:\Terraform\ghosts_client_log.log"
Function lwrite {
    Param ([string]$logstring)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logstring = "$timestamp $logstring"
    Add-Content $logfile -value $logstring
}
lwrite("Starting ghosts client bootstrap")

lwrite("s3 bucket: ${s3_bucket}")
lwrite("region: ${region}")
lwrite("hostname: ${hostname}")
lwrite("application_json: ${application_json}")
$timeline_file = "timeline-" + "${hostname}" + ".json"
lwrite("custom timeline for this client: $timeline_file")

#array of filenames
$fileNames = @("${ghosts_zip}", "${application_json}", "$timeline_file") 

lwrite("Going to download from S3 bucket: ${s3_bucket}")
foreach ($filename in $fileNames) {
  lwrite("Processing download for file: $filename")
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
}

# make dir path for c:\tools
if (Test-Path -Path "C:\Tools") {
  lwrite("C:\Tools exists")
} else {
  lwrite("Creating C:\Tools")
  New-Item -Path "C:\Tools" -ItemType Directory
}

# make dir path for c:\Tools\ghosts
if (Test-Path -Path "C:\Tools\ghosts") {
  lwrite("C:\Tools\ghosts exists")
} else {
  lwrite("Creating C:\Tools\ghosts")
  New-Item -Path "C:\Tools\ghosts" -ItemType Directory
}

lwrite("Moving ghosts zip to C:\Tools\ghosts")
Move-Item -Path "C:\Terraform\${ghosts_zip}" -Destination "C:\Tools\ghosts\${ghosts_zip}" 

# Expand the Ghosts zip archive
if (Test-Path -Path "C:\Tools\ghosts\${ghosts_zip}") {
  lwrite("Expand the ghosts zip file")
  Expand-Archive -Force -LiteralPath 'C:\Tools\ghosts\${ghosts_zip}' -DestinationPath 'C:\Tools\ghosts'
} else {
  lwrite("Something wrong - ghosts zip file doesn't exist")
}

$ghosts_dir = "${ghosts_zip}" -replace "\.zip$" 
$configPath = "C:\Tools\ghosts\" + $ghosts_dir + "\config"

$application_json = $configPath + "\application.json" 
lwrite("Copying ${application_json} to $application_json")
Copy-Item "C:\Terraform\${application_json}" -Destination $application_json 

$timeline_json = $configPath + "\timeline.json" 
lwrite("Copying $timeline_file to $timeline_json")
Copy-Item "C:\Terraform\$timeline_file" -Destination $timeline_json 

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

choco install microsoft-office-deployment --Force -y
choco install firefox --Force -y

lwrite("End of ghosts client bootstrap")
