import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: bridge
  property bool enabled: true
  property bool active: false
  property bool desired: enabled && active
  property bool applied: false
  property bool available: false
  property bool sent: false
  property bool queued: false
  onDesiredChanged: sync()
  function sync() {
    if (!enabled && !applied) return;
    if (request.running) { queued = true; return; }
    queued = false; sent = desired;
    request.command = ["hyprctl", "eval", "if type(omarchy_spaces_gesture) == 'function' then omarchy_spaces_gesture(" + (sent ? "true" : "false") + ") else hl.dispatch(hl.dsp.event('predmore.spaces:bridge,unavailable')) end"];
    request.running = true;
  }
  Process {
    id: request
    onExited: function(code) {
      if (code === 0) bridge.applied = bridge.sent && bridge.available;
      if (bridge.queued || bridge.sent !== bridge.desired) Qt.callLater(bridge.sync);
    }
  }
  Timer { interval: 1000; running: bridge.desired && bridge.available; repeat: true; onTriggered: bridge.sync() }
  Component.onDestruction: {
    if (bridge.enabled && (bridge.active || bridge.applied))
      Quickshell.execDetached(["hyprctl", "eval", "if type(omarchy_spaces_gesture) == 'function' then omarchy_spaces_gesture(false) end"]);
  }
}
