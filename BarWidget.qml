import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

// The bar's cat button: left click opens a menu like Bluetooth's, right click
// switches the grip on or off. The menu carries the corner choice (all four
// corners of the window) and the pad's keybinding hints, both stored by the
// overlay in ~/.config/omarchy/window-controls.json.
//
// This file is a small client: every change is written through the overlay's
// IPC (`omarchy-shell window-controls …`), and opening the menu re-reads
// `status` so the switches always show what the grip will actually do.
Panel {
  id: root

  // Mirror of the overlay's persisted state, refreshed when the menu opens.
  property bool gripEnabled: true
  property string corner: "tl"
  property bool hints: true

  // 󰄛 is JetBrainsMono Nerd Font's cat — the same icon set the Bluetooth
  // button uses, so it sits in the bar as a native widget. While the grip
  // is switched off the cat sleeps: the font's Zzz mark (󰒲) next to it.
  readonly property string icon: "󰄛"
  readonly property string sleepingIcon: "󰄛󰒲"
  // 󰍽 is the font's mouse — the symbol beside the menu's title.
  readonly property string mouseIcon: "󰍽"

  // The bar asks the widget how much room the button needs; without these it
  // lays the button out at zero size and the cat is invisible.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property color hoverFill: bar
    ? "#22ffffff"
    : "transparent"
  readonly property color selectedFill: bar
    ? "#33e68e0d"
    : "transparent"

  function applyState(raw) {
    var data = null
    try { data = JSON.parse(String(raw || "")) } catch (error) { data = null }
    if (!data) return
    if (data.gripEnabled !== undefined) root.gripEnabled = data.gripEnabled === true
    if (data.corner !== undefined) {
      var next = String(data.corner)
      if (next === "tl" || next === "tr" || next === "bl" || next === "br") root.corner = next
    }
    if (data.hints !== undefined) root.hints = data.hints === true
  }

  function dispatch(args) {
    // Run the change through the overlay's IPC, then sync so the switches
    // follow exactly what was persisted even if a value was clamped.
    Quickshell.execDetached(["omarchy-shell", "window-controls"].concat(args))
  }

  function sync() {
    if (!statusProc.running) statusProc.running = true
  }

  Process {
    id: statusProc
    running: false
    command: ["omarchy-shell", "window-controls", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyState(text)
    }
  }

  onOpenedChanged: if (opened) root.sync()

  IpcHandler {
    target: "eep.window-controls"

    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.gripEnabled ? root.icon : root.sleepingIcon
    opacity: root.gripEnabled ? 1.0 : 0.5
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        var next = !root.gripEnabled
        root.dispatch(["enabled", next ? "true" : "false"])
        root.gripEnabled = next
      } else {
        root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(340)
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.close()
      onCloseRequested: root.close()
    }

    Column {
      id: column
      anchors.fill: parent
      spacing: 14

      // ---------- Hero: mouse icon · title · grip on/off ----------
      Item {
        width: parent.width
        implicitHeight: Math.max(heroIcon.implicitHeight, heroText.implicitHeight, gripSwitch.implicitHeight)

        Text {
          id: heroIcon
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: root.mouseIcon
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: 20
          opacity: root.gripEnabled ? 1.0 : 0.5
        }

        Column {
          id: heroText
          anchors.left: heroIcon.right
          anchors.leftMargin: 14
          anchors.right: gripSwitch.left
          anchors.rightMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2

          Text {
            text: "Control the windows"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: 16
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            text: root.gripEnabled ? "GRIP ON" : "GRIP OFF"
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1.2
          }
        }

        ToggleSwitch {
          id: gripSwitch
          checked: root.gripEnabled
          foreground: root.bar.foreground
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          onToggled: {
            root.dispatch(["enabled", checked ? "true" : "false"])
          }
        }
      }

      PanelSeparator {
        foreground: root.bar.foreground
      }

      PanelSectionHeader {
        text: "GRIP CORNER"
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
      }

      OptionRow {
        label: "Top left"
        checked: root.corner === "tl"
        onClicked: {
          root.dispatch(["corner", "tl"])
          root.corner = "tl"
        }
      }

      OptionRow {
        label: "Top right"
        checked: root.corner === "tr"
        onClicked: {
          root.dispatch(["corner", "tr"])
          root.corner = "tr"
        }
      }

      OptionRow {
        label: "Bottom left"
        checked: root.corner === "bl"
        onClicked: {
          root.dispatch(["corner", "bl"])
          root.corner = "bl"
        }
      }

      OptionRow {
        label: "Bottom right"
        checked: root.corner === "br"
        onClicked: {
          root.dispatch(["corner", "br"])
          root.corner = "br"
        }
      }

      PanelSeparator {
        foreground: root.bar.foreground
      }

      Item {
        width: parent.width
        implicitHeight: Math.max(hintsLabel.implicitHeight, hintsSwitch.implicitHeight)

        Text {
          id: hintsLabel
          text: "Keybinding hints on the pad"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: 13
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
        }

        ToggleSwitch {
          id: hintsSwitch
          checked: root.hints
          foreground: root.bar.foreground
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          onToggled: {
            root.dispatch(["hints", checked ? "true" : "false"])
          }
        }
      }
    }
  }

  // A menu row with hover highlight and a check mark for the selected corner.
  component OptionRow: CursorSurface {
    id: row
    required property string label
    required property bool checked
    signal clicked()

    width: parent ? parent.width : 0

    hasCursor: rowMouse.containsMouse
    current: row.checked
    foreground: root.bar.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill

    implicitHeight: rowText.implicitHeight + 10

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.clicked()
    }

    Text {
      id: rowCheck
      text: row.checked ? "✓" : ""
      color: root.bar.foreground
      font.family: root.bar.fontFamily
      font.pixelSize: 13
      anchors.left: parent.left
      anchors.leftMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      width: 16
    }

    Text {
      id: rowText
      text: row.label
      color: root.bar.foreground
      font.family: root.bar.fontFamily
      font.pixelSize: 13
      anchors.left: rowCheck.right
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
    }
  }
}
