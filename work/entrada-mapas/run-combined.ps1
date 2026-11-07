$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$godot='C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$pattern=@(0,0,0,1,1,0,0,1,1,0,0,1)
$rows=@()
foreach($operation in @('favela','afghan')){
    for($i=0;$i -lt $pattern.Length;$i++){
        $others=@(Get-CimInstance Win32_Process|Where-Object {$_.Name -match 'Godot'})
        if($others.Count -gt 0){throw 'Contaminated: other Godot process active'}
        $variant=$pattern[$i]
        $env:TDC_IA2_HOUSING_CACHE=[string]$variant
        $env:TDC_IA2_TERRAIN_FACES=[string]$variant
        $env:TDC_IA2_MAP_STAGES='0'
        $env:TDC_IA2_NEIGHBOR_SUBSTAGES='0'
        $name='combined-{0}-{1:D2}-{2}' -f $operation,($i+1),$variant
        $before=nvidia-smi --query-gpu=timestamp,temperature.gpu,clocks_throttle_reasons.active --format=csv,noheader
        & $godot --headless --max-fps 60 --path $root --script res://tests/ia2_entry_combined_60s.gd -- "--operation=$operation" --seconds=60 "--label=$name" *> (Join-Path $PSScriptRoot ($name+'.log'))
        if($LASTEXITCODE -ne 0){throw ('Godot failed '+$name)}
        $after=nvidia-smi --query-gpu=timestamp,temperature.gpu,clocks_throttle_reasons.active --format=csv,noheader
        $line=Get-Content (Join-Path $PSScriptRoot ($name+'.log')) | Where-Object {$_.StartsWith('IA2_COMBINED_60S ')} |Select-Object -Last 1
        if(!$line){throw ('no results '+$name)}
        $raw=$line.Substring('IA2_COMBINED_60S '.Length)
        $data=$raw |ConvertFrom-Json
        if($data.bot_count -ne 28 -or $data.bots_deployed_initial -ne 28 -or $data.duration_measured_sec -lt 59.9){throw "Invalid result $name"}
        if($data.operation -ne $operation){throw "Operation mismatch $name"}
        [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot ($name+'.json')),$raw,(New-Object System.Text.UTF8Encoding($false)))
        $row=[pscustomobject]@{
            operation=$operation;run=$i+1;variant=$variant;world_ms=$data.game_world_ms;
            ready_ms=$data.join_ready_ms;frame_mean_ms=$data.frames.mean;
            frame_p95_ms=$data.frames.p95;frame_p99_ms=$data.frames.p99;frame_max_ms=$data.frames.max;
            physics_p99_ms=$data.physics_ms.p99;max_ticks=$data.max_ticks_frame;
            multi_tick_frames=$data.multi_tick_frames;shots=$data.bot_diagnostics.shots;
            join_unix_ms=$data.join_unix_ms;sample_start_unix_ms=$data.sample_start_unix_ms;
            sample_end_unix_ms=$data.sample_end_unix_ms;
            gpu_start=$before;gpu_end=$after
        }
        $rows+=$row
        $rows|Export-Csv (Join-Path $PSScriptRoot 'combined-60s-24runs.csv') -NoTypeInformation -Encoding UTF8
        Write-Output ('IA2_COMBINED_RUN '+($row|ConvertTo-Json -Compress))
    }
}
Write-Output 'IA2_COMBINED_ALL_24_RUNS_DONE'
