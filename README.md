# Omarchy Spaces

A Mission Control-inspired workspace overview for Omarchy. See your desktops across the top, hover to peek inside one, then click a larger window preview to open it.

- Actual workspace layouts with app icons for quick recognition.
- Live window previews shared between the desktop strip and larger windows.
- Horizontal workspace transitions and remembered window selection/scroll position.
- Native Omarchy colors, fonts, animation preferences, and application icons.
- Automatic display scaling and notch clearance using Omarchy's platform data.
- Optional trackpad integration; keyboard and mouse work without it.

## Requirements

This is an **Omarchy shell plugin** using Quickshell, Hyprland, and Hyprland's per-window screencopy protocol. It runs inside the existing shell; there is no compiler, background server, or architecture-specific compositor hook to install.

Tested on Omarchy **4.5.0**, Hyprland **0.56.2**, and Quickshell **0.3.2**, on an Apple Silicon MacBook Air running Linux. Those are tested versions, not a promise of compatibility with older releases. The code has no dependency on Apple hardware. Other hardware and multi-monitor configurations still need community testing. This does not run on macOS or as a standalone generic Wayland overview.

## Install

```bash
omarchy plugin add https://github.com/predmore/omarchy-spaces.git --enable
```

Open it without changing any bindings:

```bash
omarchy-shell shell toggle predmore.spaces
```

Optional convenience command:

```bash
install -Dm755 ~/.config/omarchy/plugins/predmore.spaces/bin/omarchy-spaces ~/.local/bin/omarchy-spaces
omarchy-spaces
```

For a keyboard shortcut, add a free key combination to your Hyprland Lua configuration using Omarchy's `o.bind` helper. Inspect your existing bindings first. For example, if this combination is free:

```lua
o.bind("SUPER + CTRL + SPACE", "Spaces overview", { panel = "predmore.spaces" })
```

After any Lua configuration edit, run `hyprctl reload` and `hyprctl configerrors`.

## Use

| Input | Action |
|---|---|
| Hover a desktop | Preview its windows, without switching your actual desktop |
| Click a desktop | Switch to it and close the overview |
| Click a window | Focus that window and close the overview |
| Two-finger scroll / wheel | Scroll windows within the previewed desktop |
| Left / Right | Select a window |
| Ctrl + Left / Right | Preview another desktop |
| Up / Down | Move keyboard navigation between desktops and windows |
| 1–9 / 0 | Preview desktop slots 1–9 / 10 |
| Enter | Open the selected window, or switch desktops when navigating the desktop strip |
| Esc | Close without committing a peek |

### Optional trackpad gestures

The plugin installer **does not edit your Hyprland files**. This integration uses Hyprland's Lua gesture API. Add the following once, after your existing gesture declarations, in your user Lua configuration:

```lua
local spaces = dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/predmore.spaces/gestures.lua")
spaces.setup({
  fingers = 3,
  open = "down", -- use "up" to reverse the opening/closing direction
  pinch = true, -- three- and four-finger pinch in/out; two-finger app zoom is untouched
  horizontal = true,
  restore = function()
    -- Use YOUR normal horizontal gesture here. This example is Hyprland's
    -- standard workspace swipe. Custom setups should provide their own action.
    hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
  end,
})
```

This opts into three-finger down/up to open/close, pinch in/out to open/close, and horizontal swiping that follows your fingers while the overview is open. It does not silently unset conflicting vertical or pinch bindings: remove or adjust conflicting declarations yourself. Setup without `horizontal = true` only adds opening/closing gestures and leaves horizontal swipes alone. `fingers` accepts 3, 4, or 5; keep the restore callback's finger count consistent.

There is no API for reading back an existing Hyprland gesture declaration. A restore callback is therefore required for horizontal takeover. The callback runs on close and after an expired four-second renewal lease if the shell stops responding. Configuration reloads use the normal gesture declarations in your config. The helper reattaches only if the overview is still open. Never load this setup twice.

The plugin can be disabled separately from the optional helper; remove the Lua setup before removing the plugin files. Use `$XDG_CONFIG_HOME` instead of `~/.config` in these paths if you keep configuration elsewhere.

## Settings

Create `~/.config/omarchy/spaces.json` (or `$XDG_CONFIG_HOME/omarchy/spaces.json`). Missing or malformed settings fall back to defaults. Changes reload automatically; workspace slot changes take full effect on the next open.

```json
{
  "workspaceCount": 10,
  "workspaceBase": null,
  "swipeDistance": 260,
  "captureLimit": 16,
  "previewInterval": 100,
  "backgroundInterval": 1100,
  "gesturesEnabled": true
}
```

| Setting | Meaning |
|---|---|
| `workspaceCount` | Number of desktop slots, 1–20. Default 10 matches Omarchy. |
| `workspaceBase` | `null` follows Omarchy's monitor/workspace state; a number overrides the base. Base 20 gives slots 21 onward. |
| `swipeDistance` | Gesture distance per workspace; 80–1200. |
| `captureLimit` | Maximum actively refreshed previews; 1–32. At most the same number of outgoing previews are temporarily retained during transitions. |
| `previewInterval` | Selected desktop refresh interval in milliseconds; 50–2000. |
| `backgroundInterval` | Other desktops' refresh interval in milliseconds; 250–10000. |
| `gesturesEnabled` | Allows the optional Lua bridge to route overview swipes. Disabling it does not uninstall Lua open/close bindings. |

The defaults prioritize visible windows and keep capture work bounded. During a transition, outgoing captures stop refreshing but retain their last image; they are released after settling. All captures are released on close.

## Displays and limitations

The overview opens on the focused monitor and lists its ordinary windows. It follows Omarchy's ten-workspace-per-monitor allocation using the monitor/workspace state file, with an active-workspace fallback. Named or occupied workspaces outside the configured slots are included up to the overall 20-slot limit. Special/scratchpad workspaces are excluded.

Window geometry uses logical coordinates and each monitor's position/scale. Desktop miniatures show the physical viewport; windows beyond the viewport in a scrolling layout are still available in the larger window row. When supported by `/usr/share/omarchy-platform/display-cutouts.json`, the plugin reserves the active panel's top notch area. Displays without matching cutout data get no extra top inset.

Some applications or offscreen compositor surfaces do not provide a frame. Those windows remain clickable and show an app-icon fallback. Refreshing previews is not full-rate video. Opening the overview uses the compositor's screen-copy protocol and may trigger its capture indicator. No screenshots, window content, or telemetry are saved or transmitted by this plugin.

## Update and remove

```bash
omarchy plugin update predmore.spaces
```

After an update that changes `gestures.lua`, reload Hyprland to load the updated helper.

If a QML update appears stale, `omarchy-shell shell rescanPlugins` reloads plugins; a shell restart (`omarchy restart shell`) clears the component cache when needed.

To remove: first remove the optional Lua `spaces.setup(...)` block, reload Hyprland and check `hyprctl configerrors`, then run:

```bash
omarchy plugin remove predmore.spaces
```

Remove the optional `~/.local/bin/omarchy-spaces` command if you copied it. Your settings file can be kept or removed separately.

## Development and checks

The repository root is the installable plugin. It contains only plugin code, the optional gesture helper/command, documentation, and headless tests. It does not contain personal configuration or desktop screenshots.

```bash
node --test tests/model.test.cjs
lua tests/gestures.test.lua
python3 tests/package_test.py
bash -n bin/omarchy-spaces
omarchy plugin validate .  # on an Omarchy machine
```

The GitHub workflow runs the headless tests. They cover configuration bounds, monitor allocation, scaling/notch geometry, swipe settlement, safe text/address handling, gesture restoration and crash recovery, and package structure. Runtime changes should also be checked on a real Omarchy desktop: hover without changing the actual workspace, fractional swipe/cancel/edges, keyboard and click activation, overflowing window rows, and zero captures after closing. See [testing notes](docs/TESTING.md).

## License

[MIT](LICENSE). Inspired by the interaction hierarchy of Apple Mission Control / Exposé; this is an independent Omarchy plugin and contains no Apple assets or code.
