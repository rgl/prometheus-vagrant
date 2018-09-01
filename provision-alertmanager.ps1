$alertmanagerHome = 'C:/alertmanager'
$alertmanagerServiceName = 'alertmanager'
$alertmanagerServiceUsername = "NT SERVICE\$alertmanagerServiceName"

# create the windows service using a managed service account.
Write-Host "Creating the $alertmanagerServiceName service..."
nssm install $alertmanagerServiceName $alertmanagerHome\alertmanager.exe
nssm set $alertmanagerServiceName AppParameters `
    '--web.listen-address=localhost:9093' `
    '--web.external-url=https://alertmanager.example.com' `
    "--config.file=$alertmanagerHome/conf/alertmanager.yml" `
    "--storage.path=$alertmanagerHome/data" `
    "--data.retention=$(7*24)h"
nssm set $alertmanagerServiceName AppDirectory $alertmanagerHome
nssm set $alertmanagerServiceName Start SERVICE_AUTO_START
nssm set $alertmanagerServiceName AppRotateFiles 1
nssm set $alertmanagerServiceName AppRotateOnline 1
nssm set $alertmanagerServiceName AppRotateSeconds 86400
nssm set $alertmanagerServiceName AppRotateBytes 1048576
nssm set $alertmanagerServiceName AppStdout $alertmanagerHome\logs\service-stdout.log
nssm set $alertmanagerServiceName AppStderr $alertmanagerHome\logs\service-stderr.log
$result = sc.exe sidtype $alertmanagerServiceName unrestricted
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe sidtype failed with $result"
}
$result = sc.exe config $alertmanagerServiceName obj= $alertmanagerServiceUsername
if ($result -ne '[SC] ChangeServiceConfig SUCCESS') {
    throw "sc.exe config failed with $result"
}
$result = sc.exe failure $alertmanagerServiceName reset= 0 actions= restart/1000
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe failure failed with $result"
}

# download and install alertmanager.
$archiveUrl = 'https://github.com/prometheus/alertmanager/releases/download/v0.15.2/alertmanager-0.15.2.windows-amd64.tar.gz'
$archiveHash = '0198c06c86f22758a5f6749dae1b24b8f212455c36c72919de1078797202fb4d'
$archiveName = Split-Path $archiveUrl -Leaf
$archiveTarName = $archiveName -replace '\.gz',''
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading Alertmanager...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
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

Write-Host "Starting the $alertmanagerServiceName service..."
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
