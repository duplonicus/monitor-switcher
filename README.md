# Monitor Switcher

A PowerShell script that toggles between primary monitors and audio devices, perfect for switching between a desk setup and TV setup from the couch.

## Features

- **Monitor Toggle**: Switches primary display between monitor 1 and monitor 4
- **Window Management**: Automatically moves all windows to the new primary monitor
- **Audio Toggle**: Switches default audio device between "TV" and "Headphones"
- **State Persistence**: Remembers the last selected monitor and audio device
- **Simple Logging**: Uses text files to track current state

## Prerequisites

- **NirCmd**: Download and install [NirCmd](https://www.nirsoft.net/utils/nircmd.html) from NirSoft
- **MultiMonitorTool**: Download and install [MultiMonitorTool](https://www.nirsoft.net/utils/multi_monitor_tool.html) from NirSoft
- **PowerShell**: Windows PowerShell (included with Windows)
- **Audio Devices**: Ensure your audio devices are named "TV" and "Headphones" in Windows audio settings

## Installation

1. Download or clone this repository
2. Install NirCmd and ensure `nircmd.exe` is in your system PATH or in the same directory as the script
3. Install MultiMonitorTool and ensure `MultiMonitorTool.exe` is in your system PATH or in the same directory as the script
4. Configure your audio devices:
   - Open Windows Sound settings
   - Rename your devices to "TV" and "Headphones" (or modify the script to match your device names)

## MultiMonitorTool Setup

MultiMonitorTool is used to automatically move all windows to the new primary monitor when switching. Here's how to set it up:

### Download and Installation
1. Download MultiMonitorTool from [NirSoft](https://www.nirsoft.net/utils/multi_monitor_tool.html)
2. Extract the executable to a folder in your system PATH, or place it in the same directory as the script
3. No installation required - it's a portable executable

### How MultiMonitorTool Works in This Script
- When switching to monitor 4: Moves all windows from monitor 1 to monitor 4
- When switching to monitor 1: Moves all windows from monitor 4 to monitor 1
- Uses the `/MoveWindow` command with "All" parameter to move all open windows
- The `-Wait` parameter ensures the script waits for the window movement to complete

### Manual MultiMonitorTool Usage
You can also use MultiMonitorTool manually for advanced window management:
```cmd
MultiMonitorTool.exe /MoveWindow [SourceMonitor] [WindowTitle] [TargetMonitor]
MultiMonitorTool.exe /MoveWindow 1 "Notepad" 2
MultiMonitorTool.exe /MoveWindow 1 All 2
```

## Usage

Run the script from PowerShell:

```powershell
.\switch.ps1
```

Or double-click the script file in Windows Explorer.

## How It Works

### Monitor Switching
- Toggles between display 1 and display 4
- Uses NirCmd's `setprimarydisplay` command
- Automatically moves all windows to the new primary monitor using MultiMonitorTool
- State is stored in `%USERPROFILE%\SwapMonitorsLog.txt`

### Audio Switching
- Toggles between "TV" and "Headphones" audio devices
- Uses NirCmd's `setdefaultsounddevice` command
- State is stored in `%USERPROFILE%\SwapAudioLog.txt`

### MultiMonitorTool Integration
- Automatically moves all open windows to the new primary monitor
- Uses MultiMonitorTool's `/MoveWindow` command with "All" parameter
- Ensures seamless transition when switching between desk and TV setups

## Configuration

To customize the script for your setup:

1. **Change Monitor Numbers**: Modify lines 8-9 to use different display numbers
2. **Change Audio Device Names**: Update lines 18 and 22 to match your audio device names
3. **Change Log File Locations**: Modify the `$logPath` and `$audioLogPath` variables
4. **Customize MultiMonitorTool Commands**: Modify lines 15 and 17 to change window movement behavior

## Troubleshooting

- **"nircmd.exe not found"**: Ensure NirCmd is installed and in your PATH
- **"MultiMonitorTool.exe not found"**: Ensure MultiMonitorTool is installed and in your PATH
- **Audio device not switching**: Check that your audio devices are named exactly "TV" and "Headphones"
- **Monitor not switching**: Verify the display numbers (1 and 4) match your setup
- **Windows not moving**: Check that MultiMonitorTool is properly installed and accessible

## Files Created

The script creates two log files in your user profile directory:
- `SwapMonitorsLog.txt` - Tracks current monitor state
- `SwapAudioLog.txt` - Tracks current audio device state

## License

This project is open source and available under the MIT License.
