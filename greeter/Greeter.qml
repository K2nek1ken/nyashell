import Quickshell
import Quickshell.Services.Greetd
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects

// экран входа в стиле нашего экрана блокировки: размытые обои, плитка → большая группа,
// слева — пользователи и сеансы, в центре — часы, «циферблат» и пароль, справа — раскладка и питание
// login screen styled like our lock screen: blurred wallpaper, a tile → a big group,
// users and sessions on the left, clock, "dial" and password in the centre, keyboard layout and power on the right
FloatingWindow {
    id: w
    required property var greeter
    readonly property var g: greeter
    implicitWidth: Quickshell.screens[0]?.width ?? 1280
    implicitHeight: Quickshell.screens[0]?.height ?? 720
    color: "black"
    visible: true

    // стадии: 0 — ничего, 1 — плитка, 2 — раскрыто, 3 — уходим (вход удался)
    // stages: 0 nothing, 1 tile, 2 expanded, 3 leaving (login succeeded)
    property int stage: 0
    readonly property bool open: stage === 2
    Timer { interval: 60; running: true; onTriggered: w.stage = 1 }
    Timer { interval: 520; running: w.stage === 1; onTriggered: w.stage = 2 }
    Connections {
        target: w.g
        function onStatusChanged() { if (w.g.status === "go") w.stage = 3; }
        function onShakesChanged() { shakeAnim.restart(); }
    }

    readonly property real k: Math.min(1, height / 1440)
    readonly property real bigH: height * 0.7
    readonly property real bigW: Math.min(width * 0.94, bigH * 16 / 9)
    readonly property real centerW: 600 * Math.max(0.75, k)
    readonly property real tile: 110

    SystemClock { id: clock; precision: SystemClock.Seconds }

    component Card: Rectangle {
        default property alias content: inner.data
        radius: Tokens.rounding.large + 4
        color: Theme.surface
        Item { id: inner; anchors.fill: parent; anchors.margins: Tokens.gap.large }
    }

    // ─── фон: обои, мягко размытые ───
    // ─── background: softly blurred wallpaper ───
    Item {
        id: bg
        anchors.fill: parent
        property real amount: w.stage >= 1 && w.stage < 3 ? 1 : 0
        Behavior on amount { Anim { kind: "slowEffects"; duration: 500 } }
        opacity: w.stage >= 1 && w.stage < 3 ? 1 : 0
        Behavior on opacity { Anim { kind: "slowEffects"; duration: 500 } }
        layer.enabled: true
        layer.effect: MultiEffect { autoPaddingEnabled: false; blurEnabled: true; blurMax: 64; blur: bg.amount; brightness: -0.18 * bg.amount }
        Rectangle { anchors.fill: parent; color: Theme.frame }
        Image {
            anchors.fill: parent
            source: "file:///var/lib/nyagreet/wallpaper"
            onStatusChanged: if (status === Image.Error && source.toString().startsWith("file:///var")) source = Quickshell.shellPath("wallpaper")
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    // ─── группа ───
    // ─── group ───
    Item {
        id: box
        anchors.centerIn: parent
        width: w.open ? w.bigW : w.tile
        height: w.open ? w.bigH : w.tile
        scale: w.stage === 1 || w.stage === 2 ? 1 : 0
        rotation: w.stage >= 1 ? 360 : 180
        Behavior on width { Anim { kind: "spatial" } }
        Behavior on height { Anim { kind: "spatial" } }
        Behavior on scale { Anim { kind: "fastSpatial" } }
        Behavior on rotation { Anim { kind: "emphasized"; duration: 420 } }

        Rectangle {
            anchors.fill: parent
            radius: w.open ? Tokens.rounding.extraLarge * 1.5 : w.tile / 4
            color: Theme.frame
            Behavior on radius { Anim { kind: "spatial" } }
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; blurMax: 15; shadowColor: "#b0000000" }
        }
        Icon {
            anchors.centerIn: parent
            name: "pets"; size: 40; color: Theme.accent
            opacity: w.open ? 0 : 1
            Behavior on opacity { Anim { kind: "effects" } }
        }

        Item {
            id: content
            anchors.fill: parent
            anchors.margins: Tokens.gap.large + 4
            opacity: w.open ? 1 : 0
            scale: w.open ? 1 : 0.8
            visible: opacity > 0.01
            Behavior on opacity { Anim { kind: "effects" } }
            Behavior on scale { Anim { kind: "spatial" } }
            readonly property real gap: 20
            readonly property real sideW: (width - w.centerW - gap * 2) / 2

            // ── слева: пользователи и сеансы ──
            // ── left: users and sessions ──
            Column {
                width: content.sideW
                height: parent.height
                spacing: 12
                Card {
                    width: parent.width
                    height: parent.height * 0.55
                    Column {
                        anchors.fill: parent
                        spacing: 6
                        Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent; text: "USER" }
                        Repeater {
                            model: w.g.users.concat([{ name: "", full: Theme.tr("other…", "другой…") }])
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool other: modelData.name === ""
                                readonly property bool sel: other ? w.g.manual : (!w.g.manual && w.g.userIdx === index)
                                width: content.sideW - 32; height: 44; radius: 22
                                color: sel ? Theme.tonalHi : (um.containsMouse ? Theme.surfaceHi : "transparent")
                                Row {
                                    x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                                    Rectangle { width: 28; height: 28; radius: 14; color: parent.parent.sel ? Theme.accent : Theme.surfaceHi
                                                Icon { anchors.centerIn: parent; name: parent.parent.parent.other ? "user" : "pets"; size: 13
                                                       color: parent.parent.parent.sel ? Theme.onAccent : Theme.accent } }
                                    Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.pixelSize: Tokens.font.normal
                                           color: Theme.text; text: modelData.full || modelData.name }
                                }
                                MouseArea { id: um; anchors.fill: parent; hoverEnabled: true
                                            onClicked: { if (parent.other) w.g.manual = true; else { w.g.manual = false; w.g.userIdx = index; } pass.forceActiveFocus(); } }
                            }
                        }
                    }
                }
                Card {
                    width: parent.width
                    height: parent.height * 0.45 - 12
                    Column {
                        anchors.fill: parent
                        spacing: 6
                        Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent; text: Theme.tr("SESSION  ·  TAB", "СЕАНС  ·  TAB") }
                        Repeater {
                            model: w.g.sessions
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool sel: w.g.sessionIdx === index
                                width: content.sideW - 32; height: 38; radius: 19
                                color: sel ? Theme.tonalHi : (sm.containsMouse ? Theme.surfaceHi : "transparent")
                                Text { x: 16; anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font
                                       font.pixelSize: Tokens.font.smaller; color: parent.sel ? Theme.accent : Theme.text; text: modelData.name }
                                MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true
                                            onClicked: { w.g.sessionIdx = index; pass.forceActiveFocus(); } }
                            }
                        }
                    }
                }
            }

            // ── центр ──
            // ── centre ──
            Column {
                x: content.sideW + content.gap
                width: w.centerW
                anchors.verticalCenter: parent.verticalCenter
                spacing: 18

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Text { font.family: Theme.font; font.pixelSize: 130 * Math.max(0.75, w.k); font.bold: true
                           color: Theme.accent; text: Qt.formatDateTime(clock.date, "HH") }
                    Text { font.family: Theme.font; font.pixelSize: 130 * Math.max(0.75, w.k); font.bold: true
                           color: Theme.accent2; text: Qt.formatDateTime(clock.date, "mm") }
                }
                GreeterFace {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: 22 * Math.max(0.8, w.k * 1.1)
                    date: clock.date
                    user: w.g.manual ? w.g.manualName : ((w.g.users[w.g.userIdx]?.full || w.g.users[w.g.userIdx]?.name) ?? "")
                    session: w.g.sessions[w.g.sessionIdx]?.name ?? ""
                    layout: KbLayout.short
                }

                // имя (только для «другого») и пароль
                // name (only for "other") and password
                Rectangle {
                    visible: w.g.manual
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: w.centerW * 0.8; height: 48; radius: 24
                    color: Theme.surface
                    TextInput {
                        id: nameIn
                        anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.font; font.pixelSize: Tokens.font.larger; color: Theme.text
                        onTextChanged: w.g.manualName = text
                        Keys.onReturnPressed: pass.forceActiveFocus()
                        Text { anchors.verticalCenter: parent.verticalCenter; visible: !nameIn.text
                               font.family: Theme.font; font.pixelSize: Tokens.font.normal; color: Theme.textDim; text: "user name" }
                    }
                }

                Rectangle {
                    id: pill
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: w.g.password ? w.centerW * 0.8 : Math.min(w.centerW * 0.8, ph.implicitWidth + 130)
                    height: 56; radius: 28
                    color: Theme.surface
                    border.color: w.g.status === "fail" || w.g.status === "test" ? Theme.danger : "transparent"
                    Behavior on width { Anim { kind: "spatial" } }
                    transform: Translate { id: shake }
                    SequentialAnimation {
                        id: shakeAnim
                        NumberAnimation { target: shake; property: "x"; to: -14; duration: 50 }
                        NumberAnimation { target: shake; property: "x"; to: 12; duration: 70 }
                        NumberAnimation { target: shake; property: "x"; to: -8; duration: 70 }
                        NumberAnimation { target: shake; property: "x"; to: 0; duration: 60 }
                    }
                    Icon { x: 20; anchors.verticalCenter: parent.verticalCenter; name: "lock"; size: 16; color: Theme.textDim }
                    Item {
                        x: 54; width: parent.width - 108; height: parent.height
                        clip: true
                        Text {
                            id: ph
                            anchors.centerIn: parent
                            opacity: w.g.password ? 0 : 1
                            Behavior on opacity { Anim { kind: "effects" } }
                            font.family: Theme.font; font.pixelSize: Tokens.font.normal; color: Theme.textDim
                            text: w.g.status === "check" ? Theme.tr("checking…", "проверяю…") : w.g.message || Theme.tr("enter password", "введи пароль")
                        }
                        ListModel { id: chars }
                        Connections {
                            target: w.g
                            function onPasswordChanged() {
                                const n = w.g.password.length;
                                while (chars.count < n) chars.append({});
                                while (chars.count > n) chars.remove(chars.count - 1);
                            }
                        }
                        ListView {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, contentWidth)
                            height: 22
                            orientation: ListView.Horizontal
                            interactive: false
                            spacing: 4
                            model: chars
                            delegate: Item {
                                id: ch
                                width: 22 * wmul; height: 22
                                property real wmul: 1.3
                                readonly property int kind: Math.floor(Math.random() * 8)
                                LockShape { id: fig; anchors.centerIn: parent; size: 22; kind: ch.kind; color: Theme.accent; scale: 0 }
                                Rectangle { id: dot; anchors.centerIn: parent; width: 22; height: 22; radius: 11; color: Theme.accent; opacity: 0 }
                                SequentialAnimation {
                                    running: true
                                    ParallelAnimation {
                                        Anim { target: fig; property: "scale"; from: 0; to: 1; kind: "fastSpatial" }
                                        Anim { target: fig; property: "rotation"; from: -90; to: 0; kind: "fastSpatial" }
                                    }
                                    PauseAnimation { duration: 180 }
                                    ParallelAnimation {
                                        Anim { target: fig; property: "opacity"; to: 0; kind: "fastEffects" }
                                        Anim { target: dot; property: "opacity"; to: 1; kind: "fastEffects" }
                                        Anim { target: dot; property: "scale"; from: 1; to: 2 / 3; kind: "fastSpatial" }
                                        Anim { target: ch; property: "wmul"; to: 1; kind: "effects" }
                                    }
                                }
                            }
                        }
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40; height: 40
                        radius: w.g.password ? 14 : 20
                        color: w.g.password ? Theme.accent : Theme.surfaceHi
                        Behavior on radius { Anim { kind: "fastSpatial" } }
                        Behavior on color { CAnim {} }
                        Icon { anchors.centerIn: parent; name: "chevron_right"; size: 14
                               color: w.g.password ? Theme.onAccent : Theme.textDim }
                        MouseArea { anchors.fill: parent; onClicked: w.g.login() }
                    }
                    TextInput {
                        id: pass
                        anchors.fill: parent
                        opacity: 0
                        focus: true
                        echoMode: TextInput.Password
                        text: w.g.password
                        onTextChanged: w.g.password = text
                        Component.onCompleted: forceActiveFocus()
                        Keys.onReturnPressed: w.g.login()
                        Keys.onEnterPressed: w.g.login()
                        Keys.onEscapePressed: text = ""
                        Keys.onTabPressed: w.g.sessionIdx = (w.g.sessionIdx + 1) % Math.max(1, w.g.sessions.length)
                    }
                }
            }

            // ── справа: раскладка и питание ──
            // ── right: layout and power ──
            Column {
                x: content.sideW + content.gap * 2 + w.centerW
                width: content.sideW
                height: parent.height
                spacing: 12
                Card {
                    width: parent.width
                    height: 130
                    Column {
                        anchors.fill: parent
                        spacing: 10
                        Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent; text: Theme.tr("KEYBOARD", "РАСКЛАДКА") }
                        Rectangle {
                            width: kbt.implicitWidth + 36; height: 44; radius: 22
                            color: Theme.tonalHi
                            Text { id: kbt; anchors.centerIn: parent; font.family: Theme.font; font.bold: true
                                   font.pixelSize: Tokens.font.larger; color: Theme.accent; text: KbLayout.short || "—" }
                            MouseArea { anchors.fill: parent; onClicked: { KbLayout.next(); pass.forceActiveFocus(); } }
                        }
                    }
                }
                Card {
                    width: parent.width
                    height: parent.height - 142
                    Column {
                        anchors.fill: parent
                        spacing: 8
                        Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent; text: "POWER" }
                        Repeater {
                            model: [["sleep", "sleep", ["sh", "-c", "systemctl suspend 2>/dev/null || loginctl suspend"]],
                                    ["restart_alt", "reboot", ["sh", "-c", "systemctl reboot 2>/dev/null || loginctl reboot"]],
                                    ["power_settings_new", "power off", ["sh", "-c", "systemctl poweroff 2>/dev/null || loginctl poweroff"]]]
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: content.sideW - 32; height: 44; radius: 22
                                color: pm.containsMouse ? Theme.surfaceHi : "transparent"
                                Row {
                                    x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                                    Icon { name: modelData[0]; size: 15; color: index === 2 ? Theme.danger : Theme.accent }
                                    Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font
                                           font.pixelSize: Tokens.font.normal; color: Theme.text; text: modelData[1] }
                                }
                                MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; onClicked: Quickshell.execDetached(modelData[2]) }
                            }
                        }
                        Item { width: 1; height: 12 }
                        Text {
                            visible: !Greetd.available
                            width: content.sideW - 32; wrapMode: Text.Wrap
                            font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                            text: Theme.tr("test mode — greetd is not running", "тестовый режим — greetd не запущен")
                        }
                    }
                }
            }
        }
    }
}
