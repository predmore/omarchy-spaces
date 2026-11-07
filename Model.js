.pragma library

function text(value, fallback) {
  var s = String(value || "").replace(/[\u0000-\u001f\u007f]/g, " ").trim();
  return (s || fallback || "").slice(0, 1000);
}

function address(value) {
  var raw = String(value || "");
  return /^(?:0x)?[0-9a-fA-F]+$/.test(raw) ? "0x" + raw.replace(/^0x/, "") : "";
}

function appName(value) {
  var parts = text(value, "Application").split(".");
  return parts[parts.length - 1].replace(/[-_]+/g, " ").replace(/\b\w/g, function(c) { return c.toUpperCase(); });
}

function merge(previous, candidates, monitor) {
  var valid = candidates.filter(function(w) {
    return w && w.workspace && w.workspace.id > 0 && w.monitor
      && w.monitor.name === monitor && address(w.address).length > 0;
  }).slice(0, 128);
  var rank = {};
  previous.forEach(function(w, i) { if (w) rank[String(w.address)] = i; });
  valid.sort(function(a, b) {
    var ar = rank[String(a.address)], br = rank[String(b.address)];
    if (ar !== undefined || br !== undefined)
      return (ar === undefined ? 10000 : ar) - (br === undefined ? 10000 : br);
    var ap = a.lastIpcObject && a.lastIpcObject.at || [0, 0];
    var bp = b.lastIpcObject && b.lastIpcObject.at || [0, 0];
    return a.workspace.id - b.workspace.id || ap[0] - bp[0] || ap[1] - bp[1] || String(a.address).localeCompare(String(b.address));
  });
  return valid;
}

function filter(windows, workspace) {
  return windows.filter(function(w) { return w && w.workspace && (!workspace || w.workspace.id === workspace); });
}

function tabs(windows, current, selected) {
  var counts = {}, names = {};
  windows.forEach(function(w) {
    if (!w || !w.workspace) return;
    var id = w.workspace.id;
    counts[id] = (counts[id] || 0) + 1;
    names[id] = text(w.workspace.name, String(id));
  });
  if (current > 0 && counts[current] === undefined) { counts[current] = 0; names[current] = String(current); }
  if (selected > 0 && counts[selected] === undefined) { counts[selected] = 0; names[selected] = String(selected); }
  return Object.keys(counts).map(Number).sort(function(a, b) { return a - b; }).map(function(id) {
    return { id: id, name: names[id], count: counts[id] };
  });
}

function workspaceLabel(id, name) {
  return /^\d+$/.test(String(name || id)) ? String(id) : text(name, String(id)).slice(0, 32);
}

function next(index, delta, count) {
  return count > 0 ? Math.max(0, Math.min(count - 1, index + delta)) : 0;
}

function clamp(value, min, max) { return Math.max(min, Math.min(max, value)); }

function baseForMonitor(raw, monitorName, activeId) {
  var lines = String(raw || "").slice(0, 32768).split("\n");
  for (var i = 0; i < lines.length; i++) {
    var fields = lines[i].split("\t");
    if (fields.length >= 2 && fields[1] === monitorName && /^\d+$/.test(fields[0])) return Number(fields[0]) * 10;
  }
  return Math.floor((Math.max(1, activeId) - 1) / 10) * 10;
}

function spaces(windows, base, count) {
  count = Math.round(clamp(Number(count) || 10, 1, 20));
  var out = [];
  for (var i = 1; i <= count; i++) {
    var id = base + i;
    out.push({id: id, label: String(i), windows: filter(windows, id)});
  }
  windows.forEach(function(w) {
    if (w && w.workspace && !out.some(function(s) { return s.id === w.workspace.id; }))
      out.push({id: w.workspace.id, label: workspaceLabel(w.workspace.id, w.workspace.name), windows: filter(windows, w.workspace.id)});
  });
  return out.slice(0, 20);
}

function geometry(window, monitor) {
  var ipc = window && window.lastIpcObject || {};
  var at = ipc.at || [monitor.x || 0, monitor.y || 0];
  var size = ipc.size || [400, 300];
  var mw = Math.max(1, Number(monitor.width || 1600) / Number(monitor.scale || 1));
  var mh = Math.max(1, Number(monitor.height || 1000) / Number(monitor.scale || 1));
  return {
    x: clamp((Number(at[0]) - Number(monitor.x || 0)) / mw, -5, 5),
    y: clamp((Number(at[1]) - Number(monitor.y || 0)) / mh, -5, 5),
    width: clamp(Number(size[0]) / mw, 0.01, 5),
    height: clamp(Number(size[1]) / mh, 0.01, 5),
    aspect: clamp(Number(size[0]) / Math.max(1, Number(size[1])), 0.1, 8)
  };
}

function swipeTarget(start, position, velocity, displacement, cancelled, count) {
  if (cancelled) return clamp(Math.round(start), 0, count - 1);
  var target = Math.round(position);
  if (Math.abs(displacement) > 24 && Math.abs(velocity) > 0.35)
    target = velocity < 0 ? Math.ceil(position + 0.15) : Math.floor(position - 0.15);
  else if (Math.abs(position - start) > 0.22)
    target = position > start ? Math.ceil(position) : Math.floor(position);
  return clamp(target, 0, count - 1);
}

function apps(windows) {
  var out = [];
  windows.forEach(function(w) {
    var id = text(w && w.wayland ? w.wayland.appId : w && w.lastIpcObject ? w.lastIpcObject.class : "", "application");
    if (!out.some(function(a) { return a.id === id; })) out.push({id: id, name: appName(id)});
  });
  return out;
}

// Match Omarchy's platform cutout descriptions against this output's physical mode.
// Keep hardware pixels independent of font and spacing scales.
function safeTopInset(raw, mode, calibrated) {
  if (!mode || (Number(mode.transform || 0) !== 0 && Number(mode.transform || 0) !== 4)) return 0;
  var parsed;
  try { parsed = JSON.parse(String(raw || "").slice(0, 32768)); } catch (error) { return 0; }
  var panels = parsed && Array.isArray(parsed.panels) ? parsed.panels : [];
  var name = String(mode.name || ""), scale = Number(mode.scale);
  if (!isFinite(scale) || scale <= 0) return 0;
  for (var i = 0; i < Math.min(64, panels.length); i++) {
    var panel = panels[i] || {};
    var width = Number(panel.width), height = Number(panel.height), top = Number(panel.top);
    if (typeof panel.connector !== "string" || !panel.connector || name.indexOf(panel.connector) !== 0) continue;
    if (!(width > 0 && height > 0 && top > 0 && top < height)) continue;
    if (Math.abs(Number(mode.width) - width) <= 4 && Math.abs(Number(mode.height) - height) <= 4)
      return Math.max(Math.ceil(top / scale), Number(calibrated) > 0 ? Math.round(Number(calibrated)) : 0);
  }
  return 0;
}

function settings(raw) {
  var value;
  try { value = JSON.parse(String(raw || "").slice(0, 32768)); } catch (error) { value = {}; }
  if (!value || typeof value !== "object" || Array.isArray(value)) value = {};
  function number(key, fallback, min, max) {
    return typeof value[key] === "number" && isFinite(value[key]) ? Math.round(clamp(value[key], min, max)) : fallback;
  }
  return {
    workspaceCount: number("workspaceCount", 10, 1, 20),
    workspaceBase: typeof value.workspaceBase === "number" && isFinite(value.workspaceBase) ? Math.round(clamp(value.workspaceBase, 0, 100000)) : null,
    swipeDistance: number("swipeDistance", 260, 80, 1200),
    captureLimit: number("captureLimit", 16, 1, 32),
    previewInterval: number("previewInterval", 100, 50, 2000),
    backgroundInterval: number("backgroundInterval", 1100, 250, 10000),
    gesturesEnabled: value.gesturesEnabled !== false
  };
}
