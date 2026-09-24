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
  property var dockApps: []
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
    "keynames":    "Mac key names",
    "cmdkeys":     "Command key shortcuts",
    "windowtitle": "Window name in bar",
    "appswitcher": "⌘Tab switches apps",
    "dock":        "Dock",
    "launchpad":   "Launchpad",
    "gestures":    "Trackpad gestures"
  })
  readonly property var hints: ({
    "scroll":      "Trackpad scrolls the macOS way",
    "capslock":    "Caps Lock works, Compose moves to right ⌘",
    "mediakeys":   "Brightness and volume direct · asks for your password",
    "keynames":    "⌘K says Shift-Command-Return, not SUPER SHIFT + RETURN",
    "cmdkeys":     "⌘A ⌘Z ⌘N ⌘Q … tap Edit to choose",
    "windowtitle": "Show the focused window's name",
    "appswitcher": "Icon bar of apps, not workspaces · ⌘⌥Tab for workspaces",
    "dock":        "Auto-hiding app bar along the bottom · tap Edit to choose",
    "launchpad":   "Every app in a grid · ⌘⌥A, or the dock tile",
    "gestures":    "3 fingers for spaces · up/down for Mission Control and Exposé · 4-finger pinch for Launchpad",
    // The only switch here that reaches outside Macifier: it installs and
    // enables somebody else's plugin. The hint says whose, because a switch
    // that quietly fetches code from GitHub should not look like the nine
    // above it, which only move files around inside this machine.
    "trackpad":    "Pointer speed, tap to click, acceleration · installs David Fano's Trackpad Plus"
  })
  readonly property var order: ["scroll", "capslock", "mediakeys", "keynames", "cmdkeys", "appswitcher", "dock", "launchpad", "gestures", "trackpad", "windowtitle"]

  // Every option the CLI reports — `order` only decides the order, never
  // membership. The panel used to iterate `order` itself, so an option added
  // to the CLI was simply invisible here until someone remembered to add it in
  // two more places. That shipped twice: appswitcher, then launchpad. Anything
  // the CLI knows about and this file does not now lands at the end with the
  // CLI's own description under it, which is wrong-looking rather than absent,
  // and wrong-looking gets fixed.
  readonly property var rows: {
    var out = [], seen = ({}), i
    for (i = 0; i < order.length; i++) {
      if (opts[order[i]] !== undefined) { out.push(order[i]); seen[order[i]] = true }
    }
    for (var k in opts) if (!seen[k]) out.push(k)
    return out
  }

  function hintFor(id) {
    if (hints[id]) return hints[id]
    var o = opts[id]
    return (o && o.description) ? String(o.description) : ""
  }

  function refresh() {
    if (!stateProc.running) stateProc.running = true
    if (!keysProc.running) keysProc.running = true
    if (view === "dock" && !dockProc.running) dockProc.running = true
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
    // The dock's own context menu ends in "Dock Settings…", and the editor it
    // wants is a view of this panel — so the dock summons it the same way a
    // keybinding would.
    function dock(): void { root.view = "dock"; root.open() }
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
    id: dockProc
    command: ["omarchy-macifier", "dock", "apps"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.dockApps = (JSON.parse(text).apps) || [] } catch (e) { }
      }
    }
  }

  Process {
    id: actionProc
    command: ["omarchy-macifier", "status"]
    onExited: root.refresh()
  }

  // Toggling a bar-widget plugin makes the shell rebuild the bar, and this
  // widget is destroyed along with the panel the user was standing in front
  // of. The CLI leaves a mark when that is about to happen; whichever widget
  // is built next asks for it, and puts the panel back.
  //
  // It has to be this way round. Anything the outgoing widget spawned dies
  // with it, and an external timer would have to guess when the rebuild ends.
  // The replacement asking on arrival needs neither.
  Process {
    id: restoreProc
    command: ["omarchy-macifier", "panel", "restore-claim"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (String(text).trim() === "1") { root.view = "main"; root.open() }
      }
    }
  }

  Component.onCompleted: restoreProc.running = true

  Timer {
    interval: 4000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Coming back to a closed panel on the sub-view would be disorienting.
  onOpenedChanged: if (!opened) view = "main"

  // A new page starts at its top, not wherever the last one was left.
  onViewChanged: pageScroll.contentItem.contentY = 0

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
        text: root.preset === "full" ? "MAC Full" : "MAC"
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

  // "There is more below", said the way macOS says it. Overlay scroll bars
  // stay hidden until you scroll, so on their own they give no hint at all;
  // macOS flashes them once when a scrollable view appears, and fades the
  // content into the edge it continues past. Both here: the bar shows for a
  // second when the panel opens or changes page, and each fade shows only
  // while there is content beyond its edge, so the bottom one leaves once you
  // reach the end and the top one arrives once you have scrolled away from it.
  component ScrollHint: Item {
    id: hint
    required property var view
    required property var bar

    readonly property var flick: view.contentItem
    readonly property bool overflows: flick && flick.contentHeight > flick.height + 1
    readonly property color ground: Color.popups.background
    readonly property int fadeSize: Style.space(28)

    function flash() {
      if (!hint.overflows || !hint.view.visible) return
      hint.bar.policy = ScrollBar.AlwaysOn
      flashTimer.restart()
    }

    Timer {
      id: flashTimer
      interval: 1100
      onTriggered: hint.bar.policy = ScrollBar.AsNeeded
    }

    // callLater: the page has to be laid out before it knows it overflows.
    Connections {
      target: root
      function onOpenedChanged() { if (root.opened) Qt.callLater(hint.flash) }
      function onViewChanged() { Qt.callLater(hint.flash) }
    }

    Rectangle {
      anchors { left: parent.left; right: parent.right; top: parent.top }
      height: hint.fadeSize
      opacity: hint.overflows && !hint.flick.atYBeginning ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 150 } }
      gradient: Gradient {
        GradientStop { position: 0.0; color: hint.ground }
        GradientStop { position: 1.0; color: Qt.rgba(hint.ground.r, hint.ground.g, hint.ground.b, 0) }
      }
    }

    Rectangle {
      anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
      height: hint.fadeSize
      opacity: hint.overflows && !hint.flick.atYEnd ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 150 } }
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(hint.ground.r, hint.ground.g, hint.ground.b, 0) }
        GradientStop { position: 1.0; color: hint.ground }
      }
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
      root.view === "main" ? mainCol.implicitHeight
        : (root.view === "dock" ? dockCol.implicitHeight : keysCol.implicitHeight),
      Style.space(520))

    // Every page scrolls when it is taller than the card. The card is capped
    // (and capped again by the screen), and without this whatever did not fit
    // simply spilled out below it — drawn on the transparent window with no
    // card behind it, unreadable and out of reach. The keys and dock lists keep
    // their own inner scroll so their headers stay put; this is the outer one.
    ScrollView {
      id: pageScroll
      anchors.fill: parent
      clip: true
      contentWidth: availableWidth
      contentHeight: root.view === "main" ? mainCol.implicitHeight
        : (root.view === "dock" ? dockCol.implicitHeight : keysCol.implicitHeight)
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: ScrollBar.AsNeeded

      // ---------------------------------------------------------------- main --
      ColumnLayout {
        id: mainCol
        width: pageScroll.availableWidth
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
          model: root.rows
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
                text: root.hintFor(modelData)
                color: Qt.darker(Color.foreground, 1.5)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }

            // Two options have something to drill into.
            Button {
              visible: modelData === "cmdkeys" || modelData === "dock"
              text: "Edit"
              bordered: true
              onClicked: {
                root.view = (modelData === "dock") ? "dock" : "keys"
                root.refresh()
              }
            }

            ToggleSwitch {
              readonly property var entry: root.opts[modelData]
              checked: entry !== undefined && entry.on === true
              interactive: entry !== undefined && entry.available === true
              opacity: interactive ? 1.0 : 0.4
              // --from-panel tells the CLI a panel is open in front of it. It
              // matters for options that enable a bar-widget plugin: the shell
              // rebuilds the bar, this widget is destroyed with it, and the CLI
              // summons the panel back once the replacement exists. Harmless for
              // every other option, which never touches the bar.
              onToggled: root.run(["option", modelData, checked ? "off" : "on", "--from-panel"])
            }
          }
        }

        PanelSeparator { Layout.fillWidth: true }

        // The dock grew a System Settings tile; the panel never learned about it.
        // That matters because the dock is itself an option: turn it off and the
        // settings window has no door left anywhere in the shell, only
        // `omarchy-macifier settings open` in a terminal. The bar widget is the
        // one surface that is always there, so it keeps a way in — the mirror of
        // the dock's own context menu, which ends in "Dock Settings…" and summons
        // this panel.
        //
        // Not a row in Options above: those are toggles the CLI reports, and this
        // is a door, not a switch. The panel closes behind it because the window
        // is a full surface of its own and two settings UIs stacked on each other
        // read as a bug rather than a hand-off.
        Button {
          Layout.fillWidth: true
          text: "System Settings…"
          bordered: true
          onClicked: {
            root.run(["settings", "open"])
            root.close()
          }
        }
      }

      // ---------------------------------------------------------------- keys --
      ColumnLayout {
        id: keysCol
        width: pageScroll.availableWidth
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
        // The frame holds the list and its scroll hint together; the hint
        // has to sit over the list, which a ColumnLayout will not allow.
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(keyList.implicitHeight, Style.space(240))

          ScrollView {
            id: keyScroll
            anchors.fill: parent
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

          ScrollHint { anchors.fill: keyScroll; view: keyScroll; bar: keyScroll.ScrollBar.vertical }
        }
      }

      // ---------------------------------------------------------------- dock --
      ColumnLayout {
        id: dockCol
        width: pageScroll.availableWidth
        visible: root.view === "dock"
        spacing: Style.space(10)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)
          Button { text: "\u2039  Back"; bordered: true; onClicked: root.view = "main" }
          Item { Layout.fillWidth: true }
          Button { text: "Reset"; bordered: true; onClicked: root.run(["dock", "reset"]) }
        }

        PanelSectionHeader { text: "Dock apps"; Layout.fillWidth: true }

        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: "Pinned apps stay on the dock. Anything running shows up anyway, "
              + "with a dot under it."
          color: Qt.darker(Color.foreground, 1.5)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        PanelSeparator { Layout.fillWidth: true }

        // The frame holds the list and its scroll hint together; the hint
        // has to sit over the list, which a ColumnLayout will not allow.
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(dockList.implicitHeight, Style.space(240))

          ScrollView {
            id: dockScroll
            anchors.fill: parent
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
              id: dockList
              width: dockScroll.availableWidth
              spacing: Style.space(10)

              Repeater {
                model: root.dockApps
                delegate: RowLayout {
                  required property var modelData
                  Layout.fillWidth: true
                  spacing: Style.space(8)

                  Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: modelData.name
                    color: Color.foreground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                  }

                  ToggleSwitch {
                    checked: modelData.pinned === true
                    onToggled: root.run(["dock", modelData.id, checked ? "remove" : "add"])
                  }
                }
              }
            }
          }

          ScrollHint { anchors.fill: dockScroll; view: dockScroll; bar: dockScroll.ScrollBar.vertical }
        }
      }
    }

    ScrollHint { anchors.fill: pageScroll; view: pageScroll; bar: pageScroll.ScrollBar.vertical }
  }
}
