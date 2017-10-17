$prometheusHome = 'C:/prometheus'
$prometheusServiceName = 'prometheus-service' # NB you cannot change this. its hard-coded in the prometheus chocolatey package.
$prometheusServiceUsername = "NT SERVICE\$prometheusServiceName"

# install prometheus.
choco install -y prometheus --version 1.8.0

$prometheusInstallHome = Split-Path -Parent -Resolve C:\ProgramData\chocolatey\lib\prometheus\tools\prometheus-*\prometheus.exe

# configure the windows service using a managed service account.
Write-Host "Configuring the $prometheusServiceName service..."
nssm set $prometheusServiceName Start SERVICE_AUTO_START
nssm set $prometheusServiceName AppRotateFiles 1
nssm set $prometheusServiceName AppRotateOnline 1
nssm set $prometheusServiceName AppRotateSeconds 86400
nssm set $prometheusServiceName AppRotateBytes 1048576
nssm set $prometheusServiceName AppStdout $prometheusHome\logs\service.log
nssm set $prometheusServiceName AppStderr $prometheusHome\logs\service.log
nssm set $prometheusServiceName AppParameters `
    "-config.file=$prometheusHome/prometheus.yml" `
    "-storage.local.path=$prometheusHome/data" `
    "-storage.local.retention=$(7*24)h" `
    "-web.console.libraries=$prometheusInstallHome/console_libraries" `
    "-web.console.templates=$prometheusInstallHome/consoles" `
    '-web.listen-address=localhost:9090' `
    '-web.external-url=https://prometheus.example.com' `
    '-alertmanager.url=http://localhost:9093'
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

mkdir $prometheusHome | Out-Null
Disable-AclInheritance $prometheusHome
Grant-Permission $prometheusHome SYSTEM FullControl
Grant-Permission $prometheusHome Administrators FullControl
Grant-Permission $prometheusHome $prometheusServiceUsername Read
Copy-Item c:/vagrant/prometheus.yml $prometheusHome
Copy-Item c:/vagrant/*.rules $prometheusHome
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
