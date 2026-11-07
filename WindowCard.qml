import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons
import "Model.js" as Model

Rectangle {
  id: card
  required property var target
  property bool selected: false
  property bool captureEnabled: false
  property var frame: null
  property string unavailableText: "Preview unavailable"
  property string workspaceText: ""
  readonly property var source: target ? target.wayland : null
  readonly property string appId: source ? source.appId : (target && target.lastIpcObject ? target.lastIpcObject.class || "" : "")
  readonly property var entry: {
    var applications = DesktopEntries.applications.values;
    return applications.length ? DesktopEntries.heuristicLookup(appId) : null;
  }
  readonly property string appName: Model.text(entry ? entry.name : Model.appName(appId), "Application")
  readonly property string iconSource: card.entry && card.entry.icon ? Quickshell.iconPath(card.entry.icon, true) : ""
  readonly property string title: Model.text(target ? target.title : "", appName)
  readonly property bool hasPreview: !!frame && frame.hasContent
  readonly property bool hasCapture: !!frame && frame.captureActive
  property bool loadingFinished: false
  onCaptureEnabledChanged: loadingFinished = false
  onSourceChanged: loadingFinished = false
  signal chosen()
  signal inspectTitle(string title, real x, real y)
  signal leaveTitle()

  radius: Math.max(4, Commons.Style.cornerRadius)
  color: Commons.Util.alpha(Commons.Color.foreground, hover.hovered ? 0.055 : 0.018)
  border.width: selected ? 2 : 1
  border.color: selected ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.foreground, hover.hovered ? 0.25 : 0.075)
  Accessible.role: Accessible.Button
  Accessible.name: appName + ": " + title
  Accessible.description: workspaceText
  Accessible.selected: selected
  Accessible.focused: selected && captureEnabled
  Accessible.onPressAction: card.chosen()

  Rectangle {
    id: preview
    x: 8; y: 8
    width: parent.width - 16
    height: parent.height - 62
    radius: Math.max(4, card.radius - 4)
    color: Commons.Util.alpha(Commons.Color.background, 0.7)
    clip: true

    TexturePreview {
      anchors.fill: parent
      frame: card.frame
    }

    Column {
      anchors.centerIn: parent
      spacing: 12
      visible: !card.hasPreview
      Image {
        id: fallbackIcon
        anchors.horizontalCenter: parent.horizontalCenter
        width: 42; height: 42
        source: card.iconSource
        visible: card.iconSource.length > 0 && status !== Image.Error
        sourceSize: Qt.size(42, 42)
        fillMode: Image.PreserveAspectFit
      }
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 42; height: 42; radius: 8
        visible: !fallbackIcon.visible
        color: Commons.Util.alpha(Commons.Color.accent, 0.15)
        Text {
          anchors.centerIn: parent
          text: card.appName.charAt(0).toUpperCase(); textFormat: Text.PlainText
          color: Commons.Color.accent
          font.family: Commons.Style.font.menuFamily; font.pixelSize: 22
        }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: card.loadingFinished ? card.unavailableText : ""
        textFormat: Text.PlainText
        font.family: Commons.Style.font.menuFamily
        font.pixelSize: Commons.Style.font.bodySmall
        color: Commons.Util.alpha(Commons.Color.foreground, 0.65)
      }
    }
  }

  Image {
    id: icon
    x: 14; y: preview.y + preview.height + 13
    width: 24; height: 24
    source: card.iconSource
    visible: card.iconSource.length > 0 && status !== Image.Error
    sourceSize: Qt.size(26, 26)
    fillMode: Image.PreserveAspectFit
  }
  Rectangle {
    x: icon.x; y: icon.y; width: icon.width; height: icon.height
    radius: 5
    visible: !icon.visible
    color: Commons.Util.alpha(Commons.Color.accent, 0.15)
    Text {
      anchors.centerIn: parent
      text: card.appName.charAt(0).toUpperCase(); textFormat: Text.PlainText
      color: Commons.Color.accent
      font.family: Commons.Style.font.menuFamily; font.pixelSize: 14
    }
  }
  Text {
    id: titleLabel
    x: 50; y: preview.y + preview.height + 8
    width: parent.width - x - 14
    text: card.title
    textFormat: Text.PlainText
    font.family: Commons.Style.font.menuFamily
    font.pixelSize: Commons.Style.font.body
    font.weight: Font.Medium
    color: Commons.Color.foreground
    elide: Text.ElideRight
  }
  Text {
    x: 50; y: preview.y + preview.height + 30
    width: parent.width - x - 14
    text: card.appName + (card.workspaceText ? "  ·  " + card.workspaceText : "")
    textFormat: Text.PlainText
    font.family: Commons.Style.font.menuFamily
    font.pixelSize: Commons.Style.font.bodySmall
    color: Commons.Util.alpha(Commons.Color.foreground, 0.65)
    elide: Text.ElideRight
  }
  MouseArea {
    id: hover
    property bool hovered: containsMouse
    anchors.fill: parent; hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: card.chosen()
  }
  Item {
    x: titleLabel.x; y: titleLabel.y
    width: titleLabel.width; height: titleLabel.height
    HoverHandler { id: titleHover; onHoveredChanged: if (!hovered) card.leaveTitle() }
  }
  Timer {
    interval: 650
    running: titleHover.hovered && titleLabel.truncated
    onTriggered: { var p = card.mapToItem(null, 0, card.height); card.inspectTitle(card.title, p.x, p.y) }
  }
  Timer {
    interval: 650
    running: card.captureEnabled && !card.hasPreview
    onTriggered: card.loadingFinished = true
  }
}
