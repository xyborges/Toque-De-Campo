$ErrorActionPreference = 'Stop'
$godot = 'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$prefix = 'afghan-ground-ab-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$lockPath = Join-Path $PWD 'work/performance-benchmark.lock'
$exclusive = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
$monitor = $null
try {
    $monitorPath = Join-Path $PWD "work/$prefix-hardware.jsonl"
    $monitorScript = Join-Path $PWD 'tests/perf200_cpu_monitor.ps1'
    $monitor = Start-Job -ScriptBlock { param($scriptPath,$outputPath) & $scriptPath -Path $outputPath } -ArgumentList $monitorScript,$monitorPath
    Write-Output "BR_AB_PREFIX $prefix"
    foreach ($entry in @('a1','b1','a2','b2','a3','b3','a4')) {
        $others = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(Godot.*|ToqueDeCampo(?:\.console)?)\.exe$' })
        if ($others.Count -gt 0) { throw 'Outro Godot está aberto; comparação cancelada para não concorrer pela GPU.' }
        $extra = @('--after')
        if ($entry.StartsWith('a')) { $extra += '--ground-unbaked' }
        $label = "$prefix-$entry"
        $log = Join-Path $PWD "work/$label.log"
        & $godot --path . --rendering-method gl_compatibility --resolution 1920x1080 --screen 0 --windowed --script res://tests/br_atmosphere_benchmark.gd --log-file $log -- "--label=$label" --seconds=24 --warmup=8 --naval-test-accounts "--naval-data=$PWD/work/br-atmosphere-data" @extra *> (Join-Path $PWD "work/$label-stdout.log")
        if ($LASTEXITCODE -ne 0) { throw "Benchmark falhou em $entry" }
        if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|ERROR:') { throw "Erros no benchmark $entry" }
        $data = Get-Content -LiteralPath "work/$label.json" -Raw | ConvertFrom-Json
        if ($data.actors -ne 18 -or $data.resolution[0] -ne 1920 -or $data.resolution[1] -ne 1080) { throw 'Condições inválidas de medição' }
        Write-Output "$entry FPS=$($data.fps) low=$($data.one_percent_low) worst=$($data.worst_ms)"
    }
} finally {
    if ($monitor) { Stop-Job $monitor; Remove-Job $monitor }
    if ($exclusive) { $exclusive.Dispose() }
}
