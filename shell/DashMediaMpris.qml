import QtQuick
import QtQuick.Layouts

// вкладка «медиа»: большая пластинка, прогресс, управление, выбор плеера
// media tab: big vinyl, progress, controls, player choice
Item {
    id: m
    property var dash
    readonly property var p: dash.player

    function fmt(sec: real): string {
        if (!sec || sec < 0) return "0:00";
        const s = Math.floor(sec);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }
    Timer { interval: 1000; repeat: true; running: !!(m.p?.isPlaying) && m.dash.open && m.dash.tab === 1
            onTriggered: m.p.positionChanged() }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.gap.extraLarge
        anchors.rightMargin: Tokens.gap.extraLarge
        spacing: Tokens.gap.extraLarge

        Vinyl { size: 230; art: m.p?.trackArtUrl ?? ""; spinning: (m.p?.isPlaying ?? false) && m.dash.open && m.dash.tab === 1 }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Text { Layout.fillWidth: true; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: 22; font.bold: true
                   color: Theme.text; text: m.p?.trackTitle || L.t("тишина") }
            Text { Layout.fillWidth: true; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Tokens.font.larger
                   color: Theme.accent; text: m.p?.trackArtist || L.t("ничего не играет") }
            Text { Layout.fillWidth: true; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                   color: Theme.textDim; text: m.p?.trackAlbum ?? "" }

            // прогресс
            // progress
            Item {
                Layout.fillWidth: true
                Layout.topMargin: 14
                height: 26
                visible: m.p?.lengthSupported ?? false
                Rectangle {
                    id: track
                    y: 4; width: parent.width; height: 6; radius: 3; color: Theme.surfaceHi
                    Rectangle {
                        height: parent.height; radius: 3; color: Theme.accent
                        width: m.p && m.p.length > 0 ? parent.width * Math.min(1, m.p.position / m.p.length) : 0
                        Behavior on width { Anim { kind: "effects"; duration: 900 } }
                    }
                    MouseArea { anchors.fill: parent; anchors.margins: -8; enabled: m.p?.canSeek ?? false
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (e) => m.p.position = m.p.length * Math.max(0, Math.min(1, e.x / track.width)) }
                }
                Text { anchors.left: parent.left; anchors.bottom: parent.bottom; font.family: Theme.font
                       font.pixelSize: Tokens.font.small; color: Theme.textDim; text: m.fmt(m.p?.position) }
                Text { anchors.right: parent.right; anchors.bottom: parent.bottom; font.family: Theme.font
                       font.pixelSize: Tokens.font.small; color: Theme.textDim; text: m.fmt(m.p?.length) }
            }

            MediaControls { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 10; player: m.p; big: 54 }

            // какие плееры есть — чипсы для переключения
            // which players there are: chips to switch
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 10
                spacing: 6
                Repeater {
                    model: m.dash.players
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool sel: modelData === m.p
                        width: chip.implicitWidth + 20; height: 26; radius: 13
                        color: sel ? Theme.tonalHi : Theme.surface
                        border.color: sel ? Theme.accent : Theme.outline
                        Text { id: chip; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                               color: parent.sel ? Theme.accent : Theme.text; text: modelData.identity || L.t("плеер") }
                        StateLayer { radius: 13; onClicked: m.dash.playerIdx = index }
                    }
                }
            }
        }
    }
}
