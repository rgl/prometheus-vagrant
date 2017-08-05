$alertmanagerHome = 'C:/alertmanager'
$alertmanagerServiceName = 'alertmanager'
$alertmanagerServiceUsername = '.\alertmanager'
$alertmanagerServicePassword = 'HeyH0Password!'
$alertmanagerServiceCredential = New-Object PSCredential $alertmanagerServiceUsername,(ConvertTo-SecureString $alertmanagerServicePassword -AsPlainText -Force)

# create the alertmanager local account.
Install-User -Credential $alertmanagerServiceCredential
Grant-Privilege $alertmanagerServiceUsername SeServiceLogonRight

# download and install alertmanager.
$archiveUrl = 'https://github.com/prometheus/alertmanager/releases/download/v0.8.0/alertmanager-0.8.0.windows-amd64.tar.gz'
$archiveHash = 'b4c8ca956ff7e3dad20ae890a49012fba4c7297a38d4ab2c725fadc9410c9a1f'
$archiveName = Split-Path $archiveUrl -Leaf
$archiveTarName = $archiveName -replace '\.gz',''
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading Alertmanager...'
Invoke-WebRequest $archiveUrl -UseBasicParsing -OutFile $archivePath
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing Alertmanager...'
mkdir $alertmanagerHome | Out-Null
Import-Module C:\ProgramData\chocolatey\helpers\chocolateyInstaller.psm1
Get-ChocolateyUnzip -FileFullPath $archivePath -Destination $alertmanagerHome
Get-ChocolateyUnzip -FileFullPath $alertmanagerHome\$archiveTarName -Destination $alertmanagerHome
Remove-Item $alertmanagerHome\$archiveTarName
$alertmanagerArchiveTempPath = Resolve-Path $alertmanagerHome\alertmanager-*
Move-Item $alertmanagerArchiveTempPath\* $alertmanagerHome
Remove-Item $alertmanagerArchiveTempPath
Remove-Item $archivePath
'logs','data' | ForEach-Object {
    mkdir $alertmanagerHome/$_ | Out-Null
    Disable-AclInheritance $alertmanagerHome/$_
    Grant-Permission $alertmanagerHome/$_ Administrators FullControl
    Grant-Permission $alertmanagerHome/$_ $alertmanagerServiceUsername FullControl
}
mkdir $alertmanagerHome/conf | Out-Null
Disable-AclInheritance $alertmanagerHome/conf
Grant-Permission $alertmanagerHome/conf Administrators FullControl
Grant-Permission $alertmanagerHome/conf $alertmanagerServiceUsername Read
Copy-Item c:/vagrant/alertmanager.yml $alertmanagerHome/conf

# create and start the windows service.
Write-Host "Creating the $alertmanagerServiceName service..."
nssm install $alertmanagerServiceName $alertmanagerHome\alertmanager.exe
nssm set $alertmanagerServiceName AppParameters `
    '-web.listen-address=localhost:9093' `
    '-web.external-url=https://alertmanager.example.com' `
    "-config.file=$alertmanagerHome/conf/alertmanager.yml" `
    "-storage.path=$alertmanagerHome/data" `
    "-data.retention=$(7*24)h"
nssm set $alertmanagerServiceName AppDirectory $alertmanagerHome
sc.exe failure $alertmanagerServiceName reset= 0 actions= restart/1000
nssm set $alertmanagerServiceName ObjectName $alertmanagerServiceUsername $alertmanagerServicePassword
nssm set $alertmanagerServiceName Start SERVICE_AUTO_START
nssm set $alertmanagerServiceName AppRotateFiles 1
nssm set $alertmanagerServiceName AppRotateOnline 1
nssm set $alertmanagerServiceName AppRotateSeconds 86400
nssm set $alertmanagerServiceName AppRotateBytes 1048576
nssm set $alertmanagerServiceName AppStdout $alertmanagerHome\logs\service.log
nssm set $alertmanagerServiceName AppStderr $alertmanagerHome\logs\service.log
Start-Service $alertmanagerServiceName

# add default desktop shortcuts (called from a provision-base.ps1 generated script).
[IO.File]::WriteAllText(
    "$env:USERPROFILE\ConfigureDesktop-Alertmanager.ps1",
@'
[IO.File]::WriteAllText(
    "$env:USERPROFILE\Desktop\Alertmanager.url",
    @"
[InternetShortcut]
URL=https://alertmanager.example.com
"@)
'@)
