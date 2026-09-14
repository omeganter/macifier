import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Macifier — bar control and options panel.
//
// The CLI owns all state; this panel only reflects it and calls back into it.
// `omarchy-macifier status --json` is the single read, so the bar, the terminal
// and the panel can never disagree about what is on.
Panel {
  id: root
  moduleName: "local.macifier"
  // Registers open/close/toggle over IPC, so the panel is reachable from the
  // CLI and the Omarchy menu, not only by clicking the bar.
  ipcTarget: "local.macifier"

  // Panel extends plain Item, so unlike BarWidget it does not derive these
  // from the bar. Same definitions BarWidget uses.
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal

  property var opts: ({})
  property string preset: "off"
  readonly property bool anyOn: {
    for (var k in opts) if (opts[k] && opts[k].on) return true
    return false
  }

  readonly property var labels: ({
    "scroll":      "Natural scrolling",
    "capslock":    "Caps Lock key",
    "mediakeys":   "Media keys on F1-F12",
    "windowtitle": "Window name in bar",
    "cmdkeys":     "Command key shortcuts",
    "cmdkeys-wm":  "Command keys, everything"
  })
  readonly property var hints: ({
    "scroll":      "Trackpad scrolls the macOS way",
    "capslock":    "Caps Lock works, Compose moves to right ⌘",
    "mediakeys":   "Brightness and volume direct · asks for your password",
    "windowtitle": "Show the focused window's name",
    "cmdkeys":     "⌘A select all, ⌘Z undo, ⌘N new, ⌘Q close …",
    "cmdkeys-wm":  "⌘F ⌘S ⌘T ⌘O too · window shortcuts move to ⌃⌥"
  })
  readonly property var order: ["scroll", "capslock", "mediakeys", "cmdkeys", "cmdkeys-wm", "windowtitle"]

  function refresh() { if (!stateProc.running) stateProc.running = true }

  function run(args) {
    if (actionProc.running) return
    actionProc.command = ["omarchy-macifier"].concat(args)
    actionProc.running = true
  }

  Process {
    id: stateProc
    command: ["omarchy-macifier", "status", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var d = JSON.parse(text)
          root.opts = d.options || ({})
          root.preset = d.preset || "off"
        } catch (e) { /* leave last good state rather than blanking the panel */ }
      }
    }
  }

  Process {
    id: actionProc
    command: ["omarchy-macifier", "status"]
    onExited: root.refresh()
  }

  // Catches changes made from the terminal as well as our own.
  Timer {
    interval: 4000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: root.refresh()
  }

  visible: !vertical
  implicitWidth: visible ? barRow.implicitWidth + Style.space(16) : 0
  implicitHeight: barSize

  Behavior on implicitWidth {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  Item {
    id: anchor
    anchors.fill: parent

    Row {
      id: barRow
      anchors.centerIn: parent
      spacing: Style.space(6)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: ""
        color: root.barForeground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        opacity: root.anyOn ? 1.0 : 0.45
        Behavior on opacity { NumberAnimation { duration: 150 } }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.anyOn
        textFormat: Text.PlainText
        text: root.preset === "full" ? "Macifier Full" : "Macifier"
        color: root.barForeground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        opacity: 0.85
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: anchor
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(460))

    ColumnLayout {
      id: column
      width: parent.width
      spacing: Style.space(10)

      PanelSectionHeader { text: "Presets"; Layout.fillWidth: true }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        Repeater {
          model: [
            { id: "off",     label: "Off" },
            { id: "minimal", label: "Minimal" },
            { id: "full",    label: "Full" }
          ]
          delegate: Button {
            required property var modelData
            Layout.fillWidth: true
            text: modelData.label
            // "custom" matches no preset, so no button reads as active — which
            // is honest: the user has a mix none of the presets describe.
            selected: root.preset === modelData.id
            bordered: true
            onClicked: root.run(["preset", modelData.id])
          }
        }
      }

      PanelSeparator { Layout.fillWidth: true }

      PanelSectionHeader { text: "Options"; Layout.fillWidth: true }

      Repeater {
        model: root.order
        delegate: RowLayout {
          required property var modelData
          Layout.fillWidth: true
          spacing: Style.space(10)

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
              Layout.fillWidth: true
              textFormat: Text.PlainText
              text: root.labels[modelData] || modelData
              color: Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }
            Text {
              Layout.fillWidth: true
              textFormat: Text.PlainText
              text: root.hints[modelData] || ""
              color: Qt.darker(Color.foreground, 1.5)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          ToggleSwitch {
            readonly property var entry: root.opts[modelData]
            checked: entry !== undefined && entry.on === true
            // An option the hardware cannot support is shown greyed rather than
            // hidden, so its absence is explained instead of mysterious.
            interactive: entry !== undefined && entry.available === true
            opacity: interactive ? 1.0 : 0.4
            onToggled: root.run(["option", modelData, checked ? "off" : "on"])
          }
        }
      }
    }
  }
}
