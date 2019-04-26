Import-Module Carbon
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"

$prometheusbeatHome = 'C:\prometheusbeat'
$prometheusbeatServiceName = 'prometheusbeat'
$prometheusbeatServiceUsername = "NT SERVICE\$prometheusbeatServiceName"
$elasticsearchBaseUrl = 'https://elasticsearch.example.com'

# wrap prometheusbeat.exe to ignore logging and to prevent PowerShell
# from stopping the script when there is data in stderr.
function prometheusbeat {
    $eap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        &"$prometheusbeatHome\prometheusbeat.exe" -e @Args 2>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                $null
            } else {
                "$_"
            }
        }
        if ($LASTEXITCODE) {
            throw "prometheusbeat failed to execute with exit code $LASTEXITCODE"
        }
    } finally {
        $ErrorActionPreference = $eap
    }
}

function Invoke-ElasticsearchApi($relativeUrl, $body, $method='Post') {
    Invoke-RestMethod `
        -Method $method `
        -Uri $elasticsearchBaseUrl/$relativeUrl `
        -ContentType 'application/json' `
        -Body (ConvertTo-Json -Depth 100 $body)
}

function New-ElasticsearchTemplate($name, $body) {
    Invoke-ElasticsearchApi "_template/$name" $body 'Put'
}

function Get-PrometheusbeatMetricNamesCount {
    $result = Invoke-ElasticsearchApi 'prometheusbeat-*/_search' @{
        size = 0
        aggs = @{
            metric_name_count = @{
                cardinality = @{
                    field = 'labels.name'
                }
            }
        }
    }
    $result.aggregations.metric_name_count.value
}

function Get-PrometheusbeatMetricNames {
    $results = Invoke-ElasticsearchApi 'prometheusbeat-*/_search' @{
        size = 0
        aggs = @{
            metric_names = @{
                terms = @{
                    field = 'labels.name'
                    size = 10000
                }
            }
        }
    }
    $results.aggregations.metric_names.buckets.key | Sort-Object
}

# download and install.
$archiveUrl = 'https://github.com/infonova/prometheusbeat/releases/download/v6.4.1/prometheusbeat-6.4.1-windows-x86_64.zip'
$archiveHash = '64b82249a6dadb5faff49d90919621f2538927a0b148215686a6c9893e2a30786e8bbab37e4810f38d5822dd57c2864cf43cfebb8426118fbdb55fba57e09ac3'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading Prometheusbeat...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA512).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing Prometheusbeat...'
Get-ChocolateyUnzip -FileFullPath $archivePath -Destination "$prometheusbeatHome.tmp"
mkdir $prometheusbeatHome | Out-Null
Move-Item "$(Resolve-Path "$prometheusbeatHome.tmp\prometheusbeat-*")\*" $prometheusbeatHome
rmdir -Recurse "$prometheusbeatHome.tmp"
Remove-Item $archivePath

# configure the windows service using a managed service account.
Write-Host "Configuring the $prometheusbeatServiceName service..."
New-Service `
    -Name $prometheusbeatServiceName `
    -StartupType 'Automatic' `
    -BinaryPathName "$prometheusbeatHome\prometheusbeat.exe -c $prometheusbeatHome\prometheusbeat.yml -path.home $prometheusbeatHome" `
    | Out-Null
$result = sc.exe sidtype $prometheusbeatServiceName unrestricted
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe sidtype failed with $result"
}
$result = sc.exe config $prometheusbeatServiceName obj= $prometheusbeatServiceUsername
if ($result -ne '[SC] ChangeServiceConfig SUCCESS') {
    throw "sc.exe config failed with $result"
}
$result = sc.exe failure $prometheusbeatServiceName reset= 0 actions= restart/1000
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe failure failed with $result"
}

Disable-AclInheritance $prometheusbeatHome
Grant-Permission $prometheusbeatHome SYSTEM FullControl
Grant-Permission $prometheusbeatHome Administrators FullControl
Grant-Permission $prometheusbeatHome $prometheusbeatServiceUsername ReadAndExecute
Copy-Item c:\vagrant\prometheusbeat.yml $prometheusbeatHome
mkdir $prometheusbeatHome\tls | Out-Null
Copy-Item c:\vagrant\shared\prometheus-example-ca\prometheus-example-ca-crt.pem $prometheusbeatHome\tls
'data','logs' | ForEach-Object {
    mkdir $prometheusbeatHome\$_ | Out-Null
    Disable-AclInheritance $prometheusbeatHome\$_
    Grant-Permission $prometheusbeatHome\$_ SYSTEM FullControl
    Grant-Permission $prometheusbeatHome\$_ Administrators FullControl
    Grant-Permission $prometheusbeatHome\$_ $prometheusbeatServiceUsername FullControl
}

Write-Host "Checking the prometheusbeat configuration..."
prometheusbeat -c "$prometheusbeatHome\prometheusbeat.yml" test config

# manually create the prometheusbeat template.
# NB prometheusbeat automatically creates the index if it does not exist.
Write-Host "Creating the prometheusbeat elasticsearch index..."
$prometheusbeatTemplate = prometheusbeat -c "$prometheusbeatHome\prometheusbeat.yml" export template | Out-String | ConvertFrom-Json
# for testing purposes, we do not need replicas (and for not showing an
# health yellow status alert on our single node cluster).
$prometheusbeatTemplate.settings.index | Add-Member number_of_replicas 0
New-ElasticsearchTemplate 'prometheusbeat' $prometheusbeatTemplate

Write-Host "Starting the $prometheusbeatServiceName service..."
Start-Service $prometheusbeatServiceName
