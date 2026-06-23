Set-ExecutionPolicy Bypass -Scope Process -Force

# Принудительно включаем TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split("\")[-1]

# 1. Установка Xray-core через Chocolatey (гарантирует обход блокировок загрузки)
Write-Host "Installing Xray via Chocolatey..."
if (-not (Get-Command xray -ErrorAction SilentlyContinue)) {
    choco install xray -y --no-progress
}

# Пути по умолчанию для Chocolatey версии Xray
$XrayDir = "C:\ProgramData\chocolatey\lib\xray\tools"
$XrayExe = "C:\ProgramData\chocolatey\bin\xray.exe"

# Если Chocolatey поставил в другую папку, делаем фолбэк поиск
if (-not (Test-Path $XrayExe)) {
    $XrayExe = (Get-Command xray -ErrorAction SilentlyContinue).Source
    $XrayDir = Split-Path $XrayExe
}

if (-not (Test-Path $XrayExe)) {
    Write-Error "Critical Error: Xray installation failed via Chocolatey."
    Exit 1
}

# 2. Генерация ключей Reality и UUID
Write-Host "Generating Reality keys and UUID..."
$UUID = ([guid]::NewGuid()).Guid

# Получаем ключи напрямую из бинарника
$KeysOutput = & $XrayExe x25519
$PrivateKey = ($KeysOutput | Select-String "Private key:").Line.Split(" ").Trim()
$PublicKey = ($KeysOutput | Select-String "Public key:").Line.Split(" ").Trim()

$ShortId = -join ((1..8) | ForEach-Object { "{0:x}" -f (Get-Random -Min 0 -Max 16) })

# Выбор стабильного домена для маскировки в РФ (разрешенный CDN/сервис)
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
    $HostName = $AddrParts
    $PortNumber = $AddrParts
    
    $FormatString = "vless://{0}@{1}:{2}?security=reality&encryption=none&pbk={3}&headerType=none&fp=chrome&spx=%2F&type=tcp&flow=xtls-rprx-vision&sni={4}&sid={5}#Xray-Reality-RU"
    $VlessLink = $FormatString -f $UUID, $HostName, $PortNumber, $PublicKey, $FakeDomain, $ShortId

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
