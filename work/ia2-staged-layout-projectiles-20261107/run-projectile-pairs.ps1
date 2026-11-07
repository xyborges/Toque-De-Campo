$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$godot = 'C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$pattern = @(0,1,1,0,0,1,1,0,0,1)
$all = @()
$expectedDigest = $null
foreach ($i in 0..9) {
    if (@(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue).Count -gt 0) {throw 'Godot concorrente'}
    $variant=$pattern[$i]
    $name = 'projectiles-{0:D2}-{1}' -f ($i+1),$variant
    $log = Join-Path $PSScriptRoot ($name+'.log')
    $env:TDC_IA2_CLIENT_PROJECTILE_30HZ='0'
    & $godot --headless --path $repo --script res://tests/ia2_projectile_visual_cost_qa.gd -- "--optimized=$variant" "--run=$($i+1)" *> $log
    if ($LASTEXITCODE -ne 0) {throw "Failed projectile test $name"}
    $line = Get-Content $log | Where-Object {$_.StartsWith('IA2_VISUAL_PROJECTILE_BENCH ')} | Select-Object -Last 1
    if (!$line) {throw "No benchmark data: $name"}
    $raw=$line.Substring('IA2_VISUAL_PROJECTILE_BENCH '.Length)
    $obj=$raw|ConvertFrom-Json
    if (@($obj.errors).Count -gt 0 -or $obj.hits -ne 120) {throw "Invalid projectile run: $name"}
    if (!$expectedDigest) {$expectedDigest=$obj.hit_positions_sha256}
    if ($obj.hit_positions_sha256 -ne $expectedDigest) {throw "Hit position regression: $name"}
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot ($name+'.json')),$raw,(New-Object System.Text.UTF8Encoding($false)))
    $row=[pscustomobject]@{
        run=$i+1;variant=$variant;mean_tick_ms=$obj.tick_cpu.mean_ms;p95_tick_ms=$obj.tick_cpu.p95_ms
        p99_tick_ms=$obj.tick_cpu.p99_ms;max_tick_ms=$obj.tick_cpu.max_ms
        mean_frame_interval_ms=$obj.frame_intervals.mean_ms
        p99_frame_interval_ms=$obj.frame_intervals.p99_ms
        shots=$obj.shots;hits=$obj.hits;skips=$obj.skipped_queries;queries=$obj.visual_queries
        digest=$obj.hit_positions_sha256
    }
    $all+=$row
    $all | Export-Csv (Join-Path $PSScriptRoot 'projectile-5pairs.csv') -Encoding UTF8 -NoTypeInformation
    Write-Output ('IA2_PROJECTILE_PAIR '+($row | ConvertTo-Json -Compress))
}
Write-Output 'ALL_TEN_PROJECTILE_RUNS_VALID'
