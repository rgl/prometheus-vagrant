Import-Module Carbon
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"

choco install -y adoptopenjdk11jre
Update-SessionEnvironment

$elasticsearchHome = 'C:\elasticsearch'
$elasticsearchServiceName = 'elasticsearch'
$elasticsearchServiceUsername = "NT SERVICE\$elasticsearchServiceName"
# see https://www.elastic.co/downloads/past-releases/elasticsearch-oss-6-8-5
$archiveUrl = 'https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-oss-6.8.5.zip'
$archiveHash = 'de7dc38575551c4a9dcdfd85b178e3817e1437e70db1fda0792986fc0c145e7cf0dcc7bd4ae5f32e50e94d44cab11f6100bb21cc39700ca21723ca016c0a5edc'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"

Write-Host 'Downloading Elasticsearch...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA512).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}

Write-Host 'Installing Elasticsearch...'
Get-ChocolateyUnzip -FileFullPath $archivePath -Destination $elasticsearchHome
$elasticsearchArchiveTempPath = Resolve-Path $elasticsearchHome\elasticsearch-*
Move-Item $elasticsearchArchiveTempPath\* $elasticsearchHome
Remove-Item $elasticsearchArchiveTempPath
Remove-Item $archivePath

Write-Host 'Creating the Elasticsearch keystore...'
cmd.exe /c "$elasticsearchHome\bin\elasticsearch-keystore.bat" create
if ($LASTEXITCODE) {
    throw "failed to create the keystore with exit code $LASTEXITCODE"
}

# NB the service has its settings on the following registry key:
#      HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Apache Software Foundation\Procrun 2.0\elasticsearch
Write-Host "Creating the $elasticsearchServiceName service..."
$env:ES_TMPDIR = "$elasticsearchHome\tmp"
cmd.exe /c "$elasticsearchHome\bin\elasticsearch-service.bat" install $elasticsearchServiceName
if ($LASTEXITCODE) {
    throw "failed to create the $elasticsearchServiceName service with exit code $LASTEXITCODE"
}

Write-Host "Configuring the $elasticsearchServiceName service..."
$result = sc.exe sidtype $elasticsearchServiceName unrestricted
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe sidtype failed with $result"
}
$result = sc.exe config $elasticsearchServiceName obj= $elasticsearchServiceUsername
if ($result -ne '[SC] ChangeServiceConfig SUCCESS') {
    throw "sc.exe config failed with $result"
}
$result = sc.exe failure $elasticsearchServiceName reset= 0 actions= restart/1000
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe failure failed with $result"
}
Set-Service $elasticsearchServiceName -StartupType Automatic

Write-Host 'Configuring the file system permissions...'
'logs','data','tmp' | ForEach-Object {
    mkdir -Force $elasticsearchHome\$_ | Out-Null
    Disable-AclInheritance $elasticsearchHome\$_
    Grant-Permission $elasticsearchHome\$_ Administrators FullControl
    Grant-Permission $elasticsearchHome\$_ $elasticsearchServiceUsername FullControl
}
Disable-AclInheritance $elasticsearchHome\config
Grant-Permission $elasticsearchHome\config Administrators FullControl
Grant-Permission $elasticsearchHome\config $elasticsearchServiceUsername Read
Disable-AclInheritance $elasticsearchHome\config\elasticsearch.keystore
Grant-Permission $elasticsearchHome\config\elasticsearch.keystore Administrators FullControl
Grant-Permission $elasticsearchHome\config\elasticsearch.keystore $elasticsearchServiceUsername FullControl

Write-Host "Starting the $elasticsearchServiceName service..."
Start-Service $elasticsearchServiceName

# add default desktop shortcuts (called from a provision-base.ps1 generated script).
[IO.File]::WriteAllText(
    "$env:USERPROFILE\ConfigureDesktop-Elasticsearch.ps1",
@'
[IO.File]::WriteAllText(
    "$env:USERPROFILE\Desktop\Elasticsearch.url",
    @"
[InternetShortcut]
URL=https://elasticsearch.example.com
"@)
'@)
