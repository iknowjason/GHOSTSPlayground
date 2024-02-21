
# Set logfile and function for writing logfile
$logfile = "C:\Terraform\velociraptor_log.log"
Function lwrite {
    Param ([string]$logstring)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logstring = "$timestamp $logstring"
    Add-Content $logfile -value $logstring
}
lwrite("Starting velociraptor.ps1")

# Download velociraptor client windows MSI
$uri = "${client_uri}" 
lwrite("Downloading velociraptor client from $uri")

$a = 0
do {
  lwrite("Iteration $a")
  (New-Object System.Net.WebClient).DownloadFile($uri, 'C:\terraform\${windows_msi}')
  $a++
  Start-Sleep -Seconds 5
} until ($a -eq 5 -Or (Test-Path -Path "C:\terraform\${windows_msi}" -PathType Leaf))

lwrite("Downloaded windows client MSI")

lwrite("Creating Program Files Velociraptor Directory")
New-Item "C:\Program Files\Velociraptor" -ItemType Directory

# Download velociraptor client configuration
lwrite("Download velociraptor client configuration")
$uri = "https://${s3_bucket}.s3.${region}.amazonaws.com/${client_config}"
lwrite("uri: $uri")
$a = 0
do {
  lwrite("Iteration $a")
  (New-Object System.Net.WebClient).DownloadFile($uri, "C:\terraform\${client_config}")
  $a++
  Start-Sleep -Seconds 5
} until ($a -eq 5 -Or (Test-Path -Path "C:\terraform\${client_config}" -PathType Leaf))

# Install the velociraptor MSI with quiet mode
lwrite("Install velociraptor with quiet mode")

# Verify service is running
$a = 0
do {
  lwrite("Iteration $a")
  (Start-Process "msiexec.exe" -ArgumentList "/I C:\terraform\${windows_msi} /quiet")
  $a++
  Start-Sleep -Seconds 5
  $retval = Get-Service -name "velociraptor"
} until ($a -eq 5 -Or $retval.Status -eq "Running")
lwrite("Velociraptor service running")

# Copy the client config file
Copy-Item -Force "C:\terraform\${client_config}" -Destination "C:\Program Files\velociraptor\client.config.yaml"

# Restart velociraptor service after copying client config 
Restart-Service -Name velociraptor 

lwrite("End of velociraptor.ps1")
