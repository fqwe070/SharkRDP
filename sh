Set-ExecutionPolicy Bypass -Scope Process -Force

$UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split("\")[-1]
$PasswordPlain = "Develop1234"
$SecurePassword = ConvertTo-SecureString $PasswordPlain -AsPlainText -Force

Set-LocalUser -Name $UserName -Password $SecurePassword -ErrorAction SilentlyContinue
Get-LocalUser -Name $UserName | Enable-LocalUser

Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction SilentlyContinue

$SshdConfig = "$env:ProgramData\ssh\sshd_config"
if (Test-Path $SshdConfig) {
    (Get-Content $SshdConfig) -replace '#PasswordAuthentication yes', 'PasswordAuthentication yes' | Set-Content $SshdConfig
    Add-Content $SshdConfig "`nAllowUsers $UserName"
}

ssh-keygen -A -ErrorAction SilentlyContinue

Start-Service sshd -ErrorAction SilentlyContinue
Set-Service -Name sshd -StartupType 'Automatic'
Enable-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue

New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds" -Name "ConsolePrompting" -Value $true -PropertyType "Boolean" -Force -ErrorAction SilentlyContinue

if (-not (Get-Command ngrok -ErrorAction SilentlyContinue)) {
    choco install ngrok -y --no-progress
}

& "C:\ProgramData\chocolatey\bin\ngrok.exe" config add-authtoken "3FXg3L4EvG25jxRWiRaZVNPi6Hu_4uaMokgmcJrry78mC8Luy"

Start-Sleep -Seconds 3

Start-Process "C:\ProgramData\chocolatey\bin\ngrok.exe" -ArgumentList "tcp 22 --log=stdout" -RedirectStandardOutput ".\ngrok.log" -WindowStyle Hidden

Start-Sleep -Seconds 7

$SshAddress = Select-String -Path ".\ngrok.log" -Pattern "url=tcp://" | ForEach-Object { $_.Matches.Value }
if ($SshAddress) {
    $CleanAddress = ($SshAddress -split "url=tcp://")[-1]
    Write-Host "=================================================="
    Write-Host "NEW SSH ADDRESS: $CleanAddress"
    Write-Host "=================================================="
} else {
    Write-Host "Failed to parse address"
    Get-Content ".\ngrok.log" -Tail 10
}

ping.exe -t 127.0.0.1
