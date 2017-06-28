$grafanaHome = 'C:/grafana'
$grafanaServiceName = 'grafana'
$grafanaServiceUsername = '.\grafana'
$grafanaServicePassword = 'HeyH0Password!'
$grafanaServiceCredential = New-Object PSCredential $grafanaServiceUsername,(ConvertTo-SecureString $grafanaServicePassword -AsPlainText -Force)

# create the grafana local account.
Install-User -Credential $grafanaServiceCredential
Grant-Privilege $grafanaServiceUsername SeServiceLogonRight

# create the grafana home.
mkdir $grafanaHome | Out-Null
Disable-AclInheritance $grafanaHome
Grant-Permission $grafanaHome SYSTEM FullControl
Grant-Permission $grafanaHome Administrators FullControl
Grant-Permission $grafanaHome $grafanaServiceUsername FullControl

# download and install grafana.
$archiveUrl = 'https://s3-us-west-2.amazonaws.com/grafana-releases/release/grafana-4.3.2.windows-x64.zip'
$archiveHash = 'cee19ec4db8f0546c75d65b2fbe460587e8eb9539f9ffdb4baf9daefd7df706c'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Invoke-WebRequest $archiveUrl -UseBasicParsing -OutFile $archivePath
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Expand-Archive $archivePath -DestinationPath $grafanaHome
$grafanaArchiveTempPath = Resolve-Path $grafanaHome\grafana-*
Move-Item $grafanaArchiveTempPath\* $grafanaHome
Remove-Item $grafanaArchiveTempPath
Remove-Item $archivePath
mkdir $grafanaHome/data
Copy-Item c:/vagrant/grafana.ini $grafanaHome/conf

# create and start the windows service.
mkdir $grafanaHome\logs | Out-Null
nssm install $grafanaServiceName $grafanaHome\bin\grafana-server.exe
nssm set $grafanaServiceName AppParameters `
    "--config=$grafanaHome/conf/grafana.ini" `
sc.exe failure $grafanaServiceName reset= 0 actions= restart/1000
nssm set $grafanaServiceName ObjectName $grafanaServiceUsername $grafanaServicePassword
nssm set $grafanaServiceName Start SERVICE_AUTO_START
nssm set $grafanaServiceName AppRotateFiles 1
nssm set $grafanaServiceName AppRotateOnline 1
nssm set $grafanaServiceName AppRotateSeconds 86400
nssm set $grafanaServiceName AppRotateBytes 1048576
nssm set $grafanaServiceName AppStdout $grafanaHome\logs\service.log
nssm set $grafanaServiceName AppStderr $grafanaHome\logs\service.log
Start-Service $grafanaServiceName

$apiBaseUrl = 'http://localhost:3000/api'
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
New-GrafanaDataSource @{
    name = 'Prometheus'
    type = 'prometheus'
    url = 'http://localhost:9090'
    access = 'direct'
    basicAuth = $false
}

# create a dashboard for the wmi_exporter.
# NB this dashboard originaly came from https://grafana.com/dashboards/2129
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
URL=http://localhost:3000
"@)
'@)