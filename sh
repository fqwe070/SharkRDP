Set-ExecutionPolicy Bypass -Scope Process -Force

# Принудительно включаем TLS 1.2 для стабильного скачивания с GitHub
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split("\")[-1]

# 1. Скачивание и установка Xray-core
$XrayDir = "C:\ProgramData\xray"
if (-not (Test-Path $XrayDir)) {
    New-Item -ItemType Directory -Path $XrayDir | Out-Null
}

Write-Host "Downloading Xray-core..."
$XrayZip = "$XrayDir\xray.zip"

# Используем curl/Invoke-WebRequest с флагами для обхода проблем с сертификатами
Invoke-WebRequest -Uri "https://github.com" -OutFile $XrayZip -UseBasicParsing

# Проверяем размер файла перед распаковкой (если меньше 10 КБ — значит скачалась ошибка)
if ((Get-Item $XrayZip).Length -lt 10240) {
    Write-Error "Download failed or file is corrupted. Re-trying with curl..."
    curl.exe -L -o $XrayZip "https://github.com"
}

Write-Host "Extracting Xray-core..."
# Использование tar.exe вместо Expand-Archive предотвращает ошибку повреждения архива в CI
tar.exe -xf $XrayZip -C $XrayDir
Remove-Item $XrayZip -Force

# 2. Генерация ключей Reality и UUID
Write-Host "Generating Reality keys and UUID..."
$XrayExe = "$XrayDir\xray.exe"
$UUID = ([guid]::NewGuid()).Guid

$KeysOutput = & $XrayExe x25519
$PrivateKey = ($KeysOutput | Select-String "Private key:").Line.Split(" ").Trim()
$PublicKey = ($KeysOutput | Select-String "Public key:").Line.Split(" ").Trim()

$ShortId = -join ((1..8) | ForEach-Object { "{0:x}" -f (Get-Random -Min 0 -Max 16) })

# Выбор оптимального домена для маскировки в РФ (разрешенный CDN/сервис)
$FakeDomain = "speedtest.net"

# 3. Создание конфигурационного файла config.json под РФ
$ConfigJson = @"
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$UUID",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "$FakeDomain:443",
                    "xver": 0,
                    "serverNames": [
                        "$FakeDomain",
                        "www.$FakeDomain"
                    ],
                    "privateKey": "$PrivateKey",
                    "shortIds": [
                        "$ShortId"
                    ]
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
"@

$ConfigJson | Out-File -FilePath "$XrayDir\config.json" -Encoding utf8 -Force

# 4. Настройка брандмауэра Windows
Enable-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Out-Null
New-NetFirewallRule -DisplayName "Xray Reality Inbound" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 443 -ErrorAction SilentlyContinue | Out-Null

# 5. Запуск Xray-core в фоне
Start-Process $XrayExe -ArgumentList "run -config $XrayDir\config.json" -WorkingDirectory $XrayDir -WindowStyle Hidden

# 6. Установка и настройка ngrok
if (-not (Get-Command ngrok -ErrorAction SilentlyContinue)) {
    Write-Host "Installing ngrok via Chocolatey..."
    choco install ngrok -y --no-progress
}

& "C:\ProgramData\chocolatey\bin\ngrok.exe" config add-authtoken "3FXg3L4EvG25jxRWiRaZVNPi6Hu_4uaMokgmcJrry78mC8Luy"

Start-Process "C:\ProgramData\chocolatey\bin\ngrok.exe" -ArgumentList "tcp 443" -WindowStyle Hidden

# 7. Получение адреса туннеля
$NgrokUrl = $null
for ($i = 0; $i -lt 10; $i++) {
    Start-Sleep -Seconds 3
    try {
        $NgrokApi = Invoke-WebRequest -Uri "http://127.0.0" -UseBasicParsing -ErrorAction Stop | ConvertFrom-Json
        $NgrokUrl = $NgrokApi.tunnels.public_url
        if ($NgrokUrl) { break }
    } catch {}
}

# 8. Вывод ссылки vless:// адаптированной под ТСПУ
if ($NgrokUrl) {
    $CleanAddress = $NgrokUrl -replace "tcp://", ""
    $AddrParts = $CleanAddress -split ":"
    $HostName = $AddrParts[0]
    $PortNumber = $AddrParts[1]
    
    $VlessLink = "vless://$UUID@${HostName}:${PortNumber}?security=reality&encryption=none&pbk=$PublicKey&headerType=none&fp=chrome&spx=%2F&type=tcp&flow=xtls-rprx-vision&sni=$FakeDomain&sid=$ShortId#Xray-Reality-RU"

    Write-Host "`n=================================================="
    Write-Host "XRAY REALITY SERVER IS CONFIGURATED FOR RU"
    Write-Host "=================================================="
    Write-Host "YOUR CLIENT CONFIG LINK (VLESS):"
    Write-Host $VlessLink
    Write-Host "=================================================="
} else {
    Write-Host "Ngrok failed to start or bind tunnel."
}

while ($true) {
    Write-Host "Keep-alive: Xray and Ngrok tunnel are active..."
    Start-Sleep -Seconds 30
}
