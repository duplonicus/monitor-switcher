# Monitor Switcher

A PowerShell script that toggles between primary monitors and audio devices, perfect for switching between a desk setup and TV setup from the couch.

## Features

- **Monitor Toggle**: Toggles primary display between chosen monitors
- **Window Management**: Automatically moves all windows to the new primary monitor
- **Audio Toggle**: Switches default audio device between chosen audio devices
- **State Persistence**: Remembers the last selected monitor and audio device
- **Simple Logging**: Uses text files to track current state
- **Window Customizations**: Toggleable per-user window customizations for robust window management (must write you own nircmd.exe [commands](https://nircmd.nirsoft.net/win.html))

## Prerequisites

- **PowerShell**: Windows PowerShell (included with Windows)
- **AutoHotkey v2** (Optional): Download and install [AutoHotkey v2](https://www.autohotkey.com/) for keyboard shortcuts
- **Audio Devices**: Ensure your audio device names match in `config.json` and in Windows audio settings

**Note**: [NirCmd](https://www.nirsoft.net/utils/nircmd.html) and [MultiMonitorTool](https://www.nirsoft.net/utils/multi_monitor_tool.html) are included in this repository - no additional downloads required! These tools are freeware and can be freely redistributed.

## Installation

1. **Download or clone this repository**
2. **Configure your audio devices**:
   - Open Windows Sound settings
   - Rename your devices to "TV" and "Speakers" (or update `config.json` to match your device names)
3. **Test the setup**:
   ```powershell
   .\switch.ps1
   ```
4. **Setup Scheduled Task (Optional)**:
   - Run the following command from the project directory as Administrator:
   ```powershell
   schtasks /Create /XML "MonitorSwitcher-Task.xml" /TN "MonitorSwitcher"
   ```
   - This enables moving admin windows. See "Admin Window Movement Fix" section below for details.
5. **Install AutoHotkey v2 (Optional)**:
   - Download and install [AutoHotkey v2](https://www.autohotkey.com/)
   - This enables keyboard shortcuts (Ctrl+Alt+M or Ctrl+Alt+S) to switch monitors
   - See "AutoHotkey v2 Setup and Usage" section below for full details

That's it! All required tools (except AutoHotkey) are included in the repository.

## Usage

### Method 1: Keyboard Shortcut (Recommended)
1. Install AutoHotkey v2 if you haven't already
2. Run `switch.ahk` by double-clicking it or running it from command line
3. Press **Ctrl+Alt+M** or **Ctrl+Alt+S** to toggle monitors and audio
4. The script will show a brief tooltip notification when switching
5. Add a shortcut to `switch.ahk` in `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp` if you want it to run on startup

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
       & "\path\to\switch.ps1"
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

## How It Works

### Monitor Switching
- Toggles between chosen displays in `config.json`
- Uses MultiMonitorTool's `/SetPrimary` command
- Automatically moves all windows to the new primary monitor using MultiMonitorTool's `/MoveWindow Primary All` command
- State is stored in `./SwapMonitorsLog.txt` by default

### Audio Switching
- Toggles between "TV" and "Headphones" audio devices
- Uses NirCmd's `setdefaultsounddevice` command
- State is stored in `./SwapAudioLog.txt` by default

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
    "monitorLog": "/path/to/log/folder/SwapMonitorsLog.txt",
    "audioLog": "/path/to/log/folder/SwapAudioLog.txt"
  },
  "notifications": {
    "enabled": true,
    "monitorMessage": "Switched to Monitor {0}",
    "audioMessage": "Switched to {0}"
  }
}
```

**Note**: If your monitors don't seem to match Windows display settings, use `get_monitor_numbers.ps1` to get their actual numbers or use trial and error.

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

#### Window Customizations
- **`enabled`**: Enable/disable per-user window customizations (default: true)
   - Set this to `false` until you define your own customizations
- **`rules`**: Array of customization rules that run when switching to the primary monitor

### Per-User Window Customizations

The window customizations feature allows you to automatically position specific windows at custom locations, sizes, or monitors when switching to your primary monitor (desk setup). This is perfect for multi-monitor setups where you want certain apps to always go to specific monitors.

#### How It Works

When you switch **to your primary monitor** (typically your desk setup), the customization rules run after all windows are moved to the primary display. Each rule can:
1. Move a specific window to a different monitor
2. Run custom NirCmd commands to resize, maximize, or reposition the window
3. Or run any other arbirtrary PowerShell commands

When you switch **to your secondary monitor** (typically your TV), all windows simply move to that monitor and are maximized with no customizations applied.

#### Configuration Structure

Each rule in the `windowCustomizations.rules` array requires:

- **`findMethod`**: How to find the window
  - `"Process"` - Find by process name (e.g., "Discord.exe")
  - `"Title"` - Find by window title (e.g., "WhatsApp")
- **`findValue`**: The process name or window title to match
- **`monitor`**: Target monitor number to move the window to
- **`command`** (optional): Additional PowerShell command to run for advanced customization

#### Example Configuration

```json
{
  "windowCustomizations": {
    "enabled": true,
    "rules": [
      {
        "findMethod": "Process",
        "findValue": "Discord.exe",
        "monitor": 3,
        "command": "if ($customization.findValue -eq 'Discord.exe') { & nircmd.exe win max process 'Discord.exe'; & Write-Host 'Discord maximized' }"
      },
      {
        "findMethod": "Title",
        "findValue": "WhatsApp",
        "monitor": 4,
        "_comment": "if WhatsApp, make normal, activate, and resize to right half of screen",
        "command": "if ($customization.findValue -eq 'WhatsApp') { & nircmd.exe win normal ititle 'WhatsApp'; & nircmd.exe win activate ititle 'WhatsApp'; & nircmd.exe win setsize ititle 'WhatsApp' -1287 0 1294 1039; & Write-Host 'WhatsApp snapped to right' }"
      }
    ]
  }
}
```

#### Common Use Cases

**Move Discord to a specific monitor:**
```json
{
  "findMethod": "Process",
  "findValue": "Discord.exe",
  "monitor": 3
}
```

**Move and maximize Spotify:**
```json
{
  "findMethod": "Process",
  "findValue": "Spotify.exe",
  "monitor": 4,
  "command": "if ($customization.findValue -eq 'Spotify.exe') { & nircmd.exe win max process 'Spotify.exe' }"
}
```

**Snap a window to the right half of the screen:**
```json
{
  "findMethod": "Title",
  "findValue": "WhatsApp",
  "monitor": 4,
  "command": "if ($customization.findValue -eq 'WhatsApp') { & nircmd.exe win normal ititle 'WhatsApp'; & nircmd.exe win setsize ititle 'WhatsApp' -1287 0 1294 1039 }"
}
```

#### NirCmd Commands Reference

The `command` field supports any NirCmd window commands. **Important**: Always wrap commands in an `if` statement that checks `$customization.findValue` to ensure the command only applies to the intended window.

Common command patterns:

- **Maximize**:
  ```powershell
  if ($customization.findValue -eq 'Discord.exe') { & nircmd.exe win max process 'Discord.exe' }
  ```
- **Minimize**:
  ```powershell
  if ($customization.findValue -eq 'Spotify.exe') { & nircmd.exe win min process 'Spotify.exe' }
  ```
- **Normal/Restore**:
  ```powershell
  if ($customization.findValue -eq 'WhatsApp') { & nircmd.exe win normal ititle 'WhatsApp' }
  ```
- **Activate/Focus**:
  ```powershell
  if ($customization.findValue -eq 'WhatsApp') { & nircmd.exe win activate ititle 'WhatsApp' }
  ```
- **Resize**:
  ```powershell
  if ($customization.findValue -eq 'WhatsApp') { & nircmd.exe win setsize ititle 'WhatsApp' x y width height }
  ```
- **Multiple commands** (chain with semicolons):
  ```powershell
  if ($customization.findValue -eq 'WhatsApp') { & nircmd.exe win normal ititle 'WhatsApp'; & nircmd.exe win activate ititle 'WhatsApp'; & nircmd.exe win setsize ititle 'WhatsApp' -1287 0 1294 1039 }
  ```

For more NirCmd commands, see the [NirCmd documentation](https://nircmd.nirsoft.net/win.html).

#### Tips

- **Use `_comment` fields**: Add comments to your rules for documentation (they're ignored by the script)
- **Test your commands**: Run NirCmd commands manually first to get the right coordinates
- **Find process names**: Use Task Manager to find the exact process name
- **Find window titles**: Check in MultiMonitorTool GUI
- **Disable temporarily**: Set `"enabled": false` to disable all customizations without deleting rules
- **Order matters**: Rules run in the order they appear in the array

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

## Admin Window Movement Fix

If you notice that some windows (especially admin windows like Terminal, Task Manager, TreeSize) don't move when switching monitors, this is due to Windows security restrictions (UIPI). The solution is to run the script with elevated privileges using Task Scheduler.

### One-Time Setup (Requires Admin)

1. Open PowerShell as Administrator
2. Navigate to the monitor_switcher directory
3. Import the scheduled task:
   ```powershell
   schtasks /Create /XML "MonitorSwitcher-Task.xml" /TN "MonitorSwitcher"
   ```

### Usage After Setup

Once configured, you can run the elevated version without UAC prompts:

**From AutoHotkey**: The `Ctrl+Alt+S` hotkey in `switch.ahk` already uses the elevated method by calling `admin_scheduled_task_switch.ps1` which in turn calls the scheduled task

**From command line**:
```powershell
.\admin_scheduled_task_switch.ps1
```

### Uninstall Task Scheduler Method
```powershell
schtasks /Delete /TN "MonitorSwitcher" /F
```

### Comparison of Methods

- **Ctrl+Alt+M**: Uses original `switch.ps1` (may not move admin windows)
- **Ctrl+Alt+S**: Uses `admin_scheduled_task_switch.ps1` via Task Scheduler (moves all windows including admin)

## Troubleshooting

### General Issues
- **"nircmd.exe not found"**: Ensure `nircmd.exe` is in the same folder as `switch.ps1`
- **"MultiMonitorTool.exe not found"**: Ensure `MultiMonitorTool.exe` is in the same folder as `switch.ps1`
- **Audio device not switching**: Check that your audio devices are named exactly as configured in `config.json`
- **Monitor not switching**: Verify the display numbers in `config.json` match your setup
- **Admin windows not moving**: Follow the "Admin Window Movement Fix" section above to set up Task Scheduler

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

The script creates two log files in the project root directory:
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
- **Ctrl+Alt+S**: Toggle monitors and audio (scheduled task)
   - Feel free to edit these to your liking in `switch.ahk`

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

### Managing the AutoHotKey Script

#### System Tray
- **Icon**: Look for the AutoHotkey icon in the system tray
- **Right-click**: Access context menu with options to pause, reload, or exit
- **Exit**: Right-click tray icon → Exit to stop the script

#### Script Management
- **Reload**: Right-click tray icon → Reload Script (useful after editing)
- **Pause**: Right-click tray icon → Pause Script (temporarily disable hotkeys)
- **Edit**: Right-click tray icon → Edit Script (opens in default editor)

### Known Issues
- Taskbar dissapears on previous monitor:
   - Not an issue with nircmd.exe
   - Current workaround is to end explorer process (toggleable in `config.json`)
   - If there is a better way to redraw the taskbar while preserving opened explorer windows, please open an issue to let me know how

## License

This project is open source and available under the MIT License.