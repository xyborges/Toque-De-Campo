$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$file=Join-Path $repo 'maps\prepared\favela\housing_plan_cache.res'
$backup=$file+'.signature_backup'
$py='C:\Users\Microgate\Documents\Codex\tools\Python-3.13.9\python.exe'
$godot='C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
if(@(Get-Process -Name Godot* -ErrorAction SilentlyContinue).Count -gt 0){throw 'Godot concorrente'}
if(!(Test-Path $file) -or (Test-Path $backup)){throw 'Unsafe asset state'}
$original=(Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash
try {
    Copy-Item -LiteralPath $file -Destination $backup -ErrorAction Stop
    & $py -c "from pathlib import Path;p=Path(r'$file');data=p.read_bytes();sig=b'c32fd8a5d8a5b58b84f9d550ae3f1949d3316cbeecadfef721275d40eae15dd4';assert data.count(sig)==1;p.write_bytes(data.replace(sig,b'0'*64));print('SIGNATURE_CORRUPTED_WITHOUT_CHANGING_LOTS')"
    if($LASTEXITCODE -ne 0){throw 'Could not prepare invalid signature'}
    $env:TDC_IA2_HOUSING_CACHE='1'
    $log=Join-Path $PSScriptRoot 'fallback-signature-invalid.log'
    & $godot --headless --path $repo --script res://tests/ia2_housing_plan_cache_qa.gd -- --expect-fallback --run=998 *> $log
    $code=$LASTEXITCODE
    Write-Output ('INVALID_SIGNATURE_EXIT='+$code)
    Get-Content -LiteralPath $log -Tail 4
    if($code -ne 0){throw 'Signature mismatch fallback failed'}
} finally {
    if(Test-Path $backup){Copy-Item -LiteralPath $backup -Destination $file -Force;Remove-Item -LiteralPath $backup -Force}
}
if((Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash -ne $original){throw 'Cache failed to restore'}
Write-Output 'SIGNATURE_GUARD_AND_ASSET_RESTORATION_PASS'
