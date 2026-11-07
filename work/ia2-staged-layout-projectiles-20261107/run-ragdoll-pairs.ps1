$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$godot='C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$pattern=@(0,1,1,0,0,1,1,0,0,1)
$rows=@()
foreach($i in 0..9){
    if(@(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue).Count -gt 0){throw 'Godot concurrent'}
    $variant=$pattern[$i]
    $env:TDC_IA2_RAGDOLL_MASK_ONLY=[string]$variant
    $name='ragdoll-mask-{0:D2}-{1}' -f ($i+1),$variant
    $log=Join-Path $PSScriptRoot ($name+'.log')
    & $godot --headless --path $repo --script res://tests/ia2_ragdoll_single_bench.gd -- "--run=$($i+1)" *> $log
    if($LASTEXITCODE -ne 0){throw "QA failed: $name"}
    $line=Get-Content $log|Where-Object {$_.StartsWith('IA2_RAGDOLL_MASK_BENCH ')}|Select-Object -Last 1
    if(!$line){throw "Missing metric: $name"}
    $raw=$line.Substring('IA2_RAGDOLL_MASK_BENCH '.Length)
    $j=$raw|ConvertFrom-Json
    if(@($j.errors).Count -ne 0 -or $j.ragdolls -ne 16 -or $j.bodies -ne 15 -or $j.joints -ne 14){throw "Unexpected skeleton: $name"}
    $expected=if($variant -eq 0){238}else{28}
    if($j.exceptions_in_last_corpse -ne $expected){throw "Unexpected collision exceptions $name"}
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot ($name+'.json')),$raw,(New-Object System.Text.UTF8Encoding($false)))
    $row=[pscustomobject]@{run=$i+1;variant=$variant;create_mean_ms=$j.create_ms.mean_ms;
        create_p95_ms=$j.create_ms.p95_ms;create_p99_ms=$j.create_ms.p99_ms;
        create_max_ms=$j.create_ms.max_ms;ragdolls=$j.ragdolls;
        bodies=$j.bodies;joints=$j.joints;exceptions=$j.exceptions_in_last_corpse}
    $rows+=$row
    $rows|Export-Csv (Join-Path $PSScriptRoot 'ragdoll-single-5pairs.csv') -Encoding UTF8 -NoTypeInformation
    Write-Output ('IA2_RAGDOLL_MASK_PAIR '+($row |ConvertTo-Json -Compress))
}
Write-Output 'ALL_TEN_RAGDOLL_PAIRS_VALID'
