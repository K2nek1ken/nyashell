import QtQuick

// плитка быстрых настроек: включена — акцентная и чуть «квадратнее» (morph формы как в M3 Expressive),
// выключена — таблетка. Клик — переключить, стрелка справа — подробности.
// a quick settings tile: on, it's accent-coloured and a bit "squarer" (shape morph as in M3 Expressive),
// off, it's a pill. Click to toggle, the arrow on the right for details.
Rectangle {
    id: t
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool hasMore: false
    signal toggled()
    signal more()

    implicitHeight: 62
    radius: active ? 20 : height / 2
    color: active ? Theme.accent : (ma.containsMouse ? Theme.surfaceHi : Theme.surface)
    border.color: active ? "transparent" : Theme.outline
    border.width: 1
    Behavior on radius { NumberAnimation { duration: Theme.springMs; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
    Behavior on color  { ColorAnimation { duration: Theme.anim } }
    scale: ma.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 120 } }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: 14
        spacing: 10
        Rectangle {
            width: 34; height: 34; radius: 17
            anchors.verticalCenter: parent.verticalCenter
            color: t.active ? Qt.rgba(Theme.onAccent.r, Theme.onAccent.g, Theme.onAccent.b, 0.12) : Theme.tonal
            Icon { anchors.centerIn: parent; name: t.icon; size: 15; color: t.active ? Theme.onAccent : Theme.accent }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: t.width - 14 - 34 - 10 - (t.hasMore ? 40 : 14)
            Text {
                font.family: Theme.font
                width: parent.width
                elide: Text.ElideRight
                text: t.title
                color: t.active ? Theme.onAccent : Theme.text
                font.pixelSize: 13
                font.bold: true
            }
            Text {
                font.family: Theme.font
                visible: text.length > 0
                width: parent.width
                elide: Text.ElideRight
                text: t.subtitle
                color: t.active ? Qt.rgba(Theme.onAccent.r, Theme.onAccent.g, Theme.onAccent.b, 0.7) : Theme.textDim
                font.pixelSize: 10
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.rightMargin: t.hasMore ? 36 : 0
        hoverEnabled: true
        onClicked: t.toggled()
    }
    // «›» — открыть подробности
    // "›": open the details
    Item {
        visible: t.hasMore
        width: 36
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        Text {
            font.family: Theme.font
            anchors.centerIn: parent
            text: "›"
            font.pixelSize: 22
            color: t.active ? Theme.onAccent : Theme.textDim
        }
        MouseArea { anchors.fill: parent; onClicked: t.more() }
    }
}
