import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

// Macifier dock — the bottom strip of favourite apps.
//
// Pinned apps come first in the order the user arranged them, then anything
// running that is not pinned, so the dock shows the same thing macOS does:
// what you chose, plus what is open right now.
Item {
  id: root

  property bool revealed: false
  property var pinned: []
  property var running: ({})
  property int iconSize: Style.space(46)
  property int peek: 3

  readonly property color background: Color.popups ? Color.popups.background : Color.background
  readonly property color foreground: Color.foreground

  readonly property var items: {
    var out = [], seen = ({}), i
    for (i = 0; i < pinned.length; i++) {
      var id = String(pinned[i])
      if (!id || seen[id]) continue
      seen[id] = true
      out.push({ id: id, pinned: true })
    }
    for (var cls in running) {
      var eid = running[cls].entryId
      if (!eid || seen[eid]) continue
      seen[eid] = true
      out.push({ id: eid, pinned: false })
    }
    return out
  }

  function entryById(id) {
    var vals = (DesktopEntries.applications && DesktopEntries.applications.values) || []
    var lc = String(id || "").toLowerCase()
    for (var i = 0; i < vals.length; i++) {
      var e = vals[i]
      if (String(e.id || "").toLowerCase().replace(/\.desktop$/, "") === lc) return e
    }
    return null
  }


  // Omarchy ships icons for the coding agents but no desktop entry, so agent
  // windows fall back to a generic cog. Resolve the user's chosen agent once
  // and use its own artwork instead.
  property string agentIcon: ""
  property string agentName: ""

  Process {
    id: agentProc
    command: ["omarchy-default-agent"]
    stdout: StdioCollector {
      onStreamFinished: {
        var a = String(text).trim()
        if (a.length === 0) return
        root.agentName = a.charAt(0).toUpperCase() + a.substring(1)
        root.agentIcon = "file:///usr/share/omarchy/shell/plugins/agents/assets/" + a + ".svg"
      }
    }
  }

  // org.omarchy.agent is always an agent. org.omarchy.terminal is Omarchy's
  // general-purpose terminal, but the agent is launched into it on first run
  // and then keeps it for the session, so it is an agent window far more often
  // than not — a transient package-install window borrowing the icon for a few
  // seconds is a smaller cost than a permanently wrong one.
  function isAgentClass(cls) {
    var lc = String(cls || "").toLowerCase()
    return lc === "org.omarchy.agent" || lc === "org.omarchy.terminal"
  }

  function iconFor(id) {
    if (isAgentClass(id) && agentIcon.length > 0) return agentIcon
    var e = entryById(id)
    if (e) {
      var p = Quickshell.iconPath(e.icon, true)
      if (p && p.length > 0) return p
    }
    var d = Quickshell.iconPath(String(id).toLowerCase(), true)
    return (d && d.length > 0) ? d : Quickshell.iconPath("application-x-executable", true)
  }

  function nameFor(id) {
    if (isAgentClass(id) && agentName.length > 0) return agentName
    var e = entryById(id)
    return e && e.name ? String(e.name) : String(id)
  }

  // A running app is raised, never launched twice — the macOS behaviour, and
  // the reason the dock is not just a launcher.
  function activate(id) {
    for (var cls in running) {
      if (running[cls].entryId === id) {
        focusProc.command = ["hyprctl", "dispatch",
          "hl.dsp.focus({ window = 'address:" + running[cls].address + "' })"]
        focusProc.running = true
        return
      }
    }
    var e = entryById(id)
    if (e && e.execute) { e.execute(); return }
    launchProc.command = ["gtk-launch", id]
    launchProc.running = true
  }

  Process { id: focusProc; command: ["true"] }

  Component.onCompleted: agentProc.running = true
  Process { id: launchProc; command: ["true"] }

  Process {
    id: pinsProc
    command: ["omarchy-macifier", "dock", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        var out = [], lines = String(text).split("\n")
        for (var i = 0; i < lines.length; i++) {
          var v = lines[i].trim()
          if (v.length > 0) out.push(v)
        }
        root.pinned = out
      }
    }
  }

  // Window classes rarely match desktop ids exactly, so resolve each running
  // class to an entry the same way the switcher does.
  Process {
    id: clientsProc
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector {
      onStreamFinished: {
        var list = []
        try { list = JSON.parse(text) } catch (e) { return }
        var map = ({})
        var vals = (DesktopEntries.applications && DesktopEntries.applications.values) || []
        for (var i = 0; i < list.length; i++) {
          var c = list[i]
          if (!c || !c.class) continue
          var lc = String(c.class).toLowerCase()
          if (map[lc]) continue
          var tail = lc.indexOf(".") >= 0 ? lc.substring(lc.lastIndexOf(".") + 1) : lc
          var host = ""
          if (lc.indexOf("chrome-") === 0) {
            host = lc.substring(7)
            var cut = host.indexOf("__")
            if (cut > 0) host = host.substring(0, cut)
          }
          var found = ""
          for (var j = 0; j < vals.length; j++) {
            var e = vals[j]
            var id = String(e.id || "").replace(/\.desktop$/, "")
            var idl = id.toLowerCase()
            var sc = String(e.startupClass || "").toLowerCase()
            if (sc === lc || idl === lc) { found = id; break }
            if (!found && idl === tail) found = id
            if (!found && host.length > 0 &&
                String(e.execString || e.command || "").toLowerCase().indexOf(host) >= 0) found = id
          }
          // No desktop entry is not a reason to be absent from the dock — the
          // agent windows are exactly that case. Fall back to the class as the
          // key so they still get a tile.
          map[lc] = { entryId: found || String(c.class), address: String(c.address) }
        }
        root.running = map
      }
    }
  }

  Timer {
    interval: 2000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: {
      if (!pinsProc.running) pinsProc.running = true
      if (!clientsProc.running) clientsProc.running = true
    }
  }

  // Hiding parks the dock just past the screen edge rather than unmapping it,
  // the same trick Omarchy's bar uses: the surface and scene graph stay alive,
  // so revealing is a margin change instead of a rebuild.
  PanelWindow {
    id: dockWindow
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "macifier-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { bottom: true; left: true; right: true }
    implicitHeight: root.iconSize + Style.space(34)

    margins.bottom: root.revealed ? 0 : -(implicitHeight - root.peek)
    Behavior on margins.bottom {
      NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    // Only the dock itself takes pointer events. Without a mask the full-width
    // strip would swallow clicks meant for whatever is behind it.
    mask: Region { item: hoverArea }

    MouseArea {
      id: hoverArea
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      width: Math.max(card.width, Style.space(120))
      height: parent.height
      hoverEnabled: true
      onEntered: { hideTimer.stop(); root.revealed = true }
      onExited: hideTimer.restart()

      Timer {
        id: hideTimer
        interval: 450
        onTriggered: root.revealed = false
      }

      BorderSurface {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(8)
        width: iconRow.implicitWidth + Style.space(20)
        height: root.iconSize + Style.space(18)
        radius: Style.cornerRadius > 0 ? Style.space(16) : 0
        color: root.background
        borderSpec: Border.surfaceSpec("popups", "border",
          Color.popups ? Color.popups.border : root.foreground, 2)

        Row {
          id: iconRow
          anchors.centerIn: parent
          spacing: Style.space(8)

          Repeater {
            model: root.items
            delegate: Item {
              required property var modelData
              width: root.iconSize + Style.space(8)
              height: root.iconSize + Style.space(8)

              readonly property bool isRunning: {
                for (var cls in root.running)
                  if (root.running[cls].entryId === modelData.id) return true
                return false
              }

              Image {
                id: img
                anchors.centerIn: parent
                width: root.iconSize; height: root.iconSize
                sourceSize.width: 96; sourceSize.height: 96
                fillMode: Image.PreserveAspectFit
                source: root.iconFor(modelData.id)
                smooth: true
                scale: tileMouse.containsMouse ? 1.18 : 1.0
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
              }

              // The running dot, as on macOS.
              Rectangle {
                visible: isRunning
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: Style.space(4); height: Style.space(4); radius: width / 2
                color: root.foreground
                opacity: 0.75
              }

              MouseArea {
                id: tileMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activate(modelData.id)
                onEntered: hideTimer.stop()
              }

              Text {
                visible: tileMouse.containsMouse
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: Style.space(4)
                textFormat: Text.PlainText
                text: root.nameFor(modelData.id)
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }
        }
      }
    }
  }
}
