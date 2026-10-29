import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons

// A small handle in the top-right corner of the focused window. Clicking it
// opens a pad with six actions: wider, narrower and move up/down/left/right.
//
// Hyprland has no per-window decoration we can hang a widget off, so the
// geometry comes from `hyprctl -j activewindow` + `hyprctl -j monitors` on a
// short poll, and every action is a `hyprctl dispatch`. Tiled windows are moved
// inside the tile layout (like SUPER+arrows), floating ones are nudged in pixels.
Item {
  id: root

  property var shell: null
  property var manifest: null

  // -------------------------------------------------------------- tuning
  readonly property int buttonSize: 20
  readonly property int buttonInset: 5      // px inside the window's top-right corner
  readonly property int step: 80            // px per resize / nudge click
  readonly property int pollInterval: 300   // ms between geometry refreshes
  readonly property int autoCloseMs: 6000   // pad closes itself after this much idle

  readonly property int popupWidth: 152
  readonly property int rowHeight: 24
  readonly property int rowGap: 2
  readonly property int popupPadding: 6
  readonly property int popupGap: 6
  readonly property int popupHeight: popupPadding * 2 + rowHeight * 6 + rowGap * 5

  // ----------------------------------------------- focused window state
  property string address: ""
  property int winX: 0
  property int winY: 0
  property int winW: 0
  property int winH: 0
  property bool winFloating: false
  property string screenName: ""
  property int screenWidth: 0
  property int screenHeight: 0

  readonly property bool hasWindow: address !== "" && winW > 0 && winH > 0 && screenName !== ""

  property bool popupOpen: false

  // -------------------------------------------------------------- geometry
  readonly property int buttonX: Math.round(winX + winW - buttonInset - buttonSize)
  readonly property int buttonY: Math.round(winY + buttonInset)
  readonly property int popupX: Math.max(4, Math.min(buttonX + buttonSize - popupWidth,
                                                   Math.max(4, screenWidth - popupWidth - 4)))
  readonly property bool popupAbove: buttonY + buttonSize + popupGap + popupHeight > screenHeight
  readonly property int popupY: popupAbove
    ? Math.max(4, buttonY - popupHeight - popupGap)
    : buttonY + buttonSize + popupGap

  // --------------------------------------------------------------- actions
  // Dispatch through Hyprland's Lua dispatchers, addressed by window so the
  // action never depends on what happens to hold focus while the pad is used.
  function act(kind) {
    if (!root.hasWindow || !kind) return

    var target = 'address:' + root.address
    var expression = ""

    if (kind === "wider" || kind === "narrower") {
      var magnitude = kind === "wider" ? root.step : -root.step
      var dx = 0
      var dy = 0
      if (root.winFloating) {
        dx = magnitude
      } else if (root.winW < root.screenWidth - 4) {
        // Side-by-side tiles share a vertical edge, so the delta grows the
        // window only when it moves that edge away from the screen centre.
        dx = (root.winX + root.winW / 2) < root.screenWidth / 2 ? magnitude : -magnitude
      } else {
        // Stacked tiles share a horizontal edge instead.
        dy = (root.winY + root.winH / 2) < root.screenHeight / 2 ? magnitude : -magnitude
      }
      expression = 'hl.dsp.window.resize({ window = "' + target + '", x = ' + dx
        + ', y = ' + dy + ', relative = true })'
    } else if (root.winFloating) {
      var nudgeX = kind === "left" ? -root.step : (kind === "right" ? root.step : 0)
      var nudgeY = kind === "up" ? -root.step : (kind === "down" ? root.step : 0)
      expression = 'hl.dsp.window.move({ window = "' + target + '", x = ' + nudgeX
        + ', y = ' + nudgeY + ', relative = true })'
    } else {
      var directions = { left: "l", right: "r", up: "u", down: "d" }
      var direction = directions[kind]
      if (!direction) return
      expression = 'hl.dsp.window.swap({ window = "' + target + '", direction = "'
        + direction + '" })'
    }

    Quickshell.execDetached(["hyprctl", "dispatch", expression])
    autoCloseTimer.restart()
  }

  function togglePopup() {
    if (!root.hasWindow) return
    root.popupOpen = !root.popupOpen
    if (root.popupOpen) autoCloseTimer.restart()
  }

  function closePopup() {
    root.popupOpen = false
  }

  // --------------------------------------------------------------- polling
  function poll() {
    if (!queryProc.running) queryProc.running = true
  }

  function reset() {
    if (root.address !== "") root.address = ""
    root.winW = 0
    root.winH = 0
    root.popupOpen = false
  }

  function applySnapshot(raw) {
    var data = null
    try { data = JSON.parse(String(raw || "")) } catch (e) { data = null }
    if (!data || !data.win) { root.reset(); return }

    var win = data.win
    var mons = Array.isArray(data.mons) ? data.mons : []

    // Nothing to point at: no window, or one that is hidden/fullscreen.
    if (!win.address || win.mapped === false || win.hidden === true
        || win.visible === false || Number(win.fullscreen || 0) !== 0) {
      root.reset()
      return
    }

    var at = win.at || []
    var size = win.size || []
    if (at.length < 2 || size.length < 2 || !(size[0] > 0) || !(size[1] > 0)) {
      root.reset()
      return
    }

    var mon = null
    for (var i = 0; i < mons.length; i++) {
      if (mons[i] && Number(mons[i].id) === Number(win.monitor)) { mon = mons[i]; break }
    }
    if (!mon) { root.reset(); return }

    var scale = Number(mon.scale) > 0 ? Number(mon.scale) : 1
    var turned = Number(mon.transform) % 2 === 1
    var monW = Math.round((turned ? Number(mon.height) : Number(mon.width)) / scale)
    var monH = Math.round((turned ? Number(mon.width) : Number(mon.height)) / scale)

    var nextAddress = String(win.address)
    if (nextAddress !== root.address) {
      root.address = nextAddress
      root.popupOpen = false
    }

    root.winX = Math.round(Number(at[0]) - Number(mon.x))
    root.winY = Math.round(Number(at[1]) - Number(mon.y))
    root.winW = Math.round(Number(size[0]))
    root.winH = Math.round(Number(size[1]))
    root.winFloating = win.floating === true
    root.screenName = String(mon.name || "")
    root.screenWidth = monW
    root.screenHeight = monH
  }

  function isOnScreen(screenName) {
    return root.hasWindow && String(screenName || "") === root.screenName
  }

  Timer {
    id: pollTimer
    interval: root.pollInterval
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.poll()
  }

  Timer {
    id: autoCloseTimer
    interval: root.autoCloseMs
    onTriggered: root.closePopup()
  }

  Process {
    id: queryProc
    running: false
    command: ["sh", "-c",
      "printf '{\"win\":%s,\"mons\":%s}' \"$(hyprctl -j activewindow)\" \"$(hyprctl -j monitors)\""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applySnapshot(text)
    }
  }

  // Lets a keybinding drive the same actions, e.g.
  //   o.bind("SUPER + SHIFT + W", "Window pad", "omarchy-shell window-controls toggle")
  IpcHandler {
    target: "window-controls"

    function toggle(): string {
      root.togglePopup()
      return root.popupOpen ? "open" : "closed"
    }

    function act(kind: string): string {
      if (!root.hasWindow) return "none"
      root.act(kind)
      return "ok"
    }

    function status(): string {
      return JSON.stringify({
        address: root.address,
        x: root.winX,
        y: root.winY,
        width: root.winW,
        height: root.winH,
        floating: root.winFloating,
        screen: root.screenName,
        buttonX: root.buttonX,
        buttonY: root.buttonY,
        open: root.popupOpen
      })
    }
  }

  // ------------------------------------------------------------ surfaces
  // One small, otherwise-click-through surface per output. The input region is
  // masked down to the handle, so the invisible full-screen surface never eats
  // clicks meant for the application.
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: handleWindow

      required property var modelData

      visible: root.isOnScreen(modelData ? modelData.name : "")
      screen: modelData

      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "omarchy-window-controls"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      mask: Region { item: handle }

      Rectangle {
        id: handle

        x: root.buttonX
        y: root.buttonY
        width: root.buttonSize
        height: root.buttonSize
        radius: Math.min(Style.cornerRadius, 5)
        color: Commons.Color.menu.background
        border.width: 1
        border.color: Commons.Color.menu.border
        opacity: handleArea.containsMouse || root.popupOpen ? 0.95 : 0.5

        // Two diagonal ticks read as a resize grip without depending on a glyph.
        Rectangle {
          width: Math.round(handle.width * 0.5)
          height: 1
          rotation: -45
          radius: 1
          color: Commons.Color.menu.text
          anchors.centerIn: parent
          anchors.horizontalCenterOffset: -2
          anchors.verticalCenterOffset: -2
        }

        Rectangle {
          width: Math.round(handle.width * 0.3)
          height: 1
          rotation: -45
          radius: 1
          color: Commons.Color.menu.text
          anchors.centerIn: parent
          anchors.horizontalCenterOffset: 3
          anchors.verticalCenterOffset: 3
        }

        MouseArea {
          id: handleArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.togglePopup()
        }
      }
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: padWindow

      required property var modelData

      visible: root.popupOpen && root.isOnScreen(modelData ? modelData.name : "")
      screen: modelData

      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "omarchy-window-controls-pad"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      mask: Region { item: card }

      Rectangle {
        id: card

        x: root.popupX
        y: root.popupY
        width: root.popupWidth
        height: root.popupHeight
        radius: Math.min(Style.cornerRadius, 8)
        color: Commons.Color.menu.background
        border.width: 1
        border.color: Commons.Color.menu.border

        Column {
          anchors.fill: parent
          anchors.margins: root.popupPadding
          spacing: root.rowGap

          Repeater {
            model: [
              { glyph: "↑", label: "Move up", kind: "up" },
              { glyph: "↓", label: "Move down", kind: "down" },
              { glyph: "←", label: "Move left", kind: "left" },
              { glyph: "→", label: "Move right", kind: "right" },
              { glyph: "−", label: "Narrower", kind: "narrower" },
              { glyph: "+", label: "Wider", kind: "wider" }
            ]

            Rectangle {
              id: row
              required property var modelData

              width: parent ? parent.width : 0
              height: root.rowHeight
              radius: Math.min(Style.cornerRadius, 4)
              color: rowArea.containsMouse ? Commons.Color.menu.selectedBackground : "transparent"

              Text {
                anchors.left: parent.left
                anchors.leftMargin: 4
                width: 16
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                text: row.modelData.glyph
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.body
                color: rowArea.containsMouse ? Commons.Color.menu.selectedText : Commons.Color.menu.text
              }

              Text {
                anchors.left: parent.left
                anchors.leftMargin: 26
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.label
                elide: Text.ElideRight
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.body
                color: rowArea.containsMouse ? Commons.Color.menu.selectedText : Commons.Color.menu.text
              }

              MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.act(row.modelData.kind)
              }
            }
          }
        }
      }
    }
  }
}
