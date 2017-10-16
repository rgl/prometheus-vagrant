# install the wmi-exporter.
choco install -y prometheus-wmi-exporter.install -Version 0.2.7 `
    --params '"/ListenAddress:127.0.0.1 /ListenPort:9182"'
sc.exe failure wmi_exporter reset= 0 actions= restart/1000

# add default desktop shortcuts (called from a provision-base.ps1 generated script).
[IO.File]::WriteAllText(
    "$env:USERPROFILE\ConfigureDesktop-Wmi-Exporter.ps1",
@'
[IO.File]::WriteAllText(
    "$env:USERPROFILE\Desktop\wmi exporter.url",
    @"
[InternetShortcut]
URL=https://prometheus.example.com:9182
"@)
'@)
