$serviceHome = 'C:/blackbox-exporter'
$serviceName = 'prometheus-blackbox-exporter'
$serviceUsername = '.\blackbox-exporter'
$servicePassword = 'HeyH0Password!'
$serviceCredential = New-Object PSCredential $serviceUsername,(ConvertTo-SecureString $servicePassword -AsPlainText -Force)

# create the service local account.
Install-User -Credential $serviceCredential
Grant-Privilege $serviceUsername SeServiceLogonRight

# install the blackbox-exporter.
choco install -y prometheus-blackbox-exporter -Version 0.10.0
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
sc.exe failure $serviceName reset= 0 actions= restart/1000
nssm set $serviceName ObjectName $serviceUsername $servicePassword
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
