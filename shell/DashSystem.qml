import QtQuick

// вкладка «система» по мотивам «Performance» caelestia: индикаторы, графики истории, сеть
// "system" tab after caelestia's "Performance": gauges, history graphs, network
Item {
    id: ds
    readonly property real pad: Tokens.gap.large
    readonly property real gap: Tokens.gap.small
    readonly property real w: width - pad * 2

    // верх: четыре индикатора
    // top: four gauges
    Row {
        x: ds.pad
        spacing: ds.gap
        Repeater {
            model: [
                ["memory", L.t("процессор"), () => SysInfo.cpu, () => Math.round(SysInfo.cpu * 100) + "%", false],
                ["dashboard", L.t("память"), () => SysInfo.mem, () => SysInfo.memUsedGb.toFixed(1) + " / " + SysInfo.memTotalGb.toFixed(1) + L.t(" ГБ"), true],
                ["hdd", L.t("диск /"), () => SysInfo.disk, () => SysInfo.diskText, false],
                ["thermo", L.t("температура"), () => Math.min(1, SysInfo.temp / 100), () => Math.round(SysInfo.temp) + " °C", true]
            ]
            delegate: Card {
                required property var modelData
                width: (ds.w - ds.gap * 3) / 4
                height: 128
                Row {
                    anchors.centerIn: parent
                    spacing: 12
                    Gauge { size: 76; thickness: 8; icon: modelData[0]; value: modelData[2]()
                            color: modelData[4] ? Theme.accent2 : Theme.accent }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { font.family: Theme.font; font.pixelSize: Tokens.font.normal; font.bold: true; color: Theme.text
                               text: modelData[3]() }
                        Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: modelData[1] }
                    }
                }
            }
        }
    }

    // низ: графики и сеть
    // bottom: graphs and network
    Row {
        x: ds.pad
        y: 128 + ds.gap
        spacing: ds.gap
        readonly property real hh: ds.height - 128 - ds.gap

        Repeater {
            model: [[L.t("процессор, 2 мин"), () => SysInfo.cpuHist, false], [L.t("память, 2 мин"), () => SysInfo.memHist, true]]
            delegate: Card {
                required property var modelData
                width: (ds.w - ds.gap * 2) * 0.36
                height: parent.hh
                Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: modelData[0] }
                Spark {
                    y: 22
                    width: parent.width
                    height: parent.height - 22
                    values: modelData[1]()
                    color: modelData[2] ? Theme.accent2 : Theme.accent
                }
            }
        }
        Card {
            width: (ds.w - ds.gap * 2) * 0.28
            height: parent.hh
            Column {
                anchors.centerIn: parent
                spacing: 12
                Repeater {
                    model: [["▼", L.t("загрузка"), () => SysInfo.rxRate], ["▲", L.t("отдача"), () => SysInfo.txRate]]
                    delegate: Row {
                        required property var modelData
                        spacing: 10
                        Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font
                               font.pixelSize: 16; color: Theme.accent; text: modelData[0] }
                        Column {
                            Text { font.family: Theme.font; font.pixelSize: Tokens.font.larger; font.bold: true; color: Theme.text
                                   text: SysInfo.human(modelData[2]()) }
                            Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: modelData[1] }
                        }
                    }
                }
                Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                       text: L.t("в сети ") + SysInfo.uptimeText }
            }
        }
    }
}
