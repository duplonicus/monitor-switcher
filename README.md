# Monitor Switcher

A PowerShell script that toggles between primary monitors and audio devices, perfect for switching between a desk setup and TV setup from the couch.

## Features

- **Monitor Toggle**: Switches primary display between monitor 1 and monitor 4
- **Audio Toggle**: Switches default audio device between "TV" and "Headphones"
- **State Persistence**: Remembers the last selected monitor and audio device
- **Simple Logging**: Uses text files to track current state

## Prerequisites

- **NirCmd**: Download and install [NirCmd](https://www.nirsoft.net/utils/nircmd.html) from NirSoft
- **PowerShell**: Windows PowerShell (included with Windows)
- **Audio Devices**: Ensure your audio devices are named "TV" and "Headphones" in Windows audio settings

## Installation

1. Download or clone this repository
2. Install NirCmd and ensure `nircmd.exe` is in your system PATH or in the same directory as the script
3. Configure your audio devices:
   - Open Windows Sound settings
   - Rename your devices to "TV" and "Headphones" (or modify the script to match your device names)

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
- State is stored in `%USERPROFILE%\SwapMonitorsLog.txt`

### Audio Switching
- Toggles between "TV" and "Headphones" audio devices
- Uses NirCmd's `setdefaultsounddevice` command
- State is stored in `%USERPROFILE%\SwapAudioLog.txt`

## Configuration

To customize the script for your setup:

1. **Change Monitor Numbers**: Modify lines 8-9 to use different display numbers
2. **Change Audio Device Names**: Update lines 18 and 22 to match your audio device names
3. **Change Log File Locations**: Modify the `$logPath` and `$audioLogPath` variables

## Troubleshooting

- **"nircmd.exe not found"**: Ensure NirCmd is installed and in your PATH
- **Audio device not switching**: Check that your audio devices are named exactly "TV" and "Headphones"
- **Monitor not switching**: Verify the display numbers (1 and 4) match your setup

## Files Created

The script creates two log files in your user profile directory:
- `SwapMonitorsLog.txt` - Tracks current monitor state
- `SwapAudioLog.txt` - Tracks current audio device state

## License

This project is open source and available under the MIT License.
