import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var shell: null
  property string serviceName: "hyprland-per-window-layout"
  property string unitName: root.serviceName + ".service"
  property string binaryPath: "/usr/bin/hyprland-per-window-layout"

  property bool available: false
  property bool running: false
  property bool enabled: false
  property bool busy: false
  property string lastError: ""
  property string lastStderr: ""


  function refreshStatus() {
    if (statusProc.running) return
    statusProc.running = true
  }

  function toggle() {
    if (root.busy) return
    if (!root.available) {
      root.lastError = root.binaryPath + " not found"
      return
    }
    root.busy = true
    root.lastError = ""
    if (!root.running) {
      opProc.command = ["bash", "-c",
        "pkill -x " + root.serviceName + " >/dev/null 2>&1 || true; " +
        "systemctl --user daemon-reload; " +
        "systemctl --user enable --now " + root.unitName]
    } else {
      opProc.command = ["bash", "-c",
        "systemctl --user disable --now " + root.unitName]
    }
    opProc.running = true
  }

  Process {
    id: statusProc
    command: ["bash", "-c",
      "systemctl --user show " + root.unitName + " -p ActiveState -p UnitFileState 2>&1; " +
      "echo '---'; command -v " + root.binaryPath + " 2>&1 || true"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var activeState = "inactive"
        var unitFileState = "disabled"
        var binaryFound = false
        var lines = String(text || "").split("\n")
        var afterSep = false
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim()
          if (line === "---") { afterSep = true; continue }
          if (afterSep) {
            if (line.indexOf(root.binaryPath) !== -1 || line === root.binaryPath) binaryFound = true
            continue
          }
          if (line.indexOf("ActiveState=") === 0) activeState = line.substring("ActiveState=".length)
          else if (line.indexOf("UnitFileState=") === 0) unitFileState = line.substring("UnitFileState=".length)
        }
        // command -v may print the path; fall back to checking the known location.
        if (!binaryFound) {
          // try direct stat via a synchronous-ish check is not available; rely on path text
          binaryFound = String(text || "").indexOf(root.binaryPath) !== -1
        }
        root.available = binaryFound
        root.running = (activeState === "active" || activeState === "activating" || activeState === "reloading")
        root.enabled = (unitFileState === "enabled" || unitFileState === "enabled-runtime")
        if (activeState === "failed") {
          root.lastError = "Service failed to start"
        } else if (!root.available) {
          root.lastError = root.binaryPath + " not found"
        } else if (root.lastError === "Service failed to start" && activeState !== "failed") {
          root.lastError = ""
        }
      }
    }
  }

  Process {
    id: opProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text && text.trim().length > 0) {
          // keep last line as diagnostic
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.lastStderr = String(text || "").trim().slice(-300)
      }
    }
    onExited: function(code, status) {
      root.busy = false
      if (code !== 0) {
        root.lastError = root.lastStderr.length > 0 ? root.lastStderr : "Operation failed"
      } else {
        root.lastError = ""
      }
      root.refreshStatus()
    }
  }

  Timer {
    id: pollTimer
    interval: 2000
    running: true
    repeat: true
    onTriggered: root.refreshStatus()
  }

  Component.onCompleted: root.refreshStatus()
}
