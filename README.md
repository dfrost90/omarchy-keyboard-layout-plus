# Keyboard Layout+

A local clone of `omarchy.keyboard-layout` that adds per-window keyboard layout
memory through the installed `hyprland-per-window-layout` utility.

## Dependency

- `hyprland-per-window-layout` (installed at `/usr/bin/hyprland-per-window-layout`)

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
   omarchy plugin validate ~/.config/omarchy/plugins/dfrost.keyboard-layout
   ```

## Usage

- Left click: cycle keyboard layouts (unchanged from the stock widget).
- Right click: start or stop per-window layout memory.
- The indicator uses the theme accent color while memory is running, and the
  normal foreground otherwise.
- Tooltip shows the full layout name, memory status, and both click actions.

Stopping the utility clears its in-memory window choices and returns the seat
to ordinary global layout switching.

## Removal

```bash
systemctl --user disable --now hyprland-per-window-layout.service
rm ~/.config/systemd/user/hyprland-per-window-layout.service
systemctl --user daemon-reload
```

## Rollback (restore the stock indicator)

```bash
systemctl --user disable --now hyprland-per-window-layout.service
omarchy plugin disable dfrost.keyboard-layout
omarchy plugin enable omarchy.keyboard-layout
# re-add to ~/.config/hypr/autostart.lua:
# o.launch_on_start("hyprland-per-window-layout")
```
