import QtQuick
import Quickshell
import qs.Commons as Commons
import "Model.js" as Model

Item {
  id: thumbnail
  required property var space
  required property var monitor
  required property var pool
  property string wallpaper: ""
  property bool selected: false
  property bool current: false
  property bool keyboardFocused: false
  property string emptyLabel: "Empty"
  readonly property var apps: Model.apps(space.windows)
  property string accessibleLabel: ""
  readonly property real desktopAspect: monitor ? (monitor.width / monitor.scale) / (monitor.height / monitor.scale) : 1.6
  readonly property real canvasHeight: width / desktopAspect
  signal pointerEntered()
  signal pointerLeft()
  signal pointerMoved(real x, real y)
  signal chosen()
  height: canvasHeight + 52
  Accessible.role: Accessible.PageTab
  Accessible.name: accessibleLabel
  Accessible.selected: selected
  Accessible.focused: keyboardFocused
  Accessible.description: apps.map(function(app) { return app.name; }).join(", ")
  Accessible.onPressAction: chosen()

  Rectangle {
    id: canvas
    width: parent.width; height: thumbnail.canvasHeight
    radius: Math.max(3, Commons.Style.cornerRadius)
    color: Commons.Color.background
    border.width: thumbnail.selected ? 2 : 1
    border.color: thumbnail.selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, hover.hovered ? 0.3 : 0.14)
    Item {
      x: 3; y: 3; width: parent.width - 6; height: parent.height - 6
      clip: true
      Rectangle { anchors.fill: parent; color: Commons.Util.alpha(Commons.Color.foreground, 0.045) }
      Image {
        anchors.fill: parent
        source: thumbnail.wallpaper
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.round(width * 2), Math.round(height * 2))
        asynchronous: true
        visible: status === Image.Ready
        opacity: thumbnail.space.windows.length ? 1 : hover.hovered ? 0.55 : 0.20
      }
      Repeater {
        model: thumbnail.space.windows.slice().sort(function(a,b) {
          var ai = a.lastIpcObject || {}, bi = b.lastIpcObject || {};
          return Number(!!ai.floating) - Number(!!bi.floating) || Number(!!a.activated) - Number(!!b.activated);
        })
        delegate: Rectangle {
          id: miniWindow
          required property var modelData
          readonly property var geometry: Model.geometry(modelData, thumbnail.monitor || {})
          readonly property var frame: thumbnail.pool ? thumbnail.pool.frameFor(modelData.address) : null
          x: geometry.x * parent.width; y: geometry.y * parent.height
          width: Math.max(2, geometry.width * parent.width)
          height: Math.max(2, geometry.height * parent.height)
          color: Commons.Util.alpha(Commons.Color.foreground, 0.1)
          border.width: 0.5
          border.color: Commons.Util.alpha(Commons.Color.foreground, 0.25)
          TexturePreview { anchors.fill: parent; frame: miniWindow.frame; fill: true }
        }
      }
    }
  }

  Row {
    anchors.top: canvas.bottom; anchors.topMargin: 8
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 5
    Rectangle {
      width: 4; height: 4; radius: 2
      anchors.verticalCenter: parent.verticalCenter
      color: Commons.Color.accent
      opacity: thumbnail.current ? 1 : 0
    }
    Text {
      text: thumbnail.space.label
      textFormat: Text.PlainText
      color: thumbnail.selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, 0.72)
      font.family: Commons.Style.font.menuFamily
      font.pixelSize: Commons.Style.font.bodySmall
      font.weight: thumbnail.selected ? Font.DemiBold : Font.Normal
    }
    Text {
      text: thumbnail.space.windows.length ? "· " + Commons.I18n.formatNumber(thumbnail.space.windows.length) : ""
      textFormat: Text.PlainText
      color: Commons.Util.alpha(Commons.Color.foreground, 0.4)
      font.family: Commons.Style.font.menuFamily
      font.pixelSize: Commons.Style.font.bodySmall
    }
  }

  Row {
    y: canvas.height + 30
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 5
    Repeater {
      model: thumbnail.apps.slice(0,4)
      delegate: AppBadge { required property var modelData; app: modelData }
    }
    Text {
      visible: thumbnail.apps.length > 4
      text: "+" + Commons.I18n.formatNumber(Math.max(0, thumbnail.apps.length - 4))
      textFormat: Text.PlainText
      color: Commons.Util.alpha(Commons.Color.foreground, 0.65)
      font.family: Commons.Style.font.menuFamily
      font.pixelSize: Commons.Style.font.bodySmall
    }
  }
  Text {
    y: canvas.height + 30
    anchors.horizontalCenter: parent.horizontalCenter
    visible: thumbnail.space.windows.length === 0
    text: thumbnail.emptyLabel
    textFormat: Text.PlainText
    font.family: Commons.Style.font.menuFamily
    font.pixelSize: Commons.Style.font.bodySmall
    color: Commons.Util.alpha(Commons.Color.foreground, 0.52)
  }
  MouseArea {
    id: hover
    property bool hovered: containsMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: thumbnail.pointerEntered()
    onExited: thumbnail.pointerLeft()
    onPositionChanged: function(mouse) {
      var p = mapToItem(null, mouse.x, mouse.y);
      thumbnail.pointerMoved(p.x, p.y);
    }
    onClicked: thumbnail.chosen()
  }
}
