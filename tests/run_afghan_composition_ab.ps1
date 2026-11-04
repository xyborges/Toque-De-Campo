param([switch]$WarmCache)
$ErrorActionPreference='Stop'
$godot='C:/Users/Joao Borges/Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$prefix='afghan-composition-'+(Get-Date -Format 'yyyyMMdd-HHmmss')
$lockPath=Join-Path $PWD 'work/performance-benchmark.lock'
$exclusive=[System.IO.File]::Open($lockPath,[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
$monitor=$null
try {
    $monitorPath=Join-Path $PWD "work/$prefix-hardware.jsonl"
    $monitorScript=Join-Path $PWD 'tests/perf200_cpu_monitor.ps1'
    $monitor=Start-Job -ScriptBlock {param($scriptPath,$outputPath) & $scriptPath -Path $outputPath} -ArgumentList $monitorScript,$monitorPath
    Write-Output "COMPOSITION_AB $prefix"
    $entries=if($WarmCache){@('a-warm','b-warm')}else{@('a1','b1','a2','b2','a3','b3','a4')}
    foreach($entry in $entries){
        $others=@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match '^(Godot.*|ToqueDeCampo(?:\.console)?)\.exe$'})
        if($others.Count -gt 0){throw 'Outra instância aberta; comparação cancelada.'}
        $label="$prefix-$entry"
        $log=Join-Path $PWD "work/$label.log"
        $extra=@()
        if($entry.StartsWith('a')){$extra+='--reference'}
        if($WarmCache){$extra+='--bake-afghan-static';$extra+='--captures'}
        & $godot --path . --rendering-method gl_compatibility --resolution 1920x1080 --screen 0 --windowed --script res://tests/afghan_composition_benchmark.gd --log-file $log -- --after --village-captures "--label=$label" --seconds=24 --warmup=8 --naval-test-accounts "--naval-data=$PWD/work/br-test-data" @extra *> (Join-Path $PWD "work/$label-stdout.log")
        if($LASTEXITCODE -ne 0){throw "Falha em $entry"}
        if(Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|Parse Error|Shader.*failed'){throw "Erro em $entry"}
        if($WarmCache){Write-Output "WARM $entry";continue}
        $data=Get-Content -LiteralPath "work/$label.json" -Raw|ConvertFrom-Json
        if($data.actors -ne 18 -or $data.resolution[0] -ne 1920 -or $data.resolution[1] -ne 1080){throw 'Condições inválidas'}
        if(-not(Select-String -LiteralPath $log -Pattern 'NVIDIA GeForce GTX 1650')){throw 'GPU diferente; descartar medição'}
        Write-Output "$entry FPS=$($data.fps) LOW=$($data.one_percent_low) WORST=$($data.worst_ms) DRAW=$($data.draw_calls)"
    }
} finally {
    if($monitor){Stop-Job $monitor;Remove-Job $monitor}
    $exclusive.Dispose()
}
