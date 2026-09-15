import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

// Macifier Launchpad — every installed application, in a grid, full screen.
//
// The one Mac staple with nothing to adopt. Fifteen docks and a dozen Mission
// Controls exist for Omarchy; Launchpad has none published, so this is a build
// rather than a recommendation (docs/SETTINGS.md §8).
//
// It is also the cheapest of the big Mac surfaces to get right, because every
// hard part was already solved next door: the dock resolves .desktop icons and
// launches entries, and the switcher proved an overlay can hold exclusive
// keyboard focus. What is left is layout and paging.
//
// Deliberately not a fuzzy launcher. Omarchy's menu and Spotlight both already
// do search-first; Launchpad's whole point is that you *look* rather than type,
// so the grid is the feature and the filter is the fallback.
Item {
  id: root

  property bool opened: false
  property var allApps: []
  property string query: ""
  property int index: 0
  property int page: 0

  // The selection square means "Enter launches this", so it only appears
  // once the keyboard is actually in play. Showing it from the moment
  // Launchpad opens marks an app nobody chose, and a Mac shows nothing
  // until you arrow or type either.
  property bool keyboardNav: false

  // Filled from the window, so the grid adapts to the display instead of
  // assuming the 7x5 a 16:10 Mac happens to use.
  property int columns: 7
  property int rows: 5
  readonly property int perPage: Math.max(1, columns * rows)

  readonly property color foreground: Color.foreground
  readonly property color background: Color.popups ? Color.popups.background : Color.background

  // Reading allApps and query inside the function is what makes this re-run
  // when either changes; QML tracks property reads during evaluation.
  readonly property var shown: root.filterApps()
  readonly property int pageCount: Math.max(1, Math.ceil(shown.length / perPage))

  function filterApps() {
    var q = String(query).trim().toLowerCase()
    if (q.length === 0) return allApps
    var out = []
    for (var i = 0; i < allApps.length; i++) {
      var a = allApps[i]
      // Match the name first and the id second: someone typing "files" means
      // the name, someone typing "nautilus" means the entry.
      if (a.name.toLowerCase().indexOf(q) >= 0 || a.id.toLowerCase().indexOf(q) >= 0) out.push(a)
    }
    return out
  }

  // Every visible application, once, sorted by name. NoDisplay entries are the
  // ones a desktop is explicitly asked not to show — MIME handlers, per-app
  // helpers — and a grid of them is what makes most Linux app menus unusable.
  function loadApps() {
    var vals = (DesktopEntries.applications && DesktopEntries.applications.values) || []
    var seen = ({})
    var out = []
    for (var i = 0; i < vals.length; i++) {
      var e = vals[i]
      if (!e || e.noDisplay) continue
      var id = String(e.id || "").replace(/\.desktop$/, "")
      if (id.length === 0 || seen[id]) continue
      seen[id] = true
      out.push({ id: id, name: String(e.name || id), entry: e })
    }
    out.sort(function(a, b) { return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1 })
    root.allApps = out
  }

  function iconFor(app) {
    if (app && app.entry) {
      var p = Quickshell.iconPath(app.entry.icon, true)
      if (p && p.length > 0) return p
    }
    var d = Quickshell.iconPath(String(app ? app.id : "").toLowerCase(), true)
    return (d && d.length > 0) ? d : Quickshell.iconPath("application-x-executable", true)
  }

  function open() {
    loadApps()
    query = ""
    index = 0
    page = 0
    keyboardNav = false
    opened = true
  }

  function close() { opened = false }
  function toggle() { if (opened) close(); else open() }

  function launchAt(i) {
    var list = shown
    if (i < 0 || i >= list.length) return
    var a = list[i]
    // Same two-step the dock uses: the entry knows how to start itself, and
    // gtk-launch is the fallback for entries Quickshell could not model.
    if (a.entry && a.entry.execute) a.entry.execute()
    else { launchProc.command = ["gtk-launch", a.id]; launchProc.running = true }
    close()
  }

  // Selection moves across the whole filtered list, not within a page, so
  // walking off the right edge of one page lands on the left of the next —
  // which is what makes the arrow keys feel continuous rather than modal.
  function move(delta) {
    var n = shown.length
    if (n === 0) return
    keyboardNav = true
    var next = index + delta
    if (next < 0) next = 0
    if (next > n - 1) next = n - 1
    index = next
    page = Math.floor(index / perPage)
  }

  function setPage(p) {
    if (p < 0 || p > pageCount - 1) return
    page = p
    // Keep the selection on the page being looked at, or the highlight sits
    // somewhere the user cannot see and Enter launches a surprise.
    if (Math.floor(index / perPage) !== page) index = page * perPage
  }

  // --- two-finger swipe ------------------------------------------------------
  //
  // A two-finger swipe is not a gesture and cannot be bound like one. libinput
  // reports two fingers as scroll axis events and only three or more as a swipe
  // gesture, which is why Omarchy's own gesture config only ever speaks of
  // `fingers = 3` and why no Hyprland bind can catch this. The overlay has to
  // read it as a wheel, so it does.
  //
  // A trackpad sends a long stream of small deltas rather than one event, so a
  // single swipe has to be accumulated to a threshold and then locked out
  // briefly. Without the lockout one swipe flies through every page.
  property double swipeAccum: 0
  property double lastTurn: 0

  readonly property int swipeThreshold: 220   // eighths of a degree
  readonly property int swipeCooldownMs: 320

  function swiped(dx, dy) {
    if (pageCount < 2) return
    // The dominant axis, so a slightly diagonal swipe still counts and a
    // vertical one is not simply ignored — on a wide grid people swipe both
    // ways and nothing happening reads as broken.
    var d = Math.abs(dx) >= Math.abs(dy) ? dx : dy
    if (d === 0) return

    var now = Date.now()
    if (now - lastTurn < swipeCooldownMs) return

    // Direction reversing mid-swipe means a new intent, not a continuation.
    if ((d > 0) !== (swipeAccum > 0)) swipeAccum = 0
    swipeAccum += d

    if (Math.abs(swipeAccum) < swipeThreshold) return
    // One line to flip if this comes out backwards on your trackpad: the sign
    // here is the whole mapping.
    setPage(page + (swipeAccum > 0 ? 1 : -1))
    swipeAccum = 0
    lastTurn = now
  }

  function typed(ch) {
    keyboardNav = true
    query += ch
    index = 0
    page = 0
  }

  function backspace() {
    if (query.length === 0) return
    query = query.substring(0, query.length - 1)
    index = 0
    page = 0
  }

  Process { id: launchProc; command: ["true"] }

  IpcHandler {
    target: "local.macifier-launchpad"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "macifier-launchpad"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    // Cell width carries the icon plus its label; 132 is the smallest that
    // fits two lines of a long application name without clipping.
    readonly property int cell: Style.space(132)

    // Leaves room for the card's padding and its margin from the screen edge,
    // so the grid never pushes the surface wider than the display.
    onWidthChanged: root.columns = Math.max(4, Math.min(9, Math.floor((width - Style.space(240)) / cell)))
    onHeightChanged: root.rows = Math.max(3, Math.min(6, Math.floor((height - Style.space(340)) / cell)))

    // The scrim. macOS blurs the desktop behind Launchpad; Hyprland can blur a
    // layer surface, but only if the user has blur on, so this has to read
    // correctly as a plain dim as well.
    //
    // 0.72 rather than a gentler dim because of what the card is worth against
    // it. On a dark theme the popup background is near-black and so is a dimmed
    // dark wallpaper: measured here, 0.55 put rgb(26,27,38) against
    // rgb(12,12,17), a contrast ratio of 1.14:1, so the window read as a
    // hairline outline rather than a surface. Contrast compresses badly at the
    // dark end, so the scrim has to do the work the colours cannot.
    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.72)
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem

      // Anywhere in the overlay, not just over the grid: on a Mac the swipe
      // works wherever the pointer happens to be sitting.
      WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
          // pixelDelta is what a trackpad actually reports; angleDelta is the
          // mouse-wheel equivalent and the fallback. Scale the pixel figure so
          // one threshold serves both.
          var dx = event.pixelDelta.x !== 0 ? event.pixelDelta.x * 6 : event.angleDelta.x
          var dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y * 6 : event.angleDelta.y
          root.swiped(dx, dy)
        }
      }

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          // Two-stage, as on a Mac: the first Escape clears what you typed,
          // the second closes. Closing on the first would throw away a search
          // the user is still reading the results of.
          if (root.query.length > 0) root.query = ""
          else root.close()
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.launchAt(root.index); event.accepted = true
        } else if (event.key === Qt.Key_Backspace) {
          root.backspace(); event.accepted = true
        } else if (event.key === Qt.Key_Right) {
          root.move(1); event.accepted = true
        } else if (event.key === Qt.Key_Left) {
          root.move(-1); event.accepted = true
        } else if (event.key === Qt.Key_Down) {
          root.move(root.columns); event.accepted = true
        } else if (event.key === Qt.Key_Up) {
          root.move(-root.columns); event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
          root.setPage(root.page + 1); event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
          root.setPage(root.page - 1); event.accepted = true
        } else if (event.text && event.text.length === 1 && event.text >= " ") {
          root.typed(event.text); event.accepted = true
        }
      }

      // The surface the grid sits on. Without it the icons float directly on
      // the scrim, and on a dark theme a dark icon over a dimmed dark desktop
      // has nothing to sit against — you see the wallpaper through the gaps
      // rather than a thing you are choosing from. Same popup background and
      // hairline the switcher and the dock already use, so all three Macifier
      // surfaces are recognisably one family in any theme.
      BorderSurface {
        id: card
        anchors.centerIn: parent
        width: Math.min(content.implicitWidth + Style.space(64), parent.width - Style.space(80))
        height: Math.min(content.implicitHeight + Style.space(64), parent.height - Style.space(80))
        radius: Style.cornerRadius > 0 ? Style.space(22) : 0
        color: root.background
        borderSpec: Border.surfaceSpec("popups", "border",
          Color.popups ? Color.popups.border : root.foreground, 2)

        // Clicks inside the card are not clicks outside it. Without this they
        // fall through to the scrim's MouseArea and close Launchpad, so any
        // miss between two icons would dismiss it.
        MouseArea { anchors.fill: parent }

        Column {
          id: content
          anchors.centerIn: parent
          spacing: Style.space(28)

          // The search field. Not focusable on its own — every keystroke is
          // already being read by the key catcher, so this only ever reports.
          // A second focus target would mean two places a key could land.
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(320)
            height: Style.space(40)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.14)

            Row {
              anchors.centerIn: parent
              spacing: Style.space(8)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                opacity: 0.7
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: root.query.length > 0 ? root.query : "Search"
                color: root.foreground
                opacity: root.query.length > 0 ? 1.0 : 0.55
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
            }
          }

          // The grid itself. One page at a time: slicing the filtered list is
          // cheaper and far simpler than a flickable holding every application,
          // and paging is the interaction the Mac actually offers.
          Grid {
            id: grid
            anchors.horizontalCenter: parent.horizontalCenter
            columns: root.columns
            spacing: Style.space(10)

            // Sized to a whole page, not to this page's contents. A short last
            // page would otherwise shrink the card under you — the window
            // jumps as you turn to it and jumps back when you leave. macOS
            // keeps the grid the same size and lets the last page be sparse,
            // and it is right: the surface you are navigating should not move
            // while you navigate it. The same applies while filtering, where
            // every keystroke would otherwise resize the window.
            width: root.columns * panel.cell + (root.columns - 1) * spacing
            height: root.rows * panel.cell + (root.rows - 1) * spacing

            Repeater {
              model: root.shown.slice(root.page * root.perPage, (root.page + 1) * root.perPage)

              delegate: Item {
                id: tile
                required property var modelData
                required property int index

                readonly property int absolute: root.page * root.perPage + index
                readonly property bool selected: root.keyboardNav && absolute === root.index

                width: panel.cell
                height: panel.cell

                Rectangle {
                  anchors.fill: parent
                  anchors.margins: Style.space(6)
                  radius: Style.space(16)
                  color: tile.selected ? Qt.rgba(1, 1, 1, 0.18)
                                       : (hover.hovered ? Qt.rgba(1, 1, 1, 0.09) : "transparent")
                }

                HoverHandler { id: hover }

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(8)

                  // A plate under every icon. macOS needs none because every
                  // Mac icon ships its own filled artwork; a Linux icon theme
                  // is a mix, and the flat monochrome outlines in it — the
                  // Avahi browsers, HDAJackRetask — disappear into a dark card
                  // completely. The plate is what they sit on. It is faint
                  // enough that a full-bleed icon like Chromium or Discord
                  // still reads as itself rather than as a tile.
                  Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Style.space(72)
                    height: Style.space(72)

                    Rectangle {
                      anchors.centerIn: parent
                      width: Style.space(68)
                      height: width
                      radius: Style.space(18)
                      color: root.foreground
                      opacity: 0.07
                    }

                    Image {
                      anchors.centerIn: parent
                      width: Style.space(64)
                      height: Style.space(64)
                      fillMode: Image.PreserveAspectFit
                      sourceSize.width: 128
                      sourceSize.height: 128
                      source: root.iconFor(tile.modelData)
                      smooth: true
                    }
                  }

                  Text {
                    width: panel.cell - Style.space(16)
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
                    text: tile.modelData.name
                    color: root.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                  }
                }

                // Hovering deliberately does NOT move the selection. It used
                // to, and the selection then stuck to whatever tile the pointer
                // last crossed on its way to the search field or the page dots
                // — a highlight sitting on an app the pointer had long left.
                // A Mac does not do this either: the highlight is the keyboard's
                // and the pointer has its own, fainter one.
                MouseArea {
                  anchors.fill: parent
                  onClicked: root.launchAt(tile.absolute)
                  hoverEnabled: true
                }
              }
            }
          }

          // Page dots. A single dot tells you nothing, so on one page they go
          // invisible — but they keep their space rather than being removed.
          // Dropping the row shrinks the card the instant a filter narrows the
          // results to one page, which is the same jump the fixed grid above
          // exists to prevent, except it would fire on every keystroke.
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(8)
            opacity: root.pageCount > 1 ? 1 : 0

            Repeater {
              model: root.pageCount
              delegate: Rectangle {
                required property int index
                width: Style.space(8)
                height: Style.space(8)
                radius: width / 2
                color: root.foreground
                opacity: index === root.page ? 0.9 : 0.35

                MouseArea {
                  anchors.fill: parent
                  onClicked: root.setPage(index)
                }
              }
            }
          }

        }

        // Only ever seen while filtering, so it names the query rather than
        // saying "no results" into the void. Centred over the grid rather than
        // placed under it: as a row in the column it would add its own height
        // the moment it appeared, growing the card exactly when the user is
        // typing and least wants it moving.
        Text {
          // Centred on the card, not on the grid: the grid is a child of the
          // column, so it is not a sibling of this and cannot be anchored to.
          anchors.centerIn: parent
          visible: root.shown.length === 0
          textFormat: Text.PlainText
          text: "Nothing matches “" + root.query + "”"
          color: root.foreground
          opacity: 0.7
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }
    }
  }
}
