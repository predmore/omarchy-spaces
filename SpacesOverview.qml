import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root
  property var shell: null
  property var manifest: null
  property bool opened: false
  property bool gestureEnabled: settings.gesturesEnabled
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"
  property var settings: Model.settings(settingsFile.text())
  property bool spaceFocus: false
  property bool keyboardMode: false
  property var activeRail: null
  property var monitor: null
  property string monitorName: ""
  property int openingWorkspace: 1
  property int baseWorkspace: 0
  property int selectedSpace: 0
  property int selectedIndex: 0
  property real pagePosition: 0
  property bool initializing: false
  property bool swiping: false
  property real swipeStart: 0
  property real swipeDx: 0
  property real swipeTime: 0
  property real swipeVelocity: 0
  property bool hoverLocked: true
  property real pointerX: -1
  property real pointerY: -1
  property int hoveredSpace: -1
  property var offsets: ({})
  property var selections: ({})
  property var visibleAddresses: []
  property var windows: []
  property string wallpaper: ""
  property string cutoutData: cutoutFile.text()
  readonly property int safeTopInset: Model.safeTopInset(cutoutData, panel.targetMonitor ? panel.targetMonitor.lastIpcObject : null, Commons.Style.bar.notchHeight)
  readonly property var spaces: Model.spaces(windows, baseWorkspace, settings.workspaceCount)
  readonly property int selectedWorkspace: spaces[selectedSpace] ? spaces[selectedSpace].id : openingWorkspace
  readonly property var shownWindows: spaces[selectedSpace] ? spaces[selectedSpace].windows : []
  readonly property color foreground: Commons.Color.foreground
  readonly property int margin: Commons.Style.space(40)
  property string tooltipTitle: ""
  property real tooltipX: 0
  property real tooltipY: 0
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function refresh() {
    if (!opened) return;
    var workspace = selectedWorkspace;
    var address = shownWindows[selectedIndex] ? shownWindows[selectedIndex].address : "";
    windows = Model.merge(windows, Hyprland.toplevels.values, monitorName);
    selectedSpace = Math.max(0, spaces.findIndex(function(s) { return s.id === workspace; }));
    if (!swiping) pagePosition = selectedSpace;
    var index = shownWindows.findIndex(function(w) { return w.address === address; });
    selectedIndex = index >= 0 ? index : Model.next(selectedIndex, 0, shownWindows.length);
  }
  function open(payload) {
    if (opened) return;
    initializing = true;
    monitor = Hyprland.focusedMonitor;
    monitorName = monitor ? monitor.name : "";
    openingWorkspace = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1;
    baseWorkspace = settings.workspaceBase === null ? Model.baseForMonitor(workspaceMap.text(), monitorName, openingWorkspace) : settings.workspaceBase;
    windows = Model.merge([], Hyprland.toplevels.values, monitorName);
    selectedSpace = Math.max(0, spaces.findIndex(function(s) { return s.id === openingWorkspace; }));
    pagePosition = selectedSpace;
    var active = ToplevelManager.activeToplevel;
    selectedIndex = Math.max(0, shownWindows.findIndex(function(w) { return w.wayland && w.wayland === active; }));
    offsets = ({}); selections = ({}); visibleAddresses = []; tooltipTitle = ""; hoverLocked = true; pointerX = -1; pointerY = -1;
    hoveredSpace = -1; swiping = false; spaceFocus = false; keyboardMode = false;
    opened = true;
    wallpaperPath.running = true;
    Qt.callLater(function() { initializing = false; keys.forceActiveFocus(); ensureSelection(); updateVisible(); });
    Hyprland.refreshToplevels();
  }
  function close() {
    opened = false; swiping = false; hoverDelay.stop(); hoveredSpace = -1;
    tooltipTitle = ""; windows = [];
  }
  function dismiss() {
    close();
    if (shell && typeof shell.hide === "function") shell.hide("predmore.spaces");
  }
  function activateSelection() {
    updateVisible();
    var target = shownWindows[selectedIndex];
    if (target && visibleAddresses.map(Model.address).indexOf(Model.address(target.address)) < 0)
      target = shownWindows.find(function(w) { return visibleAddresses.map(Model.address).indexOf(Model.address(w.address)) >= 0; });
    activate(target);
  }
  function activate(target) {
    if (!target) { commitSpace(selectedSpace); return; }
    var source = target.wayland;
    var address = Model.address(target.address);
    dismiss();
    if (source) Qt.callLater(function() { source.activate(); });
    else if (/^0x[0-9a-fA-F]+$/.test(address))
      Qt.callLater(function() { Hyprland.dispatch('hl.dsp.focus({ window = "address:' + address + '" })'); });
  }
  function commitSpace(index) {
    var space = spaces[index];
    if (!space) return;
    var id = space.id;
    dismiss();
    Qt.callLater(function() { Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })'); });
  }
  function preview(index, lockHover) {
    if (!opened) return;
    hoverDelay.stop();
    if (lockHover) hoverLocked = true;
    index = Model.clamp(index, 0, spaces.length - 1);
    if (index !== selectedSpace) {
      rememberSelection(); selectedSpace = index; restoreSelection();
    }
    pagePosition = selectedSpace; tooltipTitle = ""; updateVisible();
    keys.forceActiveFocus();
  }
  function rememberSelection() {
    var next = Object.assign({}, selections);
    next[String(selectedWorkspace)] = shownWindows[selectedIndex] ? Model.address(shownWindows[selectedIndex].address) : "";
    selections = next;
  }
  function restoreSelection() {
    var address = selections[String(selectedWorkspace)];
    selectedIndex = Math.max(0, shownWindows.findIndex(function(w) { return Model.address(w.address) === address; }));
  }
  function selectVisible() {
    if (!opened || swiping) return;
    updateVisible();
    var visible = visibleAddresses.map(Model.address);
    var target = shownWindows[selectedIndex];
    if (target && visible.indexOf(Model.address(target.address)) < 0) {
      selectedIndex = Math.max(0, shownWindows.findIndex(function(w) { return visible.indexOf(Model.address(w.address)) >= 0; }));
      rememberSelection();
    }
  }
  function updateVisible() {
    var rail = pages.itemAt(selectedSpace); activeRail = rail; visibleAddresses = rail ? rail.visibleAddresses : [];
  }
  function filterWorkspace(id) {
    var index = spaces.findIndex(function(s) { return s.id === id; });
    if (index >= 0) preview(index, true);
  }
  function select(delta) {
    hoverLocked = true; hoverDelay.stop();
    selectedIndex = Model.next(selectedIndex, delta, shownWindows.length);
    rememberSelection();
    tooltipTitle = ""; ensureSelection();
  }
  function ensureSelection() {
    var rail = pages.itemAt(selectedSpace);
    if (rail) rail.ensureIndex(selectedIndex);
  }
  function pointerMoved(index, x, y) {
    if (pointerX < 0) { pointerX = x; pointerY = y; return; }
    if (Math.abs(x - pointerX) + Math.abs(y - pointerY) < 2) return;
    pointerX = x; pointerY = y;
    hoverLocked = false; spaceFocus = false; keyboardMode = false;
    if (!swiping && index !== selectedSpace) { hoveredSpace = index; hoverDelay.restart(); }
  }
  function swipe(phase, dx, time, cancelled) {
    if (!opened || !isFinite(dx) || !isFinite(time) || Math.abs(dx) > 100000) return;
    hoverLocked = true; hoverDelay.stop(); tooltipTitle = "";
    if (phase === "start") {
      rememberSelection(); swiping = true; swipeStart = pagePosition; swipeDx = dx; swipeTime = time; swipeVelocity = 0;
    } else if (phase === "update" && swiping) {
      var dt = time - swipeTime;
      if (dt > 0 && dt < 200) swipeVelocity = (dx - swipeDx) / dt;
      swipeDx = dx; swipeTime = time;
      pagePosition = Model.clamp(swipeStart - dx / settings.swipeDistance, 0, spaces.length - 1);
      var index = Model.clamp(Math.round(pagePosition), 0, spaces.length - 1);
      if (index !== selectedSpace) { rememberSelection(); selectedSpace = index; restoreSelection(); updateVisible(); }
    } else if (phase === "finish" && swiping) {
      var target = Model.swipeTarget(swipeStart, pagePosition, swipeVelocity, dx, cancelled, spaces.length);
      swiping = false; preview(target, true);
    }
  }
  function diagnostics(unused) {
    var thumbnails = [];
    for (var i = 0; i < thumbs.count; i++) {
      var t = thumbs.itemAt(i); if (!t) continue;
      var p = t.mapToItem(null, 0, 0);
      thumbnails.push({id: t.space.id, x:p.x, y:p.y, width:t.width, height:t.height, windows:t.space.windows.length});
    }
    var rail = pages.itemAt(selectedSpace);
    return JSON.stringify({opened:opened, version:"1.0.0", pluginId:"predmore.spaces", workspace:selectedWorkspace, actualWorkspace:monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 0, spaces:spaces.length, windows:shownWindows.length, selected:selectedIndex, position:pagePosition, swiping:swiping, safeTopInset:root.safeTopInset, spaceFocus:spaceFocus, hoverLocked:hoverLocked, captures:capturePool.stats(), thumbnails:thumbnails, rail:rail ? rail.stats() : null, screen:{width:panel.width,height:panel.height}});
  }

  IpcHandler { target: "predmore.spaces"; function diagnostics(): string { return root.diagnostics(""); } }
  FileView {
    id: cutoutFile
    path: "/usr/share/omarchy-platform/display-cutouts.json"
    blockLoading: true; watchChanges: true; printErrors: false
    onLoaded: root.cutoutData = text()
    onLoadFailed: root.cutoutData = ""
    onFileChanged: reload()
  }
  FileView {
    id: settingsFile
    path: root.configHome + "/omarchy/spaces.json"
    blockLoading: true; watchChanges: true; printErrors: false
    onLoaded: root.settings = Model.settings(text())
    onLoadFailed: root.settings = Model.settings("")
    onFileChanged: reload()
  }
  FileView { id: workspaceMap; path: root.stateHome + "/omarchy/monitor-workspaces"; preload: true }
  Process {
    id: wallpaperPath
    command: ["readlink", "-f", root.stateHome + "/omarchy/current/background"]
    stdout: StdioCollector { onStreamFinished: {
      var path = text.trim();
      root.wallpaper = /^\/[\s\S]+\.(png|jpg|jpeg|webp|avif)$/i.test(path) ? "file://" + path : "";
    } }
  }
  GestureBridge { id: bridge; enabled: root.gestureEnabled; active: root.opened }
  Connections { target: Hyprland.toplevels; function onValuesChanged() { if (root.opened) updateDebounce.restart(); } }
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event) return;
      if (event.name === "custom" && String(event.data || "").indexOf("predmore.spaces:bridge,") === 0)
        bridge.available = String(event.data) === "predmore.spaces:bridge,ready";
      if (!root.opened) return;
      if (["movewindow", "movewindowv2", "openwindow", "closewindow"].indexOf(event.name) >= 0) updateDebounce.restart();
      if (event.name === "configreloaded") { bridge.available = false; bridge.sync(); }
      if (event.name === "custom") {
        var parts = String(event.data || "").split(",");
        if (parts.length === 5 && parts[0] === "predmore.spaces:swipe" && ["start","update","finish"].indexOf(parts[1]) >= 0)
          root.swipe(parts[1], Number(parts[2]), Number(parts[3]), parts[4] === "1");
      }
    }
  }
  Timer { id: updateDebounce; interval: 70; onTriggered: root.refresh() }
  Timer { id: scrollSelection; interval: 250; onTriggered: root.selectVisible() }
  Timer { id: hoverDelay; interval: 80; onTriggered: if (!root.hoverLocked && root.hoveredSpace >= 0 && !root.swiping) root.preview(root.hoveredSpace, false) }
  Behavior on pagePosition { enabled: root.opened && !root.swiping && !root.initializing; NumberAnimation { id: pageMotion; duration: Commons.Style.duration(220); easing.type: Easing.OutCubic } }

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "omarchy-window-overview"
    CapturePool { id: capturePool; opened: root.opened; windows: root.windows; previewWorkspace: root.selectedWorkspace; preferredAddresses: root.visibleAddresses; captureLimit: root.settings.captureLimit; previewInterval: root.settings.previewInterval; backgroundInterval: root.settings.backgroundInterval; transitioning: root.swiping || pageMotion.running }
    Rectangle { anchors.fill: parent; color: Commons.Color.background }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }
    Item {
      id: keys
      anchors.fill: parent; focus: true
      Accessible.role: Accessible.Grouping
      Accessible.name: strings.t("title")
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        root.keyboardMode = true;
        if (event.key === Qt.Key_Escape) root.dismiss();
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { if (root.spaceFocus) root.commitSpace(root.selectedSpace); else root.activateSelection(); }
        else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Left) root.preview(root.selectedSpace - 1, true);
        else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Right) root.preview(root.selectedSpace + 1, true);
        else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) root.preview(event.key - Qt.Key_1, true);
        else if (event.key === Qt.Key_0) root.preview(9, true);
        else if (event.key === Qt.Key_Up) { root.spaceFocus = true; root.hoverLocked = true; }
        else if (event.key === Qt.Key_Down) { root.spaceFocus = false; root.ensureSelection(); }
        else if (event.key === Qt.Key_Left) { if (root.spaceFocus) root.preview(root.selectedSpace - 1, true); else root.select(-1); }
        else if (event.key === Qt.Key_Right) { if (root.spaceFocus) root.preview(root.selectedSpace + 1, true); else root.select(1); }
        else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) { if (root.spaceFocus) root.spaceFocus = false; else root.select(event.modifiers & Qt.ShiftModifier ? -1 : 1); }
        else if (event.key === Qt.Key_Home) root.select(-root.shownWindows.length);
        else if (event.key === Qt.Key_End) root.select(root.shownWindows.length);
        else return;
        event.accepted = true;
      }
      Rectangle {
        id: topBand
        width: parent.width
        height: spaceStrip.y + spaceStrip.height + 26
        color: Commons.Util.alpha(Commons.Color.foreground, 0.025)
        MouseArea { anchors.fill: parent; onClicked: {} }
        Flickable {
          id: spaceStrip
          x: root.margin; y: root.safeTopInset + 26
          width: parent.width - root.margin * 2
          height: spaceRow.height
          contentWidth: Math.max(width, spaceRow.width); contentHeight: height
          clip: true; boundsBehavior: Flickable.StopAtBounds
          Row {
            id: spaceRow
            x: Math.max(0, (spaceStrip.width - width) / 2)
            spacing: 12
            Repeater {
              id: thumbs
              model: root.spaces
              delegate: SpaceThumbnail {
                required property var modelData
                required property int index
                width: Math.max(86, Math.min(150, (spaceStrip.width - 12 * (Math.min(10, root.spaces.length) - 1)) / Math.min(10, root.spaces.length)))
                space: modelData; monitor: root.monitor; pool: capturePool
                wallpaper: root.wallpaper
                selected: index === root.selectedSpace
                keyboardFocused: root.spaceFocus && index === root.selectedSpace
                emptyLabel: strings.t("emptySpace")
                current: modelData.id === root.openingWorkspace
                accessibleLabel: modelData.id === root.openingWorkspace ? strings.t("currentWorkspace").arg(modelData.label) : strings.t("workspace").arg(modelData.label)
                onPointerEntered: { root.hoveredSpace = index; if (!root.hoverLocked && !root.swiping) hoverDelay.restart(); }
                onPointerLeft: { if (root.hoveredSpace === index) { root.hoveredSpace = -1; hoverDelay.stop(); } }
                onPointerMoved: function(x,y) { root.pointerMoved(index,x,y); }
                onChosen: root.commitSpace(index)
              }
            }
          }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Commons.Util.alpha(root.foreground, 0.07) }
      }
      Item {
        id: lower
        x: root.margin; width: parent.width - root.margin * 2
        y: topBand.height + Math.max(46, (parent.height - topBand.height - height - 80) / 3)
        height: Math.min(590, Math.max(240, parent.height - topBand.height - 160))
        Item {
          y: -34; width: parent.width; height: parent.height + 34
          clip: true
          Row {
            y: 34
            x: -root.pagePosition * lower.width
            Repeater {
              id: pages
              model: root.spaces
              delegate: WindowRail {
                required property var modelData
                required property int index
                width: lower.width; height: lower.height
                windows: modelData.windows; pool: capturePool; opened: root.opened
                summaryText: strings.t("spaceSummary").arg(modelData.label).arg(strings.tn("windowCount", modelData.windows.length).arg(Commons.I18n.formatNumber(modelData.windows.length)))
                selectedPage: index === root.selectedSpace
                selectedIndex: root.selectedIndex
                keyboardActive: !root.spaceFocus
                previousText: strings.t("previousWindows"); nextText: strings.t("nextWindows")
                savedOffset: root.offsets[String(modelData.id)] || 0
                unavailableText: strings.t("previewUnavailable")
                emptyText: strings.t("empty"); emptyHint: strings.t("emptyHint")
                onVisibleAddressesChanged: if (selectedPage) root.updateVisible()
                onSelectedPageChanged: if (selectedPage) Qt.callLater(root.updateVisible)
                onChosen: function(target) { root.activate(target); }
                onScrolled: function(offset) { var next = Object.assign({}, root.offsets); next[String(modelData.id)] = offset; root.offsets = next; if (selectedPage) scrollSelection.restart(); }
                onInspectTitle: function(title,x,y) { root.tooltipTitle=title; root.tooltipX=x; root.tooltipY=y; }
                onLeaveTitle: root.tooltipTitle = ""
              }
            }
          }
        }
      }
      Text {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 34; anchors.horizontalCenter: parent.horizontalCenter
        text: root.keyboardMode ? (root.spaceFocus ? strings.t("helpSpaces") : strings.t("helpWindows")) : (bridge.available && root.gestureEnabled ? strings.t("help") : strings.t("helpBasic"))
        textFormat: Text.PlainText
        color: Commons.Util.alpha(root.foreground, 0.60)
        font.family: Commons.Style.font.menuFamily; font.pixelSize: Commons.Style.font.bodySmall
      }
    }
    Rectangle {
      visible: root.tooltipTitle.length > 0; z: 20
      x: Math.max(16, Math.min(root.tooltipX, panel.width - width - 16))
      y: Math.min(root.tooltipY + 8, panel.height - height - 16)
      width: Math.min(480, titleTip.implicitWidth + 24); height: titleTip.implicitHeight + 18
      color: Commons.Color.background; radius: 6
      border.width: 1; border.color: Commons.Util.alpha(root.foreground, 0.16)
      Text {
        id: titleTip
        x:12; y:9; width:Math.min(456, implicitWidth)
        text:root.tooltipTitle; textFormat:Text.PlainText; wrapMode:Text.Wrap
        color:root.foreground; font.family:Commons.Style.font.menuFamily; font.pixelSize:Commons.Style.font.body
      }
    }
  }
}
