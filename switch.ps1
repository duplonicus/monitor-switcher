# Toggle primary monitor and audio device
# Useful for when you need to switch between a monitor at a desk and a TV from the couch

# Load configuration
$configPath = Join-Path $PSScriptRoot "config.json"
if (!(Test-Path $configPath)) {
    Write-Error "Configuration file not found: $configPath"
    exit 1
}

try {
    $config = Get-Content $configPath | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse configuration file: $($_.Exception.Message)"
    exit 1
}

# Expand environment variables in paths
$logPath = [System.Environment]::ExpandEnvironmentVariables($config.paths.monitorLog)
$audioLogPath = [System.Environment]::ExpandEnvironmentVariables($config.paths.audioLog)

# Monitor Toggle using NirCmd
if (!(Test-Path $logPath)) { Set-Content $logPath $config.monitors.primary }
$lastMonitor = Get-Content $logPath
$nextMonitor = if ($lastMonitor -eq $config.monitors.primary.ToString()) { $config.monitors.secondary } else { $config.monitors.primary }
Set-Content $logPath $nextMonitor
Start-Process $config.tools.nircmd -ArgumentList "setprimarydisplay $nextMonitor"
if ($config.notifications.enabled) {
    Write-Host ($config.notifications.monitorMessage -f $nextMonitor)
}

# Move windows to primary monitor using MultiMonitorTool
if ($nextMonitor -eq $config.monitors.secondary) {
    Start-Process $config.tools.multiMonitorTool -ArgumentList "/MoveWindow $($config.monitors.secondary) All $($config.monitors.primary)" -Wait
} else {
    Start-Process $config.tools.multiMonitorTool -ArgumentList "/MoveWindow $($config.monitors.primary) All $($config.monitors.secondary)" -Wait
}

# Audio Toggle using NirCmd
if (!(Test-Path $audioLogPath)) { Set-Content $audioLogPath "device1" }
$lastAudioDevice = Get-Content $audioLogPath

if ($lastAudioDevice -eq "device1") {
    Start-Process $config.tools.nircmd -ArgumentList "setdefaultsounddevice `"$($config.audio.device1)`" 1"
    Set-Content $audioLogPath "device2"
    if ($config.notifications.enabled) {
        Write-Host ($config.notifications.audioMessage -f $config.audio.device1)
    }
} else {
    Start-Process $config.tools.nircmd -ArgumentList "setdefaultsounddevice `"$($config.audio.device2)`" 1"
    Set-Content $audioLogPath "device1"
    if ($config.notifications.enabled) {
        Write-Host ($config.notifications.audioMessage -f $config.audio.device2)
    }
}