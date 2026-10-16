import Quickshell
import QtQuick

// главная вкладка: погода, «я», часы, календарь, индикаторы, плеер
// (раскладка на явной геометрии — Layout-ы тут вели себя непредсказуемо)
// home tab: weather, "me", clock, calendar, gauges, player
// (laid out with explicit geometry: Layouts behaved unpredictably here)
Item {
    id: home
    property var dash
    SystemClock { id: clock; precision: SystemClock.Minutes }

    readonly property real pad: Tokens.gap.large
    readonly property real gap: Tokens.gap.small
    readonly property real playerW: 190
    readonly property real leftW: width - pad * 2 - playerW - gap
    readonly property real topH: 96
    readonly property real botY: topH + gap
    readonly property real botH: height - botY
    readonly property real sideW: 84

    // плеер — сверху во всю левую часть: название трека влезает, кнопки под рукой
    // player at the top across the whole left part: the track title fits, the buttons are at hand
    Card {
        x: home.pad; y: 0
        width: home.leftW; height: home.topH
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 8
            spacing: 14
            Vinyl {
                anchors.verticalCenter: parent.verticalCenter
                size: home.topH - 16
                art: Mpd.alive ? Mpd.art : (home.dash.player?.trackArtUrl ?? "")
                seed: Mpd.alive ? (Mpd.cur.file ?? "") : (home.dash.player?.trackTitle ?? "")
                spinning: (home.dash.player?.isPlaying ?? false) && home.dash.open && home.dash.tab === 0
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: home.leftW - home.topH - 190
                spacing: 2
                Text { width: parent.width; elide: Text.ElideRight
                       font.family: Theme.font; font.pixelSize: Tokens.font.larger; font.bold: true; color: Theme.text
                       text: home.dash.player?.trackTitle || L.t("тишина") }
                Text { width: parent.width; elide: Text.ElideRight
                       font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.textDim
                       text: home.dash.player?.trackArtist || L.t("ничего не играет") }
            }
            MediaControls { anchors.verticalCenter: parent.verticalCenter; player: home.dash.player; big: 40 }
        }
    }
    // вертикальные часы
    // vertical clock
    Card {
        x: home.pad; y: home.botY
        width: home.sideW; height: home.botH

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.font
                               text: Qt.formatDateTime(clock.date, "HH"); color: Theme.text; font.pixelSize: 30; font.bold: true }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 4
                            Repeater { model: 3; delegate: Rectangle { width: 5; height: 5; radius: 2.5; color: Theme.accent } }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.font
                               text: Qt.formatDateTime(clock.date, "mm"); color: Theme.text; font.pixelSize: 30; font.bold: true }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.font
                               text: L.locale.toString(clock.date, "ddd"); color: Theme.accent; font.pixelSize: Tokens.font.smaller }
                    }
                
    }
    // календарь
    // calendar
    Card {
        x: home.pad + home.sideW + home.gap; y: home.botY
        width: home.leftW - home.sideW * 2 - home.gap * 2; height: home.botH

                    Calendar { anchors.fill: parent; today: clock.date }
                
    }
    // индикаторы
    // gauges
    Card {
        x: home.pad + home.leftW - home.sideW; y: home.botY
        width: home.sideW; height: home.botH

                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        Gauge { size: 56; icon: "memory"; value: SysInfo.cpu }
                        Gauge { size: 56; icon: "dashboard"; value: SysInfo.mem; color: Theme.accent2 }
                        Gauge { size: 56; icon: "hdd"; value: SysInfo.disk }
                    }
                
    }
    // погода — справа сверху
    // weather: top right
    Card {
        x: home.pad + home.leftW + home.gap; y: 0
        width: home.playerW; height: home.topH
        Row {
            anchors.centerIn: parent
            spacing: 12
            Icon { name: Weather.iconFor(Weather.code, !Weather.isDay)
                   size: 34; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { font.family: Theme.font; text: Weather.ok ? Weather.temp + "°C" : "…"
                       color: Theme.text; font.pixelSize: 24; font.bold: true }
                Text { font.family: Theme.font; text: Weather.ok ? Weather.desc : L.t("нет данных"); width: 100
                       elide: Text.ElideRight; color: Theme.textDim; font.pixelSize: Tokens.font.small }
            }
        }
    }
    // «я» — справа снизу
    // "me": bottom right
    Card {
        x: home.pad + home.leftW + home.gap; y: home.botY
        width: home.playerW; height: home.botH
        Column {
            anchors.centerIn: parent
            spacing: 10
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64; height: 64; radius: 22
                color: Theme.tonalHi
                Icon { anchors.centerIn: parent; name: "pets"; size: 28; color: Theme.accent }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.font
                   text: ShellState.userName; color: Theme.text; font.pixelSize: Tokens.font.larger; font.bold: true }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: upT.implicitWidth + 18; height: 24; radius: 12; color: Theme.accent
                Text { id: upT; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                       text: L.t("в сети ") + SysInfo.uptimeText; color: Theme.onAccent }
            }
        }
    }
}
