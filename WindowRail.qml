import QtQuick
import QtQuick.Controls as Controls
import qs.Commons as Commons
import "Model.js" as Model

Item {
  id: page
  property var windows: []
  property var pool: null
  property bool opened: false
  property bool selectedPage: false
  property bool keyboardActive: true
  property string summaryText: ""
  property string previousText: "Previous windows"
  property string nextText: "More windows"
  property int selectedIndex: 0
  property real savedOffset: 0
  property string unavailableText: "Preview unavailable"
  property string emptyText: "No windows here"
  property string emptyHint: "Choose a space above."
  property bool restoring: true
  readonly property int gap: Commons.Style.space(18)
  readonly property real naturalPreviewHeight: Math.max(120, height - 70)
  readonly property real previewHeight: {
    if (windows.length < 2 || windows.length > 4) return naturalPreviewHeight;
    function total(h) {
      var sum = Math.max(0, page.windows.length - 1) * page.gap;
      page.windows.forEach(function(w) {
        var size = w && w.lastIpcObject && w.lastIpcObject.size || [900,700];
        sum += Model.clamp(h * Model.clamp(Number(size[0]) / Math.max(1, Number(size[1])), 0.15, 6) + 16, 240, 620);
      });
      return sum;
    }
    if (total(naturalPreviewHeight) <= width) return naturalPreviewHeight;
    var low = naturalPreviewHeight * 0.68, high = naturalPreviewHeight;
    if (total(low) > width) return naturalPreviewHeight;
    for (var i = 0; i < 12; i++) {
      var middle = (low + high) / 2;
      if (total(middle) > width) high = middle; else low = middle;
    }
    return low;
  }
  readonly property real contentStart: Math.max(0, row.x - rail.contentX)
  readonly property real contentEnd: Math.min(width, row.x + row.width - rail.contentX)
  readonly property real contentTop: {
    var top = page.height;
    for (var i = 0; i < cards.count; i++) { var c = cards.itemAt(i); if (c) top = Math.min(top, c.y); }
    return Math.max(0, top === page.height ? 0 : top);
  }
  readonly property real contentOffset: rail.contentX
  readonly property var visibleAddresses: {
    var out = [], widths = [], total = 0;
    windows.forEach(function(w) {
      var size = w && w.lastIpcObject && w.lastIpcObject.size || [900,700];
      var width = Model.clamp(page.previewHeight * Model.clamp(Number(size[0]) / Math.max(1, Number(size[1])), 0.15, 6) + 16, 240, 620);
      widths.push(width); total += width;
    });
    total += Math.max(0, windows.length - 1) * gap;
    var x = Math.max(0, (rail.width - total) / 2);
    for (var i = 0; i < windows.length; i++) {
      if (x + widths[i] > rail.contentX && x < rail.contentX + rail.width) out.push(windows[i].address);
      x += widths[i] + gap;
    }
    return out;
  }
  signal chosen(var target)
  signal scrolled(real offset)
  signal inspectTitle(string title, real x, real y)
  signal leaveTitle()

  function ensureIndex(index) {
    var item = cards.itemAt(index);
    if (!item) return;
    var next = rail.contentX;
    var left = item.x + row.x;
    if (left < next + 4) next = left - 4;
    else if (left + item.width > next + rail.width - 4) next = left + item.width - rail.width + 4;
    scrollTo(next, true);
  }
  function scrollTo(offset, animated) {
    var target = Model.clamp(offset, 0, Math.max(0, rail.contentWidth - rail.width));
    wheelMotion.stop();
    if (animated) { wheelMotion.from = rail.contentX; wheelMotion.to = target; wheelMotion.restart(); }
    else rail.contentX = target;
  }
  function stats() {
    var out = [];
    for (var i = 0; i < cards.count; i++) {
      var c = cards.itemAt(i);
      if (c && c.selected) {
        var p = c.mapToItem(null, 0, 0);
        out.push({index: i, x: p.x, y: p.y, width: c.width, height: c.height});
      }
    }
    return {start:page.contentStart, end:page.contentEnd, top:page.contentTop, visible:page.visibleAddresses, offset: rail.contentX, maximum: Math.max(0, rail.contentWidth - rail.width), selectedCards: out};
  }
  Component.onCompleted: Qt.callLater(function() { page.scrollTo(page.savedOffset, false); page.restoring = false; })

  Text {
    visible: page.windows.length > 0
    x: page.contentStart; y: page.contentTop - 34
    text: page.summaryText
    textFormat: Text.PlainText
    color: Commons.Util.alpha(Commons.Color.foreground, 0.78)
    font.family: Commons.Style.font.menuFamily; font.pixelSize: Commons.Style.font.body
  }
  Flickable {
    id: rail
    anchors.fill: parent
    contentWidth: Math.max(width, row.width)
    contentHeight: height
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.HorizontalFlick
    clip: true
    onContentXChanged: if (!page.restoring && page.opened) page.scrolled(contentX)
    Row {
      id: row
      x: Math.max(0, (rail.contentWidth - width) / 2)
      spacing: page.gap
      Repeater {
        id: cards
        model: page.windows
        delegate: WindowCard {
          required property var modelData
          required property int index
          readonly property var ipc: modelData && modelData.lastIpcObject || {}
          readonly property var size: ipc.size || [900, 700]
          readonly property real aspect: Model.clamp(Number(size[0]) / Math.max(1, Number(size[1])), 0.15, 6)
          readonly property real imageHeight: Math.min(page.previewHeight, (620 - 16) / aspect)
          width: Model.clamp(page.previewHeight * aspect + 16, 240, 620)
          height: imageHeight + 62
          y: Math.round((page.height - height) / 2)
          target: modelData
          frame: page.pool ? page.pool.frameFor(modelData.address) : null
          selected: page.selectedPage && page.keyboardActive && index === page.selectedIndex
          captureEnabled: page.opened && page.selectedPage && x + width > rail.contentX && x < rail.contentX + rail.width
          unavailableText: page.unavailableText
          onChosen: page.chosen(target)
          onInspectTitle: function(title, x, y) { page.inspectTitle(title, x, y); }
          onLeaveTitle: page.leaveTitle()
        }
      }
    }
    Controls.ScrollBar.horizontal: Controls.ScrollBar {
      policy: rail.contentWidth > rail.width + 2 ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
      height: 3; padding: 0
      active: true
      contentItem: Rectangle { implicitWidth: 28; implicitHeight: 3; radius: 1; color: Commons.Util.alpha(Commons.Color.foreground, 0.40) }
      background: Rectangle { color: Commons.Util.alpha(Commons.Color.foreground, 0.06); radius: 1 }
    }
    WheelHandler {
      target: null
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: function(event) {
        var pixel = Math.abs(event.pixelDelta.x) > Math.abs(event.pixelDelta.y) ? event.pixelDelta.x : event.pixelDelta.y;
        if (pixel) page.scrollTo(rail.contentX - pixel, false);
        else {
          var angle = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? event.angleDelta.x : event.angleDelta.y;
          page.scrollTo((wheelMotion.running ? wheelMotion.to : rail.contentX) - angle * 0.8, true);
        }
        event.accepted = true;
      }
    }
  }
  NumberAnimation {
    id: wheelMotion; target: rail; property: "contentX"
    duration: Commons.Style.duration(160); easing.type: Easing.OutCubic
  }

  Repeater {
    model: [-1,1]
    delegate: Rectangle {
      required property int modelData
      readonly property bool previous: modelData < 0
      readonly property bool available: previous ? rail.contentX > 2 : rail.contentX < rail.contentWidth - rail.width - 2
      visible: available
      x: previous ? 6 : page.width - width - 6
      y: (page.height - height) / 2
      width: 32; height: 40
      radius: Math.max(3, Commons.Style.cornerRadius)
      color: Commons.Color.background
      border.width: 1
      border.color: Commons.Util.alpha(Commons.Color.foreground, arrowHover.containsMouse ? 0.4 : 0.18)
      Text {
        anchors.centerIn: parent
        text: parent.previous ? "‹" : "›"; textFormat: Text.PlainText
        font.family: Commons.Style.font.menuFamily; font.pixelSize: 24
        color: Commons.Util.alpha(Commons.Color.foreground, 0.85)
      }
      Accessible.role: Accessible.Button
      Accessible.name: previous ? page.previousText : page.nextText
      Accessible.onPressAction: page.scrollTo(rail.contentX + modelData * rail.width * 0.75, true)
      z: 5
      MouseArea {
        id: arrowHover
        anchors.fill: parent; hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: page.scrollTo(rail.contentX + modelData * rail.width * 0.75, true)
      }
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: 10
    visible: page.windows.length === 0
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: page.emptyText; textFormat: Text.PlainText
      color: Commons.Color.foreground
      font.family: Commons.Style.font.menuFamily; font.pixelSize: Commons.Style.font.title
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: page.emptyHint; textFormat: Text.PlainText
      color: Commons.Util.alpha(Commons.Color.foreground, 0.6)
      font.family: Commons.Style.font.menuFamily; font.pixelSize: Commons.Style.font.body
    }
  }
}
