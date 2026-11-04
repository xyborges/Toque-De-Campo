$ErrorActionPreference='Stop'
$others=@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match '^(Godot.*|ToqueDeCampo(?:\.console)?)\.exe$'})
if($others.Count){throw 'Feche o jogo antes do benchmark.'}
$lock=[IO.File]::Open((Join-Path $PWD 'work/performance-benchmark.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$monitor=$null
try {
    $monitor=Start-Job -ScriptBlock {param($s,$p) & $s -Path $p} -ArgumentList "$PWD/tests/perf200_cpu_monitor.ps1","$PWD/work/afghan-ground-clean-hardware.jsonl"
    & 'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --rendering-method gl_compatibility --resolution 1920x1080 --screen 0 --windowed --script res://tests/br_atmosphere_benchmark.gd --log-file "$PWD/work/afghan-ground-clean.log" -- --after --ground-paired --label=afghan-ground-clean --warmup=8 --naval-test-accounts "--naval-data=$PWD/work/br-test-data"
    if($LASTEXITCODE -ne 0){throw 'Benchmark inválido ou interrompido'}
    Copy-Item -LiteralPath work/afghan-ground-paired.json -Destination work/afghan-ground-clean.json
} finally {
    if($monitor){Stop-Job $monitor;Remove-Job $monitor}
    $lock.Dispose()
}
