$serviceHome = 'C:/blackbox-exporter'
$serviceName = 'prometheus-blackbox-exporter'
$serviceUsername = "NT SERVICE\$serviceName"

# install blackbox-exporter.
choco install -y prometheus-blackbox-exporter --version 0.10.0

# configure the windows service to use a managed service account.
Write-Host "Configuring the $serviceName service..."
nssm set $serviceName Start SERVICE_AUTO_START
nssm set $serviceName AppRotateFiles 1
nssm set $serviceName AppRotateOnline 1
nssm set $serviceName AppRotateSeconds 86400
nssm set $serviceName AppRotateBytes 1048576
nssm set $serviceName AppStdout $serviceHome\logs\service.log
nssm set $serviceName AppStderr $serviceHome\logs\service.log
nssm set $serviceName AppParameters `
    '--web.listen-address=localhost:9115' `
    "--config.file=$serviceHome/conf/blackbox.yml"
$result = sc.exe sidtype $serviceName unrestricted
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe sidtype failed with $result"
}
$result = sc.exe config $serviceName obj= $serviceUsername
if ($result -ne '[SC] ChangeServiceConfig SUCCESS') {
    throw "sc.exe config failed with $result"
}
$result = sc.exe failure $serviceName reset= 0 actions= restart/1000
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe failure failed with $result"
}

# configure the blackbox-exporter service.
mkdir $serviceHome | Out-Null
Disable-AclInheritance $serviceHome
Grant-Permission $serviceHome SYSTEM FullControl
Grant-Permission $serviceHome Administrators FullControl
Grant-Permission $serviceHome $serviceUsername Read
mkdir $serviceHome/conf | Out-Null
Copy-Item c:/vagrant/blackbox.yml $serviceHome/conf
mkdir $serviceHome/logs | Out-Null
Disable-AclInheritance $serviceHome/logs
Grant-Permission $serviceHome/logs SYSTEM FullControl
Grant-Permission $serviceHome/logs Administrators FullControl
Grant-Permission $serviceHome/logs $serviceUsername FullControl

Write-Host "Starting the $serviceUsername service..."
Start-Service $serviceName

# give it a try.
(Invoke-RestMethod 'http://localhost:9115/probe?target=ruilopes.com&module=http_2xx') -split '\r?\n' | Where-Object {$_ -match '^probe_(success|duration_seconds|ssl_earliest_cert_expiry) .+'}
(Invoke-RestMethod 'http://localhost:9115/probe?target=https://ruilopes.com&module=http_2xx') -split '\r?\n' | Where-Object {$_ -match '^probe_(success|duration_seconds|ssl_earliest_cert_expiry) .+'}

# add default desktop shortcuts (called from a provision-base.ps1 generated script).
[IO.File]::WriteAllText(
    "$env:USERPROFILE\ConfigureDesktop-Blackbox-Exporter.ps1",
@'
[IO.File]::WriteAllText(
    "$env:USERPROFILE\Desktop\Blackbox Exporter.url",
    @"
[InternetShortcut]
URL=https://prometheus.example.com:9115
"@)
'@)
