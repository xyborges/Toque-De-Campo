$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$godot='C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$sourceCache=Join-Path $repo 'maps\prepared\favela\housing_plan_cache.res'
$otherCache='C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Toque-De-Campo-ia2-architecture-cache\maps\prepared\favela\housing_plan_cache.res'
$originalSHA=(Get-FileHash -Algorithm SHA256 $sourceCache).Hash
$pattern=@(0,0,0,1,1,0,0,1,1,0,0,1)
$records=@()
$firstHash=''
foreach($i in 0..($pattern.Length-1)){
    if(@(Get-CimInstance Win32_Process|Where-Object {$_.Name -match 'Godot'}).Count -gt 0){throw 'Godot concorrente'}
    $v=$pattern[$i];$env:TDC_IA2_HOUSING_CACHE=[string]$v
    $out=Join-Path $PSScriptRoot ('v25-{0:D2}-{1}.log' -f ($i+1),$v)
    & $godot --headless --path $repo --script res://tests/ia2_v25_housing_cache_qa.gd -- --mode=measure *> $out
    if($LASTEXITCODE -ne 0){throw ('Godot failed '+$out)}
    $line=Get-Content $out |Where-Object {$_.StartsWith('IA2_V25_PLAN ')}|Select-Object -Last 1
    if(!$line){throw ('no result '+$out)}
    $json=$line.Substring('IA2_V25_PLAN '.Length)|ConvertFrom-Json
    if($json.count -ne 4313){throw ('houses changed '+$out)}
    if(!$firstHash){$firstHash=$json.digest}
    if($firstHash -ne $json.digest){throw 'Plan differs'}
    if($v -eq 1 -and $json.status -ne 'loaded'){throw 'Cache was not used'}
    if($v -eq 0 -and $json.status -ne 'generated'){throw 'Baseline incorrect'}
    $record=[pscustomobject]@{run=$i+1;variant=$v;duration_ms=$json.elapsed_ms;sha256=$json.digest;status=$json.status}
    $records+=$record
    $records|Export-Csv (Join-Path $PSScriptRoot 'v25-12runs.csv') -Encoding UTF8 -NoTypeInformation
    Write-Output ('V25_AB '+($record|ConvertTo-Json -Compress))
}
$held=$sourceCache+'.temporarily_hidden'
if(Test-Path $held){throw 'Temporary file already exists'}
try {
    Move-Item $sourceCache $held
    $env:TDC_IA2_HOUSING_CACHE='1'
    & $godot --headless --path $repo --script res://tests/ia2_v25_housing_cache_qa.gd -- --mode=measure *> (Join-Path $PSScriptRoot 'v25-fallback-missing.log')
    if($LASTEXITCODE -ne 0){throw 'Missing fallback failed'}
    $j=(Get-Content (Join-Path $PSScriptRoot 'v25-fallback-missing.log')|Where-Object {$_.StartsWith('IA2_V25_PLAN ')}|Select-Object -Last 1).Substring(13)|ConvertFrom-Json
    if($j.status -ne 'generated' -or $j.digest -ne $firstHash){throw 'Missing cache failed integrity'}
} finally {
    if(Test-Path $held){Move-Item $held $sourceCache -Force}
}
$backup=$sourceCache+'.backup_validation'
if(Test-Path $backup){throw 'Backup unexpectedly exists'}
try {
    Copy-Item $sourceCache $backup
    Copy-Item $otherCache $sourceCache -Force
    $env:TDC_IA2_HOUSING_CACHE='1'
    & $godot --headless --path $repo --script res://tests/ia2_v25_housing_cache_qa.gd -- --mode=measure *> (Join-Path $PSScriptRoot 'v25-fallback-foreign-cache.log')
    if($LASTEXITCODE -ne 0){throw 'Foreign signature test failed'}
    $j=(Get-Content (Join-Path $PSScriptRoot 'v25-fallback-foreign-cache.log')|Where-Object {$_.StartsWith('IA2_V25_PLAN ')}|Select-Object -Last 1).Substring(13)|ConvertFrom-Json
    if($j.status -ne 'generated' -or $j.digest -ne $firstHash){throw 'Incompatible cache wrongly accepted'}
} finally {
    if(Test-Path $backup){Copy-Item $backup $sourceCache -Force;Remove-Item $backup -Force}
}
if((Get-FileHash -Algorithm SHA256 $sourceCache).Hash -ne $originalSHA){throw 'v25 cache changed'}
Write-Output 'V25_FIVE_PAIRS_AND_TWO_FALLBACKS_PASSED'
