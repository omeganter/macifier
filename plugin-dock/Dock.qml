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
// what you chose, plus what is open right now. After a separator come the
// placeholders: Mac staples we have not built, drawn grey and barred.
//
// Two-finger click (right click) opens a context menu, as on macOS — one menu
// for a tile, another for the dock itself. Anything we cannot do yet is listed
// but greyed, with the reason, rather than omitted: the same honesty the
// barred tiles are for, and the same rule docs/SETTINGS.md sets for its rows.
Item {
  id: root

  property bool revealed: false
  property var pinned: []
  property var clients: []
  property var placeholders: []
  property int iconSize: Style.space(46)
  property int peek: 3

  readonly property color background: Color.popups ? Color.popups.background : Color.background
  readonly property color foreground: Color.foreground

  // One entry per running window, not per app, because the context menu needs
  // to list windows and close every one of them.
  readonly property var runningIds: {
    var m = ({})
    for (var i = 0; i < clients.length; i++) m[clients[i].entryId] = true
    return m
  }

  function windowsFor(id) {
    var out = []
    for (var i = 0; i < clients.length; i++)
      if (clients[i].entryId === id) out.push(clients[i])
    return out
  }

  function isPinned(id) {
    for (var i = 0; i < pinned.length; i++) if (String(pinned[i]) === id) return true
    return false
  }

  readonly property var items: {
    var out = [], seen = ({}), i
    for (i = 0; i < pinned.length; i++) {
      var id = String(pinned[i])
      if (!id || seen[id]) continue
      seen[id] = true
      out.push({ kind: "app", id: id, pinned: true })
    }
    for (i = 0; i < clients.length; i++) {
      var eid = clients[i].entryId
      if (!eid || seen[eid]) continue
      seen[eid] = true
      out.push({ kind: "app", id: eid, pinned: false })
    }
    if (placeholders.length > 0) {
      out.push({ kind: "sep", id: "__sep__" })
      for (i = 0; i < placeholders.length; i++) {
        var p = placeholders[i]
        out.push({ kind: "planned", id: String(p.id), name: String(p.name),
                   glyph: String(p.glyph), phase: String(p.phase), note: String(p.note) })
      }
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
    var wins = windowsFor(id)
    if (wins.length > 0) { focusWindow(wins[0].address); return }
    launch(id)
  }

  function launch(id) {
    var e = entryById(id)
    if (e && e.execute) { e.execute(); return }
    launchProc.command = ["gtk-launch", id]
    launchProc.running = true
  }

  // Omarchy's hyprctl parses `dispatch` as Lua, so the plain
  // `focuswindow address:0x…` form is a syntax error, not a no-op.
  function focusWindow(address) {
    focusProc.command = ["hyprctl", "dispatch",
      "hl.dsp.focus({ window = 'address:" + address + "' })"]
    focusProc.running = true
  }

  // macOS quits an application; Hyprland has no application, so closing every
  // window of it is the closest honest equivalent. Closes run one at a time —
  // a queue rather than a shell loop, so no address ever goes through quoting.
  property var closeQueue: []

  function quitApp(id) {
    var wins = windowsFor(id), q = []
    for (var i = 0; i < wins.length; i++) q.push(wins[i].address)
    closeQueue = q
    closeNext()
  }

  function closeNext() {
    if (closeQueue.length === 0) return
    var addr = closeQueue[0]
    closeQueue = closeQueue.slice(1)
    closeProc.command = ["hyprctl", "dispatch",
      "hl.dsp.window.close({ window = 'address:" + addr + "' })"]
    closeProc.running = true
  }

  function run(args) {
    actionProc.command = ["omarchy-macifier"].concat(args)
    actionProc.running = true
  }

  Process { id: focusProc; command: ["true"] }
  Process { id: launchProc; command: ["true"] }
  Process { id: actionProc; command: ["true"] }
  Process {
    id: closeProc
    command: ["true"]
    onExited: root.closeNext()
  }

  Component.onCompleted: agentProc.running = true

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

  // The explicit `list` verb matters: a CLI older than this file would read a
  // bare `dock placeholders` as "pin an app named placeholders". With the verb,
  // every older version refuses and writes nothing.
  Process {
    id: placeholdersProc
    command: ["omarchy-macifier", "dock", "placeholders", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var d = JSON.parse(text)
          root.placeholders = d.placeholders || []
        } catch (e) {
          root.placeholders = []
        }
      }
    }
  }

  // Window classes rarely match desktop ids exactly, so resolve each running
  // class to an entry the same way the switcher does. Resolution is per class
  // and cached across the windows sharing it; the list itself keeps every
  // window, which is what the context menu needs.
  Process {
    id: clientsProc
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector {
      onStreamFinished: {
        var list = []
        try { list = JSON.parse(text) } catch (e) { return }
        var resolved = ({})
        var out = []
        var vals = (DesktopEntries.applications && DesktopEntries.applications.values) || []
        for (var i = 0; i < list.length; i++) {
          var c = list[i]
          if (!c || !c.class) continue
          var lc = String(c.class).toLowerCase()
          if (resolved[lc] === undefined) {
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
            resolved[lc] = found || String(c.class)
          }
          out.push({ entryId: resolved[lc], address: String(c.address),
                     title: String(c.title || ""), cls: String(c.class) })
        }
        root.clients = out
      }
    }
  }

  Timer {
    interval: 2000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: {
      if (!pinsProc.running) pinsProc.running = true
      if (!clientsProc.running) clientsProc.running = true
      if (!placeholdersProc.running) placeholdersProc.running = true
    }
  }

  // --- the context menu ------------------------------------------------------
  //
  // Rows are plain data so the delegate stays one component. `kind` decides how
  // a row draws and whether it acts:
  //   header   the app's name, as macOS titles its dock menus
  //   window   one open window, focused on click
  //   action   does something now
  //   check    does something now, and shows whether it is currently on
  //   planned  greyed, inert, and says why — the barred tile in menu form
  //   sep      a rule

  property bool menuOpen: false
  property var menuRows: []
  property real menuAnchorX: 0

  // Sized from the text rather than from the laid-out rows. Letting the card
  // measure its children would close a loop — card width feeds the column,
  // which feeds each row, whose implicit width would feed the card back. An
  // estimate from character counts is coarser but terminates, and the rows
  // elide, so being a few pixels out costs nothing.
  readonly property int menuWidth: {
    var longest = 0
    for (var i = 0; i < menuRows.length; i++) {
      var r = menuRows[i]
      longest = Math.max(longest, String(r.label || "").length)
      if (r.note) longest = Math.max(longest, String(r.note).length * 0.9)
    }
    var px = Math.round(longest * Style.font.bodySmall * 0.62) + Style.space(40)
    return Math.max(Style.space(200), Math.min(Style.space(380), px))
  }

  function openMenu(rows, anchorX) {
    menuRows = rows
    menuAnchorX = anchorX
    menuOpen = true
    revealed = true
  }

  function closeMenu() { menuOpen = false; menuRows = [] }

  function menuForApp(id) {
    var rows = [], wins = windowsFor(id), i
    rows.push({ kind: "header", label: nameFor(id) })
    if (wins.length > 0) {
      // macOS lists the open windows by name at the top of the menu. A window
      // with no title gets the app's name rather than an empty row.
      for (i = 0; i < wins.length && i < 8; i++) {
        var t = wins[i].title.length > 0 ? wins[i].title : nameFor(id)
        rows.push({ kind: "window", label: t, address: wins[i].address })
      }
      rows.push({ kind: "sep" })
    }
    rows.push({ kind: "check", label: "Keep in Dock", checked: isPinned(id),
                args: ["dock", id, "toggle"] })
    rows.push({ kind: "planned", label: "Open at Login",
                note: "Login Items — nothing in Omarchy owns this yet (P3)" })
    rows.push({ kind: "sep" })
    rows.push({ kind: "planned", label: "Hide",
                note: "Hyprland has no minimise; needs a scratchpad (P3)" })
    if (wins.length > 0)
      rows.push({ kind: "action", label: wins.length > 1 ? "Quit (" + wins.length + " windows)" : "Quit",
                  quit: id })
    else
      rows.push({ kind: "action", label: "Open", open: id })
    return rows
  }

  function menuForPlanned(item) {
    return [
      { kind: "header", label: item.name },
      { kind: "planned", label: item.note, note: "Not built yet — " + item.phase },
      { kind: "sep" },
      { kind: "action", label: "Hide placeholders", args: ["dock", "placeholders", "off"] }
    ]
  }

  // macOS puts this menu on the dock's separator. We have no separator to spare,
  // so it is the dock background — every empty pixel of the card.
  function menuForDock() {
    return [
      { kind: "header", label: "Dock" },
      { kind: "planned", label: "Turn Hiding Off", note: "Always auto-hides today (P1)" },
      { kind: "planned", label: "Turn Magnification On", note: "P1 — or adopt a published plugin" },
      { kind: "planned", label: "Position on Screen", note: "Bottom only today (P1)" },
      { kind: "planned", label: "Minimize using", note: "No minimise in Hyprland (P3)" },
      { kind: "sep" },
      { kind: "check", label: "Show placeholders", checked: placeholders.length > 0,
        args: ["dock", "placeholders", "toggle"] },
      { kind: "action", label: "Dock Settings…", args: ["panel", "dock"] }
    ]
  }

  function invoke(row) {
    if (row.kind === "planned" || row.kind === "header" || row.kind === "sep") return
    if (row.address !== undefined) focusWindow(row.address)
    else if (row.quit !== undefined) quitApp(row.quit)
    else if (row.open !== undefined) launch(row.open)
    else if (row.args !== undefined) run(row.args)
    closeMenu()
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
        // An open menu is a conversation with the dock. Sliding away mid-click
        // would take the menu with it.
        onTriggered: if (!root.menuOpen) root.revealed = false
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

        // Declared before the row so tiles keep their own clicks; this catches
        // only the card's empty margins.
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.RightButton
          onClicked: root.openMenu(root.menuForDock(),
                                   card.mapToItem(null, card.width / 2, 0).x)
        }

        Row {
          id: iconRow
          anchors.centerIn: parent
          spacing: Style.space(8)

          Repeater {
            model: root.items
            delegate: Item {
              id: tile
              required property var modelData

              readonly property bool isSep: modelData.kind === "sep"
              readonly property bool isPlanned: modelData.kind === "planned"
              readonly property bool isRunning: !isSep && !isPlanned && !!root.runningIds[modelData.id]

              width: isSep ? Style.space(9) : root.iconSize + Style.space(8)
              height: root.iconSize + Style.space(8)

              // macOS divides the apps from the stacks. Ours divides what works
              // from what does not yet.
              Rectangle {
                visible: tile.isSep
                anchors.centerIn: parent
                width: Style.space(1)
                height: root.iconSize * 0.72
                color: root.foreground
                opacity: 0.22
              }

              Image {
                id: img
                visible: !tile.isSep && !tile.isPlanned
                anchors.centerIn: parent
                width: root.iconSize; height: root.iconSize
                sourceSize.width: 96; sourceSize.height: 96
                fillMode: Image.PreserveAspectFit
                source: (tile.isSep || tile.isPlanned) ? "" : root.iconFor(modelData.id)
                smooth: true
                scale: tileMouse.containsMouse ? 1.18 : 1.0
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
              }

              // The placeholder tile: the glyph greyed back, inside a dashed-ish
              // reserved square, with a bar struck through it. Grey alone reads
              // as "disabled, try again later"; the bar reads as "not a thing
              // yet", which is the truth.
              Item {
                id: planned
                visible: tile.isPlanned
                anchors.centerIn: parent
                width: root.iconSize; height: root.iconSize
                opacity: tileMouse.containsMouse ? 0.95 : 0.7
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Rectangle {
                  anchors.centerIn: parent
                  width: root.iconSize * 0.86
                  height: width
                  radius: Style.space(10)
                  color: root.foreground
                  opacity: 0.06
                  border.width: Math.max(1, Style.space(1))
                  border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.28)
                }

                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: tile.isPlanned ? modelData.glyph : ""
                  color: root.foreground
                  opacity: 0.45
                  font.family: Style.font.family
                  font.pixelSize: Math.round(root.iconSize * 0.46)
                }

                // The bar.
                Rectangle {
                  anchors.centerIn: parent
                  width: root.iconSize * 0.92
                  height: Math.max(2, Style.space(2))
                  radius: height / 2
                  rotation: -45
                  color: root.foreground
                  opacity: 0.55
                }
              }

              // The running dot, as on macOS.
              Rectangle {
                visible: tile.isRunning
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: Style.space(4); height: Style.space(4); radius: width / 2
                color: root.foreground
                opacity: 0.75
              }

              MouseArea {
                id: tileMouse
                anchors.fill: parent
                enabled: !tile.isSep
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: tile.isPlanned ? Qt.ArrowCursor : Qt.PointingHandCursor
                onEntered: hideTimer.stop()
                onClicked: function (mouse) {
                  var x = tile.mapToItem(null, tile.width / 2, 0).x
                  if (mouse.button === Qt.RightButton) {
                    root.openMenu(tile.isPlanned ? root.menuForPlanned(modelData)
                                                 : root.menuForApp(modelData.id), x)
                  } else if (tile.isPlanned) {
                    // Left-clicking a thing that does not exist should say so,
                    // not silently do nothing.
                    root.openMenu(root.menuForPlanned(modelData), x)
                  } else {
                    root.activate(modelData.id)
                  }
                }
              }

              Text {
                visible: tileMouse.containsMouse && !tile.isSep
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: Style.space(4)
                textFormat: Text.PlainText
                text: tile.isPlanned ? modelData.name + " · not built yet"
                                     : (tile.isSep ? "" : root.nameFor(modelData.id))
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

  // The menu is its own window rather than part of the dock's. The dock is a
  // short bottom strip with a pointer mask cut to the card; a menu living
  // inside it would have to grow both, and would still be clipped. A separate
  // full-screen overlay also gets what a menu needs for free: click-anywhere to
  // dismiss, and Escape.
  PanelWindow {
    id: menuWindow
    visible: root.menuOpen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "macifier-dock-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: root.closeMenu()
    }

    Item {
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) { root.closeMenu(); event.accepted = true }
      }

      BorderSurface {
        id: menuCard
        width: root.menuWidth
        height: menuColumn.implicitHeight + Style.space(14)

        // Centred on the tile, then pushed back inside the screen — a menu off
        // the edge is worse than a menu not quite under the cursor.
        x: Math.max(Style.space(8),
             Math.min(parent.width - width - Style.space(8),
                      root.menuAnchorX - width / 2))
        y: parent.height - height - (root.iconSize + Style.space(40))

        radius: Style.cornerRadius > 0 ? Style.space(14) : 0
        color: root.background
        borderSpec: Border.surfaceSpec("popups", "border",
          Color.popups ? Color.popups.border : root.foreground, 2)

        Column {
          id: menuColumn
          anchors.centerIn: parent
          width: parent.width - Style.space(14)
          spacing: 0

          Repeater {
            model: root.menuRows
            delegate: Item {
              id: row
              required property var modelData

              readonly property bool isSep: modelData.kind === "sep"
              readonly property bool isHeader: modelData.kind === "header"
              readonly property bool isPlanned: modelData.kind === "planned"
              readonly property bool actionable: !isSep && !isHeader && !isPlanned

              width: menuColumn.width
              height: isSep ? Style.space(9)
                            : (isPlanned && modelData.note ? Style.space(34) : Style.space(24))

              Rectangle {
                visible: row.isSep
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: Style.space(1)
                color: root.foreground
                opacity: 0.18
              }

              Rectangle {
                visible: rowMouse.containsMouse && row.actionable
                anchors.fill: parent
                anchors.margins: Style.space(1)
                radius: Style.space(6)
                color: root.foreground
                opacity: 0.12
              }

              // The tick sits in its own column so labels line up whether or
              // not a row has one.
              Text {
                visible: row.modelData.kind === "check"
                anchors.left: parent.left
                anchors.leftMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: row.modelData.checked ? "✓" : ""
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }

              Column {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(20)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                  visible: !row.isSep
                  width: parent.width
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  text: row.modelData.label || ""
                  color: root.foreground
                  opacity: row.isHeader ? 0.55 : (row.isPlanned ? 0.38 : 1.0)
                  font.family: Style.font.family
                  font.pixelSize: row.isHeader ? Style.font.caption : Style.font.bodySmall
                  font.bold: row.isHeader
                }

                // The reason, always — the same rule docs/SETTINGS.md sets for
                // its "Not on Linux" rows. A greyed row that does not say why
                // is just a broken one.
                Text {
                  visible: row.isPlanned && !!row.modelData.note
                  width: parent.width
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  text: row.modelData.note || ""
                  color: root.foreground
                  opacity: 0.3
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                enabled: row.actionable
                hoverEnabled: row.actionable
                cursorShape: Qt.PointingHandCursor
                onClicked: root.invoke(row.modelData)
              }
            }
          }
        }
      }
    }
  }
}
