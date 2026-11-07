import QtQuick
import qs.Commons as Commons
import Quickshell.Wayland
import "Model.js" as Model

Item {
  id: pool
  property bool opened: false
  property var windows: []
  property int previewWorkspace: 1
  property int captureLimit: 16
  property int previewInterval: 100
  property int backgroundInterval: 1100
  property var entries: ({})
  property var preferredAddresses: []
  property bool transitioning: false
  property var previousPriority: []
  property var heldAddresses: []
  onPriorityChanged: {
    if (opened) {
      var retained = [];
      previousPriority.concat(heldAddresses).forEach(function(a) {
        if (priority.indexOf(a) < 0 && retained.indexOf(a) < 0) retained.push(a);
      });
      heldAddresses = retained.slice(0, captureLimit);
    }
    previousPriority = priority.slice();
  }
  onOpenedChanged: if (!opened) { heldAddresses = []; previousPriority = []; }
  Timer {
    interval: Commons.Style.duration(100)
    running: pool.opened && !pool.transitioning && pool.heldAddresses.length > 0
    onTriggered: pool.heldAddresses = []
  }
  readonly property var priority: {
    var selected = windows.filter(function(w) { return w && w.workspace && w.workspace.id === previewWorkspace; });
    var others = windows.filter(function(w) { return w && w.workspace && w.workspace.id !== previewWorkspace; });
    var addresses = preferredAddresses.map(Model.address);
    selected.concat(others).forEach(function(w) { var a = Model.address(w.address); if (addresses.indexOf(a) < 0) addresses.push(a); });
    return addresses.slice(0, captureLimit);
  }

  function frameFor(address) { return entries[Model.address(address)] || null; }
  function registerFrame(address, frame) {
    var next = Object.assign({}, entries); next[Model.address(address)] = frame; entries = next;
  }
  function forgetFrame(address, frame) {
    if (entries[Model.address(address)] !== frame) return;
    var next = Object.assign({}, entries); delete next[Model.address(address)]; entries = next;
  }
  function stats() {
    var count = 0, ready = 0, live = 0, held = 0, heldReady = 0;
    for (var key in entries) { var e = entries[key]; if (e.captureActive) { count++; if (e.priorityCapture) live++; else { held++; if (e.hasContent) heldReady++; } } if (e.hasContent) ready++; }
    return {captures: count, ready: ready, live:live, held:held, heldReady:heldReady};
  }

  Repeater {
    model: pool.windows
    delegate: Item {
      id: entry
      required property var modelData
      required property int index
      readonly property var source: modelData ? modelData.wayland : null
      property string registeredAddress: ""
      readonly property bool priorityCapture: !!modelData && pool.priority.indexOf(Model.address(modelData.address)) >= 0
      readonly property bool heldCapture: !!modelData && pool.heldAddresses.indexOf(Model.address(modelData.address)) >= 0
      readonly property bool captureActive: !!capture.item
      readonly property bool hasContent: capture.item ? capture.item.hasContent : false
      readonly property var texture: capture.item ? capture.item.texture : null
      readonly property real aspect: capture.item ? capture.item.aspect : 1.6
      property bool captureGate: true
      property bool stopped: false
      property int retries: 0
      Component.onCompleted: { registeredAddress = Model.address(modelData ? modelData.address : ""); pool.registerFrame(registeredAddress, entry); }
      Component.onDestruction: pool.forgetFrame(registeredAddress, entry)
      onSourceChanged: { stopped = false; retries = 0; captureGate = true; }

      Loader {
        id: capture
        active: pool.opened && (entry.priorityCapture || entry.heldCapture) && !!entry.source && entry.captureGate
        sourceComponent: Item {
          readonly property bool hasContent: view.hasContent
          readonly property real aspect: view.sourceSize.height > 0 ? view.sourceSize.width / view.sourceSize.height : 1.6
          property alias texture: sharedTexture
          width: view.width; height: view.height
          ScreencopyView {
            id: view
            visible: false
            captureSource: entry.source
            paintCursor: false
            live: false
            width: parent.aspect >= 1.2 ? 960 : 800 * parent.aspect
            height: parent.aspect >= 1.2 ? 960 / parent.aspect : 800
            onStopped: {
              entry.stopped = true;
              if (entry.retries < 1 && pool.opened) retry.restart();
            }
          }
          ShaderEffectSource {
            id: sharedTexture
            visible: false
            sourceItem: view
            hideSource: true
            live: true
            textureSize: Qt.size(Math.max(1, Math.round(view.width)), Math.max(1, Math.round(view.height)))
          }
          Timer {
            interval: entry.modelData && entry.modelData.workspace && entry.modelData.workspace.id === pool.previewWorkspace ? pool.previewInterval : pool.backgroundInterval
            running: pool.opened && entry.priorityCapture && !entry.stopped
            repeat: true
            onTriggered: view.captureFrame()
          }
        }
      }
      Timer {
        id: retry; interval: 300
        onTriggered: {
          if (!pool.opened || !entry.source) return;
          entry.retries++; entry.captureGate = false;
          Qt.callLater(function() { if (pool.opened) { entry.stopped = false; entry.captureGate = true; } });
        }
      }
    }
  }
}
