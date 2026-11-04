param([Parameter(Mandatory=$true)][string]$Executable,[Parameter(Mandatory=$true)][string]$ResultPath,[switch]$Elevated)
$ErrorActionPreference = 'Stop'
function Write-Result($state,$message) {
    $json = @{state=$state;message=$message} | ConvertTo-Json -Compress
    [IO.File]::WriteAllText(($ResultPath+'.tmp'), $json, (New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath ($ResultPath+'.tmp') -Destination $ResultPath -Force
}
try {
    $Executable = (Resolve-Path -LiteralPath $Executable).Path
    if ([IO.Path]::GetExtension($Executable) -ne '.exe') { throw 'Executavel invalido.' }
    $matching = @(Get-NetFirewallApplicationFilter -Program $Executable -ErrorAction SilentlyContinue | Get-NetFirewallRule | Where-Object { $_.Enabled -eq 'True' -and $_.Direction -eq 'Inbound' })
    $activeProfiles = @(Get-NetConnectionProfile | ForEach-Object { if ($_.NetworkCategory -eq 'DomainAuthenticated') { 'Domain' } else { $_.NetworkCategory.ToString() } } | Sort-Object -Unique)
    foreach ($rule in $matching) {
        $protocol = ($rule | Get-NetFirewallPortFilter).Protocol
        if ($rule.Action -eq 'Block' -and $protocol -in @('Any','UDP','17')) { throw 'Uma regra de bloqueio do Windows impede este executavel. Revise as permissoes do aplicativo no Firewall.' }
    }
    foreach ($rule in $matching) {
        $ports = $rule | Get-NetFirewallPortFilter
        $profiles = @($rule.Profile.ToString() -split ',\s*')
        $addresses = @(($rule | Get-NetFirewallAddressFilter).RemoteAddress)
        $missing = @($activeProfiles | Where-Object { $_ -notin $profiles })
        $coversNetwork = 'Any' -in $profiles -or ($activeProfiles.Count -gt 0 -and $missing.Count -eq 0)
        if ($rule.Action -eq 'Allow' -and $ports.Protocol -in @('Any','UDP','17') -and $coversNetwork -and $ports.LocalPort -contains 'Any' -and ('Any' -in $addresses -or 'LocalSubnet' -in $addresses)) {
            Write-Result 'allowed' 'Acesso UDP do aplicativo ja permitido.'
            exit 0
        }
    }
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $admin) {
        if ($Elevated) { throw 'Permissao de administrador nao concedida.' }
        $arguments = '-NoProfile -ExecutionPolicy Bypass -File "'+$PSCommandPath+'" -Executable "'+$Executable+'" -ResultPath "'+$ResultPath+'" -Elevated'
        $process = Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Hidden -ArgumentList $arguments -Wait -PassThru
        if (-not (Test-Path -LiteralPath $ResultPath)) { throw 'Permissao de rede nao confirmada pelo Windows.' }
        exit $process.ExitCode
    }
    $sha = [Security.Cryptography.SHA256]::Create()
    $suffix = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Executable.ToLowerInvariant())))).Replace('-','').Substring(0,16)
    $sha.Dispose()
    $name = 'ToqueDeCampo-Naval-LAN-'+$suffix
    New-NetFirewallRule -Name $name -DisplayName 'Toque de Campo - Naval na rede local' -Direction Inbound -Action Allow -Enabled True -Program $Executable -Protocol UDP -Profile Any -RemoteAddress LocalSubnet | Out-Null
    Write-Result 'allowed' 'Conexoes UDP na rede local permitidas para este aplicativo.'
} catch {
    Write-Result 'denied' $_.Exception.Message
    exit 1
}
