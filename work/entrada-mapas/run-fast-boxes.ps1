$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$godot='C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$pattern=@(0,0,0,1,1,0,0,1,1,0,0,1) # first two are A/A, next 10 A/B/B/A/A/B/B/A/A/B
$results=@()
$expected=''
$env:TDC_IA2_MAP_STAGES='1'
$env:TDC_IA2_NEIGHBOR_SUBSTAGES='0'
$env:TDC_IA2_HOUSING_CACHE='1'
foreach($i in 0..($pattern.Count-1)){
    if(@(Get-CimInstance Win32_Process|Where-Object{$_.Name -match 'Godot'}).Count -gt 0){throw 'Concurrent Godot; stop contaminated benchmark'}
    $v=$pattern[$i]
    $env:TDC_IA2_FAST_HEADLESS_BOX=[string]$v
    $name=('fastbox-{0:D2}-{1}' -f ($i+1),$v)
    $before=(nvidia-smi --query-gpu=timestamp,temperature.gpu,clocks_throttle_reasons.active --format=csv,noheader)
    & $godot --headless --path $repo --script res://tests/ia2_housing_plan_cache_qa.gd -- "--run=$($i+1)" *> (Join-Path $PSScriptRoot ($name+'.log'))
    $code=$LASTEXITCODE
    $after=(nvidia-smi --query-gpu=timestamp,temperature.gpu,clocks_throttle_reasons.active --format=csv,noheader)
    if($code -ne 0){throw "Godot failed $name"}
    $line=Get-Content (Join-Path $PSScriptRoot ($name+'.log'))|Where-Object{$_.StartsWith('IA2_HOUSING_PLAN_BENCH ')}|Select-Object -Last 1
    if(!$line){throw "Missing report $name"}
    $json=$line.Substring('IA2_HOUSING_PLAN_BENCH '.Length)
    $j=$json|ConvertFrom-Json
    if(@($j.errors).Count -gt 0 -or $j.layout_status -ne 'loaded' -or $j.lots -ne 4188 -or $j.collisions -ne 11146){throw "Invalid map $name"}
    $stamp="$($j.plan_sha256):$($j.geometry_sha256):$($j.ray_sha256)"
    if(!$expected){$expected=$stamp}
    if($expected -ne $stamp){throw "Geometry mismatch $name"}
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot ($name+'.json')),$json,(New-Object System.Text.UTF8Encoding($false)))
    $row=[pscustomobject]@{run=$i+1;variant=$v;world_ms=$j.world_ms;ready_ms=$j.ready_ms;
        neighborhoods_ms=$j.stages.neighborhoods;layout_ms=$j.layout_ms;
        temperature_before=$before;temperature_after=$after;
        geometry_hash=$j.geometry_sha256}
    $results+=$row
    $results|Export-Csv (Join-Path $PSScriptRoot 'fastbox-12runs.csv') -NoTypeInformation -Encoding UTF8
    Write-Output ('FASTBOX_RUN '+($row|ConvertTo-Json -Compress))
}
Write-Output 'FASTBOX_AA_FIVE_PAIRS_DONE'
