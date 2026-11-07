import QtQuick

Item {
  id: preview
  property var frame: null
  property bool fill: false
  readonly property bool hasContent: !!frame && frame.hasContent
  Loader {
    anchors.fill: parent
    active: preview.hasContent && !!preview.frame.texture
    sourceComponent: Item {
      ShaderEffect {
        anchors.centerIn: parent
        readonly property real aspect: preview.frame ? preview.frame.aspect : 1.6
        width: preview.fill ? preview.width : Math.min(preview.width, preview.height * aspect)
        height: preview.fill ? preview.height : Math.min(preview.height, preview.width / aspect)
        property variant source: preview.frame ? preview.frame.texture : null
      }
    }
  }
}
