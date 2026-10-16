import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// универсальное меню: прозрачный оверлей на весь экран, клик мимо или Esc закрывают
// items: [{ icon, text, action, danger }]
// a general-purpose menu: a transparent full-screen overlay, click outside or Esc to close
// items: [{ icon, text, action, danger }]
PanelWindow {
    id: menu
    property var items: []
    property real px: 0
    property real py: 0
    property bool above: false      // true — меню над точкой, по центру (для панели) / true: the menu goes above the point, centred (for the bar)

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    // по умолчанию меню встаёт под курсором (левый верхний угол — в точке клика);
    // не влезает снизу — открывается над курсором, справа — левее. up=true — над точкой, по центру
    // by default the menu opens under the cursor (top-left corner at the click point);
    // if it doesn't fit below it opens above the cursor, on the right edge further left. up=true: above the point, centred
    function openAt(x: real, y: real, up: bool): void {
        closeAnim.stop();            // меню могли открыть заново, пока старое ещё гасло / the menu may have been reopened while the old one was still fading
        px = x; py = y; above = up; closing = false;
        if (visible) popAnim.restart(); else visible = true;
    }
    property bool closing: false
    function close(): void { if (visible && !closing) { closing = true; closeAnim.restart(); } }

    onVisibleChanged: if (visible) { popAnim.restart(); keys.forceActiveFocus(); }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: menu.close()
    }
    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: menu.close()
    }

    Rectangle {
        id: box
        width: 230
        height: col.implicitHeight + 12
        readonly property bool flipY: !menu.above && menu.py + height + 8 > menu.height
        readonly property bool flipX: !menu.above && menu.px + width + 8 > menu.width
        x: Math.max(8, Math.min(menu.above ? menu.px - width / 2 : (flipX ? menu.px - width : menu.px), menu.width - width - 8))
        y: Math.max(8, Math.min(menu.above ? menu.py - height - 10 : (flipY ? menu.py - height : menu.py), menu.height - height - 8))
        radius: Tokens.rounding.large
        color: Theme.frame                              // цвета рамки, без прозрачности / frame colour, no transparency
        border.color: Theme.line
        transformOrigin: menu.above ? Item.Bottom : (flipY ? (flipX ? Item.BottomRight : Item.BottomLeft) : (flipX ? Item.TopRight : Item.TopLeft))

        ParallelAnimation {
            id: popAnim
            NumberAnimation { target: box; property: "scale";   from: 0.9; to: 1; duration: 170; easing.type: Easing.OutBack }
            NumberAnimation { target: box; property: "opacity"; from: 0;   to: 1; duration: 140 }
        }
        SequentialAnimation {
            id: closeAnim
            ParallelAnimation {
                NumberAnimation { target: box; property: "scale";   to: 0.94; duration: 110; easing.type: Easing.InQuad }
                NumberAnimation { target: box; property: "opacity"; to: 0;    duration: 110 }
            }
            ScriptAction { script: { menu.visible = false; menu.closing = false; } }
        }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2
            Repeater {
                model: menu.items
                delegate: Item {
                    id: it
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: modelData.separator ? 9 : 34
                    StaggerIn { index: parent.index; step: 22; active: menu.visible && !menu.closing }
                    Rectangle { visible: !!it.modelData.separator; anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Theme.line }
                    Rectangle {
                        visible: !it.modelData.separator
                        anchors.fill: parent
                        radius: 17
                        color: im.containsMouse && it.modelData.enabled !== false ? (it.modelData.danger ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.15) : Theme.surfaceHi) : "transparent"
                        opacity: it.modelData.enabled === false ? 0.4 : 1
                        Behavior on color { CAnim {} }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 12
                            spacing: 10
                            Icon { anchors.verticalCenter: parent.verticalCenter; name: it.modelData.icon ?? ""; size: 15
                                   color: it.modelData.danger ? Theme.danger : Theme.accent }
                            Text {
                                font.family: Theme.font
                                anchors.verticalCenter: parent.verticalCenter
                                width: col.width - 50
                                elide: Text.ElideRight
                                text: it.modelData.text ?? ""
                                color: it.modelData.danger ? Theme.danger : Theme.text
                                font.pixelSize: Tokens.font.normal
                            }
                        }
                        Icon { visible: !!it.modelData.checked; anchors.right: parent.right; anchors.rightMargin: 12
                               anchors.verticalCenter: parent.verticalCenter; name: "check"; size: 11; color: Theme.accent }
                        MouseArea {
                            id: im
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: it.modelData.enabled !== false
                            onClicked: { menu.close(); it.modelData.action?.(); }
                        }
                    }
                }
            }
        }
    }
}
