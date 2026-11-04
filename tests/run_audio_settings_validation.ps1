$ErrorActionPreference='Stop'
$engine='C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$workspace=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$runs=@(
    @{Name='audio-settings-functional'; Script='audio_settings_functional'; Native=$true},
    @{Name='audio-voice-lifecycle'; Script='br_voice_lifecycle_validation'; Native=$false},
    @{Name='audio-naval-voice'; Script='revision_1102_naval_voice'; Native=$false},
    @{Name='audio-capture-control'; Script='voice_capture1103_validation'; Native=$false},
    @{Name='audio-voice-codec'; Script='br_voice_codec_validation'; Native=$false},
    @{Name='audio-war-state'; Script='war_state_ordering'; Native=$false},
    @{Name='audio-war-round'; Script='war_round_transition_regression'; Native=$false}
)
$jobs=@()
try {
    foreach($run in $runs) {
        $arguments=@('--path',('"'+$workspace+'"'),'--script',('res://tests/'+$run.Script+'.gd'),'--log-file',('"'+$workspace+'/work/'+$run.Name+'.log"'))
        if($run.Native){$arguments+=@('--rendering-method','gl_compatibility','--resolution','800x600','--position','0,0')}
        else {$arguments+='--headless'}
        $arguments+=@('--','--naval-test-accounts',('"--naval-data='+$workspace+'/work/'+$run.Name+'-profile"'))
        $process=Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $workspace -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $workspace ('work/'+$run.Name+'-stdout.log')) -RedirectStandardError (Join-Path $workspace ('work/'+$run.Name+'-stderr.log'))
        $jobs+=@{Name=$run.Name; Process=$process}
    }
    $deadline=(Get-Date).AddSeconds(100)
    while(@($jobs | Where-Object {-not $_.Process.HasExited}).Count -gt 0 -and (Get-Date) -lt $deadline){Start-Sleep -Milliseconds 250}
    $failed=@()
    foreach($job in $jobs) {
        if(-not $job.Process.HasExited){$failed+=$job.Name+' timeout';continue}
        $stderr=Get-Content -LiteralPath (Join-Path $workspace ('work/'+$job.Name+'-stderr.log')) -Raw
        $stdout=Get-Content -LiteralPath (Join-Path $workspace ('work/'+$job.Name+'-stdout.log')) -Raw
        Write-Output ($job.Name+' exit='+$job.Process.ExitCode)
        if($job.Process.ExitCode -ne 0 -or $stderr -match 'SCRIPT ERROR|Parse Error|(?m)^ERROR:' -or $stdout -match 'SCRIPT ERROR|Parse Error|(?m)^ERROR:'){
            $failed+=$job.Name
            Write-Output $stderr
            Write-Output $stdout
        }
    }
    if($failed.Count -gt 0){throw ('Audio validation failed: '+($failed -join ', '))}
} finally {
    foreach($job in $jobs){if(-not $job.Process.HasExited){Stop-Process -Id $job.Process.Id -Force}}
}
