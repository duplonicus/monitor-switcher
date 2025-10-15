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

# Maximize all windows to ensure there are no minimize windows or they won't move due to how Windows handles the restore/normal state
Start-Process "nircmd.exe" -ArgumentList "win max alltopnodesktop" -Wait

# Monitor Toggle using NirCmd
if (!(Test-Path $logPath)) { Set-Content $logPath $config.monitors.primary }
$lastMonitor = Get-Content $logPath
$nextMonitor = if ($lastMonitor -eq $config.monitors.primary.ToString()) { $config.monitors.secondary } else { $config.monitors.primary }
Set-Content $logPath $nextMonitor
Start-Process "MultiMonitorTool.exe" -ArgumentList "/SetPrimary $nextMonitor" -Wait
if ($config.notifications.enabled) {
    Write-Host ($config.notifications.monitorMessage -f $nextMonitor)
}

# Move windows to primary monitor using MultiMonitorTool
Start-Process "MultiMonitorTool.exe" -ArgumentList "/MoveWindow Primary All" -Wait

# Maximize all windows again to ensure they fill the screen in case of different resolutions or scaling
Start-Process "nircmd.exe" -ArgumentList "win max alltopnodesktop" -Wait

# Per user window customizations
# Allows you to position specific windows at custom locations/sizes
# When switching to the TV, move all windows
# When switch to the desk, move some windows to other monitors
if ($config.windowCustomizations.enabled -and $nextMonitor -eq $config.monitors.primary) {
    foreach ($customization in $config.windowCustomizations.rules) {
        # Move specified apps to specified monitors
        MultiMonitorTool.exe /MoveWindow $customization.monitor $customization.findMethod $customization.findValue -Wait
        # Script block to run additional customization command defined in config, e.g. resizing windows
        if ($customization.command) {
            $sb = [ScriptBlock]::Create($customization.command)
            & $sb
            }
    }
}

# Close and restart explorer to redraw taskbar correctly on the previous monitor(s)
if ($config.redrawTaskbar.enabled) {
    Stop-Process -Name 'explorer' -Force
}

# Toggle between two audio devices
if ($lastAudioDevice -eq "device1") {
    Start-Process "nircmd.exe" -ArgumentList "setdefaultsounddevice `"$($config.audio.device1)`" 1"
    Set-Content $audioLogPath "device2"
    if ($config.notifications.enabled) {
        Write-Host ($config.notifications.audioMessage -f $config.audio.device1)
    }
} else {
    Start-Process "nircmd.exe" -ArgumentList "setdefaultsounddevice `"$($config.audio.device2)`" 1"
    Set-Content $audioLogPath "device1"
    if ($config.notifications.enabled) {
        Write-Host ($config.notifications.audioMessage -f $config.audio.device2)
    }
}