$ErrorActionPreference='Stop'
$engine='C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$processes=@()
try {
    foreach($role in @('server','alpha','bravo')) {
        $log=Join-Path $PWD "work/br-optic-duel-$role.log"
        $arguments=@('--path',('"'+$PWD+'"'),'--script','res://tests/br_optic_duel.gd','--log-file',('"'+$log+'"'),'--resolution','960x640')
        if($role -eq 'server'){$arguments=@('--headless')+$arguments}
        $arguments+=@('--','--naval-test-accounts',"--role=$role",('"--naval-data='+$PWD+'/work/br-optic-duel-profile-'+$role+'"'),('"--game-tls-cert='+$PWD+'/work/security182/test.crt"'),('"--game-tls-key='+$PWD+'/work/security182/test.key"'),('"--game-tls-ca='+$PWD+'/work/security182/test.crt"'),'--game-tls-host=localhost')
        $p=Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $PWD -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PWD "work/br-optic-duel-$role-stdout.log") -RedirectStandardError (Join-Path $PWD "work/br-optic-duel-$role-stderr.log")
        $processes+=$p
        if($role -eq 'server'){Start-Sleep -Seconds 2}
    }
    $limit=(Get-Date).AddSeconds(120)
    while(@($processes | Where-Object {-not $_.HasExited}).Count -gt 0 -and (Get-Date) -lt $limit){
        if(Select-String -Path 'work/br-optic-duel-*-stderr.log' -Pattern 'SCRIPT ERROR|Parse Error' -Quiet){throw 'Script error in duel harness'}
        Start-Sleep -Milliseconds 500
    }
    foreach($p in $processes){if(-not $p.HasExited){throw 'Duel timeout'}}
    foreach($role in @('server','alpha','bravo')) {Get-Content -LiteralPath "work/br-optic-duel-$role-stderr.log" -Tail 8}
    $result=Get-Content work/br-optic-duel.json -Raw | ConvertFrom-Json
    $result | Select-Object ok,checks,failures,scope | ConvertTo-Json
    if(-not $result.ok -or @($processes | Where-Object {$_.ExitCode -ne 0}).Count -gt 0){throw 'Duel failed'}
} finally {
    foreach($p in $processes){if(-not $p.HasExited){Stop-Process -Id $p.Id -Force}}
}
