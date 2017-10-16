$caddyHome = 'C:\Program Files\Caddy'
$caddyServiceName = 'caddy'
$caddyServiceUsername = '.\caddy'
$caddyServicePassword = 'HeyH0Password!'
$caddyServiceCredential = New-Object PSCredential $caddyServiceUsername,(ConvertTo-SecureString $caddyServicePassword -AsPlainText -Force)

# create the caddy local account.
Install-User -Credential $caddyServiceCredential
Grant-Privilege $caddyServiceUsername SeServiceLogonRight

# install caddy for exposing the prometheus server at an https endpoint.
# NB The Prometheus server itself does not support HTTPS or Authentication.
#    see https://prometheus.io/docs/introduction/faq/#why-don-t-the-prometheus-server-components-support-tls-or-authentication-can-i-add-those
$archiveUrl = 'https://github.com/mholt/caddy/releases/download/v0.10.10/caddy_v0.10.10_windows_amd64.zip'
$archiveHash = '728f9eb905b6e0c506bd603e130eca1f40e1fa90182f187e6572a688de7d6924'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Invoke-WebRequest $archiveUrl -UseBasicParsing -OutFile $archivePath
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Expand-Archive $archivePath -DestinationPath $caddyHome
Remove-Item $archivePath
Copy-Item c:/vagrant/Caddyfile $caddyHome
mkdir $caddyHome/logs | Out-Null
Disable-AclInheritance $caddyHome/logs
Grant-Permission $caddyHome/logs Administrators FullControl
Grant-Permission $caddyHome/logs $caddyServiceUsername FullControl
mkdir $caddyHome/tls | Out-Null
Disable-AclInheritance $caddyHome/tls
Grant-Permission $caddyHome/tls Administrators FullControl
Grant-Permission $caddyHome/tls $caddyServiceUsername Read
Copy-Item c:/vagrant/shared/prometheus-example-ca/prometheus-example-ca-crt.pem $caddyHome/tls
Copy-Item c:/vagrant/shared/prometheus-example-ca/prometheus.example.com-crt.pem $caddyHome/tls
Copy-Item c:/vagrant/shared/prometheus-example-ca/prometheus.example.com-key.pem $caddyHome/tls
Copy-Item c:/vagrant/shared/prometheus-example-ca/alertmanager.example.com-crt.pem $caddyHome/tls
Copy-Item c:/vagrant/shared/prometheus-example-ca/alertmanager.example.com-key.pem $caddyHome/tls
nssm install $caddyServiceName $caddyHome/caddy.exe
sc.exe failure $caddyServiceName reset= 0 actions= restart/1000
nssm set $caddyServiceName ObjectName $caddyServiceUsername $caddyServicePassword
nssm set $caddyServiceName Start SERVICE_AUTO_START
nssm set $caddyServiceName AppRotateFiles 1
nssm set $caddyServiceName AppRotateOnline 1
nssm set $caddyServiceName AppRotateSeconds 86400
nssm set $caddyServiceName AppRotateBytes 1048576
nssm set $caddyServiceName AppStdout $caddyHome/logs/service.log
nssm set $caddyServiceName AppStderr $caddyHome/logs/service.log
nssm set $caddyServiceName AppDirectory $caddyHome
nssm set $caddyServiceName AppParameters `
    '-agree=true' `
    "-log=logs/Caddy.log"
Start-Service $caddyServiceName
