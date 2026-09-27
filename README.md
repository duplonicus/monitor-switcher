# Monitor Switcher

One hotkey moves your whole Windows session between a desk setup and a TV: the primary display,
every open window, and the default audio device. Press it again to come back.

Built from PowerShell, [AutoHotkey v2](https://www.autohotkey.com/) for the hotkey, and two NirSoft
freeware tools that are included in the repo: [MultiMonitorTool](https://www.nirsoft.net/utils/multi_monitor_tool.html)
(the primary-monitor switch) and [NirCmd](https://www.nirsoft.net/utils/nircmd.html) (the tray balloon).

## What a press does

1. Reads which monitor is primary **right now** and picks the other setup. There is no state file.
2. Sets the new primary and polls until Windows confirms it. If it never does, nothing else happens.
3. Moves every window to the new primary, or where your rules say, keeping each window's
   minimized / maximized / normal state. Every move is verified and retried once.
4. Nudges the taskbar (Windows 11 sometimes leaves the old primary's taskbar blank).
5. Switches the default audio device to the one that belongs to the destination monitor.
6. Shows a tray balloon with the result and writes `logs\switch-YYYY-MM-DD.log`.

## Setup

1. Clone or download the repo.
2. Copy `config.example.json` to `config.json` (git-ignored, so it stays yours).
3. Find your monitor IDs and put them in `config.json`:
   ```powershell
   .\switch.ps1 -DryRun        # lists every monitor it can see, then the plan; changes nothing
   .\switch.ps1 -ListAudio     # every active playback device and which monitor it belongs to
   ```
   Use the **Short Monitor ID** column (e.g. `AOC2401`), the serial number, or the `\\.\DISPLAYn`
   name. Never a bare number: to MultiMonitorTool `2` means `\\.\DISPLAY2`, and Windows renumbers
   those on driver installs and hot-plugs.
4. Register the elevated scheduled task once, from an **admin** shell in this folder. It is what
   lets admin windows (an elevated Terminal, Task Manager) move too. Edit the two paths in
   `MonitorSwitcher-Task.xml` first if the repo is not at `C:\Users\<you>\dev\monitor_switcher`:
   ```powershell
   schtasks /Create /XML "MonitorSwitcher-Task.xml" /TN "MonitorSwitcher" /F
   ```
5. Run `switch.ahk` (double-click). For startup, put a shortcut to it in `shell:startup`.

## Hotkeys

| Key | Does |
|---|---|
| **Ctrl+Alt+S** (or **V**) | Switch, elevated, via the scheduled task. Falls back to a direct non-elevated run with a tooltip if the task is not registered. |
| **Ctrl+Alt+M** | Switch directly, non-elevated. Admin windows will not move. |
| **Ctrl+Alt+D** | Dry run: writes the plan to the log, changes nothing. |
| **Ctrl+Alt+X** | Monitors off, PC stays on. Move the mouse to wake. |

Edit `switch.ahk` to change them. After editing, right-click the AutoHotkey tray icon → Reload Script.

## Command line

```powershell
.\switch.ps1              # toggle: desk -> couch or couch -> desk, from the live primary
.\switch.ps1 -To desk     # force a direction, or re-apply the desk layout without switching
.\switch.ps1 -DryRun      # plan only
.\switch.ps1 -ListAudio   # active playback endpoints, each with the monitor it belongs to
```

## `config.json`

```json
{
  "modes": {
    "desk":  { "monitor": "AOC2401", "audio": { "monitor": "RTK3B3D" }, "defaultPlace": "keep" },
    "couch": { "monitor": "MST0030", "audio": { "monitor": "MST0030" }, "defaultPlace": "max"  }
  },
  "audioRoles": [0, 1, 2],
  "fallbackMode": "desk",
  "rules": [
    { "when": "desk", "match": { "process": "Discord.exe" }, "monitor": "RTK3B3D", "place": "max" },
    { "when": "desk", "match": { "title": "WhatsApp" },      "monitor": "GSM76F9", "place": "right" },
    { "when": "desk", "match": { "class": "CabinetWClass" }, "place": "normal" }
  ],
  "timing": { "primaryTimeoutMs": 8000, "settleMs": 750, "verifyDelayMs": 300 },
  "taskbarNudge": true,
  "notify": true
}
```

- **`modes.desk` / `modes.couch`**: `monitor` is the primary for that setup. `audio` is
  `{ "monitor": ID }` for audio that comes out of a monitor: HDMI/DP audio, or headphones plugged into
  a monitor's jack. For a non-monitor device use `{ "id": ... }` or `{ "topology": ... }` from
  `-ListAudio`; `{ "name": ... }` also works but Windows resets device names on driver installs.
  `defaultPlace` applies to windows no rule matches: `keep` (preserve min/max/normal), `normal`,
  `max`, `min`, `left`, `right`.
- **`audioRoles`**: which defaults to set. `[0, 1, 2]` = console, multimedia, communications, which
  is what the Settings app sets. Drop `2` to keep calls on one device.
- **`fallbackMode`**: used when the current primary is neither desk nor couch.
- **`rules`**: first match wins. `when` is `desk`, `couch`, or omitted for both. `match` takes any of
  `process` (exe name), `class`, `title` (substring); all given keys must match. `monitor` defaults to
  the new primary. `place` as above; `left`/`right` are halves of that monitor's work area, so they
  survive resolution and scaling changes.
- **`timing`**: `primaryTimeoutMs` (how long to wait for Windows to confirm the primary), `settleMs`
  (pause after confirmation before windows move), `verifyDelayMs`.

## When something does not move

Read the log. Each failed window is listed with a reason:

- `access denied: elevated window` — the run was not elevated. Register the task and use Ctrl+Alt+S.
- `did not land on the destination` — the app repositions itself (some games, some UWP apps). Add a rule
  or live with it.
- `primary did not change ... within N ms` — nothing else was touched. MultiMonitorTool's readme notes
  that on Windows 11 24H2 the cure is to change something in Display settings once, then retry.
- `audio: nothing matches` — run `-ListAudio` and fix the `audio` entry.
- `another switch is still running` — you pressed twice; the second press is ignored.

## Why it identifies things the way it does

The first version of this tool used monitor numbers, device names and a state file, and it
"sometimes" broke. Each of those was the reason:

- **Monitor numbers are not stable.** MultiMonitorTool reads `2` as `\\.\DISPLAY2`. GPU driver installs,
  virtual-display drivers (Oculus, streaming tools) and hot-plugs all push those numbers up; a machine
  that started at DISPLAY1–4 was at DISPLAY13–16 a year later, and every numbered command was a silent
  no-op. EDID short IDs (`AOC2401`) come from the monitor itself and do not change.
- **Audio device names are not stable either.** Windows recreates display-audio endpoints with stock
  names on driver installs and leaves your renamed ones as "not present". A display-audio endpoint
  shares a PnP container ID with its monitor, so "the audio of monitor X" is stable when the name is not.
- **A state file drifts.** If any step fails, the file and reality disagree and the next press does the
  wrong thing. Reading the live primary cannot drift.
- **Fire-and-forget does not work here.** A primary change takes Windows a moment; moving windows before
  it settles puts them in the wrong place. And `nircmd.exe` / `MultiMonitorTool.exe` are GUI-subsystem
  programs, so a shell does not wait for them unless told to; chained commands raced each other.
- **Maximizing everything to make minimized windows movable** destroys the layout. `SetWindowPlacement`
  moves a minimized window's restore position without un-minimizing it.
- **Elevated windows** can only be moved by an elevated process (UIPI). Hence the scheduled task, which
  runs elevated without a UAC prompt.

## License

MIT. MultiMonitorTool and NirCmd are freeware by Nir Sofer, redistributed as permitted.
