import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// меню значка в трее — пункты берём у самого приложения (как в KDE), а рисуем в нашем стиле.
// подменю открываются на месте, со строкой «назад»
// a tray icon's menu: the items come from the app itself (as in KDE), drawn in our style.
// submenus open in place, with a "back" row
PanelWindow {
    id: tm
    property var rootMenu: null        // QsMenuHandle из SystemTrayItem.menu / QsMenuHandle from SystemTrayItem.menu
    property var stack: []             // открытые подменю / open submenus
    property real px: 0
    property real py: 0
    readonly property var current: stack.length ? stack[stack.length - 1] : rootMenu

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"

    property string appId: ""          // Id значка в трее (по нему находим процесс) / the tray icon's Id (used to find the process)
    property string appTitle: ""
    function openFor(menuHandle, x: real, y: real, id: string, title: string): void {
        rootMenu = menuHandle; stack = []; px = x; py = y; appId = id || ""; appTitle = title || ""; visible = true; pop.restart();
    }
    function close(): void { visible = false; stack = []; }

    QsMenuOpener { id: opener; menu: tm.current }

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: tm.close() }
    Item { focus: true; Keys.onEscapePressed: tm.stack.length ? tm.stack = tm.stack.slice(0, -1) : tm.close() }

    Rectangle {
        id: box
        width: 250
        height: col.implicitHeight + 12
        x: Math.max(8, Math.min(tm.px - width / 2, tm.width - width - 8))
        y: Math.max(8, tm.py - height - 10)
        radius: Tokens.rounding.large
        color: Theme.frame
        border.color: Theme.outline
        transformOrigin: Item.Bottom
        Behavior on height { Anim { kind: "fastSpatial" } }
        ParallelAnimation {
            id: pop
            NumberAnimation { target: box; property: "scale"; from: 0.92; to: 1; duration: 170; easing.type: Easing.OutBack }
            NumberAnimation { target: box; property: "opacity"; from: 0; to: 1; duration: 140 }
        }
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            x: 6; y: 6
            width: parent.width - 12
            // «назад» из подменю
            // "back" from a submenu
            Rectangle {
                visible: tm.stack.length > 0
                width: parent.width; height: 34; radius: 17
                color: bm.containsMouse ? Theme.surface : "transparent"
                Row {
                    x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    Icon { name: "chevron_left"; size: 11; color: Theme.accent }
                    Text { font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.accent; text: L.t("назад") }
                }
                MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; onClicked: tm.stack = tm.stack.slice(0, -1) }
            }
            Repeater {
                model: opener.children
                delegate: Item {
                    id: it
                    required property var modelData
                    required property int index
                    width: col.width
                    height: modelData.isSeparator ? 9 : 34
                    StaggerIn { index: parent.index; step: 25; active: tm.visible }
                    Rectangle {
                        visible: it.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 20; height: 1
                        color: Theme.line
                    }
                    Rectangle {
                        visible: !it.modelData.isSeparator
                        anchors.fill: parent
                        radius: 17
                        color: im.containsMouse && it.modelData.enabled ? Theme.surface : "transparent"
                        Row {
                            x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                            opacity: it.modelData.enabled ? 1 : 0.4
                            // галочка/радио, если пункт с отметкой
                            // check/radio mark if the item has one
                            Rectangle {
                                visible: it.modelData.buttonType !== QsMenuButtonType.None
                                width: 14; height: 14; anchors.verticalCenter: parent.verticalCenter
                                radius: it.modelData.buttonType === QsMenuButtonType.RadioButton ? 7 : 4
                                color: it.modelData.checkState === Qt.Checked ? Theme.accent : "transparent"
                                border.color: Theme.accent
                            }
                            IconImage {
                                visible: it.modelData.icon !== ""
                                implicitSize: 16; anchors.verticalCenter: parent.verticalCenter
                                source: it.modelData.icon
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: col.width - 90
                                elide: Text.ElideRight
                                font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text
                                text: it.modelData.text.replace(/&(?!&)/g, "")      // «&» — метка горячей клавиши в Qt/GTK / "&" is the mnemonic marker in Qt/GTK
                            }
                        }
                        Icon { visible: it.modelData.hasChildren; anchors.right: parent.right; anchors.rightMargin: 12
                               anchors.verticalCenter: parent.verticalCenter; name: "chevron_right"; size: 10; color: Theme.textDim }
                        MouseArea {
                            id: im
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: it.modelData.enabled
                            onClicked: {
                                if (it.modelData.hasChildren) { tm.stack = tm.stack.concat([it.modelData]); return; }
                                it.modelData.triggered();
                                tm.close();
                            }
                        }
                    }
                }
            }
            // наш пункт — всегда снизу: приложение не всегда закрывается своими кнопками (особенно Steam)
            // our item is always at the bottom: an app doesn't always close with its own buttons (Steam especially)
            Rectangle { visible: tm.stack.length === 0; width: col.width - 20; x: 10; height: 1; color: Theme.line }
            // процесс ищется по самому значку: через D-Bus узнаём, какая программа его повесила (см. kill-app.sh -t)
            // the process is found from the icon itself: D-Bus tells which program put it up (see kill-app.sh -t)
            Rectangle {
                visible: tm.stack.length === 0 && (tm.appId !== "" || tm.appTitle !== "")
                width: col.width; height: 34; radius: 17
                color: km.containsMouse ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.15) : "transparent"
                Behavior on color { CAnim {} }
                Row {
                    x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "close"; size: 12; color: Theme.danger }
                    Text { anchors.verticalCenter: parent.verticalCenter; width: col.width - 50; elide: Text.ElideRight
                           font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                           color: km.containsMouse ? Theme.danger : Theme.text; text: L.t("завершить принудительно") }
                }
                MouseArea { id: km; anchors.fill: parent; hoverEnabled: true
                            onClicked: { Quickshell.execDetached(["sh", Quickshell.shellPath("kill-app.sh"), "-t", tm.appId, tm.appTitle]); tm.close(); } }
            }
        }
    }
}
