$grafanaHome = 'C:/grafana'
$grafanaServiceName = 'grafana'
$grafanaServiceUsername = "NT SERVICE\$grafanaServiceName"

# create the windows service using a managed service account.
Write-Host "Creating the $grafanaServiceName service..."
nssm install $grafanaServiceName $grafanaHome\bin\grafana-server.exe
nssm set $grafanaServiceName AppParameters `
    "--config=$grafanaHome/conf/grafana.ini"
nssm set $grafanaServiceName AppDirectory $grafanaHome
nssm set $grafanaServiceName Start SERVICE_AUTO_START
nssm set $grafanaServiceName AppRotateFiles 1
nssm set $grafanaServiceName AppRotateOnline 1
nssm set $grafanaServiceName AppRotateSeconds 86400
nssm set $grafanaServiceName AppRotateBytes 1048576
nssm set $grafanaServiceName AppStdout $grafanaHome\logs\service.log
nssm set $grafanaServiceName AppStderr $grafanaHome\logs\service.log
$result = sc.exe sidtype $grafanaServiceName unrestricted
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe sidtype failed with $result"
}
$result = sc.exe config $grafanaServiceName obj= $grafanaServiceUsername
if ($result -ne '[SC] ChangeServiceConfig SUCCESS') {
    throw "sc.exe config failed with $result"
}
$result = sc.exe failure $grafanaServiceName reset= 0 actions= restart/1000
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe failure failed with $result"
}

# download and install grafana.
$archiveUrl = 'https://s3-us-west-2.amazonaws.com/grafana-releases/release/grafana-4.5.2.windows-x64.zip'
$archiveHash = 'e3ac7ba137daee1110d7a74b1bbcbc26082c76a9101d25a05da9837e91e1261a'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading Grafana...'
Invoke-WebRequest $archiveUrl -UseBasicParsing -OutFile $archivePath
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing Grafana...'
mkdir $grafanaHome | Out-Null
Expand-Archive $archivePath -DestinationPath $grafanaHome
$grafanaArchiveTempPath = Resolve-Path $grafanaHome\grafana-*
Move-Item $grafanaArchiveTempPath\* $grafanaHome
Remove-Item $grafanaArchiveTempPath
Remove-Item $archivePath
'logs','data' | ForEach-Object {
    mkdir $grafanaHome/$_ | Out-Null
    Disable-AclInheritance $grafanaHome/$_
    Grant-Permission $grafanaHome/$_ Administrators FullControl
    Grant-Permission $grafanaHome/$_ $grafanaServiceUsername FullControl
}
Disable-AclInheritance $grafanaHome/conf
Grant-Permission $grafanaHome/conf Administrators FullControl
Grant-Permission $grafanaHome/conf $grafanaServiceUsername Read
Copy-Item c:/vagrant/shared/prometheus-example-ca/grafana.example.com-crt.pem $grafanaHome/conf
Copy-Item c:/vagrant/shared/prometheus-example-ca/grafana.example.com-key.pem $grafanaHome/conf
Copy-Item c:/vagrant/grafana.ini $grafanaHome/conf

Write-Host "Starting the $grafanaServiceName service..."
Start-Service $grafanaServiceName

$apiBaseUrl = 'https://grafana.example.com/api'
$apiAuthorizationHeader = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('admin:admin')))"

function Invoke-GrafanaApi($relativeUrl, $body, $method='Post') {
    Invoke-RestMethod `
        -Method $method `
        -Uri $apiBaseUrl/$relativeUrl `
        -ContentType 'application/json' `
        -Headers @{
            Authorization = $apiAuthorizationHeader
        } `
        -Body (ConvertTo-Json -Depth 100 $body)
}

function New-GrafanaDataSource($body) {
    Invoke-GrafanaApi datasources $body
}

function New-GrafanaDashboard($body) {
    Invoke-GrafanaApi dashboards/db $body
}

# create a data source for the local prometheus server.
Write-Host 'Creating the Prometheus Data Source...'
New-GrafanaDataSource @{
    name = 'Prometheus'
    type = 'prometheus'
    url = 'https://prometheus.example.com'
    access = 'direct'
    basicAuth = $false
}

# create a dashboard for the wmi_exporter.
# NB this dashboard originaly came from https://grafana.com/dashboards/2129
Write-Host 'Creating the Windows Dashboard...'
$dashboard = (Get-Content -Raw grafana-windows-dashboard.json) `
    -replace '\${DS_PROMETHEUS}','Prometheus' `
    | ConvertFrom-Json
$dashboard.PSObject.Properties.Remove('__inputs')
$dashboard.PSObject.Properties.Remove('__requires')
$dashboard.title = 'Windows'
#Invoke-GrafanaApi dashboards/db/$($dashboard.title.ToLower() -replace ' ','-') $null Delete
New-GrafanaDashboard @{
    dashboard = $dashboard
}

# add default desktop shortcuts (called from a provision-base.ps1 generated script).
[IO.File]::WriteAllText(
    "$env:USERPROFILE\ConfigureDesktop-Grafana.ps1",
@'
[IO.File]::WriteAllText(
    "$env:USERPROFILE\Desktop\Grafana.url",
    @"
[InternetShortcut]
URL=https://grafana.example.com
"@)
'@)
