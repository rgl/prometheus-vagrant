choco install -y openssl.light

# update this session environment variables with the changes made by
# the recently installed Chocolatey packages.
Import-Module C:\ProgramData\chocolatey\helpers\chocolateyInstaller.psm1
Update-SessionEnvironment

$caDirectory = "c:\vagrant\shared\prometheus-example-ca"
$caPathPrefix = "$caDirectory\prometheus-example-ca"
$caCommonName = 'Prometheus Example CA'

function openssl {
    # openssl uses stderr to write error and progress messages, but
    # when $ErrorActionPreference is 'Stop' and something is written
    # to stderr PowerShell assumes that the application had a problem
    # and aborts the application and this script, so we have to
    # temporaly ignore that PowerShell behaviour.
    $arguments = $Args
    &{
        $ErrorActionPreference = 'Continue'
        $stderr = $($stdout = &'C:\Program Files\OpenSSL\bin\openssl.exe' @arguments) 2>&1
        $ErrorActionPreference = 'Stop'
        Write-Output $stdout
        if ($LASTEXITCODE) {
            throw "$(@('openssl')+$arguments | ConvertTo-Json -Compress) failed with exit code $LASTEXITCODE and stderr $stderr"
        }
    }
}

function With-TemporaryFile([ScriptBlock]$block) {
    $path = [IO.Path]::GetTempFileName()
    try {
        &$block $path
    } finally {
        Remove-Item $path
    }
}

function New-CertificationAuthority {
    if (!(Test-Path $caDirectory)) {
        mkdir $caDirectory | Out-Null
    }
    if (Test-Path $caPathPrefix-crt.pem) {
        return
    }
    openssl genrsa `
        -out $caPathPrefix-key.pem `
        2048
    openssl req -new `
        -sha256 `
        -subj "/CN=$caCommonName" `
        -key $caPathPrefix-key.pem `
        -out $caPathPrefix-csr.pem
    With-TemporaryFile {
        param($extensionsPath)
        Set-Content -Encoding Ascii -Path $extensionsPath -Value @'
[a]
basicConstraints=critical,CA:TRUE,pathlen:0
keyUsage=critical,digitalSignature,keyCertSign,cRLSign
'@
        openssl x509 -req -sha256 `
            -signkey $caPathPrefix-key.pem `
            -extensions a `
            -extfile $extensionsPath `
            -days 365 `
            -in $caPathPrefix-csr.pem `
            -out $caPathPrefix-crt.pem
    }
    openssl x509 `
        -in $caPathPrefix-crt.pem `
        -outform der `
        -out $caPathPrefix-crt.der
    # dump the certificate contents (for logging purposes).
    openssl x509 -noout -text -in $caPathPrefix-crt.pem
}

function New-ClientCertificate($commonName) {
    $certificatePrefix = "$caDirectory\$commonName-client"
    if (Test-Path $certificatePrefix-crt.pem) {
        return
    }
    openssl genrsa `
        -out $certificatePrefix-key.pem `
        2048
    openssl req -new `
        -sha256 `
        -subj "/CN=$commonName" `
        -key $certificatePrefix-key.pem `
        -out $certificatePrefix-csr.pem
    With-TemporaryFile {
        param($extensionsPath)
        Set-Content -Encoding Ascii -Path $extensionsPath -Value @'
[a]
extendedKeyUsage=critical,clientAuth
'@
        openssl x509 -req -sha256 `
            -CA $caPathPrefix-crt.pem `
            -CAkey $caPathPrefix-key.pem `
            -CAcreateserial `
            -extensions a `
            -extfile $extensionsPath `
            -days 365 `
            -in $certificatePrefix-csr.pem `
            -out $certificatePrefix-crt.pem
    }
    openssl pkcs12 -export `
        -keyex `
        -inkey $certificatePrefix-key.pem `
        -in $certificatePrefix-crt.pem `
        -certfile $certificatePrefix-crt.pem `
        -passout pass: `
        -out $certificatePrefix-key.p12
    # dump the certificate contents (for logging purposes).
    openssl x509 -noout -text -in $certificatePrefix-crt.pem
    #openssl pkcs12 -info -nodes -passin pass: -in $certificatePrefix-key.p12
}

function New-ServerCertificate($domain, $ip=$null) {
    $certificatePrefix = "$caDirectory\$domain"
    if (Test-Path $certificatePrefix-crt.pem) {
        return
    }
    openssl genrsa `
        -out $certificatePrefix-key.pem `
        2048
    openssl req -new `
        -sha256 `
        -subj "/CN=$domain" `
        -key $certificatePrefix-key.pem `
        -out $certificatePrefix-csr.pem
    With-TemporaryFile {
        param($extensionsPath)
        Set-Content -Encoding Ascii -Path $extensionsPath -Value @"
[a]
subjectAltName=DNS:$domain$(if ($ip) {",IP:$ip"})
extendedKeyUsage=critical,serverAuth
"@
        openssl x509 -req -sha256 `
            -CA $caPathPrefix-crt.pem `
            -CAkey $caPathPrefix-key.pem `
            -CAcreateserial `
            -extensions a `
            -extfile $extensionsPath `
            -days 365 `
            -in $certificatePrefix-csr.pem `
            -out $certificatePrefix-crt.pem
    }
    openssl pkcs12 -export `
        -keyex `
        -inkey $certificatePrefix-key.pem `
        -in $certificatePrefix-crt.pem `
        -certfile $certificatePrefix-crt.pem `
        -passout pass: `
        -out $certificatePrefix-key.p12
    # dump the certificate contents (for logging purposes).
    openssl x509 -noout -text -in $certificatePrefix-crt.pem
    #openssl pkcs12 -info -nodes -passin pass: -in $certificatePrefix-key.p12
}

New-CertificationAuthority
Import-Certificate `
    -FilePath $caPathPrefix-crt.pem `
    -CertStoreLocation Cert:\LocalMachine\Root `
    | Out-Null

New-ClientCertificate 'prometheus.example.com'
# import the client certificate to be able to use a browser to access the
# exporters endpoints that are behind caddy https.
Import-PfxCertificate `
    -FilePath "$caDirectory\prometheus.example.com-client-key.p12" `
    -CertStoreLocation Cert:\CurrentUser\My `
    -Password $null `
    -Exportable `
    | Out-Null

New-ServerCertificate 'prometheus.example.com'
New-ServerCertificate 'alertmanager.example.com'
New-ServerCertificate 'elasticsearch.example.com'
New-ServerCertificate 'kibana.example.com'
New-ServerCertificate 'grafana.example.com'
