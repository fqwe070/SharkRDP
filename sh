[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy Bypass -Scope Process -Force

$UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split("\")[-1]
$PasswordPlain = "Develop1234"
$SecurePassword = ConvertTo-SecureString $PasswordPlain -AsPlainText -Force

Set-LocalUser -Name $UserName -Password $SecurePassword -ErrorAction SilentlyContinue
Get-LocalUser -Name $UserName | Enable-LocalUser

Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue

Start-Service -Name "TermService" -ErrorAction SilentlyContinue

$NgrokUrl = "https://equinox.io"
$ZipFile = "$env:TEMP\ngrok.zip"

Invoke-WebRequest -Uri $NgrokUrl -OutFile $ZipFile -UseBasicParsing

Expand-Archive -Path $ZipFile -DestinationPath . -Force
Remove-Item -Path $ZipFile -Force

.\ngrok.exe config add-authtoken "3FXg3L4EvG25jxRWiRaZVNPi6Hu_4uaMokgmcJrry78mC8Luy"

Start-Sleep -Seconds 3

Start-Process .\ngrok.exe -ArgumentList "tcp 3389" -WindowStyle Hidden

Start-Sleep -Seconds 5

$NgrokApi = Invoke-WebRequest -Uri "http://127.0.0" -UseBasicParsing | ConvertFrom-Json
$RdpAddress = $NgrokApi.tunnels.public_url -replace "tcp://", ""

Write-Host "=================================================="
Write-Host "NEW RDP ADDRESS:"
Write-Host $RdpAddress
Write-Host "=================================================="

ping.exe -t 127.0.0.1
