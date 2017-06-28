$prometheusHome = 'C:/prometheus'
$prometheusServiceName = 'prometheus-service'
$prometheusServiceUsername = '.\prometheus'
$prometheusServicePassword = 'HeyH0Password!'
$prometheusServiceCredential = New-Object PSCredential $prometheusServiceUsername,(ConvertTo-SecureString $prometheusServicePassword -AsPlainText -Force)

# create the prometheus local account.
Install-User -Credential $prometheusServiceCredential
Grant-Privilege $prometheusServiceUsername SeServiceLogonRight

# install prometheus.
choco install -y prometheus
$prometheusInstallHome = Split-Path -Parent -Resolve C:\ProgramData\chocolatey\lib\prometheus\tools\prometheus-*\prometheus.exe
mkdir $prometheusHome | Out-Null
Disable-AclInheritance $prometheusHome
Grant-Permission $prometheusHome SYSTEM FullControl
Grant-Permission $prometheusHome Administrators FullControl
Grant-Permission $prometheusHome $prometheusServiceUsername FullControl
Copy-Item c:/vagrant/prometheus.yml $prometheusHome
mkdir $prometheusHome/data | Out-Null
mkdir $prometheusHome/logs | Out-Null
sc.exe failure $prometheusServiceName reset= 0 actions= restart/1000
nssm set $prometheusServiceName ObjectName $prometheusServiceUsername $prometheusServicePassword
nssm set $prometheusServiceName Start SERVICE_AUTO_START
nssm set $prometheusServiceName AppRotateFiles 1
nssm set $prometheusServiceName AppRotateOnline 1
nssm set $prometheusServiceName AppRotateSeconds 86400
nssm set $prometheusServiceName AppRotateBytes 1048576
nssm set $prometheusServiceName AppStdout $prometheusHome\logs\service.log
nssm set $prometheusServiceName AppStderr $prometheusHome\logs\service.log
nssm set $prometheusServiceName AppParameters `
    "-config.file=$prometheusHome/prometheus.yml" `
    '-web.listen-address=localhost:9090' `
    "-storage.local.path=$prometheusHome/data" `
    "-web.console.libraries=$prometheusInstallHome/console_libraries" `
    "-web.console.templates=$prometheusInstallHome/consoles"
Start-Service $prometheusServiceName

# install the wmi-exporter.
choco install -y prometheus-wmi-exporter.install
sc.exe failure wmi_exporter reset= 0 actions= restart/1000

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
[IO.File]::WriteAllText(
    "$env:USERPROFILE\Desktop\wmi exporter.url",
    @"
[InternetShortcut]
URL=http://localhost:9182
"@)
'@)
