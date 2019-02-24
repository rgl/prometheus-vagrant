$prometheusHome = 'C:/prometheus'
$prometheusServiceName = 'prometheus-service' # NB you cannot change this. its hard-coded in the prometheus chocolatey package.
$prometheusServiceUsername = "NT SERVICE\$prometheusServiceName"

# download and install prometheus.
$archiveUrl = 'https://github.com/prometheus/prometheus/releases/download/v2.7.1/prometheus-2.7.1.windows-amd64.tar.gz'
$archiveHash = '9b62202cce19cdde1edca6e421c85fe5080b06c02ef61b194ca476f52216b758'
$archiveName = Split-Path $archiveUrl -Leaf
$archiveTarName = $archiveName -replace '\.gz',''
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading Prometheus...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing Prometheus...'
mkdir $prometheusHome | Out-Null
Import-Module C:\ProgramData\chocolatey\helpers\chocolateyInstaller.psm1
Get-ChocolateyUnzip -FileFullPath $archivePath -Destination $prometheusHome
Get-ChocolateyUnzip -FileFullPath $prometheusHome\$archiveTarName -Destination $prometheusHome
Remove-Item $prometheusHome\$archiveTarName
$prometheusArchiveTempPath = Resolve-Path $prometheusHome\prometheus-*
Move-Item $prometheusArchiveTempPath\* $prometheusHome
Remove-Item $prometheusArchiveTempPath
Remove-Item $archivePath

$prometheusInstallHome = $prometheusHome

# configure the windows service using a managed service account.
Write-Host "Configuring the $prometheusServiceName service..."
nssm install $prometheusServiceName $prometheusInstallHome\prometheus.exe
nssm set $prometheusServiceName Start SERVICE_AUTO_START
nssm set $prometheusServiceName AppRotateFiles 1
nssm set $prometheusServiceName AppRotateOnline 1
nssm set $prometheusServiceName AppRotateSeconds 86400
nssm set $prometheusServiceName AppRotateBytes 1048576
nssm set $prometheusServiceName AppStdout $prometheusHome\logs\service-stdout.log
nssm set $prometheusServiceName AppStderr $prometheusHome\logs\service-stderr.log
nssm set $prometheusServiceName AppDirectory $prometheusInstallHome
nssm set $prometheusServiceName AppParameters `
    "--config.file=$prometheusHome/prometheus.yml" `
    "--storage.tsdb.path=$prometheusHome/data" `
    "--storage.tsdb.retention=$(7*24)h" `
    "--web.console.libraries=$prometheusInstallHome/console_libraries" `
    "--web.console.templates=$prometheusInstallHome/consoles" `
    '--web.listen-address=localhost:9090' `
    '--web.external-url=https://prometheus.example.com'
$result = sc.exe sidtype $prometheusServiceName unrestricted
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe sidtype failed with $result"
}
$result = sc.exe config $prometheusServiceName obj= $prometheusServiceUsername
if ($result -ne '[SC] ChangeServiceConfig SUCCESS') {
    throw "sc.exe config failed with $result"
}
$result = sc.exe failure $prometheusServiceName reset= 0 actions= restart/1000
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe failure failed with $result"
}

Disable-AclInheritance $prometheusHome
Grant-Permission $prometheusHome SYSTEM FullControl
Grant-Permission $prometheusHome Administrators FullControl
Grant-Permission $prometheusHome $prometheusServiceUsername ReadAndExecute
Copy-Item c:/vagrant/prometheus.yml $prometheusHome
Copy-Item c:/vagrant/*-rules.yml $prometheusHome
mkdir $prometheusHome/tls | Out-Null
Copy-Item c:/vagrant/shared/prometheus-example-ca/prometheus.example.com-client-crt.pem $prometheusHome/tls
Copy-Item c:/vagrant/shared/prometheus-example-ca/prometheus.example.com-client-key.pem $prometheusHome/tls
Copy-Item c:/vagrant/shared/prometheus-example-ca/prometheus-example-ca-crt.pem $prometheusHome/tls
'data','logs' | ForEach-Object {
    mkdir $prometheusHome/$_ | Out-Null
    Disable-AclInheritance $prometheusHome/$_
    Grant-Permission $prometheusHome/$_ SYSTEM FullControl
    Grant-Permission $prometheusHome/$_ Administrators FullControl
    Grant-Permission $prometheusHome/$_ $prometheusServiceUsername FullControl
}

Write-Host "Checking the prometheus configuration..."
&"$prometheusInstallHome\promtool.exe" check config $prometheusHome/prometheus.yml

Write-Host "Starting the $prometheusServiceName service..."
Start-Service $prometheusServiceName

# add default desktop shortcuts (called from a provision-base.ps1 generated script).
[IO.File]::WriteAllText(
    "$env:USERPROFILE\ConfigureDesktop-Prometheus.ps1",
@'
[IO.File]::WriteAllText(
    "$env:USERPROFILE\Desktop\Prometheus.url",
    @"
[InternetShortcut]
URL=https://prometheus.example.com
"@)
'@)
