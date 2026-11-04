param([Parameter(Mandatory=$true)][string]$Path,[int]$RunnerPid=0)
$previous = @{}
$previousTime = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000.0
while ($true) {
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000.0
    $elapsed = [Math]::Max(.01, $now - $previousTime)
    $sample = @{ unix=$now; cpu_temp_c=$null; cpu_temp_status='thermal sensor unavailable'; cpu_clock_source='Windows estimated aggregate'; external_processes=@() }
    try {
        $cpu = Get-CimInstance -ClassName Win32_PerfFormattedData_Counters_ProcessorInformation -Filter "Name='_Total'"
        $sample.cpu_estimated_mhz = [double]$cpu.ProcessorFrequency * [double]$cpu.PercentProcessorPerformance / 100.0
        $sample.cpu_utilization_percent = [double]$cpu.PercentProcessorTime
    } catch { $sample.cpu_error = $_.Exception.Message }
    try {
        $gpu = (& nvidia-smi --query-gpu=temperature.gpu,clocks.current.graphics,clocks.current.memory,power.draw,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits | Select-Object -First 1).Split(',')
        $fields = @('gpu_temp_c','gpu_clock_mhz','gpu_memory_clock_mhz','gpu_power_w','gpu_utilization_percent','gpu_memory_used_mib','gpu_memory_total_mib')
        for ($i=0; $i -lt $fields.Count; $i++) { $sample[$fields[$i]] = [double]::Parse($gpu[$i].Trim(),[cultureinfo]::InvariantCulture) }
    } catch { $sample.gpu_error = $_.Exception.Message }
    $current = @{}
    $external = @()
    foreach ($proc in Get-Process) {
        try {
            $cpuTime = $proc.CPU
            if ($null -eq $cpuTime) { continue }
            $id = [string]$proc.Id
            $current[$id] = [double]$cpuTime
            if ($previous.ContainsKey($id) -and $proc.Id -ne $PID -and $proc.Id -ne $RunnerPid -and $proc.ProcessName -notmatch '^Godot' -and $proc.ProcessName -notin @('Idle','System')) {
                $cores = [Math]::Max(0.0,([double]$cpuTime - $previous[$id]) / $elapsed)
                if ($cores -ge .05) { $external += @{name=$proc.ProcessName; id=$proc.Id; cpu_cores=[Math]::Round($cores,3)} }
            }
        } catch { }
    }
    $sample.external_processes = @($external | Sort-Object -Property cpu_cores -Descending | Select-Object -First 8)
    Add-Content -LiteralPath $Path -Value ($sample | ConvertTo-Json -Compress -Depth 5) -Encoding UTF8
    $previous=$current; $previousTime=$now
    Start-Sleep -Seconds 3
}
