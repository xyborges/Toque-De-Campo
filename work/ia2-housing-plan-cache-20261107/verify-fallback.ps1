$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$godot='C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$file=Join-Path $repo 'maps\prepared\favela\housing_plan_cache.res'
$held=$file+'.temporarily_hidden'
if(@(Get-Process -Name Godot* -ErrorAction SilentlyContinue).Count -gt 0){throw 'Godot concorrente'}
if(!(Test-Path $file) -or (Test-Path $held)){throw 'Unsafe cache state'}
$original=(Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash
try {
    Move-Item -LiteralPath $file -Destination $held
    $env:TDC_IA2_HOUSING_CACHE='1'
    $log=Join-Path $PSScriptRoot 'fallback-cache-missing.log'
    & $godot --headless --path $repo --script res://tests/ia2_housing_plan_cache_qa.gd -- --expect-fallback --run=999 *> $log
    $code=$LASTEXITCODE
    Write-Output ('FALLBACK_EXIT='+$code)
    Get-Content -LiteralPath $log -Tail 5
    if($code -ne 0){throw 'Fallback test failed'}
} finally {
    if(Test-Path $held){Move-Item -LiteralPath $held -Destination $file -Force}
}
if(!(Test-Path $file) -or (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash -ne $original){throw 'Cache asset was not restored intact'}
Write-Output 'FALLBACK_AND_RESTORATION_PASS'
