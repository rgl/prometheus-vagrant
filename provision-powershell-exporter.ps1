$serviceHome = 'C:\powershell-exporter'
$serviceName = 'PowerShellExporter'

# install powershell-exporter.
$archiveUrl = 'https://github.com/rgl/PowerShellExporter/releases/download/v0.0.1/PowerShellExporter.zip'
$archiveHash = 'aa4d761fd4372c61762e2f5148161b3744c1ceb7a446a279bc457fed11508bd5'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading powershell-exporter...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing powershell-exporter...'
Expand-Archive $archivePath $serviceHome

Write-Host "Installing the $serviceName service..."
&"$serviceHome\PowerShellExporter" install

Write-Host "Starting the $serviceName service..."
Start-Service $serviceName

# add default desktop shortcuts (called from a provision-base.ps1 generated script).
[IO.File]::WriteAllText(
    "$env:USERPROFILE\ConfigureDesktop-powershell-exporter.ps1",
@'
[IO.File]::WriteAllText(
    "$env:USERPROFILE\Desktop\PowerShell Exporter.url",
    @"
[InternetShortcut]
URL=https://prometheus.example.com:9009/pse/metrics
"@)
'@)
