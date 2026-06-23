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

ssh-keygen.exe -A

Start-Service sshd -ErrorAction SilentlyContinue
Set-Service -Name sshd -StartupType 'Automatic'
Enable-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue

if (-not (Get-Command ngrok -ErrorAction SilentlyContinue)) {
    choco install ngrok -y --no-progress
}

& "C:\ProgramData\chocolatey\bin\ngrok.exe" config add-authtoken "3FXg3L4EvG25jxRWiRaZVNPi6Hu_4uaMokgmcJrry78mC8Luy"

Start-Process "C:\ProgramData\chocolatey\bin\ngrok.exe" -ArgumentList "tcp 22" -WindowStyle Hidden

$NgrokUrl = $null
for ($i = 0; $i -lt 10; $i++) {
    Start-Sleep -Seconds 3
    try {
        $NgrokApi = Invoke-WebRequest -Uri "http://127.0.0" -UseBasicParsing -ErrorAction Stop | ConvertFrom-Json
        $NgrokUrl = $NgrokApi.tunnels.public_url
        if ($NgrokUrl) { break }
    } catch {}
}

if ($NgrokUrl) {
    $CleanAddress = $NgrokUrl -replace "tcp://", ""
    $AddrParts = $CleanAddress -split ":"
    $HostName = $AddrParts[0]
    $PortNumber = $AddrParts[1]
    
    Write-Host "=================================================="
    Write-Host "NEW SSH ADDRESS: $CleanAddress"
    Write-Host "COMMAND TO CONNECT:"
    Write-Host "ssh ${UserName}@${HostName} -p ${PortNumber}"
    Write-Host "=================================================="
} else {
    Write-Host "Ngrok failed to start or bind tunnel."
}

while ($true) {
    Write-Host "Keep-alive: Session is running..."
    Start-Sleep -Seconds 30
}
