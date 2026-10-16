import QtQuick

// толстый ползунок как в шторке Pixel: значок внутри, заливка акцентом
// a thick slider like in the Pixel quick settings: icon inside, accent fill
Item {
    id: s
    property real value: 0
    property string icon: ""
    signal moved(real v)
    signal iconClicked()
    implicitHeight: 44

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.surfaceHi
        clip: true
        Rectangle {
            height: parent.height
            radius: height / 2
            width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, s.value)))
            color: Theme.accent
            Behavior on width { enabled: !ma.pressed; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
    }
    Icon {
        id: ic
        x: (s.height - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        name: s.icon
        size: 15
        color: Theme.onAccent
        z: 2
        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: s.iconClicked() }
    }
    Text {
        font.family: Theme.font
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(s.value * 100) + "%"
        color: s.value > 0.85 ? Theme.onAccent : Theme.textDim
        font.pixelSize: 11
        z: 2
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.leftMargin: s.height
        function set(mx) { s.moved(Math.max(0, Math.min(1, (mx + s.height) / s.width))); }
        onPressed: (m) => set(m.x)
        onPositionChanged: (m) => { if (pressed) set(m.x); }
        onWheel: (w) => s.moved(Math.max(0, Math.min(1, s.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
