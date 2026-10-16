import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// «циферблат» в духе Nothing OS 5.0: строки заглавного моноширинного текста,
// в которые вплетены таблетки (залитые и контурные), значки и «звёздочка»-бейдж
// a Nothing OS 5.0 style "dial": lines of uppercase monospace text
// with pills (filled and outlined), icons and a "star" badge woven in
Item {
    id: nf
    property real size: 30                  // кегль строки / line size
    property color ink: Theme.text           // основной цвет / main colour
    property color knock: Theme.frame        // цвет текста внутри залитых таблеток / text colour inside filled pills
    property var date: new Date()
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? null

    component Word: Text {
        font.family: Theme.font
        font.pixelSize: nf.size
        font.capitalization: Font.AllUppercase
        font.letterSpacing: nf.size * 0.02
        color: nf.ink
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }
    component Pill: Rectangle {
        property string text: ""
        property bool filled: true
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        implicitWidth: pt.implicitWidth + nf.size * 0.6
        implicitHeight: nf.size * 1.25
        radius: height / 2
        color: filled ? nf.ink : "transparent"
        border.width: filled ? 0 : Math.max(1.5, nf.size * 0.06)
        border.color: nf.ink
        Text {
            id: pt
            anchors.centerIn: parent
            font.family: Theme.font
            font.pixelSize: nf.size * 0.95
            font.bold: true
            font.capitalization: Font.AllUppercase
            color: parent.filled ? nf.knock : nf.ink
            text: parent.text
        }
    }
    component Pic: Icon {
        size: nf.size * 0.85
        color: nf.ink
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }

    Column {
        id: col
        spacing: nf.size * 0.18

        // ПН (10) (АВГ) ✹87
        // MON (10) (AUG) ✹87
        Row {
            spacing: nf.size * 0.25
            Word { text: L.locale.toString(nf.date, "ddd").replace(".", "") }
            Pill { text: nf.date.getDate() }
            Pill { text: L.locale.standaloneMonthName(nf.date.getMonth(), Locale.ShortFormat).replace(".", ""); filled: false }
            // «звёздочка» с зарядом
            // the "star" with the charge
            Item {
                visible: Power.dev?.isLaptopBattery ?? false
                width: nf.size * 1.4; height: nf.size * 1.4
                anchors.verticalCenter: parent.verticalCenter
                LockShape { anchors.fill: parent; size: parent.width; kind: 0; color: nf.ink }
                Text { anchors.centerIn: parent; font.family: Theme.font; font.bold: true; font.pixelSize: nf.size * 0.42
                       color: nf.knock; text: Math.round(Power.pct) }
            }
        }

        // 🌡 10° (C) 💧 (ДОЖДЬ)
        // 🌡 10° (C) 💧 (RAIN)
        Row {
            visible: Weather.ok
            spacing: nf.size * 0.25
            Pic { name: "thermo" }
            Word { text: Weather.temp + "°" }
            Pill { text: "C"; filled: false; implicitWidth: implicitHeight }
            Pic { name: Weather.iconFor(Weather.code, !Weather.isDay) }
            Pill { text: Weather.desc }
        }

        // ♪ НАЗВАНИЕ ТРЕКА (→)   или   🔔 3 УВЕДОМЛЕНИЯ
        // ♪ TRACK TITLE (→)   or   🔔 3 NOTIFICATIONS
        Row {
            spacing: nf.size * 0.25
            Pic { name: nf.player ? "music" : "bell" }
            Word {
                text: nf.player ? (nf.player.trackTitle || L.t("тишина"))
                     : Notifs.history.length ? Notifs.history.length + " " + L.t("уведомления").toUpperCase()
                     : L.t("уведомлений нет")
                elide: Text.ElideRight
                width: Math.min(implicitWidth, nf.size * 12)
            }
            Pill {
                visible: !!nf.player
                implicitWidth: nf.size * 1.9
                Pic { anchors.centerIn: parent; name: "arrow_right"; color: nf.knock }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: nf.player?.next() }
            }
        }

        // В СЕТИ ⌊2Ч 13МИН
        // ONLINE ⌊2H 13MIN
        Row {
            spacing: nf.size * 0.25
            Word { text: L.t("в сети ").trim() }
            Item {
                width: upw.implicitWidth + nf.size * 0.4
                height: nf.size * 1.25
                anchors.verticalCenter: parent.verticalCenter
                // скобка-«уголок» снизу слева, как у Nothing
                // a corner bracket at the bottom left, as on Nothing
                Rectangle { x: 0; y: parent.height * 0.1; width: Math.max(2, nf.size * 0.08); height: parent.height * 0.85; radius: width / 2; color: nf.ink }
                Rectangle { x: 0; y: parent.height * 0.95 - height; width: parent.width; height: Math.max(2, nf.size * 0.08); radius: height / 2; color: nf.ink }
                Word { id: upw; x: nf.size * 0.3; text: SysInfo.uptimeText }
            }
        }
    }
}
