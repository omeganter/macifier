import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "Magnification.js" as Magnification

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

  // The system trash, not one of ours. Linux already has a freedesktop.org
  // trash and Omarchy leaves it alone; this tile is a view onto it, so the
  // file manager and the dock can never disagree about what is in there.
  property int trashCount: 0
  property bool trashShown: false
  property bool trashAvailable: false
  readonly property bool hasTrash: trashShown && trashAvailable

  // Launchpad sits first, where a Mac keeps it — second only to Finder, which
  // we do not have. Drawn from a glyph rather than an icon theme because it is
  // ours, not an installed application with a .desktop entry to look up.
  // System Settings sits at the end of the apps, where a Mac keeps it — after
  // everything running, before the rule that fences off the stacks and Trash.
  // It wears the same cog it wore as a barred placeholder, so the tile the user
  // has been looking at all along is the one that now opens.
  readonly property string settingsGlyph: ""

  property bool launchpadOn: false
  readonly property string launchpadGlyph: ""

  // Calendar — promaaa's Chronica, not ours. A Mac keeps Calendar in the dock;
  // Chronica is a *bar widget* that replaces the clock and hangs its agenda off
  // itself, so this tile owns nothing and only asks, over the IpcHandler the
  // plugin exposes on `promaa.clock`. Split the way the trash is: `shown` is
  // what the user asked for, `available` is whether Chronica is there to ask.
  // The agenda opens at the bar widget, not above this tile — it is Chronica's
  // popout and it anchors to its own owner.
  property bool calendarShown: false
  property bool calendarAvailable: false
  readonly property bool hasCalendar: calendarShown && calendarAvailable
  readonly property string calendarGlyph: ""

  property int iconSize: Style.space(46)
  property int peek: 3

  // Magnification. The pointer's x inside the icon row, or -1 when it is not
  // over the dock at all — which is the resting state, every icon at 1.0.
  //
  // The wave itself is wdg's, vendored in Magnification.js; see
  // THIRD_PARTY_NOTICES.md. What stays here is our geometry, because our row
  // is not his: ours has separators, barred placeholders and a trash tile, and
  // slots come in two widths.
  property real pointerX: -1
  property real magnification: 1.6
  readonly property real magRadius: iconSize * 3.0

  // Slot widths, duplicated from the delegate because the wave has to know the
  // baseline before a single tile is laid out. Keep the two in step.
  function slotWidth(item) {
    return item && item.kind === "sep" ? Style.space(9) : iconSize + Style.space(8)
  }

  // Centres of every slot in row coordinates, then one scale per slot from the
  // pointer's distance to it, then the offsets that keep the row centred.
  // `extra` is how much wider the magnified row is than the resting one; the
  // card grows by it so the wave never spills past the edge.
  readonly property var magState: {
    var n = items.length
    var scales = [], centres = [], x = 0, gap = Style.space(8)

    for (var i = 0; i < n; i++) {
      var w = slotWidth(items[i])
      centres.push(x + w / 2)
      x += w + gap
    }

    if (pointerX < 0 || n === 0)
      return { scales: [], offsets: [], extra: 0 }

    for (var j = 0; j < n; j++) {
      // Separators do not grow; on the Mac the divider stays put while the
      // icons swell around it.
      scales.push(items[j].kind === "sep"
                  ? 1.0
                  : Magnification.scaleFromDistance(Math.abs(pointerX - centres[j]),
                                                    magnification, magRadius))
    }

    var offsets = Magnification.computeMagnifiedOffsets(scales, iconSize, 0.82)
    return { scales: scales, offsets: offsets, extra: offsets.totalExtra }
  }

  readonly property color background: Color.popups ? Color.popups.background : Color.background
  readonly property color foreground: Color.foreground

  // One entry per running window, not per app, because the context menu needs
  // to list windows and close every one of them.
  readonly property var runningIds: {
    var m = ({})
    for (var i = 0; i < clients.length; i++) m[clients[i].entryId] = true
    return m
  }

  // The overlay contract. Omarchy summons and dismisses an overlay through
  // these two, the way the first-party clipboard and emoji pickers do, and the
  // app switcher next door already did.
  //
  // The dock never needed them to work, because it reveals itself on pointer
  // hover and hides on a timer. But without them nothing *else* can show it —
  // no keybinding, no `omarchy-shell` call, no other plugin — and the dock was
  // the one Macifier surface you could not ask for by name.
  function open(): void { hideTimer.stop(); revealed = true }

  function close(): void {
    hideTimer.stop()
    revealed = false
    pointerX = -1
    closeMenu()
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
    if (launchpadOn) out.push({ kind: "launchpad", id: "__launchpad__" })
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
    // Before System Settings, so the tiles that are ours stay together at the
    // end of the apps rather than splitting around the user's own.
    if (hasCalendar) out.push({ kind: "calendar", id: "__calendar__" })
    // Always present, unlike Launchpad, which is an option the user can turn
    // off. The window is the dock's own settings as much as the system's, so a
    // dock with no way into it would be a dead end.
    out.push({ kind: "settings", id: "__settings__" })
    if (placeholders.length > 0) {
      out.push({ kind: "sep", id: "__sep__" })
      for (i = 0; i < placeholders.length; i++) {
        var p = placeholders[i]
        out.push({ kind: "planned", id: String(p.id), name: String(p.name),
                   glyph: String(p.glyph), phase: String(p.phase), note: String(p.note) })
      }
    }
    // Trash sits last behind its own rule, where macOS keeps it. When the
    // placeholders are hidden that collapses to apps | rule | Trash, which is
    // exactly the Mac arrangement.
    if (hasTrash) {
      out.push({ kind: "sep", id: "__sep_trash__" })
      out.push({ kind: "trash", id: "__trash__" })
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

  // Straight to the overlay rather than through the CLI: there is no state to
  // change, and `omarchy-macifier` would only shell out to this same call.
  function toggleLaunchpad() {
    launchpadToggleProc.command = ["omarchy-shell", "local.macifier-launchpad", "toggle"]
    launchpadToggleProc.running = true
  }

  // Through the CLI rather than straight to `omarchy-shell`, unlike Launchpad:
  // the plugin may have been disabled since the last poll, and the CLI is where
  // that check already lives.
  function toggleCalendar() {
    run(["dock", "calendar", "open"])
  }

  Process { id: focusProc; command: ["true"] }
  Process { id: launchProc; command: ["true"] }
  Process { id: actionProc; command: ["true"] }
  Process { id: launchpadToggleProc; command: ["true"] }
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

  // Same `status` verb guard as the placeholders poll: a CLI older than this
  // file refuses it instead of reading "trash" as an app to pin.
  Process {
    id: trashProc
    command: ["omarchy-macifier", "dock", "trash", "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var d = JSON.parse(text)
          root.trashCount = d.count || 0
          root.trashShown = !!d.shown
          root.trashAvailable = !!d.available
        } catch (e) {
          root.trashShown = false
          root.trashAvailable = false
        }
      }
    }
  }

  // The Launchpad tile is drawn only while the `launchpad` option is on, so the
  // dock never offers a button for a plugin that is disabled. Same `status`
  // verb guard as the two polls above.
  Process {
    id: launchpadProc
    command: ["omarchy-macifier", "dock", "launchpad", "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.launchpadOn = !!JSON.parse(text).on }
        catch (e) { root.launchpadOn = false }
      }
    }
  }

  // Polled rather than read once: Chronica can be installed, enabled or removed
  // while the dock is up, and the tile should come and go without a restart.
  Process {
    id: calendarProc
    command: ["omarchy-macifier", "dock", "calendar", "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var cal = JSON.parse(text)
          root.calendarShown = !!cal.shown
          root.calendarAvailable = !!cal.available
        } catch (e) {
          root.calendarShown = false
          root.calendarAvailable = false
        }
      }
    }
  }

  Timer {
    interval: 2000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: {
      if (!pinsProc.running) pinsProc.running = true
      if (!clientsProc.running) clientsProc.running = true
      if (!placeholdersProc.running) placeholdersProc.running = true
      if (!trashProc.running) trashProc.running = true
      if (!launchpadProc.running) launchpadProc.running = true
      if (!calendarProc.running) calendarProc.running = true
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

  // macOS's Trash menu is two items: Open, and Empty Trash. Emptying is the
  // one irreversible thing the dock can do, so it asks first — as macOS does —
  // by replacing the menu with the question rather than throwing up a dialog.
  function menuForTrash() {
    var rows = [{ kind: "header", label: trashLabel() }]
    rows.push({ kind: "action", label: "Open", args: ["dock", "trash", "open"] })
    if (trashCount > 0)
      rows.push({ kind: "action", label: "Empty Trash…", confirmEmpty: true })
    else
      rows.push({ kind: "planned", label: "Empty Trash", note: "Already empty" })
    return rows
  }

  function menuForEmptyConfirm() {
    var n = trashCount
    return [
      { kind: "header", label: "Permanently erase " + n + (n === 1 ? " item?" : " items?") },
      { kind: "planned", label: "This cannot be undone", note: "Restoring is only possible before emptying" },
      { kind: "sep" },
      { kind: "action", label: "Empty Trash", args: ["dock", "trash", "empty"] },
      { kind: "action", label: "Cancel", cancel: true }
    ]
  }

  function trashLabel() {
    if (trashCount === 0) return "Trash — empty"
    return "Trash — " + trashCount + (trashCount === 1 ? " item" : " items")
  }

  // Dropping files on the Trash deletes them, the way the Mac dock's does.
  // Whether a layer-shell surface is offered a drag from the file manager is
  // the compositor's call, so this is best-effort: if the drop never arrives
  // the tile still opens and empties.
  function trashUrls(urls) {
    if (!urls || urls.length === 0) return
    var args = ["trash"]
    for (var i = 0; i < urls.length; i++) args.push(String(urls[i]))
    dropProc.command = ["gio"].concat(args)
    dropProc.running = true
  }

  Process { id: dropProc; command: ["true"] }

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
      { kind: "check", label: "Show Trash", checked: trashShown,
        args: ["dock", "trash", "toggle"] },
      { kind: "action", label: "Dock Settings…", args: ["panel", "dock"] }
    ]
  }

  function invoke(row) {
    if (row.kind === "planned" || row.kind === "header" || row.kind === "sep") return
    // The two rows that stay inside the menu rather than closing it.
    if (row.confirmEmpty !== undefined) { menuRows = menuForEmptyConfirm(); return }
    if (row.cancel !== undefined) { closeMenu(); return }
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

    // Room for a fully magnified icon. A layer-shell surface is a hard edge —
    // anything taller than this is not clipped prettily, it is simply not
    // drawn — so the tallest the wave can ever get has to fit.
    implicitHeight: Math.round(root.iconSize * root.magnification) + Style.space(34)

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
        //
        // The wave settles here rather than when the pointer leaves the outer
        // area, because crossing from that area onto a tile also counts as
        // leaving it — resetting there would blink every icon back to rest on
        // the way in.
        onTriggered: if (!root.menuOpen) { root.revealed = false; root.pointerX = -1 }
      }

      BorderSurface {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(8)
        // Grows with the wave. The offsets are centred on the row, so the card
        // widening symmetrically around its own centre keeps them aligned.
        width: iconRow.implicitWidth + Style.space(20) + root.magState.extra
        height: root.iconSize + Style.space(18)
        radius: Style.cornerRadius > 0 ? Style.space(16) : 0
        color: root.background
        borderSpec: Border.surfaceSpec("popups", "border",
          Color.popups ? Color.popups.border : root.foreground, 2)

        // Declared before the row so tiles keep their own clicks; this catches
        // only the card's empty margins.
        MouseArea {
          id: cardMouse
          anchors.fill: parent
          acceptedButtons: Qt.RightButton
          onClicked: root.openMenu(root.menuForDock(),
                                   card.mapToItem(null, card.width / 2, 0).x)

          // Only reached where no tile sits above: the card's own margins, and
          // the separators, whose MouseArea is disabled. Without this the wave
          // would freeze in place there instead of following the pointer out.
          hoverEnabled: true
          onEntered: hideTimer.stop()
          onPositionChanged: root.pointerX =
            card.mapToItem(iconRow, cardMouse.mouseX, 0).x
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
              required property int index

              // Transform-only, so the Row's layout never enters the pointer's
              // hot path: the slot keeps its width and the icon moves inside it.
              readonly property real magScale: root.magState.scales[index] || 1.0
              readonly property real magOffset: root.magState.offsets[index] || 0
              transform: Translate { x: tile.magOffset }

              readonly property bool isSep: modelData.kind === "sep"
              readonly property bool isPlanned: modelData.kind === "planned"
              readonly property bool isTrash: modelData.kind === "trash"
              readonly property bool isLaunchpad: modelData.kind === "launchpad"
              readonly property bool isSettings: modelData.kind === "settings"
              readonly property bool isCalendar: modelData.kind === "calendar"
              // The tiles that are ours rather than an installed app: drawn
              // from a glyph, no .desktop entry to look up, no windows to list.
              // Calendar is here too — the plugin behind it is someone else's,
              // but it has no .desktop entry and no window either.
              readonly property bool isGlyph: isLaunchpad || isSettings || isCalendar
              readonly property bool isRunning: !isSep && !isPlanned && !isTrash && !isGlyph
                                                && !!root.runningIds[modelData.id]

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
                visible: !tile.isSep && !tile.isPlanned && !tile.isGlyph
                anchors.centerIn: parent
                width: root.iconSize; height: root.iconSize
                sourceSize.width: 96; sourceSize.height: 96
                fillMode: Image.PreserveAspectFit
                // The icon theme already ships both states under the standard
                // freedesktop names, so a full bin looks full in whatever theme
                // the user runs — no artwork of ours to keep in step.
                source: tile.isTrash
                          ? Quickshell.iconPath(root.trashCount > 0 ? "user-trash-full"
                                                                   : "user-trash", true)
                          : ((tile.isSep || tile.isPlanned || tile.isGlyph)
                               ? "" : root.iconFor(modelData.id))
                smooth: true

                // Grow upward out of the dock, as on the Mac: the icon's foot
                // stays on the floor next to its running dot, which would drift
                // if we scaled about the centre.
                transformOrigin: Item.Bottom
                scale: tile.magScale * (trashDrop.containsDrag ? 1.18 : 1.0)

                // Short, because this now tracks the pointer rather than
                // answering a hover. At 120ms the wave lags behind the cursor.
                Behavior on scale { NumberAnimation { duration: 55; easing.type: Easing.OutCubic } }
              }

              // Dropping files here deletes them, as on the Mac dock. Enabled
              // only on the trash tile; harmless if the compositor never offers
              // the drag to a layer-shell surface.
              DropArea {
                id: trashDrop
                anchors.fill: parent
                enabled: tile.isTrash
                onDropped: function (drop) {
                  if (drop.hasUrls) { root.trashUrls(drop.urls); drop.accept() }
                }
              }

              // The drop-target ring, so it is obvious where the file is going.
              Rectangle {
                visible: tile.isTrash && trashDrop.containsDrag
                anchors.centerIn: parent
                width: root.iconSize + Style.space(6)
                height: width
                radius: Style.space(10)
                color: "transparent"
                border.width: Math.max(1, Style.space(2))
                border.color: root.foreground
                opacity: 0.6
              }

              // The placeholder tile: the glyph greyed back, inside a dashed-ish
              // reserved square, with a bar struck through it. Grey alone reads
              // as "disabled, try again later"; the bar reads as "not a thing
              // yet", which is the truth.
              // Launchpad and System Settings. The same rounded square as a
              // barred tile, but at full strength and with no bar — these are
              // the glyph tiles that actually do something, and they have to
              // read that way sitting next to the ones that do not.
              Item {
                id: glyphTile
                visible: tile.isGlyph
                anchors.centerIn: parent
                width: root.iconSize; height: root.iconSize

                // Grows with the wave like every other icon, from the foot, so
                // it does not sit still while its neighbours magnify.
                transformOrigin: Item.Bottom
                scale: tile.magScale
                Behavior on scale { NumberAnimation { duration: 55; easing.type: Easing.OutCubic } }

                Rectangle {
                  anchors.centerIn: parent
                  width: root.iconSize * 0.86
                  height: width
                  radius: Style.space(10)
                  color: root.foreground
                  opacity: tileMouse.containsMouse ? 0.18 : 0.12
                  Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: tile.isLaunchpad ? root.launchpadGlyph
                        : (tile.isSettings ? root.settingsGlyph
                        : (tile.isCalendar ? root.calendarGlyph : ""))
                  color: root.foreground
                  font.family: Style.font.family
                  font.pixelSize: Math.round(root.iconSize * 0.46)
                }
              }

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

                // Mapped rather than added, so the tile's own magnification
                // offset cannot feed back into the pointer position that
                // produced it. The cursor does not move when the icons do.
                function track() {
                  root.pointerX = tile.mapToItem(iconRow, tileMouse.mouseX, 0).x
                }
                onEntered: { hideTimer.stop(); track() }
                onPositionChanged: track()
                onClicked: function (mouse) {
                  var x = tile.mapToItem(null, tile.width / 2, 0).x
                  if (mouse.button === Qt.RightButton) {
                    // A glyph tile has no windows to list and cannot be
                    // unpinned, so the app menu would be three disabled rows.
                    // Left-click is the whole interaction.
                    if (tile.isGlyph) return
                    root.openMenu(tile.isTrash ? root.menuForTrash()
                                  : (tile.isPlanned ? root.menuForPlanned(modelData)
                                                    : root.menuForApp(modelData.id)), x)
                  } else if (tile.isLaunchpad) {
                    root.toggleLaunchpad()
                  } else if (tile.isCalendar) {
                    root.toggleCalendar()
                  } else if (tile.isSettings) {
                    root.run(["settings", "open"])
                  } else if (tile.isTrash) {
                    root.run(["dock", "trash", "open"])
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
                text: tile.isLaunchpad ? "Launchpad"
                      : (tile.isCalendar ? "Calendar"
                      : (tile.isSettings ? "System Settings"
                      : (tile.isTrash ? root.trashLabel()
                      : (tile.isPlanned ? modelData.name + " · not built yet"
                                        : (tile.isSep ? "" : root.nameFor(modelData.id))))))
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
