import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Macifier — bar control for Mac-affinity mode.
//
// State is owned by `omarchy-macifier`, not by this widget: the script is the
// single source of truth and the widget only reflects and pokes it, so the CLI
// and the bar cannot disagree when either one is used.
//
// When on, the widget names itself. An unlabelled glyph is a puzzle; a named
// one tells you what is currently changing your machine and, by being visible
// at all, tells you it can be switched off.
BarWidget {
  id: root
  moduleName: "local.macifier"

  property bool active: false

  function refresh() {
    if (!stateProc.running) stateProc.running = true
  }

  // `omarchy toggle enabled <flag>` answers through its exit code, so there is
  // no output to parse.
  Process {
    id: stateProc
    command: ["omarchy", "toggle", "enabled", "macifier"]
    onExited: function(exitCode) { root.active = exitCode === 0 }
  }

  Process {
    id: toggleProc
    command: ["omarchy-macifier", "toggle"]
    onExited: root.refresh()
  }

  // Re-read on a slow tick as well as after our own click, so the bar stays
  // right when the mode is changed from the terminal or the menu.
  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  visible: !vertical
  implicitWidth: visible ? content.implicitWidth + Style.space(16) : 0
  implicitHeight: barSize

  Behavior on implicitWidth {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      id: glyph
      anchors.verticalCenter: parent.verticalCenter
      text: ""
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption
      opacity: root.active ? 1.0 : 0.45

      Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
      }
    }

    Text {
      id: name
      anchors.verticalCenter: parent.verticalCenter
      visible: root.active
      textFormat: Text.PlainText
      text: "Macifier"
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption
      opacity: 0.85
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (!toggleProc.running) toggleProc.running = true
    onEntered: if (root.bar) root.bar.showTooltip(root, root.active
      ? "Macifier is on — click to return to stock Omarchy"
      : "Macifier is off — click to turn on Mac-style defaults")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
