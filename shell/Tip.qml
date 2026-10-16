import Quickshell
import QtQuick

// подсказка над элементом панели при наведении
// a tooltip above a bar item on hover
PopupWindow {
    id: tip
    property string text: ""
    property Item target: null
    anchor.item: target
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 22
    color: "transparent"
    visible: false
    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: 8
        radius: 10
        color: Theme.bg
        border.color: Theme.line
        Text {
            id: label
            font.family: Theme.font
            anchors.centerIn: parent
            text: tip.text
            color: Theme.text
            font.pixelSize: 12
        }
    }
}
