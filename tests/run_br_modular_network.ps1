$ErrorActionPreference='Stop'
$engine='C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$processes=@()
try {
    foreach($role in @('server','alpha','bravo')) {
        $log=Join-Path $PWD "work/br-modular-$role.log"
        $arguments=@('--headless','--path',('"'+$PWD+'"'),'--script','res://tests/br_modular_network.gd','--log-file',('"'+$log+'"'),'--','--naval-test-accounts',"--role=$role",('"--naval-data='+$PWD+'/work/br-modular-profile-'+$role+'"'),('"--game-tls-cert='+$PWD+'/work/security182/test.crt"'),('"--game-tls-key='+$PWD+'/work/security182/test.key"'),('"--game-tls-ca='+$PWD+'/work/security182/test.crt"'),'--game-tls-host=localhost')
        $processes+=Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $PWD -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PWD "work/br-modular-$role-stdout.log") -RedirectStandardError (Join-Path $PWD "work/br-modular-$role-stderr.log")
        if($role -eq 'server'){Start-Sleep -Seconds 1}
    }
    $limit=(Get-Date).AddSeconds(120)
    while(@($processes | Where-Object {-not $_.HasExited}).Count -gt 0 -and (Get-Date) -lt $limit){Start-Sleep -Milliseconds 250}
    foreach($p in $processes){if(-not $p.HasExited){throw 'Modular network test timeout'}}
    foreach($role in @('server','alpha','bravo')){Get-Content -LiteralPath "work/br-modular-$role-stderr.log" -Tail 8}
    Get-Content work/br-modular-network.json
    if(@($processes | Where-Object {$_.ExitCode -ne 0}).Count -gt 0){throw 'Modular network test failed'}
} finally {
    foreach($p in $processes){if(-not $p.HasExited){Stop-Process -Id $p.Id -Force}}
}
