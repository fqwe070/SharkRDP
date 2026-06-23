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

if (-not (Get-Command ngrok -ErrorAction SilentlyContinue)) {
    choco install ngrok -y --no-progress
}

& "C:\ProgramData\chocolatey\bin\ngrok.exe" config add-authtoken "3FXg3L4EvG25jxRWiRaZVNPi6Hu_4uaMokgmcJrry78mC8Luy"

Start-Sleep -Seconds 3

Start-Process "C:\ProgramData\chocolatey\bin\ngrok.exe" -ArgumentList "tcp 3389 --log=stdout" -RedirectStandardOutput ".\ngrok.log" -WindowStyle Hidden

Start-Sleep -Seconds 7

$RdpAddress = Select-String -Path ".\ngrok.log" -Pattern "url=tcp://" | ForEach-Object { $_.Matches.Value }
if ($RdpAddress) {
    $CleanAddress = ($RdpAddress -split "url=tcp://")[-1]
    Write-Host "=================================================="
    Write-Host "NEW RDP ADDRESS: $CleanAddress"
    Write-Host "=================================================="
} else {
    Write-Host "Failed to parse address"
    Get-Content ".\ngrok.log" -Tail 10
}
ping.exe -t 127.0.0.1

