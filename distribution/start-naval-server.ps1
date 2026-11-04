param(
    [ValidateRange(1024, 65535)][int]$Port = 3012,
    [string]$DataDirectory = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$gamePath = Join-Path $projectRoot 'distribution\build\game\ToqueDeCampo.exe'
$godotPath = 'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$logName = if ($Port -eq 3012) { 'naval-server.log' } else { "naval-server-$Port.log" }
$logPath = Join-Path $projectRoot "work\$logName"
if (-not $DataDirectory) { $DataDirectory = Join-Path $projectRoot 'user_data\naval-server' }

# Serialize the check/start operation, including simultaneous double-clicks.
$startupLock = New-Object System.Threading.Mutex($false, "Local\ToqueDeCampo-Naval-Startup-$Port")
$lockHeld = $false
$ownedServer = $null
try {
    try { $lockHeld = $startupLock.WaitOne(15000) }
    catch [System.Threading.AbandonedMutexException] { $lockHeld = $true }
    if (-not $lockHeld) { throw 'Outra janela esta iniciando o servidor. Aguarde e tente novamente.' }

    $listeners = @(Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue)
    if ($listeners.Count -gt 0) {
        $knownServer = $false
        foreach ($ownerId in @($listeners.OwningProcess | Sort-Object -Unique)) {
            $owner = Get-CimInstance Win32_Process -Filter "ProcessId=$ownerId" -ErrorAction SilentlyContinue
            if ($null -eq $owner) { continue }
            $nativeGame = $owner.ExecutablePath -eq $gamePath
            $sourceGame = $owner.ExecutablePath -eq $godotPath -and
                $owner.CommandLine.IndexOf($projectRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0
            if (($nativeGame -or $sourceGame) -and $owner.CommandLine -match '(?:^|\s)"?--naval-server"?(?:\s|$)') {
                Write-Host "O servidor naval ja esta ativo (processo $ownerId)."
                Write-Host 'Pode abrir o jogo, conectar a 192.168.101.227 e entrar/criar uma sala.'
                Write-Host 'As salas existentes continuam funcionando.'
                $knownServer = $true
                break
            }
        }
        if ($knownServer) { exit 0 }
        $owners = @($listeners.OwningProcess | Sort-Object -Unique) -join ', '
        throw "A porta UDP $Port esta ocupada por outro processo ($owners). Nenhum processo foi encerrado."
    }

    New-Item -ItemType Directory -Path (Split-Path $logPath) -Force | Out-Null
    if (Test-Path -LiteralPath $gamePath) {
        $executable = $gamePath
        $arguments = @('--headless', '--max-fps', '60', '--log-file', $logPath)
    } elseif (Test-Path -LiteralPath $godotPath) {
        $executable = $godotPath
        $arguments = @('--headless', '--max-fps', '60', '--path', $projectRoot, '--log-file', $logPath)
    } else { throw 'Executavel do jogo e Godot nao encontrados. Publique o jogo antes de hospedar.' }
    $arguments += @('--', '--naval-server', "--naval-port=$Port", "--naval-data=$DataDirectory")
    $quotedArguments = ($arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $server = Start-Process -FilePath $executable -ArgumentList $quotedArguments -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru
    $ownedServer = $server

    # Hold the startup lock until the child binds successfully or exits.
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    $ready = $false
    while ([DateTime]::UtcNow -lt $deadline) {
        $server.Refresh()
        if ($server.HasExited) { break }
        $bound = @(Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue | Where-Object { $_.OwningProcess -eq $server.Id })
        if ($bound.Count -gt 0) { $ready = $true; break }
        Start-Sleep -Milliseconds 200
    }
    if (-not $ready) {
        if (-not $server.HasExited) { $server.Kill(); $server.WaitForExit() }
        throw "O servidor nao conseguiu iniciar. Consulte $logPath"
    }
    Write-Host "Servidor naval iniciado (processo $($server.Id))."
    Write-Host 'Mantenha esta janela aberta para hospedar a partida.'
    $startupLock.ReleaseMutex()
    $lockHeld = $false
    $server.WaitForExit()
    Write-Host "Servidor encerrado. Log: $logPath"
} catch {
    Write-Host "Nao foi possivel hospedar: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    if ($null -ne $ownedServer -and -not $ownedServer.HasExited) {
        $ownedServer.Kill()
        $ownedServer.WaitForExit()
    }
    if ($lockHeld) { $startupLock.ReleaseMutex() }
    $startupLock.Dispose()
}
