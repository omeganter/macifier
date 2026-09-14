import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Macifier — bar control, options panel, and per-key keybinding editor.
//
// The CLI owns all state; this panel only reflects it and calls back into it.
// Two reads, `status --json` and `key status --json`, are the single source of
// truth, so the bar, the terminal and the panel can never disagree.
Panel {
  id: root
  moduleName: "local.macifier"
  ipcTarget: "local.macifier"
  manageIpc: false

  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal

  property var opts: ({})
  property string preset: "off"
  property var keys: []
  property string keysPreset: "none"
  property string view: "main"

  readonly property bool anyOn: {
    for (var k in opts) if (opts[k] && opts[k].on) return true
    return false
  }

  readonly property var labels: ({
    "scroll":      "Natural scrolling",
    "capslock":    "Caps Lock key",
    "mediakeys":   "Media keys on F1-F12",
    "cmdkeys":     "Command key shortcuts",
    "windowtitle": "Window name in bar",
    "appswitcher": "⌘Tab switches apps"
  })
  readonly property var hints: ({
    "scroll":      "Trackpad scrolls the macOS way",
    "capslock":    "Caps Lock works, Compose moves to right ⌘",
    "mediakeys":   "Brightness and volume direct · asks for your password",
    "cmdkeys":     "⌘A ⌘Z ⌘N ⌘Q … tap Edit to choose",
    "windowtitle": "Show the focused window's name",
    "appswitcher": "Icon bar of apps, not workspaces · ⌘⌥Tab for workspaces"
  })
  readonly property var order: ["scroll", "capslock", "mediakeys", "cmdkeys", "appswitcher", "windowtitle"]

  function refresh() {
    if (!stateProc.running) stateProc.running = true
    if (!keysProc.running) keysProc.running = true
  }

  function run(args) {
    if (actionProc.running) return
    actionProc.command = ["omarchy-macifier"].concat(args)
    actionProc.running = true
  }

  // Declared by hand rather than left to Panel's default so the keybinding
  // editor gets its own entry point — reachable from a keybinding or a menu
  // item, not only by opening the panel and finding the Edit button.
  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.view = "main"; root.open() }
    function close(): void { root.close() }
    function show(): void { root.view = "main"; root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function keys(): void { root.view = "keys"; root.open() }
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
        } catch (e) { /* keep last good state rather than blanking the panel */ }
      }
    }
  }

  Process {
    id: keysProc
    command: ["omarchy-macifier", "key", "status", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var d = JSON.parse(text)
          root.keys = d.keys || []
          root.keysPreset = d.preset || "none"
        } catch (e) { }
      }
    }
  }

  Process {
    id: actionProc
    command: ["omarchy-macifier", "status"]
    onExited: root.refresh()
  }

  Timer {
    interval: 4000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Coming back to a closed panel on the sub-view would be disorienting.
  onOpenedChanged: if (!opened) view = "main"

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
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(
      root.view === "main" ? mainCol.implicitHeight : keysCol.implicitHeight,
      Style.space(520))

    // ---------------------------------------------------------------- main --
    ColumnLayout {
      id: mainCol
      width: parent.width
      visible: root.view === "main"
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
            bordered: true
            selected: root.preset === modelData.id
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
          spacing: Style.space(8)

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

          // Only the Command-key option has anything to drill into.
          Button {
            visible: modelData === "cmdkeys"
            text: "Edit"
            bordered: true
            onClicked: root.view = "keys"
          }

          ToggleSwitch {
            readonly property var entry: root.opts[modelData]
            checked: entry !== undefined && entry.on === true
            interactive: entry !== undefined && entry.available === true
            opacity: interactive ? 1.0 : 0.4
            onToggled: root.run(["option", modelData, checked ? "off" : "on"])
          }
        }
      }
    }

    // ---------------------------------------------------------------- keys --
    ColumnLayout {
      id: keysCol
      width: parent.width
      visible: root.view === "keys"
      spacing: Style.space(10)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)
        Button { text: "‹  Back"; bordered: true; onClicked: root.view = "main" }
        Item { Layout.fillWidth: true }
      }

      PanelSectionHeader { text: "Keybindings"; Layout.fillWidth: true }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)
        Repeater {
          model: [
            { id: "none",    label: "None" },
            { id: "minimal", label: "Minimal" },
            { id: "full",    label: "Full Mac" }
          ]
          delegate: Button {
            required property var modelData
            Layout.fillWidth: true
            text: modelData.label
            bordered: true
            selected: root.keysPreset === modelData.id
            onClicked: root.run(["key", "preset", modelData.id])
          }
        }
      }

      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        // Says the cost out loud, so nobody discovers it by losing a shortcut.
        text: "Minimal claims only keys Omarchy leaves free. Full Mac also takes "
            + "keys that hold window shortcuts — those move to ⌃⌥ + the same letter."
        color: Qt.darker(Color.foreground, 1.5)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      PanelSeparator { Layout.fillWidth: true }

      // Nineteen rows do not fit a bar popup, so the list scrolls inside a
      // fixed frame while the presets and the warning above it stay put.
      ScrollView {
        id: keyScroll
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(keyList.implicitHeight, Style.space(240))
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

      // Inside a ScrollView `parent` is the unbounded content item, so binding
      // to availableWidth is what actually keeps rows (and their switches)
      // within the visible frame.
      ColumnLayout {
        id: keyList
        width: keyScroll.availableWidth
        spacing: Style.space(10)

      Repeater {
        model: root.keys
        delegate: RowLayout {
          required property var modelData
          Layout.fillWidth: true
          spacing: Style.space(8)

          Text {
            Layout.preferredWidth: Style.space(52)
            textFormat: Text.PlainText
            text: "⌘" + modelData.key
            color: Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
              Layout.fillWidth: true
              textFormat: Text.PlainText
              text: modelData.label
              color: Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }
            Text {
              Layout.fillWidth: true
              visible: modelData.group === "wm"
              textFormat: Text.PlainText
              text: "moves “" + modelData.displaces + "” to ⌃⌥" + modelData.key
              color: Qt.darker(Color.foreground, 1.5)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          ToggleSwitch {
            checked: modelData.on === true
            onToggled: root.run(["key", modelData.key, checked ? "off" : "on"])
          }
        }
      }

      }
      }
    }
  }
}
