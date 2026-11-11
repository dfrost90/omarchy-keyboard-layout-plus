import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "KeyboardLayoutModel.js" as KeyboardLayoutModel

BarWidget {
  id: root
  moduleName: "omarchy.keyboard-layout"

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  property string layoutFull: ""
  property string keyboardName: ""
  property string typedKeyboardName: ""
  property bool keyboardUnresolved: false
  property bool multipleLayouts: true
  property int layoutIndex: 0
  property int layoutCount: 0
  property var syncNames: []
  property var layoutBriefs: ({})
  property bool layoutsRead: false
  property bool briefsRequested: false
  readonly property bool needsBriefs: layoutsRead && (multipleLayouts || multipleInputs)
  onNeedsBriefsChanged: loadBriefs()

  function loadBriefs() {
    if (!needsBriefs || briefsRequested) return
    briefsRequested = true
    briefsProc.running = true
  }
  readonly property string layoutLabel: KeyboardLayoutModel.shortLabel(layoutFull, layoutBriefs)
  readonly property var inputState: InputMethodState.state
  readonly property bool multipleInputs: (inputState.methods || []).length > 1
  readonly property string inputLabel: KeyboardLayoutModel.inputLabel(inputState, layoutLabel)

  property bool refreshPending: false

  function refresh() {
    if (queryProc.running) {
      refreshPending = true
      return
    }

    refreshPending = false
    queryProc.running = true
  }

  function typedKeyboards(keyboards) {
    return keyboards.filter(k => KeyboardLayoutModel.isTypedKeyboard(k.name))
  }

  function selectKeyboard(typed) {
    return KeyboardLayoutModel.selectKeyboard(typed, root.typedKeyboardName)
  }

  function cycleLayout() {
    if (!root.bar || root.layoutCount < 2 || root.syncNames.length === 0) return
    const next = (root.layoutIndex + 1) % root.layoutCount
    root.bar.run(root.syncNames.map(name =>
      "hyprctl switchxkblayout " + Util.shellQuote(name) + " " + next).join("; "))
    refreshTimer.restart()
  }

  // Shared state for the single background service, loaded once by the shell.
  readonly property var memoryService: root.bar && root.bar.shell
      ? root.bar.shell.serviceFor(root.moduleName) : null
  readonly property bool memoryAvailable: root.memoryService ? root.memoryService.available : false
  readonly property bool memoryRunning: root.memoryService ? root.memoryService.running : false
  readonly property bool memoryBusy: root.memoryService ? root.memoryService.busy : false
  readonly property string memoryError: root.memoryService ? root.memoryService.lastError : ""

  function plain(value) {
    var out = String(value === undefined || value === null ? "" : value)
    if (out.length > 200) out = out.slice(0, 200) + "…"
    return out.replace(/[<>&]/g, " ")
  }

  function memoryStatusText() {
    if (!root.memoryAvailable) return strings.t("memory.unavailable", "Memory: unavailable")
    if (root.memoryRunning) return strings.t("memory.on", "Memory: on")
    if (root.memoryError && root.memoryError.length > 0) return strings.t("memory.error", "Memory: error")
    return strings.t("memory.off", "Memory: off")
  }

  readonly property string memoryTooltip: {
    var mem = root.memoryStatusText()
    if (root.memoryError && root.memoryError.length > 0 && !root.memoryRunning)
      mem = mem + " (" + root.plain(root.memoryError) + ")"
    return mem
  }

  readonly property string tooltipTextValue: {
    var parts = []
    if (root.layoutFull)
      parts.push(strings.t("tooltip.layout", "Layout: %1").arg(root.plain(root.layoutFull)))
    parts.push(root.memoryTooltip)
    parts.push(strings.t("tooltip.left", "Left click: cycle layout"))
    parts.push(strings.t("tooltip.right", "Right click: toggle memory"))
    return parts.join(" · ")
  }

  Component.onCompleted: refresh()

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event || !event.name) return
      var name = String(event.name)
      if (name === "activelayout") {
        const named = KeyboardLayoutModel.eventKeyboardName(event)
        if (named) root.typedKeyboardName = named
      }

      if (name.indexOf("activelayout") !== -1 || name === "configreloaded") root.refresh()
    }
  }

  Process {
    id: queryProc
    command: ["hyprctl", "-j", "devices"]
    onRunningChanged: {
      if (running) {
        stallTimer.restart()
        return
      }

      stallTimer.stop()
      if (root.refreshPending) root.refresh()
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        let listed
        try {
          listed = JSON.parse(text || "{}").keyboards
        } catch (e) {
          root.keyboardUnresolved = true
          return
        }

        if (!Array.isArray(listed)) {
          root.keyboardUnresolved = true
          return
        }

        const typed = root.typedKeyboards(listed)
        const kb = root.selectKeyboard(typed)
        if (!kb || !kb.active_keymap) {
          root.keyboardUnresolved = true
          if (typed.length === 0) {
            root.layoutFull = ""
            root.keyboardName = ""
          }
          return
        }

        root.keyboardUnresolved = false
        root.keyboardName = String(kb.name || "")
        root.multipleLayouts = kb.layout === undefined || String(kb.layout).indexOf(",") !== -1
        root.layoutsRead = true
        root.layoutIndex = kb.active_layout_index || 0
        root.layoutCount = kb.layout === undefined ? 0 : String(kb.layout).split(",").length
        root.syncNames = listed.filter(k => String(k.layout) === String(kb.layout))
                               .map(k => String(k.name || ""))
                               .filter(name => name !== "")
        root.layoutFull = kb.active_keymap
      }
    }
  }

  Process {
    id: briefsProc
    command: ["xkbcli", "list", "--load-exotic"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.layoutBriefs = KeyboardLayoutModel.layoutBriefs(text)
    }
  }

  Timer {
    id: refreshTimer
    interval: 600
    onTriggered: root.refresh()
  }

  Timer {
    id: stallTimer
    interval: 5000
    onTriggered: {
      queryProc.running = false
      refreshTimer.restart()
    }
  }

  Connections {
    target: InputDevices
    function onChanged() { root.refresh() }
  }

  Timer {
    interval: 10000
    running: !root.keyboardName || root.keyboardUnresolved || !InputDevices.healthy
    repeat: true
    onTriggered: root.refresh()
  }

  visible: inputLabel !== "" && KeyboardLayoutModel.showIndicator(layoutLabel, multipleLayouts, multipleInputs)
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.inputLabel
    fontSize: Style.font.caption
    horizontalMargin: 6
    tooltipText: root.tooltipTextValue
    onPressed: function(button) {
      if (button === Qt.RightButton) {
        if (root.memoryService) root.memoryService.toggle()
        return
      }
      if (root.multipleInputs && button === Qt.LeftButton) {
        InputMethodState.cycle()
      } else if (root.multipleLayouts) {
        root.cycleLayout()
      }
    }
  }

  Rectangle {
    anchors.centerIn: button
    width: Math.max(12, button.labelWidth + 6)
    height: Style.font.caption + 6
    radius: 0
    color: "transparent"
    border.width: 1
    border.color: button.foreground
    visible: root.memoryRunning
    z: 1
  }
}
