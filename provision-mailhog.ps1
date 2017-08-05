$mailhogHome = 'C:/mailhog'
$mailhogServiceName = 'mailhog'
$mailhogServiceUsername = '.\mailhog'
$mailhogServicePassword = 'HeyH0Password!'
$mailhogServiceCredential = New-Object PSCredential $mailhogServiceUsername,(ConvertTo-SecureString $mailhogServicePassword -AsPlainText -Force)

# create the mailhog local account.
Install-User -Credential $mailhogServiceCredential
Grant-Privilege $mailhogServiceUsername SeServiceLogonRight

# download and install MailHog.
$archiveUrl = 'https://github.com/mailhog/MailHog/releases/download/v1.0.0/MailHog_windows_amd64.exe'
$archiveHash = '6db91b94b011a7586cb10cd52ca723088b207693ee56ac2aedb3c65d9052b8dd'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
$mailHogPath = "$mailhogHome\MailHog.exe"
Write-Host 'Downloading MailHog...'
Invoke-WebRequest $archiveUrl -UseBasicParsing -OutFile $archivePath
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing MailHog...'
mkdir $mailhogHome | Out-Null
Copy-Item $archivePath $mailHogPath
Remove-Item $archivePath
'logs','data' | ForEach-Object {
    mkdir $mailhogHome/$_ | Out-Null
    Disable-AclInheritance $mailhogHome/$_
    Grant-Permission $mailhogHome/$_ Administrators FullControl
    Grant-Permission $mailhogHome/$_ $mailhogServiceUsername FullControl
}

# create and start the windows service.
Write-Host "Creating the $mailhogServiceName service..."
nssm install $mailhogServiceName $mailHogPath
nssm set $mailhogServiceName AppParameters `
    '-smtp-bind-addr=localhost:1025' `
    '-api-bind-addr=localhost:8025' `
    '-ui-bind-addr=localhost:8025' `
    '-storage=maildir' `
    "-maildir-path=$mailhogHome/data"
nssm set $mailhogServiceName AppDirectory $mailhogHome
sc.exe failure $mailhogServiceName reset= 0 actions= restart/1000
nssm set $mailhogServiceName ObjectName $mailhogServiceUsername $mailhogServicePassword
nssm set $mailhogServiceName Start SERVICE_AUTO_START
nssm set $mailhogServiceName AppRotateFiles 1
nssm set $mailhogServiceName AppRotateOnline 1
nssm set $mailhogServiceName AppRotateSeconds 86400
nssm set $mailhogServiceName AppRotateBytes 1048576
nssm set $mailhogServiceName AppStdout $mailhogHome\logs\service.log
nssm set $mailhogServiceName AppStderr $mailhogHome\logs\service.log
Start-Service $mailhogServiceName

# send a test email.
@"
From: Alice Doe <alice.doe@example.com>
To: Bob Doe <bob.doe@example.com>
Subject: Test message $(Get-Date -Format s)

1 2 3
"@ | &$mailHogPath sendmail --smtp-addr=localhost:1025

# add default desktop shortcuts (called from a provision-base.ps1 generated script).
[IO.File]::WriteAllText(
    "$env:USERPROFILE\ConfigureDesktop-MailHog.ps1",
@'
[IO.File]::WriteAllText(
    "$env:USERPROFILE\Desktop\MailHog.url",
    @"
[InternetShortcut]
URL=http://localhost:8025
"@)
'@)
