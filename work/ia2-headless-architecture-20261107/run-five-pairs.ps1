$ErrorActionPreference='Stop'
$w=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$godot='C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$pattern=@(0,1,1,0,0,1,1,0,0,1)
$rows=@()
$baselineGeo=$null
$baselineProbe=$null
foreach($i in 0..9){
    if (@(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue).Count -gt 0) {throw 'Godot concorrente'}
    $variant=$pattern[$i]
    $env:TDC_IA2_SKIP_HEADLESS_ARCH_VISUALS=[string]$variant
    $name='architecture-{0:D2}-{1}' -f ($i+1),$variant
    $log=Join-Path $PSScriptRoot ($name+'.log')
    & $godot --headless --path $w --script res://tests/ia2_headless_architecture_qa.gd -- "--run=$($i+1)" *> $log
    if($LASTEXITCODE -ne 0){throw "Experiment failed: $name"}
    $line=Get-Content $log|Where-Object{$_.StartsWith('IA2_HEADLESS_ARCH_BENCH ')}|Select-Object -Last 1
    if(!$line){throw "Report missing $name"}
    $raw=$line.Substring('IA2_HEADLESS_ARCH_BENCH '.Length)
    $result=$raw|ConvertFrom-Json
    if(@($result.errors).Count -gt 0 -or $result.geometry.shapes -lt 11000){throw "QA failure: $name"}
    if(!$baselineGeo){$baselineGeo=$result.geometry.geometry_sha256;$baselineProbe=$result.probe_digest}
    if($result.geometry.geometry_sha256 -ne $baselineGeo -or $result.probe_digest -ne $baselineProbe){throw "Physics mismatch: $name"}
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot ($name+'.json')),$raw,(New-Object System.Text.UTF8Encoding($false)))
    $row=[pscustomobject]@{run=$i+1;variant=$variant;world_ms=$result.world_ms;ready_ms=$result.join_ready_ms;
        houses=$result.houses;tiles=$result.tiles;collisions=$result.collisions;
        total_shapes=$result.geometry.shapes;geometry_sha256=$result.geometry.geometry_sha256;
        ray_sha256=$result.probe_digest}
    $rows+=$row
    $rows|Export-Csv (Join-Path $PSScriptRoot 'architecture-5pairs.csv') -Encoding utf8 -NoTypeInformation
    Write-Output ('IA2_ARCH_PAIR '+($row|ConvertTo-Json -Compress))
}
Write-Output 'IA2_ARCH_ALL_TEN_VALID'
