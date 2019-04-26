Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"

$serviceHome = 'C:\performance-counters-exporter'
$serviceName = 'PerformanceCountersExporter'

# install performance-counters-exporter.
$archiveUrl = 'https://github.com/rgl/PerformanceCountersExporter/releases/download/v0.0.5/PerformanceCountersExporter.zip'
$archiveHash = 'ff2e4de7c367abf12419659e968fa2c70fe6c783e6b5c7b68f3ef49b8d49c516'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading performance-counters-exporter...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing performance-counters-exporter...'
Get-ChocolateyUnzip -FileFullPath $archivePath -Destination $serviceHome

Write-Host "Installing the $serviceName service..."
&"$serviceHome\PerformanceCountersExporter" install

Write-Host "Starting the $serviceName service..."
Start-Service $serviceName

# add default desktop shortcuts (called from a provision-base.ps1 generated script).
[IO.File]::WriteAllText(
    "$env:USERPROFILE\ConfigureDesktop-performance-counters-exporter.ps1",
@'
[IO.File]::WriteAllText(
    "$env:USERPROFILE\Desktop\Performance Counters Exporter.url",
    @"
[InternetShortcut]
URL=https://prometheus.example.com:9009/pce/metrics
"@)
'@)
