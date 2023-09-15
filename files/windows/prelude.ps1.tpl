
# Set logfile and function for writing logfile
$logfile = "C:\Terraform\prelude_log.log"
Function lwrite {
    Param ([string]$logstring)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logstring = "$timestamp $logstring"
    Add-Content $logfile -value $logstring
}
lwrite("Starting prelude.ps1")

# Download Prelude Operator for Windows 
if (Test-Path -Path "C:\tools") {
  lwrite("C:\tools exists")
} else {
  lwrite("Creating C:\tools")
  New-Item -Path "C:\tools" -ItemType Directory
}

if (Test-Path -Path "C:\tools\prelude") {
  lwrite("C:\tools\prelude exists")
} else {
  lwrite("Creating C:\tools\prelude")
  New-Item -Path "C:\tools\prelude" -ItemType Directory
}

# Turn off Defender realtime protection so tools can download properly
Set-MpPreference -DisableRealtimeMonitoring $true
# Set AV exclusion path so red team tools can run 
Set-MpPreference -ExclusionPath "C:\Tools" 

# Download Operator 
$MaxAttempts = 5
$TimeoutSeconds = 30
$Attempt = 0

$object_url = "https://" + "${s3_bucket}" + ".s3." + "${region}" + ".amazonaws.com/" + "${filename}"
$outfile = "C:\tools\prelude\" + "${filename}"
$MaxAttempts = 5
$TimeoutSeconds = 30
$Attempt = 0
lwrite("Going to download from S3 bucket: ${s3_bucket}")
lwrite("object url: $object_url")

if (Test-Path -Path $outfile) {
  lwrite("$outfile exists")
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


lwrite("Installing prelude")
& "$outfile" /S

lwrite("End of prelude.ps1")
