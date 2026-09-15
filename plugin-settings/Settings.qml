// Macifier System Settings — one window that answers "where do I change this?"
//
// A macOS System Settings clone in organisation, not in pixels: sidebar of
// panes on the left, rows on the right, search at the top. The point is the
// ordering — a Mac user finds a setting where a Mac puts it — and the tags,
// which say for every row who provides it and, when nobody does, why.
//
// Every row comes from share/settings-inventory.json, read through the CLI so
// this file never learns an install path. Rows can therefore be added,
// retagged or corrected without touching QML, and so without the
// `omarchy restart shell` that every QML edit costs.
//
// Rows tagged `planned` or `notonlinux` are drawn grey and inert, each with a
// one-line reason — the same rule the dock's barred tiles follow, and the rule
// docs/SETTINGS.md sets for the whole window. A greyed row that does not say
// why is just a broken one.
//
// The overlay is a full-screen layer-shell surface, so the compositor will
// never move it. The *card* inside it is ours, so it drags and resizes: a
// System Settings window that cannot be moved would feel wrong, and this is
// the cheapest honest way to get that back.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property bool opened: false

  // --- data ------------------------------------------------------------------
  property var panes: []            // straight from the inventory file
  property int paneIndex: 0
  property string filterText: ""
  property var optionState: ({})    // option name -> bool, for Macifier rows
  property var pluginState: ({})    // plugin id -> "enabled" | "disabled"
  property string loadError: ""

  // --- theme -----------------------------------------------------------------
  // Shares the [menu] surface tokens, like the clipboard and emoji pickers, so
  // a theme that styles the menu styles this window too.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily

  readonly property int contentMargin: Style.spacing.panelPadding
  readonly property int sidebarWidth: Style.space(210)
  readonly property int headerHeight: Math.max(Style.space(40), Style.font.title + Style.spacing.controlPaddingY * 2)
  readonly property int minCardWidth: Style.space(560)
  readonly property int minCardHeight: Style.space(360)

  // --- the card's own geometry -----------------------------------------------
  // Explicit rather than anchored, because anchoring is what would stop it
  // being draggable. `placed` keeps a reopen where the user last left it.
  property real cardX: 0
  property real cardY: 0
  property real cardW: Style.space(860)
  property real cardH: Style.space(620)
  property bool placed: false

  function centreCard() {
    if (!panel.screen) return
    cardW = Math.min(cardW, panel.width - Style.gapsOut * 2)
    cardH = Math.min(cardH, panel.height - Style.gapsOut * 2)
    cardX = Math.round((panel.width - cardW) / 2)
    cardY = Math.round((panel.height - cardH) / 2)
    placed = true
  }

  // Keeps the card reachable after a resolution or scale change: a window
  // parked off the new screen edge would be unrecoverable without a reset.
  function clampCard() {
    var maxX = Math.max(0, panel.width - cardW)
    var maxY = Math.max(0, panel.height - cardH)
    cardX = Math.max(0, Math.min(cardX, maxX))
    cardY = Math.max(0, Math.min(cardY, maxY))
  }

  // --- lifecycle -------------------------------------------------------------
  // The host routes summon/hide/toggle through these. Payload is parsed
  // defensively and may name a pane to land on: `{"pane":"keyboard"}`.
  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") || ({}) }
    catch (e) { payload = ({}) }

    if (typeof payload.pane === "string") selectPaneById(payload.pane)

    // Reopening while already visible refocuses rather than stacking a second
    // surface, and leaves the card where the user put it.
    if (!root.opened) {
      root.opened = true
      root.filterText = ""
      if (!root.placed) Qt.callLater(root.centreCard)
    }
    refresh()
    Qt.callLater(function () { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
    root.filterText = ""
  }

  function toggle() { if (root.opened) close(); else open("{}") }

  function selectPaneById(id) {
    for (var i = 0; i < panes.length; i++) {
      if (panes[i].id === id) { paneIndex = i; return }
    }
  }

  function refresh() {
    if (!inventoryProc.running) inventoryProc.running = true
    if (!statusProc.running) statusProc.running = true
    if (!pluginsProc.running) pluginsProc.running = true
  }

  // What a plugin row should say. A row that offers to install something the
  // user already has is worse than no row: it says we did not look.
  //   "enabled"  it is here and running — nothing to offer
  //   "disabled" it is here but switched off — offer to switch it on
  //   "missing"  offer to install it
  //   "unknown"  we never learned this plugin's id, so we cannot tell; the
  //              row still offers to install, which is the old behaviour
  function pluginStatus(r) {
    if (!r || r.tag !== "plugin") return "unknown"
    if (!r.pluginId) return "unknown"
    var s = pluginState[r.pluginId]
    if (s === "enabled") return "enabled"
    if (s === "disabled") return "disabled"
    return "missing"
  }

  // --- rows ------------------------------------------------------------------
  // With no filter, the selected pane's rows. With one, every matching row from
  // every pane, each carrying its pane's name so the answer to "where does this
  // live?" comes with the result — which is the question the window exists for.
  readonly property var visibleRows: {
    var out = []
    var q = filterText.trim().toLowerCase()

    function matches(r) {
      if (q.length === 0) return true
      return (r.label || "").toLowerCase().indexOf(q) !== -1
        || (r.omarchy || "").toLowerCase().indexOf(q) !== -1
        || (r.note || "").toLowerCase().indexOf(q) !== -1
        || (r.pluginName || "").toLowerCase().indexOf(q) !== -1
    }

    if (q.length === 0) {
      var pane = panes[paneIndex]
      if (!pane) return out
      for (var i = 0; i < pane.rows.length; i++) out.push({ row: pane.rows[i], pane: "" })
      return out
    }

    for (var p = 0; p < panes.length; p++) {
      for (var j = 0; j < panes[p].rows.length; j++) {
        if (matches(panes[p].rows[j])) out.push({ row: panes[p].rows[j], pane: panes[p].name })
      }
    }
    return out
  }

  // --- tags ------------------------------------------------------------------
  function tagLabel(tag) {
    if (tag === "omarchy") return "Omarchy"
    if (tag === "macifier") return "Macifier"
    if (tag === "plugin") return "Plugin"
    if (tag === "planned") return "Planned"
    if (tag === "notonlinux") return "Not on Linux"
    return tag || ""
  }

  function tagColor(tag) {
    if (tag === "macifier") return Color.accent
    if (tag === "omarchy") return foreground
    return Color.muted
  }

  function isGrey(tag) { return tag === "planned" || tag === "notonlinux" }

  function pluginLine(r) {
    var s = pluginStatus(r)
    if (s === "enabled") return "installed"
    if (s === "disabled") return "installed, switched off — click to enable"
    return "click to install"
  }

  // A row acts only if something is there to act on. Grey rows never do —
  // that is the whole contract they carry. An already-running plugin has
  // nothing left to offer either.
  function isActionable(r) {
    if (!r || !r.action || isGrey(r.tag)) return false
    if (r.tag === "plugin" && pluginStatus(r) === "enabled") return false
    return true
  }

  // The state dot on a Macifier row. `undefined` means "this option has no
  // on/off of its own" (magnification, indicators), and draws nothing rather
  // than guessing a value.
  //
  // `status --json` reports each option as an object — {on, available,
  // description} — not a bare boolean. Reading the object itself would be
  // truthy for every option and light every dot.
  function rowOn(r) {
    if (!r || r.tag !== "macifier" || !r.action || !r.action.run) return undefined
    var argv = r.action.run
    if (argv.length < 2 || argv[0] !== "option") return undefined
    var s = optionState[argv[1]]
    if (!s || typeof s.on !== "boolean") return undefined
    return s.on
  }

  function activate(r) {
    if (!isActionable(r)) return
    var a = r.action
    // Installed but switched off: switch it on rather than re-adding it, which
    // would ask the user to reinstall something they already have.
    if (r.tag === "plugin" && pluginStatus(r) === "disabled") {
      run(["omarchy", "plugin", "enable", String(r.pluginId)])
      return
    }
    if (a.run) run(["omarchy-macifier"].concat(a.run))
    else if (a.menu) run(["omarchy", "menu", "summon", String(a.menu)])
    else if (a.plugin) run(["omarchy", "plugin", "add", String(a.plugin), "--enable"])
  }

  function run(argv) {
    if (actionProc.running) return
    actionProc.command = argv
    actionProc.running = true
  }

  // --- processes -------------------------------------------------------------
  Process {
    id: actionProc
    command: ["true"]
    // Whatever just ran may have flipped an option or added a plugin; re-read
    // both rather than assume.
    onExited: if (root.opened) root.refresh()
  }

  // `settings inventory` rather than a hard-coded path: the QML should not know
  // where install.sh puts things, and the same verb guards against an older CLI
  // that would otherwise read `settings` as something else entirely.
  Process {
    id: inventoryProc
    command: ["omarchy-macifier", "settings", "inventory"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var d = JSON.parse(String(text))
          root.panes = d.panes || []
          root.loadError = root.panes.length === 0 ? "The inventory is empty." : ""
          if (root.paneIndex >= root.panes.length) root.paneIndex = 0
        } catch (e) {
          root.panes = []
          root.loadError = "Could not read the settings inventory."
        }
      }
    }
  }

  Process {
    id: pluginsProc
    command: ["omarchy-macifier", "settings", "plugins"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.pluginState = JSON.parse(String(text)).installed || ({}) }
        catch (e) { root.pluginState = ({}) }
      }
    }
  }

  Process {
    id: statusProc
    command: ["omarchy-macifier", "status", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var d = JSON.parse(String(text))
          root.optionState = d.options || d || ({})
        } catch (e) {
          root.optionState = ({})
        }
      }
    }
  }

  IpcHandler {
    target: "local.macifier-settings"
    function open(): void { root.open("{}") }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function pane(name: string): void { root.selectPaneById(name); root.open("{}") }
  }

  // --- the window ------------------------------------------------------------
  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "macifier-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    // Never hold exclusive focus while hidden — it would swallow every key
    // press on the desktop behind us.
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    onWidthChanged: root.clampCard()
    onHeightChanged: root.clampCard()

    Rectangle { anchors.fill: parent; color: root.scrim }

    // Clicking the backdrop closes. The card stops this from reaching here.
    MouseArea { anchors.fill: parent; onClicked: root.close() }

    BorderSurface {
      id: card
      x: root.cardX
      y: root.cardY
      width: root.cardW
      height: root.cardH
      radius: root.cornerRadius
      color: root.background
      borderSpec: root.borderSpec
      padding: 0

      // Swallows backdrop clicks that land on the card.
      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function (event) {
          if (event.key === Qt.Key_Escape) {
            // Escape clears a search first, closes second — so a typo never
            // costs the whole window.
            if (root.filterText.length > 0) root.filterText = ""
            else root.close()
            event.accepted = true
          } else if (event.key === Qt.Key_Down && root.filterText.length === 0) {
            if (root.paneIndex < root.panes.length - 1) root.paneIndex++
            event.accepted = true
          } else if (event.key === Qt.Key_Up && root.filterText.length === 0) {
            if (root.paneIndex > 0) root.paneIndex--
            event.accepted = true
          } else if (event.key === Qt.Key_Backspace) {
            root.filterText = root.filterText.slice(0, -1)
            event.accepted = true
          } else if (event.text && event.text.length === 1
                     && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.filterText += event.text
            event.accepted = true
          }
        }
      }

      // --- title bar: the drag handle -----------------------------------------
      Item {
        id: titleBar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.headerHeight

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.SizeAllCursor
          property real pressX: 0
          property real pressY: 0
          onPressed: function (mouse) { pressX = mouse.x; pressY = mouse.y }
          onPositionChanged: function (mouse) {
            if (!pressed) return
            root.cardX += mouse.x - pressX
            root.cardY += mouse.y - pressY
            root.clampCard()
          }
          onDoubleClicked: root.centreCard()
        }

        Text {
          anchors {
            left: parent.left; leftMargin: root.contentMargin
            verticalCenter: parent.verticalCenter
          }
          text: "System Settings"
          color: root.foreground
          textFormat: Text.PlainText
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        // Search. Typing anywhere in the window lands here — there is no focus
        // to hunt for, which is what a Mac user expects of ⌘F-less search.
        Rectangle {
          id: searchBox
          anchors {
            right: closeButton.left; rightMargin: Style.space(10)
            verticalCenter: parent.verticalCenter
          }
          width: Style.space(200)
          height: Math.max(Style.space(26), Style.font.bodySmall + Style.spacing.controlPaddingY)
          radius: height / 2
          color: root.foreground
          opacity: 0.06
        }

        Text {
          anchors.fill: searchBox
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: root.filterText.length > 0 ? root.filterText : "Search"
          color: root.foreground
          opacity: root.filterText.length > 0 ? 0.9 : 0.35
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Item {
          id: closeButton
          anchors {
            right: parent.right; rightMargin: root.contentMargin
            verticalCenter: parent.verticalCenter
          }
          width: Style.space(22); height: Style.space(22)

          Text {
            anchors.centerIn: parent
            text: "󰅖"
            color: root.foreground
            opacity: closeMouse.containsMouse ? 0.95 : 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.close()
          }
        }

        Rectangle {
          anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
          height: 1
          color: root.foreground
          opacity: 0.12
        }
      }

      // --- sidebar ------------------------------------------------------------
      Item {
        id: sidebar
        anchors {
          top: titleBar.bottom; bottom: parent.bottom; left: parent.left
        }
        width: root.sidebarWidth

        Column {
          anchors.fill: parent
          anchors.topMargin: Style.space(8)
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(2)

          Repeater {
            model: root.panes

            Rectangle {
              required property var modelData
              required property int index

              width: parent.width
              height: Math.max(Style.space(32), Style.font.body + Style.spacing.controlPaddingY * 2)
              radius: root.cornerRadius
              color: index === root.paneIndex ? root.selectedBackground
                                              : (paneMouse.containsMouse ? root.selectedBackground : "transparent")
              opacity: index === root.paneIndex ? 1.0 : (paneMouse.containsMouse ? 0.6 : 1.0)

              Row {
                anchors {
                  left: parent.left; leftMargin: Style.space(10)
                  right: parent.right; rightMargin: Style.space(8)
                  verticalCenter: parent.verticalCenter
                }
                spacing: Style.space(10)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.glyph || ""
                  color: index === root.paneIndex ? root.selectedText : root.foreground
                  opacity: index === root.paneIndex ? 1.0 : 0.7
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.name || ""
                  color: index === root.paneIndex ? root.selectedText : root.foreground
                  opacity: index === root.paneIndex ? 1.0 : 0.8
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }

              MouseArea {
                id: paneMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.paneIndex = index; root.filterText = "" }
              }
            }
          }
        }

        Rectangle {
          anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
          width: 1
          color: root.foreground
          opacity: 0.12
        }
      }

      // --- rows ---------------------------------------------------------------
      Flickable {
        id: rowsView
        anchors {
          top: titleBar.bottom; bottom: parent.bottom
          left: sidebar.right; right: parent.right
        }
        clip: true
        contentHeight: rowsColumn.height + root.contentMargin * 2
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: rowsColumn
          x: root.contentMargin
          y: root.contentMargin
          width: rowsView.width - root.contentMargin * 2
          spacing: Style.space(2)

          Text {
            visible: root.loadError.length > 0
            width: parent.width
            text: root.loadError
            color: root.foreground
            opacity: 0.5
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            visible: root.loadError.length === 0 && root.visibleRows.length === 0
            width: parent.width
            text: "Nothing matches “" + root.filterText + "”."
            color: root.foreground
            opacity: 0.45
            textFormat: Text.PlainText
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Repeater {
            model: root.visibleRows

            Rectangle {
              id: rowItem
              required property var modelData

              readonly property var r: modelData.row
              readonly property bool grey: root.isGrey(r.tag)
              readonly property bool actionable: root.isActionable(r)
              readonly property var onState: root.rowOn(r)

              width: parent.width
              height: rowBody.height + Style.space(14)
              radius: root.cornerRadius
              color: (actionable && rowMouse.containsMouse) ? root.selectedBackground : "transparent"

              Column {
                id: rowBody
                anchors {
                  left: parent.left; leftMargin: Style.space(10)
                  right: tagChip.left; rightMargin: Style.space(10)
                  verticalCenter: parent.verticalCenter
                }
                spacing: Style.space(2)

                // The pane's name, but only while searching — otherwise the
                // sidebar already says it and the line is noise.
                Text {
                  visible: modelData.pane.length > 0
                  width: parent.width
                  text: modelData.pane
                  color: root.foreground
                  opacity: 0.4
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  // The dot carries live state for Macifier's own options, so
                  // the window is never out of step with the CLI.
                  Rectangle {
                    visible: rowItem.onState !== undefined
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(7); height: Style.space(7)
                    radius: width / 2
                    color: rowItem.onState ? Color.accent : root.foreground
                    opacity: rowItem.onState ? 0.95 : 0.22
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: rowItem.r.label || ""
                    color: root.foreground
                    // Grey is the signal: 0.38 is the same value the dock's
                    // barred tiles and planned menu rows use.
                    opacity: rowItem.grey ? 0.38 : 1.0
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                }

                // What Omarchy calls it — the middle column of docs/SETTINGS.md,
                // and the thing that makes a row searchable by either name.
                Text {
                  visible: !!rowItem.r.omarchy && rowItem.r.omarchy !== "—" && !rowItem.grey
                  width: parent.width
                  text: rowItem.r.omarchy || ""
                  color: root.foreground
                  opacity: 0.45
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                // The reason. Mandatory on a grey row, optional elsewhere.
                Text {
                  visible: !!rowItem.r.note
                  width: parent.width
                  text: rowItem.r.phase ? (rowItem.r.phase + " — " + rowItem.r.note) : rowItem.r.note
                  color: root.foreground
                  opacity: 0.3
                  textFormat: Text.PlainText
                  wrapMode: Text.WordWrap
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  visible: rowItem.r.tag === "plugin" && !!rowItem.r.pluginName
                  width: parent.width
                  text: rowItem.r.pluginName + " — " + root.pluginLine(rowItem.r)
                  color: root.foreground
                  opacity: root.pluginStatus(rowItem.r) === "enabled" ? 0.5 : 0.4
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Text {
                id: tagChip
                anchors {
                  right: parent.right; rightMargin: Style.space(10)
                  verticalCenter: parent.verticalCenter
                }
                text: root.tagLabel(rowItem.r.tag)
                color: root.tagColor(rowItem.r.tag)
                opacity: rowItem.grey ? 0.35 : 0.75
                textFormat: Text.PlainText
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                enabled: rowItem.actionable
                hoverEnabled: rowItem.actionable
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activate(rowItem.r)
              }
            }
          }
        }
      }

      // --- resize grip --------------------------------------------------------
      MouseArea {
        anchors { right: parent.right; bottom: parent.bottom }
        width: Style.space(16); height: Style.space(16)
        cursorShape: Qt.SizeFDiagCursor
        property real pressX: 0
        property real pressY: 0
        onPressed: function (mouse) { pressX = mouse.x; pressY = mouse.y }
        onPositionChanged: function (mouse) {
          if (!pressed) return
          root.cardW = Math.max(root.minCardWidth,
                                Math.min(root.cardW + (mouse.x - pressX), panel.width - root.cardX))
          root.cardH = Math.max(root.minCardHeight,
                                Math.min(root.cardH + (mouse.y - pressY), panel.height - root.cardY))
        }

        Text {
          anchors.centerIn: parent
          text: "󰁝"
          rotation: 45
          color: root.foreground
          opacity: 0.25
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
