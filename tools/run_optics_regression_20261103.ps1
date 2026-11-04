$root='C:\Users\Joao Borges\Documents\campo-cartunesco-godot\campo-cartunesco-godot'
$exe='C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$tests=@(
'tests/g3_validation_20261103.gd',
'tests/optics_universal_validation_20261103.gd',
'tests/optic_catalog_validation.gd',
'tests/attachment_framework_validation.gd',
'tests/optics_transport_validation.gd',
'tests/optic_preferences.gd',
'tests/prone_weapon_pose_validation.gd', # Equipment network requires configured QA DTLS certificates and independent peers.
'tests/scoped_muzzle_regression.gd',
'tests/br_optic_inventory_validation.gd',
'tests/war_spawn_attachment_crash_regression.gd'
)
$results=@()
foreach($test in $tests) {
  Write-Output "=== RUN $test ==="
  $messages=@(& $exe --headless --path $root --script "res://$test" 2>&1 | Out-String)
  $code=$LASTEXITCODE
  Write-Output ($messages | Select-Object -Last 1)
  $tail=$messages -split "`n" | Select-Object -Last 8
  $tail | ForEach-Object { Write-Output $_ }
  $results+=@{test=$test;exit=$code}
  Write-Output "=== RESULT $test EXIT $code ==="
}
$resultFile=Join-Path $root 'work\optics-regression-results-20261103.json'
$results | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resultFile -Encoding utf8
Write-Output "OPTICS_REGRESSION_FINISHED"
$results | ForEach-Object {Write-Output "$($_.test) EXIT=$($_.exit)"}
