const assert = require("node:assert/strict")
const { isSafeKeyboardName, layoutSwitchCommand } = require("../KeyboardLayoutModel.js")

const safe = ["at-translated-set-2-keyboard", "keychron-k2", "usb_keyboard-1", "2-4G-keyboard"]
const unsafe = [
  "", null, undefined, {}, "all", "main", "active", "current", "ALL",
  "--batch", "-j", "keyboard name", "keyboard\tname", "keyboard\n", "keyboard\r",
  "keyboard;devices", "keyboard/dispatch", "keyboard[[devices]]", "keyboard]",
  "keyboard'", 'keyboard"', "keyboard\\", "keyboard()", "keyboard,devices",
  "keyboard$(id)", "keyboard`id`", "keybоard", "keyboard\0"
]

for (const name of safe) assert.equal(isSafeKeyboardName(name), true, name)
for (const name of unsafe) assert.equal(isSafeKeyboardName(name), false, String(name))

// A same-layout synchronization list can contain denied/pending devices too.
// Even if such a name reaches the command builder directly, it cannot become IPC
// or shell syntax. Ordinary keyboards still switch together to the same index.
assert.equal(layoutSwitchCommand([...safe, ...unsafe], 1), safe.map(name =>
  `hyprctl switchxkblayout ${name} 1`).join("; "))
assert.equal(layoutSwitchCommand(unsafe, 1), "")
for (const index of [-1, 0.5, NaN, Infinity, "1; devices", null])
  assert.equal(layoutSwitchCommand(safe, index), "")
assert.equal(layoutSwitchCommand([safe[0]], 0), `hyprctl switchxkblayout ${safe[0]} 0`)

console.log("Keyboard layout security checks passed")
