param([Parameter(Mandatory=$true)][string]$Path)
$ErrorActionPreference = 'Stop'
while ($true) {
    $sample = @{ unix = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000.0; cpu_temp_c = $null; cpu_temp_status = 'unavailable: thermal WMI access denied'; cpu_clock_source = 'Windows estimate: ProcessorFrequency times PercentProcessorPerformance / 100' }
    try {
        $cpu = Get-CimInstance -ClassName Win32_PerfFormattedData_Counters_ProcessorInformation -Filter "Name='_Total'"
        $sample.cpu_nominal_mhz = [double]$cpu.ProcessorFrequency
        $sample.cpu_performance_percent = [double]$cpu.PercentProcessorPerformance
        $sample.cpu_estimated_mhz = [double]$cpu.ProcessorFrequency * [double]$cpu.PercentProcessorPerformance / 100.0
        $sample.cpu_utilization_percent = [double]$cpu.PercentProcessorTime
    } catch { $sample.cpu_error = $_.Exception.Message }
    try {
        $gpu = (& nvidia-smi --query-gpu=temperature.gpu,clocks.current.graphics,clocks.current.memory,power.draw,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits | Select-Object -First 1).Split(',')
        $sample.gpu_temp_c = [double]::Parse($gpu[0].Trim(),[cultureinfo]::InvariantCulture)
        $sample.gpu_clock_mhz = [double]::Parse($gpu[1].Trim(),[cultureinfo]::InvariantCulture)
        $sample.gpu_memory_clock_mhz = [double]::Parse($gpu[2].Trim(),[cultureinfo]::InvariantCulture)
        $sample.gpu_power_w = [double]::Parse($gpu[3].Trim(),[cultureinfo]::InvariantCulture)
        $sample.gpu_utilization_percent = [double]::Parse($gpu[4].Trim(),[cultureinfo]::InvariantCulture)
        $sample.gpu_memory_used_mib = [double]::Parse($gpu[5].Trim(),[cultureinfo]::InvariantCulture)
        $sample.gpu_memory_total_mib = [double]::Parse($gpu[6].Trim(),[cultureinfo]::InvariantCulture)
    } catch { $sample.gpu_error = $_.Exception.Message }
    Add-Content -LiteralPath $Path -Value ($sample | ConvertTo-Json -Compress) -Encoding UTF8
    Start-Sleep -Seconds 3
}
