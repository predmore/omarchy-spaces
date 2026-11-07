import QtQuick
import Quickshell
import qs.Commons as Commons
import "Model.js" as Model

Item {
  id: badge
  required property var app
  readonly property var entry: {
    var applications = DesktopEntries.applications.values;
    return applications.length ? DesktopEntries.heuristicLookup(app.id) : null;
  }
  readonly property string icon: entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
  width: 16; height: 16
  Image {
    id: image
    anchors.fill: parent
    source: badge.icon
    sourceSize: Qt.size(32,32)
    fillMode: Image.PreserveAspectFit
    visible: status === Image.Ready
  }
  Rectangle {
    anchors.fill: parent
    visible: !image.visible
    color: Commons.Util.alpha(Commons.Color.foreground, 0.10)
    radius: 3
    Text {
      anchors.centerIn: parent
      text: badge.app.name.slice(0, 1).toUpperCase()
      textFormat: Text.PlainText
      font.family: Commons.Style.font.menuFamily
      font.pixelSize: 10
      color: Commons.Color.foreground
    }
  }
}
