import QtQuick

// простой ползунок в стиле темы: трек, заливка акцентом, кружок
// a simple slider in the theme style: track, accent fill, knob
Item {
    id: s
    property real value: 0          // 0..1
    signal moved(real v)
    height: 22

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.surfaceHi
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, s.value))
            height: parent.height
            radius: 3
            color: Theme.accent
        }
    }
    Rectangle {
        width: 16; height: 16; radius: 8
        color: Theme.text
        border.color: Theme.accent
        border.width: 2
        anchors.verticalCenter: parent.verticalCenter
        x: (s.width - width) * Math.max(0, Math.min(1, s.value))
        scale: ma.pressed ? 1.2 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        function set(mx) { s.moved(Math.max(0, Math.min(1, mx / width))); }
        onPressed: (m) => set(m.x)
        onPositionChanged: (m) => { if (pressed) set(m.x); }
    }
}
