import QtQuick

// ⏮ ⏯ ⏭ — центральная кнопка акцентным кругом
// ⏮ ⏯ ⏭: the centre button is an accent circle
Row {
    id: mc
    property var player: null
    property real big: 44
    spacing: 10
    Repeater {
        model: [
            ["skip_previous", () => mc.player?.previous()],
            [mc.player?.isPlaying ? "pause" : "play_arrow", () => mc.player?.togglePlaying()],
            ["skip_next", () => mc.player?.next()]
        ]
        delegate: Rectangle {
            required property var modelData
            required property int index
            readonly property bool main: index === 1
            width: main ? mc.big : mc.big * 0.8
            height: width
            radius: main && mc.player?.isPlaying ? Tokens.rounding.medium : width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: main ? Theme.accent : Theme.surfaceHi
            opacity: mc.player ? 1 : 0.4
            Behavior on radius { Anim { kind: "fastSpatial" } }
            Icon { anchors.centerIn: parent; name: modelData[0]; size: parent.width * 0.34
                   color: parent.main ? Theme.onAccent : Theme.text }
            StateLayer { radius: parent.radius; tint: parent.main ? Theme.onAccent : Theme.text
                         disabled: !mc.player; onClicked: modelData[1]() }
        }
    }
}
