import QtQuick

// календарь: неделя с понедельника, русские названия, листается стрелками и колесом
// calendar: weeks start on Monday, localised names, flips with arrows and the wheel
Item {
    id: cal
    property date today: new Date()
    property int month: today.getMonth()
    property int year: today.getFullYear()
    readonly property var loc: L.locale
    implicitHeight: col.implicitHeight

    function shift(d: int): void {
        let m = month + d, y = year;
        if (m < 0) { m = 11; y--; } else if (m > 11) { m = 0; y++; }
        month = m; year = y;
    }
    // 6 недель начиная с понедельника
    // 6 weeks starting from Monday
    readonly property var cells: {
        const first = new Date(year, month, 1);
        const offset = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) out.push(new Date(year, month, 1 - offset + i));
        return out;
    }

    Column {
        id: col
        width: parent.width
        spacing: 6

        Item {
            width: parent.width
            height: 24
            Text {
                font.family: Theme.font
                anchors.centerIn: parent
                text: cal.loc.standaloneMonthName(cal.month, Locale.LongFormat) + " " + cal.year
                color: Theme.text
                font.pixelSize: Tokens.font.normal
                font.bold: true
            }
            Repeater {
                model: [[-1, "chevron_left"], [1, "chevron_right"]]
                delegate: Item {
                    required property var modelData
                    width: 26; height: 26
                    x: modelData[0] < 0 ? 0 : parent.width - width
                    Icon { anchors.centerIn: parent; name: modelData[1]; size: 11; color: Theme.textDim }
                    StateLayer { radius: 13; onClicked: cal.shift(modelData[0]) }
                }
            }
        }

        Grid {
            columns: 7
            width: parent.width
            readonly property real cw: width / 7

            Repeater {
                model: [L.t("пн"), L.t("вт"), L.t("ср"), L.t("чт"), L.t("пт"), L.t("сб"), L.t("вс")]
                delegate: Text {
                    required property string modelData
                    required property int index
                    font.family: Theme.font
                    width: parent.cw
                    height: 20
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: index >= 5 ? Theme.accent : Theme.textDim
                    font.pixelSize: Tokens.font.small
                }
            }
            Repeater {
                model: cal.cells
                delegate: Item {
                    required property var modelData
                    readonly property bool inMonth: modelData.getMonth() === cal.month
                    readonly property bool isToday: modelData.toDateString() === cal.today.toDateString()
                    width: parent.cw
                    height: 22
                    Rectangle {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        radius: 7
                        rotation: 45                 // «бриллиант» для сегодняшнего дня / a "diamond" for today
                        visible: parent.isToday
                        color: Theme.accent
                    }
                    Text {
                        font.family: Theme.font
                        anchors.centerIn: parent
                        text: modelData.getDate()
                        color: parent.isToday ? Theme.onAccent : parent.inMonth ? Theme.text : Theme.textDim
                        opacity: parent.inMonth ? 1 : 0.45
                        font.pixelSize: Tokens.font.smaller
                        font.bold: parent.isToday
                    }
                }
            }
        }
    }

    WheelHandler { onWheel: (e) => cal.shift(e.angleDelta.y > 0 ? -1 : 1) }
}
