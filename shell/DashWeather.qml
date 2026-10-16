import QtQuick
import QtQuick.Layouts

// вкладка «погода»: сейчас, по часам, на три дня
// weather tab: now, hourly, three days
Item {
    readonly property var loc: L.locale

    Text {
        anchors.centerIn: parent
        visible: !Weather.ok
        font.family: Theme.font
        color: Theme.textDim
        horizontalAlignment: Text.AlignHCenter
        text: L.t("погоды пока нет — ") + (Weather.lastError || L.t("жду ответа от Open-Meteo…")) + L.t("\nпопробую снова через минуту")
    }

    // явная геометрия вместо Layout-ов
    // explicit geometry instead of Layouts
    Item {
        id: wx
        visible: Weather.ok
        anchors.fill: parent
        anchors.leftMargin: Tokens.gap.large
        anchors.rightMargin: Tokens.gap.large
        readonly property real gap: Tokens.gap.small
        readonly property real topH: 140
        readonly property real sideW: 280
        readonly property real smallW: (width - sideW - gap * 5) / 5

            Card {
                x: 0; y: 0
                width: wx.sideW; height: wx.topH
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 8
                    spacing: 18
                    Icon { name: Weather.iconFor(Weather.code, !Weather.isDay); size: 64; color: Theme.accent
                           anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text { font.family: Theme.font; font.pixelSize: 40; font.bold: true; color: Theme.text; text: Weather.temp + "°" }
                        Text { font.family: Theme.font; font.pixelSize: Tokens.font.normal; color: Theme.text; text: Weather.desc }
                        Row {
                            spacing: 4
                            Icon { name: "place"; size: 11; color: Theme.accent }
                            Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                                   text: Weather.city + (Weather.source === "wifi" ? L.t(" · по Wi-Fi") : Weather.source === "ip" ? L.t(" · по IP") : Weather.source === "manual" ? "" : L.t(" · запасной город")) }
                        }
                        Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                               text: L.t("восход ") + Weather.sunrise + L.t(" · закат ") + Weather.sunset }
                    }
                }
            }
          Row {
            x: wx.sideW + wx.gap
            spacing: wx.gap
            Repeater {
                model: [
                    ["thermo", L.t("ощущается"), () => Weather.feels + "°"],
                    ["w_drop", L.t("влажность"), () => Weather.humidity + "%"],
                    ["w_wind", L.t("ветер"), () => Weather.wind.toFixed(1) + L.t(" м/с")],
                    ["dashboard", L.t("давление"), () => Weather.pressure + L.t(" мм")],
                    ["w_sunny", L.t("УФ-индекс"), () => Weather.uv.toFixed(0)]
                ]
                delegate: Card {
                    required property var modelData
                    width: wx.smallW
                    height: wx.topH
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: modelData[0]; size: 20; color: Theme.accent }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.font
                               font.pixelSize: Tokens.font.large; font.bold: true; color: Theme.text; text: modelData[2]() }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.font
                               font.pixelSize: Tokens.font.small; color: Theme.textDim; text: modelData[1] }
                    }
                }
            }

          }

            // сегодня по часам
            // today by the hour
            Card {
                x: 0; y: wx.topH + wx.gap
                width: wx.width - wx.sideW - wx.gap
                height: wx.height - wx.topH - wx.gap
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Repeater {
                        model: Weather.hours
                        delegate: Column {
                            required property var modelData
                            width: 48
                            spacing: 6
                            Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.font
                                   font.pixelSize: Tokens.font.small; color: Theme.textDim
                                   text: String(modelData.h).padStart(2, "0") + ":00" }
                            Icon { anchors.horizontalCenter: parent.horizontalCenter; size: 18; color: Theme.accent
                                   name: Weather.iconFor(modelData.code, modelData.h < 6 || modelData.h >= 21) }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.font
                                   font.pixelSize: Tokens.font.normal; color: Theme.text; text: modelData.temp + "°" }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.font
                                   font.pixelSize: Tokens.font.small; color: Theme.accent2
                                   text: modelData.pop > 0 ? modelData.pop + "%" : " " }
                        }
                    }
                }
            }
            // неделя
            // week
            Card {
                x: wx.width - wx.sideW; y: wx.topH + wx.gap
                width: wx.sideW
                height: wx.height - wx.topH - wx.gap
                Column {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 3
                    Repeater {
                        model: Weather.days.slice(0, 7)
                        delegate: Row {
                            required property var modelData
                            required property int index
                            spacing: 10
                            Text { width: 70; font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text
                                   anchors.verticalCenter: parent.verticalCenter
                                   text: index === 0 ? L.t("сегодня") : index === 1 ? L.t("завтра")
                                       : loc.toString(new Date(modelData.date), "ddd, d") }
                            Icon { name: Weather.iconFor(modelData.code, false); size: 13; color: Theme.accent
                                   anchors.verticalCenter: parent.verticalCenter }
                            Text { font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text
                                   anchors.verticalCenter: parent.verticalCenter
                                   text: modelData.max + "° / " + modelData.min + "°" }
                            Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent2
                                   anchors.verticalCenter: parent.verticalCenter
                                   text: modelData.pop > 0 ? modelData.pop + "%" : "" }
                        }
                    }
                }
            }
    }
}
