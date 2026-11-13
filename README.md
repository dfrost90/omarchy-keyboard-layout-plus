![Keyboard Layout+ preview](preview.png)

# Keyboard Layout+

A local clone of `omarchy.keyboard-layout` that adds per-window keyboard layout
memory through the installed `hyprland-per-window-layout` utility.

## Dependency

- `hyprland-per-window-layout` (installed at `/usr/bin/hyprland-per-window-layout`).
  This is an external runtime dependency and is licensed under the GPL; see
  https://github.com/coffebar/hyprland-per-window-layout. This plugin does not
  bundle or modify it, and remains MIT-licensed for its own code.

## Installation

1. Clone the stock widget:

   ```bash
   omarchy plugin clone omarchy.keyboard-layout
   ```

2. Install the systemd user service (once):

   ```bash
   mkdir -p ~/.config/systemd/user
   cat > ~/.config/systemd/user/hyprland-per-window-layout.service <<'UNIT'
   [Unit]
   Description=Hyprland per-window keyboard layout memory
   After=graphical-session.target
   PartOf=graphical-session.target
   ConditionEnvironment=WAYLAND_DISPLAY
   ConditionPathExists=/usr/bin/hyprland-per-window-layout

   [Service]
   Type=simple
   ExecStart=/usr/bin/hyprland-per-window-layout
   Restart=on-failure
   RestartSec=2

   [Install]
   WantedBy=graphical-session.target
   UNIT
   systemctl --user daemon-reload
   systemctl --user enable --now hyprland-per-window-layout.service
   ```

3. Remove the old Hyprland autostart entry to avoid duplicate launches:

   ```bash
   # delete the line: o.launch_on_start("hyprland-per-window-layout")
   # from ~/.config/hypr/autostart.lua
   ```

4. Validate:

   ```bash
   omarchy plugin validate ~/.config/omarchy/plugins/omarchy-keyboard-layout-plus
   ```

## Usage

- Left click: cycle keyboard layouts (unchanged from the stock widget).
- Right click: start or stop per-window layout memory.
- The indicator uses the theme accent color while memory is running, and the
  normal foreground otherwise.
- Tooltip shows the full layout name, memory status, and both click actions.

Stopping the utility clears its in-memory window choices and returns the seat
to ordinary global layout switching.

Layout switching accepts only keyboard names starting with an ASCII letter or
digit and containing ASCII letters, digits, `_`, or `-`. Special Hyprland
selectors (`all`, `main`, `active`, `current`) are excluded. Other names are
ignored so device names cannot become IPC batch or Lua command syntax.
Hyprland 0.57.2 does not expose keyboard permission status in `hyprctl -j devices`;
this filter validates names, not keyboard authorization.

## Removal

```bash
systemctl --user disable --now hyprland-per-window-layout.service
rm ~/.config/systemd/user/hyprland-per-window-layout.service
systemctl --user daemon-reload
```

## Rollback (restore the stock indicator)

```bash
systemctl --user disable --now hyprland-per-window-layout.service
omarchy plugin disable io.github.dfrost90.keyboard-layout-plus
omarchy plugin enable omarchy.keyboard-layout
# re-add to ~/.config/hypr/autostart.lua:
# o.launch_on_start("hyprland-per-window-layout")
```
