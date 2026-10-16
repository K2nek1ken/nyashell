import Quickshell
import QtQuick

// «циферблат» Nothing OS 5.0 для экрана входа: дата, приветствие, сеанс, раскладка
// Nothing OS 5.0 style "dial" for the login screen: date, greeting, session, layout
Item {
    id: gf
    property real size: 26
    property var date: new Date()
    property string user: ""
    property string session: ""
    property string layout: ""
    property color ink: Theme.text
    property color knock: Theme.frame
    readonly property var loc: Qt.locale("en_GB")
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    component Word: Text {
        font.family: Theme.font
        font.pixelSize: gf.size
        font.capitalization: Font.AllUppercase
        color: gf.ink
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }
    component Pill: Rectangle {
        property string text: ""
        property bool filled: true
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        implicitWidth: pt.implicitWidth + gf.size * 0.6
        implicitHeight: gf.size * 1.25
        radius: height / 2
        color: filled ? gf.ink : "transparent"
        border.width: filled ? 0 : Math.max(1.5, gf.size * 0.06)
        border.color: gf.ink
        Text { id: pt; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: gf.size * 0.95; font.bold: true
               font.capitalization: Font.AllUppercase; color: parent.filled ? gf.knock : gf.ink; text: parent.text }
    }

    Column {
        id: col
        spacing: gf.size * 0.2
        Row {
            spacing: gf.size * 0.25
            Word { text: gf.loc.toString(gf.date, "ddd") }
            Pill { text: gf.date.getDate() }
            Pill { text: gf.loc.toString(gf.date, "MMM"); filled: false }
        }
        Row {
            spacing: gf.size * 0.25
            Word { text: "hello," }
            Pill { text: gf.user || "…" }
        }
        Row {
            spacing: gf.size * 0.25
            Icon { name: "dashboard"; size: gf.size * 0.85; color: gf.ink; anchors.verticalCenter: parent.verticalCenter }
            Word { text: gf.session || "session" }
            Pill { text: gf.layout; filled: false; visible: gf.layout !== "" }
        }
    }
}
