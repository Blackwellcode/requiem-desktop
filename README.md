# Requiem

A minimal gothic Windows 11 desktop theme in ember red and halo silver: a spaced weekday clock, a floating tinted dock, a matching Windows Terminal scheme and a PowerShell prompt. Every color is sampled from the included wallpaper.

## Components

| Part | Tool | Source |
| :--- | :--- | :--- |
| Weekday / date / time | [Rainmeter](https://www.rainmeter.net/) 4.5+ | `rainmeter/Requiem/Requiem.ini` |
| Floating dock and tray | [Windhawk](https://windhawk.net/) + mod *Windows 11 Taskbar Styler*, theme `DockLike` with Requiem overrides | `windhawk/taskbar-styler-requiem.yaml` |
| Windows Terminal | color scheme + tab theme "Seele Requiem", acrylic, faint wallpaper | `terminal/seele-requiem.json` |
| PowerShell prompt | Windows PowerShell 5.1, no extra modules | `powershell/requiem-prompt.ps1` |
| Tab / profile icon | halo + ember cross, generated | `icons/requiem.png`, `icons/make-icon.ps1` |
| Wallpaper | 1376×768 | `wallpaper/seele-desktop.jpg` |

## Palette

| Role | Hex |
| :--- | :--- |
| Void | `#000000` |
| Surface | `#100000` / `#200000` |
| Ember dark / mid / hot | `#801115` / `#8E1C21` / `#C03E45` |
| Halo silver | `#7F7E7C` / `#A0A09E` |
| Windows accent color | `#8E1C21` |

## Install

Requirements: Windows 11, Rainmeter, Windhawk.

```powershell
winget install --id Rainmeter.Rainmeter --exact
winget install --id RamenSoftware.Windhawk --exact
```

1. **Rainmeter skin + hidden desktop icons**
   ```powershell
   .\apply.ps1                 # deploy skin, set layout, hide desktop icons
   .\apply.ps1 -X 200 -Y 200   # move the clock (physical pixels)
   ```
   `apply.ps1` disables all other active Rainmeter skins and writes `Requiem.ini` as UTF-16 LE (required by Rainmeter for non-ASCII characters).
2. **Dock** – in Windhawk install *Windows 11 Taskbar Styler*, open *Settings > Text mode*, paste `windhawk/taskbar-styler-requiem.yaml`, save. Turn on Windows *Transparency effects* for the acrylic look.
3. **Terminal** – merge `terminal/seele-requiem.json` into Windows Terminal's `settings.json` (instructions inside the file).
4. **Prompt** – add to `$PROFILE`:
   ```powershell
   . '<path-to-repo>\powershell\requiem-prompt.ps1'
   ```
   Cross is ember when the session is elevated, silver otherwise; the arrow turns light red after a failed command.
5. **Accent color** – *Settings > Personalization > Colors > Custom colors*: `#8E1C21`.

## Revert

```powershell
.\toggle-desktop-icons.ps1 -Show   # show desktop icons again
```

- Dock: Windhawk > Windows 11 Taskbar Styler > Disable.
- Rainmeter: unload the *Requiem* skin or reactivate your previous skins.

## Notes

- Windhawk mods can break after Windows feature updates; disable or update the mod if the taskbar misbehaves.
- The wallpaper is 1376×768 and is upscaled on high-resolution and ultrawide monitors.

## License

Code and configuration: [MIT](LICENSE). The wallpaper (`wallpaper/`) and icon artwork are © Blackwellcode and not covered by the MIT license.
