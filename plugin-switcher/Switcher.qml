import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

// Macifier app switcher — Cmd+Tab over applications, not workspaces.
//
// Grouped by application rather than by window, ordered most-recently-used,
// shown as an icon bar. Hold Cmd, tap Tab to walk it, release Cmd to switch.
//
// Release detection was the open question. Hyprland's modifier-release bind
// fires only when no other bind consumed the chord during the hold, which Tab
// always does — so the release is read here instead, from the overlay's own
// exclusive keyboard focus, where the event survives.
Item {
  id: root

  property bool opened: false
  property var apps: []
  property int index: 0
  property int pendingStep: 0
  property double lastAdvance: 0

  readonly property color background: Color.popups ? Color.popups.background : Color.background
  readonly property color foreground: Color.foreground

  function advance(step) {
    // Hyprland's bind and the overlay's own key handler can both deliver one
    // press. Collapse anything arriving within a frame or two into one step.
    var now = Date.now()
    if (now - lastAdvance < 70) return
    lastAdvance = now

    if (!opened) {
      pendingStep = step
      if (!clientsProc.running) clientsProc.running = true
      return
    }
    if (apps.length === 0) return
    index = (index + step + apps.length) % apps.length
  }

  function commit() {
    if (opened && apps.length > 0 && index >= 0 && index < apps.length) {
      // Omarchy's hyprctl parses `dispatch` as Lua, so the plain
      // `focuswindow address:0x…` form is a syntax error, not a no-op.
      focusProc.command = ["hyprctl", "dispatch",
        "hl.dsp.focus({ window = 'address:" + apps[index].address + "' })"]
      focusProc.running = true
    }
    close()
  }

  function close() { opened = false; pendingStep = 0 }

  // Window classes and desktop-entry ids agree far less often than you would
  // hope, so try the conventions in turn rather than assuming one.
  //
  //   chromium                     -> chromium.desktop            (id)
  //   org.gnome.Nautilus           -> org.gnome.Nautilus.desktop  (id)
  //   foot                         -> StartupWMClass=foot
  //   chrome-discord.com__...      -> Discord.desktop             (host in Exec)
  //   org.omarchy.terminal         -> no entry at all
  function entryFor(cls) {
    var lc = String(cls || "").toLowerCase()
    if (lc.length === 0) return null
    var vals = (DesktopEntries.applications && DesktopEntries.applications.values) || []
    var tail = lc.indexOf(".") >= 0 ? lc.substring(lc.lastIndexOf(".") + 1) : lc

    // A Chromium web app encodes its site in the class: chrome-<host>__<path>.
    var host = ""
    if (lc.indexOf("chrome-") === 0) {
      host = lc.substring(7)
      var cut = host.indexOf("__")
      if (cut > 0) host = host.substring(0, cut)
    }

    var byId = null, byTail = null, byHost = null
    for (var i = 0; i < vals.length; i++) {
      var e = vals[i]
      var id = String(e.id || "").toLowerCase().replace(/\.desktop$/, "")
      var sc = String(e.startupClass || "").toLowerCase()
      if (sc.length > 0 && sc === lc) return e
      if (id === lc) byId = byId || e
      if (id === tail) byTail = byTail || e
      if (host.length > 0) {
        var ex = String(e.execString || e.command || "").toLowerCase()
        if (ex.indexOf(host) >= 0) byHost = byHost || e
      }
    }
    return byId || byHost || byTail || null
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

  function iconFor(cls) {
    if (isAgentClass(cls) && agentIcon.length > 0) return agentIcon
    var e = entryFor(cls)
    if (e) {
      var p = Quickshell.iconPath(e.icon, true)
      if (p && p.length > 0) return p
    }
    var direct = Quickshell.iconPath(String(cls || "").toLowerCase(), true)
    return (direct && direct.length > 0) ? direct : Quickshell.iconPath("application-x-executable", true)
  }

  // A Mac names the app, not its window class. Fall back to the readable half
  // of a reverse-DNS class rather than showing "org.omarchy.terminal".
  function nameFor(cls) {
    if (isAgentClass(cls) && agentName.length > 0) return agentName
    var e = entryFor(cls)
    if (e && e.name) return String(e.name)
    var v = String(cls || "")
    if (v.indexOf(".") >= 0) v = v.substring(v.lastIndexOf(".") + 1)
    if (v.indexOf("-") >= 0) v = v.substring(0, v.indexOf("-"))
    return v.length > 0 ? v.charAt(0).toUpperCase() + v.substring(1) : "Unknown"
  }

  Process {
    id: clientsProc
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector {
      onStreamFinished: {
        var list = []
        try { list = JSON.parse(text) } catch (e) { return }

        // One tile per application. focusHistoryID counts up from the focused
        // window, so the lowest value in a group is how recently that app was
        // last touched — which is the order a Mac shows them in.
        var byClass = ({})
        for (var i = 0; i < list.length; i++) {
          var c = list[i]
          if (!c || !c.class || c.workspace === undefined) continue
          if (String(c.workspace.name || "").indexOf("special:") === 0) continue
          var k = String(c.class)
          var h = (c.focusHistoryID === undefined) ? 9999 : c.focusHistoryID
          if (!byClass[k] || h < byClass[k].h) {
            byClass[k] = { cls: k, title: String(c.title || k), address: String(c.address), h: h }
          }
        }
        var arr = []
        for (var key in byClass) arr.push(byClass[key])
        arr.sort(function(a, b) { return a.h - b.h })
        root.apps = arr

        if (root.pendingStep !== 0) {
          // Opening on the second entry is what makes a single Cmd+Tab flip to
          // the previous app, the way it does on a Mac.
          root.index = arr.length > 1 ? ((root.pendingStep > 0 ? 1 : arr.length - 1)) : 0
          root.pendingStep = 0
          root.opened = true
        }
      }
    }
  }

  Process { id: focusProc; command: ["true"] }

  Component.onCompleted: agentProc.running = true

  IpcHandler {
    target: "local.macifier-switcher"
    function next(): void { root.advance(1) }
    function prev(): void { root.advance(-1) }
    function cancel(): void { root.close() }
    function commit(): void { root.commit() }
    function open(): void { root.advance(1) }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "macifier-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
        else if (event.key === Qt.Key_Tab) {
          root.advance((event.modifiers & Qt.ShiftModifier) ? -1 : 1)
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.commit(); event.accepted = true
        }
      }

      // The Mac gesture: letting go of Cmd is what commits.
      Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R) {
          root.commit(); event.accepted = true
        }
      }

      BorderSurface {
        anchors.centerIn: parent
        width: Math.min(iconRow.implicitWidth + Style.space(32), parent.width - Style.space(80))
        height: iconRow.implicitHeight + Style.space(52)
        radius: Style.cornerRadius > 0 ? Style.space(18) : 0
        color: root.background
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups ? Color.popups.border : root.foreground, 2)

        Column {
          anchors.centerIn: parent
          spacing: Style.space(10)

          Row {
            id: iconRow
            spacing: Style.space(10)
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
              model: root.apps
              delegate: Item {
                required property var modelData
                required property int index
                width: Style.space(64); height: Style.space(64)

                Rectangle {
                  anchors.fill: parent
                  radius: Style.space(12)
                  color: index === root.index ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                }

                Image {
                  anchors.centerIn: parent
                  width: Style.space(46); height: Style.space(46)
                  fillMode: Image.PreserveAspectFit
                  sourceSize.width: 96; sourceSize.height: 96
                  source: root.iconFor(modelData.cls)
                  smooth: true
                }
              }
            }
          }

          // The selected app's name, the way macOS labels the highlighted tile.
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: (root.apps.length > root.index && root.index >= 0) ? root.nameFor(root.apps[root.index].cls) : ""
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }
      }
    }
  }
}
