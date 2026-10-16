import Quickshell
import QtQuick

// меню питания по центру (Super+Space): стрелки + Enter, Esc — закрыть
// power menu in the centre (Super+Space): arrows + Enter, Esc to close
CenterPopup {
    id: pm
    open: ShellState.powerOpen
    onDismissed: ShellState.powerOpen = false
    onOpenChanged: { if (open) { sel = 0; keys.forceActiveFocus(); } }
    cardWidth: 5 * 104 + 4 * 10 + 48
    cardHeight: 196
    property int sel: 0

    // все действия; порядок задаётся в настройках (Look → Power menu order)
    // all actions; the order is set in the settings (Look → Power menu order)
    readonly property var all: ({
        lock:     ["lock", L.t("блокировка"), () => { ShellState.lock(); }],
        sleep:    ["sleep", L.t("сон"), () => ShellState.sleepNow()],
        logout:   ["logout", L.t("выход"), () => ShellState.leave(["mmsg", "dispatch", "quit"])],
        reboot:   ["restart_alt", L.t("ребут"), () => ShellState.leave(["sh", "-c", "systemctl reboot 2>/dev/null || loginctl reboot"])],
        poweroff: ["power_settings_new", L.t("выкл"), () => ShellState.leave(["sh", "-c", "systemctl poweroff 2>/dev/null || loginctl poweroff"])]
    })
    readonly property var order: ShellState.settings.powerOrder ?? ["lock", "sleep", "logout", "reboot", "poweroff"]
    readonly property var items: order.filter(k => all[k]).map(k => all[k])
    function run(i: int): void { ShellState.powerOpen = false; items[i][2](); }

    Item {
        id: keys
        focus: true
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) ShellState.powerOpen = false;
            else if (e.key === Qt.Key_Left || ShellState.keyIs(e, "a")) pm.sel = (pm.sel + pm.items.length - 1) % pm.items.length;
            else if (e.key === Qt.Key_Right || ShellState.keyIs(e, "d") || e.key === Qt.Key_Tab) pm.sel = (pm.sel + 1) % pm.items.length;
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) pm.run(pm.sel);
            else return;
            e.accepted = true;
        }
    }

    Text {
        font.family: Theme.font
        anchors.horizontalCenter: parent.horizontalCenter
        y: 20
        text: L.t("до встречи, ") + ShellState.userName + ""
        color: Theme.textDim
        font.pixelSize: Tokens.font.smaller
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 52
        spacing: 10
        Repeater {
            model: pm.items
            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool hot: pm.sel === index
                width: 104; height: 116
                radius: hot ? Tokens.rounding.extraLarge : 52
                color: hot ? (modelData[0] === "power_settings_new" ? Theme.danger : Theme.accent) : Theme.surface
                border.color: hot ? "transparent" : Theme.outline
                Behavior on radius { Anim { kind: "fastSpatial" } }
                Behavior on color { CAnim {} }
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; name: modelData[0]; size: 26
                           color: parent.parent.hot ? Theme.onAccent : Theme.accent }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.font
                           font.pixelSize: Tokens.font.normal; text: modelData[1]
                           color: parent.parent.hot ? Theme.onAccent : Theme.text }
                }
                StateLayer {
                    radius: parent.radius
                    onContainsMouseChanged: if (containsMouse) pm.sel = index
                    onClicked: pm.run(index)
                }
            }
        }
    }
}
