# Monitor Switcher

A PowerShell script that toggles between primary monitors and audio devices, perfect for switching between a desk setup and TV setup from the couch.

## Features

- **Monitor Toggle**: Switches primary display between monitor 1 and monitor 4
- **Window Management**: Automatically moves all windows to the new primary monitor
- **Audio Toggle**: Switches default audio device between "TV" and "Headphones"
- **State Persistence**: Remembers the last selected monitor and audio device
- **Simple Logging**: Uses text files to track current state

## Prerequisites

- **PowerShell**: Windows PowerShell (included with Windows)
- **AutoHotkey v2** (Optional): Download and install [AutoHotkey v2](https://www.autohotkey.com/) for keyboard shortcuts
- **Audio Devices**: Ensure your audio devices are named "TV" and "Headphones" in Windows audio settings

**Note**: NirCmd and MultiMonitorTool are included in this repository - no additional downloads required! These tools are freeware and can be freely redistributed.

## Installation

1. **Download or clone this repository**
2. **Configure your audio devices**:
   - Open Windows Sound settings
   - Rename your devices to "TV" and "Headphones" (or update `config.json` to match your device names)
3. **Test the setup**:
   ```powershell
   .\switch.ps1
   ```

That's it! All required tools are included in the repository.

## How MultiMonitorTool Works

MultiMonitorTool is included in this repository and automatically moves all windows to the new primary monitor when switching:

- **When switching to monitor 4**: Moves all windows from monitor 1 to monitor 4
- **When switching to monitor 1**: Moves all windows from monitor 4 to monitor 1
- **Uses the `/MoveWindow` command** with "All" parameter to move all open windows
- **The `-Wait` parameter** ensures the script waits for the window movement to complete

### Manual MultiMonitorTool Usage
You can also use MultiMonitorTool manually for advanced window management:
```cmd
MultiMonitorTool.exe /MoveWindow [SourceMonitor] [WindowTitle] [TargetMonitor]
MultiMonitorTool.exe /MoveWindow 1 "Notepad" 2
MultiMonitorTool.exe /MoveWindow 1 All 2
```

## Usage

### Method 1: Keyboard Shortcut (Recommended)
1. Install AutoHotkey v2 if you haven't already
2. Run `switch.ahk` by double-clicking it or running it from command line
3. Press **Ctrl+Alt+M** or **Ctrl+Alt+S** to toggle monitors and audio
4. The script will show a brief tooltip notification when switching

### Method 2: PowerShell
Run the script from PowerShell:

```powershell
.\switch.ps1
```

### Method 3: Double-click
Double-click the `switch.ps1` script file in Windows Explorer.

### Method 4: PowerShell Function (Convenient)
Add a function to your PowerShell profile for easy command-line access:

1. **Open your PowerShell profile**:
   ```powershell
   notepad $PROFILE
   ```

2. **Add this function**:
   ```powershell
   function switchmon {
       & "$PSScriptRoot\switch.ps1"
   }
   ```

3. **Save and reload**:
   ```powershell
   . $PROFILE
   ```

4. **Use the command**:
   ```powershell
   switchmon
   ```

**Note**: Replace `$PSScriptRoot` with the full path to your monitor_switcher folder if the function doesn't work from other directories.

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

The script uses a `config.json` file for easy customization. No need to edit the PowerShell script directly!

### Configuration File (`config.json`)

```json
{
  "monitors": {
    "primary": 1,
    "secondary": 4
  },
  "audio": {
    "device1": "TV",
    "device2": "Headphones"
  },
  "paths": {
    "monitorLog": "%USERPROFILE%\\SwapMonitorsLog.txt",
    "audioLog": "%USERPROFILE%\\SwapAudioLog.txt"
  },
  "notifications": {
    "enabled": true,
    "monitorMessage": "Switched to Monitor {0}",
    "audioMessage": "Switched to {0}"
  }
}
```

### Customization Options

#### Monitor Settings
- **`primary`**: First monitor number (default: 1)
- **`secondary`**: Second monitor number (default: 4)

#### Audio Settings
- **`device1`**: First audio device name (default: "TV")
- **`device2`**: Second audio device name (default: "Headphones")

#### Log File Locations
- **`monitorLog`**: Path for monitor state log (supports environment variables)
- **`audioLog`**: Path for audio state log (supports environment variables)


#### Notifications
- **`enabled`**: Enable/disable console notifications (default: true)
- **`monitorMessage`**: Message format for monitor switches (use {0} for monitor number)
- **`audioMessage`**: Message format for audio switches (use {0} for device name)

### Quick Setup Examples

#### Different Monitor Numbers
```json
{
  "monitors": {
    "primary": 2,
    "secondary": 3
  }
}
```

#### Different Audio Devices
```json
{
  "audio": {
    "device1": "Speakers",
    "device2": "Headset"
  }
}
```

#### Custom Log Locations
```json
{
  "paths": {
    "monitorLog": "C:\\Logs\\monitor_state.txt",
    "audioLog": "C:\\Logs\\audio_state.txt"
  }
}
```

#### Disable Notifications
```json
{
  "notifications": {
    "enabled": false
  }
}
```

## Troubleshooting

### General Issues
- **"nircmd.exe not found"**: Ensure `nircmd.exe` is in the same folder as `switch.ps1`
- **"MultiMonitorTool.exe not found"**: Ensure `MultiMonitorTool.exe` is in the same folder as `switch.ps1`
- **Audio device not switching**: Check that your audio devices are named exactly as configured in `config.json`
- **Monitor not switching**: Verify the display numbers in `config.json` match your setup
- **Windows not moving**: Check that MultiMonitorTool is properly installed and accessible

### Configuration Issues
- **"Configuration file not found"**: Ensure `config.json` is in the same directory as `switch.ps1`
- **"Failed to parse configuration file"**: Check that `config.json` is valid JSON syntax
- **"Invalid JSON"**: Use a JSON validator to check your configuration file
- **Settings not applying**: Restart the script after changing `config.json`

### Audio Device Troubleshooting
- **Device names must match exactly**: Check Windows Sound settings for exact device names
- **Case sensitive**: Device names are case-sensitive in the configuration
- **Special characters**: Escape quotes and special characters in device names
- **Test audio switching**: Use NirCmd directly to test: `nircmd setdefaultsounddevice "YourDeviceName" 1`

## Files Created

The script creates two log files in your user profile directory:
- `SwapMonitorsLog.txt` - Tracks current monitor state
- `SwapAudioLog.txt` - Tracks current audio device state

## AutoHotkey v2 Setup and Usage

The included `switch.ahk` script provides convenient keyboard shortcuts for monitor switching.

### Prerequisites
- **AutoHotkey v2**: Download from [autohotkey.com](https://www.autohotkey.com/)
- **Installation**: Run the installer and ensure AutoHotkey v2 is properly installed
- **Verification**: Right-click any `.ahk` file and verify "Run Script" appears in the context menu

### Hotkeys
- **Ctrl+Alt+M**: Toggle monitors and audio (primary shortcut)
- **Ctrl+Alt+S**: Toggle monitors and audio (alternative shortcut)

### Features
- **Background Execution**: Runs the PowerShell script without visible windows
- **Visual Feedback**: Shows tooltip notifications when switching
- **Single Instance**: Prevents multiple copies from running simultaneously
- **Startup Confirmation**: Displays notification when script loads
- **Modern Syntax**: Uses AutoHotkey v2 for better performance and compatibility

### Running the AutoHotkey Script

#### Method 1: Double-Click (Temporary)
1. Navigate to the script folder
2. Double-click `switch.ahk`
3. Look for the tooltip notification confirming the script loaded
4. The script will run until you close it or restart Windows

#### Method 2: Command Line
```cmd
# Navigate to script directory
cd "C:\path\to\monitor_switcher"

# Run the script
switch.ahk
```

#### Method 3: Right-Click Context Menu
1. Right-click `switch.ahk`
2. Select "Run Script" from the context menu

### Running at Windows Startup

#### Method 1: Startup Folder (Recommended)
1. Press `Win + R`, type `shell:startup`, press Enter
2. Right-click in the folder → New → Shortcut
3. Browse to and select `switch.ahk`
4. Name it "Monitor Switcher" and click Finish
5. The script will now start automatically with Windows

#### Method 2: Task Scheduler (Advanced)
1. Press `Win + R`, type `taskschd.msc`, press Enter
2. Click "Create Basic Task" in the right panel
3. Name it "Monitor Switcher"
4. Set trigger to "When the computer starts"
5. Set action to "Start a program"
6. Browse to `switch.ahk` file
7. Check "Run with highest privileges" if needed
8. Click Finish

#### Method 3: Registry (Power Users)
1. Press `Win + R`, type `regedit`, press Enter
2. Navigate to: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run`
3. Right-click → New → String Value
4. Name it "MonitorSwitcher"
5. Set value to the full path of `switch.ahk` (e.g., `C:\path\to\switch.ahk`)

### Managing the Script

#### System Tray
- **Icon**: Look for the AutoHotkey icon in the system tray
- **Right-click**: Access context menu with options to pause, reload, or exit
- **Exit**: Right-click tray icon → Exit to stop the script

#### Script Management
- **Reload**: Right-click tray icon → Reload Script (useful after editing)
- **Pause**: Right-click tray icon → Pause Script (temporarily disable hotkeys)
- **Edit**: Right-click tray icon → Edit Script (opens in default editor)

### Troubleshooting AutoHotkey

#### Common Issues
- **"Script not running"**: Ensure AutoHotkey v2 is installed and `switch.ahk` is not corrupted
- **"Hotkeys not working"**: Check if another program is using the same hotkeys
- **"Script won't start"**: Verify file permissions and that the script path is correct
- **"PowerShell errors"**: Ensure the PowerShell script is in the same directory as `switch.ahk`

#### Debugging
- **Check tray icon**: Look for AutoHotkey icon in system tray
- **Test hotkeys**: Press Ctrl+Alt+M or Ctrl+Alt+S to test functionality
- **View errors**: Right-click tray icon → View Error Log (if available)
- **Manual test**: Run the PowerShell script directly to verify it works

#### Performance Tips
- **Startup delay**: If script loads slowly, add a small delay in Task Scheduler
- **Multiple instances**: The script prevents multiple copies, but check Task Manager if issues persist
- **Antivirus**: Some antivirus software may block AutoHotkey scripts; add exception if needed

## License

This project is open source and available under the MIT License.
