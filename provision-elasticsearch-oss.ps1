# install dependencies.
choco install -y server-jre8
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"
Update-SessionEnvironment

$elasticsearchHome = 'C:\elasticsearch'
$elasticsearchServiceName = 'elasticsearch'
$elasticsearchServiceUsername = "NT SERVICE\$elasticsearchServiceName"
$archiveUrl = 'https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-oss-6.5.4.zip'
$archiveHash = 'e23e0f336bcd9f96145e10e77e7b513e95ad64fa4fbb13cf0693ba32e34f96a67b759f751ef9c389ad9224f10b8adcb6a519d79c3a74305d542c31f841c90c9a'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"

Write-Host 'Downloading Elasticsearch...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA512).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}

Write-Host 'Installing Elasticsearch...'
mkdir $elasticsearchHome | Out-Null
Expand-Archive $archivePath -DestinationPath $elasticsearchHome
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
