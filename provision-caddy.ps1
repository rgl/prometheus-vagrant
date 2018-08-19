$caddyHome = 'C:\Program Files\Caddy'
$caddyServiceName = 'caddy'
$caddyServiceUsername = "NT SERVICE\$caddyServiceName"

# create the windows service using a managed service account.
Write-Host "Creating the $caddyServiceName service..."
nssm install $caddyServiceName $caddyHome/caddy.exe
nssm set $caddyServiceName Start SERVICE_AUTO_START
nssm set $caddyServiceName AppRotateFiles 1
nssm set $caddyServiceName AppRotateOnline 1
nssm set $caddyServiceName AppRotateSeconds 86400
nssm set $caddyServiceName AppRotateBytes 1048576
nssm set $caddyServiceName AppStdout $caddyHome/logs/service-stdout.log
nssm set $caddyServiceName AppStderr $caddyHome/logs/service-stderr.log
nssm set $caddyServiceName AppDirectory $caddyHome
nssm set $caddyServiceName AppParameters `
    '-agree=true' `
    "-log=logs/Caddy.log"
$result = sc.exe sidtype $caddyServiceName unrestricted
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe sidtype failed with $result"
}
$result = sc.exe config $caddyServiceName obj= $caddyServiceUsername
if ($result -ne '[SC] ChangeServiceConfig SUCCESS') {
    throw "sc.exe config failed with $result"
}
$result = sc.exe failure $caddyServiceName reset= 0 actions= restart/1000
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe failure failed with $result"
}

# install caddy for exposing the prometheus server at an https endpoint.
# NB The Prometheus server itself does not support HTTPS or Authentication.
#    see https://prometheus.io/docs/introduction/faq/#why-don-t-the-prometheus-server-components-support-tls-or-authentication-can-i-add-those
$archiveUrl = 'https://github.com/mholt/caddy/releases/download/v0.11.0/caddy_v0.11.0_windows_amd64.zip'
$archiveHash = '52de3956a913da2045221770978c5578d828f65e094db8f8fe414f1fea9c4a8a'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading caddy...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing caddy...'
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
Copy-Item c:/vagrant/shared/prometheus-example-ca/grafana.example.com-crt.pem $caddyHome/tls
Copy-Item c:/vagrant/shared/prometheus-example-ca/grafana.example.com-key.pem $caddyHome/tls

Write-Host "Starting the $caddyServiceName service..."
Start-Service $caddyServiceName
