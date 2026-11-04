#requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$ruleName = 'ToqueDeCampo-Updates-LAN'
$pythonCommand = Get-Command python.exe -ErrorAction Stop
$existingRule = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
if ($null -eq $existingRule) {
    New-NetFirewallRule -Name $ruleName -DisplayName 'Toque de Campo - Downloads na rede local' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8088 -RemoteAddress LocalSubnet -Profile Any -Program $pythonCommand.Source | Out-Null
} else {
    Set-NetFirewallRule -Name $ruleName -Enabled True -Action Allow | Out-Null
}
Write-Host 'Downloads liberados na porta TCP 8088 somente para a rede local.'
Write-Host 'Esta regra nao abre o servidor para toda a internet e nao desliga o firewall.'
Get-NetTCPConnection -LocalPort 8088 -State Listen -ErrorAction SilentlyContinue | Select-Object LocalAddress, LocalPort, OwningProcess
Write-Host 'No outro computador: http://192.168.101.227:8088'
