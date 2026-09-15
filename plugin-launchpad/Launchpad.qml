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

  // Filled from the window, so the grid adapts to the display instead of
  // assuming the 7x5 a 16:10 Mac happens to use.
  property int columns: 7
  property int rows: 5
  readonly property int perPage: Math.max(1, columns * rows)

  readonly property color foreground: Color.foreground

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

  function typed(ch) {
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

    onWidthChanged: root.columns = Math.max(4, Math.min(9, Math.floor((width - Style.space(160)) / cell)))
    onHeightChanged: root.rows = Math.max(3, Math.min(6, Math.floor((height - Style.space(260)) / cell)))

    // The scrim. macOS blurs the desktop behind Launchpad; Hyprland can blur a
    // layer surface, but only if the user has blur on, so this has to read
    // correctly as a plain dim as well.
    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.55)
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

      Column {
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

          Repeater {
            model: root.shown.slice(root.page * root.perPage, (root.page + 1) * root.perPage)

            delegate: Item {
              id: tile
              required property var modelData
              required property int index

              readonly property int absolute: root.page * root.perPage + index
              readonly property bool selected: absolute === root.index

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

                Image {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: Style.space(64)
                  height: Style.space(64)
                  fillMode: Image.PreserveAspectFit
                  sourceSize.width: 128
                  sourceSize.height: 128
                  source: root.iconFor(tile.modelData)
                  smooth: true
                }

                Text {
                  width: panel.cell - Style.space(16)
                  horizontalAlignment: Text.AlignHCenter
                  textFormat: Text.PlainText
                  text: tile.modelData.name
                  color: root.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.small
                  elide: Text.ElideRight
                  maximumLineCount: 2
                  wrapMode: Text.WordWrap
                }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: root.launchAt(tile.absolute)
                onEntered: root.index = tile.absolute
                hoverEnabled: true
              }
            }
          }
        }

        // Page dots. Hidden on a single page, because one dot tells you
        // nothing and still costs a row of space.
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(8)
          visible: root.pageCount > 1

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

        // Only ever seen while filtering, so it names the query rather than
        // saying "no results" into the void.
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
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
