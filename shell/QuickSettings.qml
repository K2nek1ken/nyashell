import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// шторка быстрых настроек (Pixel × Caelestia): ползунки, плитки, подстраницы
// quick settings panel (Pixel × Caelestia): sliders, tiles, subpages
BarPopup {
    id: qs
    property string page: ""           // "" | "wifi" | "bt" | "audio" | "notifs" | "battery"
    property string fixedPage: ""      // если задано — это отдельный виджет одного менеджера, без главной страницы / if set, this is a separate widget for one manager, without the main page
    signal requestPage(string pg)      // из общей шторки: открыть отдельный виджет менеджера / from the shared panel: open a manager's separate widget
    property bool netAdding: false     // форма «добавить сеть» / the "add a network" form
    property string newSsid: ""
    property string newPw: ""
    property bool newHidden: false
    function addNet(): void {
        if (!newSsid) return;
        Net.add(newSsid, newPw, newHidden);
        netAdding = false;
    }
    property string netDetails: ""     // настройки выбранной сети / settings of the selected network
    property string btDetails: ""      // сведения об устройстве bluetooth / bluetooth device details

    ContextMenu { id: rowMenu; screen: qs.screen }
    function openMenu(item, items, m): void {
        const p = item.mapToItem(null, m ? m.x : item.width / 2, m ? m.y : item.height / 2);
        rowMenu.items = items;
        rowMenu.openAt(p.x, p.y, false);
    }
    property bool powerOpen: false
    property var batteryPct: 100
    property bool charging: false

    cardWidth: 390
    cardHeight: page === "" ? mainCol.implicitHeight + 32 : 460

    onVisibleChanged: {
        if (!visible) { netAdding = false; netDetails = ""; btDetails = ""; }
        if (visible && page === "notifs") Notifs.markRead()
    }
    function show(x: real, pg: string): void {
        page = fixedPage || pg || "";
        powerOpen = false;
        Net.refresh(pg === "wifi");
        Bt.refresh();
        openAt(x);
    }
    onPageChanged: { if (page === "wifi") Net.refresh(true); if (page === "notifs") Notifs.markRead(); }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // устройство звука — карточка со значком в плашке; текущее — цвета акцента с галочкой
    // an audio device: a card with an icon in a chip; the current one in the accent colour with a check mark
    component DevRow: Rectangle {
        id: dr
        property var node
        property bool current: false
        property string icon: "headphones"
        signal picked()
        height: 50
        radius: 16
        color: current ? Theme.tonalHi : (dm2.containsMouse ? Theme.surfaceHi : Theme.surface)
        Rectangle {
            x: 8; anchors.verticalCenter: parent.verticalCenter
            width: 34; height: 34; radius: 11
            color: dr.current ? Theme.accent : Theme.surfaceHi
            Icon { anchors.centerIn: parent; name: dr.icon; size: 14; color: dr.current ? Theme.onAccent : Theme.accent }
        }
        Text { x: 52; anchors.verticalCenter: parent.verticalCenter; width: dr.width - 90; elide: Text.ElideRight
               font.family: Theme.font; font.pixelSize: Tokens.font.smaller
               color: dr.current ? Theme.accent : Theme.text
               text: dr.node ? (dr.node.description || dr.node.nickname || dr.node.name) : "" }
        Icon { visible: dr.current; anchors.right: parent.right; anchors.rightMargin: 14
               anchors.verticalCenter: parent.verticalCenter; name: "check"; size: 12; color: Theme.accent }
        MouseArea { id: dm2; anchors.fill: parent; hoverEnabled: true; onClicked: dr.picked() }
    }
    component Head: Text {
        font.family: Theme.font; font.pixelSize: Tokens.font.small; font.bold: true; color: Theme.accent
        topPadding: 10
    }


    Item {
        anchors.fill: parent
        anchors.margins: 16
        clip: true

        // ════════ главная ════════
        // ════════ main ════════
        ColumnLayout {
            id: mainCol
            width: parent.width
            x: qs.page === "" ? 0 : -parent.width - 20
            opacity: qs.page === "" ? 1 : 0
            spacing: 12
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            // шапка: дата, батарея, кнопки
            // header: date, battery, buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Column {
                    Layout.fillWidth: true
                    Text {
                        font.family: Theme.font
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: Theme.text
                        font.pixelSize: 26
                        font.bold: true
                    }
                    Text {
                        font.family: Theme.font
                        text: L.locale.toString(clock.date, "dddd, d MMMM") + (Power.present ? "  ·  " + Math.round(qs.batteryPct) + "%" + (qs.charging ? L.t(" · заряжается") : "") : "")
                        color: Theme.textDim
                        font.pixelSize: 11
                    }
                }
                Repeater {
                    model: [
                        ["settings", () => { qs.close(); ShellState.settingsOpen = true; }],
                        ["lock", () => { qs.close(); ShellState.lock(); }],
                        ["power_settings_new", () => { qs.powerOpen = !qs.powerOpen; }]
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool hot: index === 2 && qs.powerOpen
                        width: 38; height: 38; radius: 19
                        color: hot ? Theme.accent : (hm.containsMouse ? Theme.surfaceHi : Theme.surface)
                        border.color: hot ? "transparent" : Theme.outline
                        Icon { anchors.centerIn: parent; name: modelData[0]; size: 15; color: parent.hot ? Theme.onAccent : Theme.text }
                        MouseArea { id: hm; anchors.fill: parent; hoverEnabled: true; onClicked: modelData[1]() }
                    }
                }
            }

            // выключение — раскрывается под шапкой
            // power off: unfolds under the header
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: qs.powerOpen ? 40 : 0
                visible: Layout.preferredHeight > 1
                clip: true
                spacing: 8
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Repeater {
                    model: [
                        ["logout", L.t("выход"), ["mmsg", "dispatch", "quit"]],
                        ["restart_alt", L.t("ребут"), ["sh", "-c", "systemctl reboot 2>/dev/null || loginctl reboot"]],
                        ["power_settings_new", L.t("выкл"), ["sh", "-c", "systemctl poweroff 2>/dev/null || loginctl poweroff"]]
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        height: 40
                        radius: 20
                        color: pm.containsMouse ? Theme.tonalHi : Theme.tonal
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Icon { name: modelData[0]; size: 13; color: Theme.accent }
                            Text { font.family: Theme.font; text: modelData[1]; color: Theme.text; font.pixelSize: 12
                                   anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true
                                    onClicked: { qs.close(); ShellState.leave(modelData[2]); } }
                    }
                }
            }

            // ползунки
            // sliders
            BigSlider {
                visible: Brightness.present
                Layout.fillWidth: true
                icon: "sun"
                value: Brightness.value
                onMoved: (v) => Brightness.set(v)
            }
            BigSlider {
                Layout.fillWidth: true
                icon: Audio.icon()
                value: Audio.muted ? 0 : Audio.volume
                onMoved: (v) => { if (Audio.muted) Audio.toggleMute(); Audio.setVolume(v); }
                onIconClicked: Audio.toggleMute()
            }

            // плитки
            // tiles
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8

                Tile {
                    StaggerIn { index: 3; active: qs.visible }
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    icon: Notifs.dnd ? "bell_off" : "bell"
                    title: Notifs.dnd ? L.t("Не беспокоить") : L.t("Уведомления")
                    subtitle: Notifs.history.length === 0 ? L.t("пусто")
                            : Notifs.history.length + L.t(" в истории") + (Notifs.unread ? " · " + Notifs.unread + L.t(" новых") : "")
                    active: Notifs.dnd
                    hasMore: true
                    onToggled: Notifs.dnd = !Notifs.dnd
                    onMore: qs.requestPage("notifs")
                }
                Tile {
                    StaggerIn { index: 4; active: qs.visible }
                    Layout.fillWidth: true
                    icon: "wifi"
                    title: "Wi-Fi"
                    subtitle: !Net.enabled ? L.t("выключен") : Net.current ? Net.current.ssid : L.t("не подключено")
                    active: Net.enabled && Net.current !== null
                    hasMore: true
                    onToggled: Net.toggle()
                    onMore: qs.requestPage("wifi")
                }
                Tile {
                    StaggerIn { index: 5; active: qs.visible }
                    Layout.fillWidth: true
                    visible: Bt.present
                    icon: "bluetooth"
                    title: "Bluetooth"
                    subtitle: !Bt.powered ? L.t("выключен") : Bt.connected.length ? Bt.connected[0].name : L.t("включён")
                    active: Bt.powered
                    hasMore: true
                    onToggled: Bt.toggle()
                    onMore: qs.requestPage("bt")
                }
                Tile {
                    StaggerIn { index: 6; active: qs.visible }
                    Layout.fillWidth: true
                    icon: "headphones"
                    title: L.t("Вывод звука")
                    subtitle: Audio.sink ? (Audio.sink.description || Audio.sink.nickname || Audio.sink.name) : L.t("нет")
                    active: false
                    hasMore: true
                    onToggled: qs.requestPage("audio")
                    onMore: qs.requestPage("audio")
                }
                Tile {
                    StaggerIn { index: 7; active: qs.visible }
                    Layout.fillWidth: true
                    icon: !Power.present ? "plug" : Power.charging ? "battery_charging_full" : Power.pct > 50 ? "battery_full" : Power.pct > 20 ? "battery_3_bar" : "battery_alert"
                    title: Power.present ? L.t("Батарея · ") + Math.round(Power.pct) + "%" : L.t("Питание")
                    subtitle: Power.stateText
                    active: false
                    hasMore: true
                    onToggled: qs.requestPage("battery")
                    onMore: qs.requestPage("battery")
                }
                Tile {
                    StaggerIn { index: 8; active: qs.visible }
                    Layout.fillWidth: true
                    icon: ShellState.caffeine ? "eye" : "moon"
                    title: L.t("Не гасить")
                    subtitle: ShellState.caffeine ? L.t("экран не гаснет") : L.t("гаснет через 5 мин")
                    active: ShellState.caffeine
                    onToggled: {
                        if (!ShellState.caffeine && Power.low) return;
                        ShellState.caffeine = !ShellState.caffeine;
                    }
                }
                Tile {
                    StaggerIn { index: 9; active: qs.visible }
                    Layout.fillWidth: true
                    icon: "sparkle"
                    title: L.t("Частицы")
                    subtitle: ({ petals: L.t("лепестки"), stars: L.t("звёзды"), off: L.t("выкл") })[ShellState.particles]
                    active: ShellState.particles !== "off"
                    onToggled: ShellState.cycleParticles()
                }
                Tile {
                    StaggerIn { index: 10; active: qs.visible }
                    Layout.fillWidth: true
                    icon: "palette"
                    title: L.t("Цвета")
                    subtitle: Theme.p.name
                    active: false
                    onToggled: ShellState.cycleAccent()
                }
            }
        }

        // ════════ подстраницы ════════
        // ════════ subpages ════════
        ColumnLayout {
            id: sub
            width: parent.width
            height: parent.height
            x: qs.page === "" ? parent.width + 20 : 0
            opacity: qs.page === "" ? 0 : 1
            spacing: 10
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    visible: false          // менеджеры — отдельные виджеты, возвращаться некуда / managers are separate widgets, there's nowhere to go back to
                    width: 34; height: 34; radius: 17
                    color: bm.containsMouse ? Theme.surfaceHi : Theme.surface
                    Text { font.family: Theme.font; anchors.centerIn: parent; text: "‹"; font.pixelSize: 22; color: Theme.text }
                    MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; onClicked: qs.page = "" }
                }
                Text {
                    font.family: Theme.font
                    Layout.fillWidth: true
                    text: ({ wifi: "Wi-Fi", bt: "Bluetooth", audio: L.t("Звук"), notifs: L.t("Уведомления"), battery: Power.present ? L.t("Батарея") : L.t("Питание") })[qs.page] ?? ""
                    color: Theme.text
                    font.pixelSize: 16
                    font.bold: true
                }
                Rectangle {
                    visible: qs.page === "notifs" && Notifs.history.length > 0
                    width: clr.implicitWidth + 30; height: 30; radius: 15
                    color: Theme.tonal
                    Row {
                        id: clr
                        anchors.centerIn: parent
                        spacing: 6
                        Icon { name: "trash"; size: 11; color: Theme.accent }
                        Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent; text: L.t("очистить") }
                    }
                    StateLayer { radius: 15; tint: Theme.accent; onClicked: Notifs.clearAll() }
                }
                // «+»: wi-fi — добавить сеть вручную, bluetooth — искать новые устройства
                // "+": wi-fi adds a network manually, bluetooth scans for new devices
                Rectangle {
                    visible: (qs.page === "wifi" && Net.enabled) || (qs.page === "bt" && Bt.powered)
                    width: 30; height: 30; radius: 15
                    color: (qs.page === "wifi" ? qs.netAdding : Bt.scanning) ? Theme.accent : Theme.tonal
                    Icon { anchors.centerIn: parent; name: "plus"; size: 12
                           color: (qs.page === "wifi" ? qs.netAdding : Bt.scanning) ? Theme.onAccent : Theme.accent }
                    StateLayer { radius: 15; onClicked: {
                        if (qs.page === "wifi") { qs.netDetails = ""; qs.netAdding = !qs.netAdding; }
                        else { qs.btDetails = ""; Bt.scan(); }
                    } }
                }
                // переключатель в стиле M3
                // an M3-style switch
                Rectangle {
                    visible: qs.page === "wifi" || qs.page === "bt"
                    readonly property bool active: qs.page === "wifi" ? Net.enabled : Bt.powered
                    width: 48; height: 28; radius: 14
                    color: active ? Theme.accent : Theme.surfaceHi
                    border.color: active ? "transparent" : Theme.textDim
                    Behavior on color { ColorAnimation { duration: Theme.anim } }
                    Rectangle {
                        width: parent.active ? 20 : 14; height: width; radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.active ? parent.width - width - 4 : 6
                        color: parent.active ? Theme.onAccent : Theme.textDim
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        Behavior on width { NumberAnimation { duration: 200 } }
                    }
                    MouseArea { anchors.fill: parent; onClicked: qs.page === "wifi" ? Net.toggle() : Bt.toggle() }
                }
            }

            Text {
                font.family: Theme.font
                visible: qs.page === "wifi" && Net.status.length > 0
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: Net.status
                color: Net.status === "…" ? Theme.textDim : Theme.danger
                font.pixelSize: 11
            }

            // ─── wi-fi ───
            // добавить сеть вручную
            // ─── wi-fi ───
            // add a network manually
            Column {
                visible: qs.page === "wifi" && qs.netAdding
                Layout.fillWidth: true
                spacing: 8
                Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent; text: L.t("новая сеть") }
                Repeater {
                    model: [["ssid", L.t("имя сети (SSID)"), false], ["pw", L.t("пароль (пусто — открытая)"), true]]
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: 40; radius: 20
                        color: Theme.surface
                        border.color: fi.activeFocus ? Theme.accent : Theme.outline
                        TextInput {
                            id: fi
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Theme.font; font.pixelSize: Tokens.font.normal; color: Theme.text
                            echoMode: modelData[2] ? TextInput.Password : TextInput.Normal
                            onTextChanged: modelData[0] === "ssid" ? (qs.newSsid = text) : (qs.newPw = text)
                            Keys.onReturnPressed: qs.addNet()
                            Text { anchors.verticalCenter: parent.verticalCenter; visible: !fi.text
                                   font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.textDim; text: modelData[1] }
                        }
                    }
                }
                Row {
                    spacing: 8
                    Rectangle {
                        width: ht.implicitWidth + 40; height: 34; radius: 17
                        color: qs.newHidden ? Theme.tonalHi : Theme.surface
                        border.color: qs.newHidden ? Theme.accent : Theme.outline
                        Text { id: ht; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                               color: qs.newHidden ? Theme.accent : Theme.text; text: L.t("скрытая сеть") }
                        StateLayer { radius: 17; onClicked: qs.newHidden = !qs.newHidden }
                    }
                    Rectangle {
                        width: at.implicitWidth + 40; height: 34; radius: 17
                        color: Theme.accent
                        opacity: qs.newSsid ? 1 : 0.4
                        Text { id: at; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                               font.bold: true; color: Theme.onAccent; text: L.t("подключиться") }
                        StateLayer { radius: 17; tint: Theme.onAccent; disabled: !qs.newSsid; onClicked: qs.addNet() }
                    }
                }
            }

            // настройки одной сети
            // settings of a single network
            Flickable {
                SmoothWheel {}
                visible: qs.page === "wifi" && qs.netDetails !== "" && !qs.netAdding
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: ncol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: ncol
                    width: parent.width
                    spacing: 6
                    Row {
                        spacing: 10
                        Rectangle {
                            width: 30; height: 30; radius: 15; color: Theme.surface
                            Icon { anchors.centerIn: parent; name: "chevron_left"; size: 11; color: Theme.text }
                            StateLayer { radius: 15; onClicked: qs.netDetails = "" }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.bold: true
                               font.pixelSize: Tokens.font.larger; color: Theme.text; text: qs.netDetails }
                    }
                    Repeater {
                        model: Net.info.active ? [["IPv4", Net.info.ip], [L.t("шлюз"), Net.info.gateway], ["DNS", Net.info.curDns],
                                                  ["IPv6", Net.info.ip6], ["MAC", Net.info.mac]]
                                               : [[L.t("защита"), Net.info.security || L.t("нет")]]
                        delegate: Row {
                            required property var modelData
                            visible: modelData[1] !== ""
                            spacing: 10
                            Text { width: 70; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: modelData[0] }
                            Text { width: ncol.width - 80; elide: Text.ElideRight; font.family: Theme.font
                                   font.pixelSize: Tokens.font.small; color: Theme.text; text: modelData[1] }
                        }
                    }
                    Item { width: 1; height: 6 }
                    Repeater {
                        model: [
                            [L.t("подключаться сразу, как только видна"), Net.info.auto, () => Net.setDefault(qs.netDetails, !Net.info.auto)],
                            [L.t("лимитное подключение (экономить трафик)"), Net.info.metered, () => Net.setMetered(qs.netDetails, !Net.info.metered)],
                            [L.t("случайный MAC-адрес"), Net.info.randomMac, () => Net.setRandomMac(qs.netDetails, !Net.info.randomMac)]
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            width: ncol.width; height: 42; radius: 21
                            color: nm2.containsMouse ? Theme.hover : "transparent"
                            Text { x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80; elide: Text.ElideRight
                                   font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text; text: modelData[0] }
                            Rectangle {
                                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                width: 42; height: 24; radius: 12
                                color: modelData[1] ? Theme.accent : Theme.surfaceHi
                                Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter
                                            x: modelData[1] ? parent.width - width - 4 : 4
                                            color: modelData[1] ? Theme.onAccent : Theme.textDim
                                            Behavior on x { Anim { kind: "fastSpatial" } } }
                            }
                            MouseArea { id: nm2; anchors.fill: parent; hoverEnabled: true; onClicked: modelData[2]() }
                        }
                    }
                    Text { topPadding: 6; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                           text: L.t("свои DNS через пробел (пусто — от роутера), Enter — применить") }
                    Rectangle {
                        width: ncol.width; height: 38; radius: 19
                        color: Theme.surface
                        border.color: dnsIn.activeFocus ? Theme.accent : Theme.outline
                        TextInput {
                            id: dnsIn
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text
                            text: Net.info.dns ?? ""
                            Keys.onReturnPressed: Net.setDns(qs.netDetails, text)
                            Text { anchors.verticalCenter: parent.verticalCenter; visible: !dnsIn.text
                                   font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.textDim; text: "1.1.1.1 9.9.9.9" }
                        }
                    }
                    Row {
                        topPadding: 6
                        spacing: 8
                        Rectangle {
                            width: dt.implicitWidth + 36; height: 34; radius: 17; color: Theme.tonal
                            Text { id: dt; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent
                                   text: Net.info.active ? L.t("отключиться") : L.t("подключиться") }
                            StateLayer { radius: 17; onClicked: Net.info.active ? Net.disconnect(qs.netDetails) : Net.choose({ ssid: qs.netDetails, saved: true }) }
                        }
                        Rectangle {
                            width: ft.implicitWidth + 36; height: 34; radius: 17; color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.15)
                            Text { id: ft; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.danger; text: L.t("забыть сеть") }
                            StateLayer { radius: 17; onClicked: { Net.forget(qs.netDetails); qs.netDetails = ""; } }
                        }
                    }
                }
            }

            // проводные: кабель, USB-модем, мобильная сеть — над списком Wi-Fi (видны, даже если Wi-Fi выключен)
            // wired: cable, USB modem, mobile network above the Wi-Fi list (visible even with Wi-Fi off)
            Column {
                visible: qs.page === "wifi" && qs.netDetails === "" && !qs.netAdding && Net.wired.length > 0
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: Net.wired
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool up: modelData.state === "connected"
                        width: parent.width; height: 54; radius: 18
                        color: up ? Theme.tonalHi : (wm.containsMouse ? Theme.surfaceHi : Theme.surface)
                        Rectangle {
                            x: 10; anchors.verticalCenter: parent.verticalCenter
                            width: 36; height: 36; radius: 12; color: parent.up ? Theme.accent : Theme.surfaceHi
                            Icon { anchors.centerIn: parent; size: 15; color: parent.parent.up ? Theme.onAccent : Theme.text
                                   name: modelData.kind === "usb" ? "usb" : modelData.kind === "gsm" ? "cell" : "ethernet" }
                        }
                        Column {
                            x: 58; anchors.verticalCenter: parent.verticalCenter
                            Text { font.family: Theme.font; font.pixelSize: Tokens.font.normal; color: Theme.text
                                   text: modelData.kind === "usb" ? L.t("USB-модем") : modelData.kind === "gsm" ? L.t("Мобильная сеть") : L.t("Кабель") }
                            Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                                   text: modelData.dev + " · " + (parent.parent.up ? L.t("подключено") + (modelData.con ? " · " + modelData.con : "")
                                         : modelData.state === "unavailable" ? L.t("нет провода / сигнала") : L.t("нажми, чтобы подключиться")) }
                        }
                        MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true
                                    enabled: modelData.state !== "unavailable"; onClicked: Net.toggleWired(modelData) }
                    }
                }
            }

            ListView {
                SmoothWheel {}
                visible: qs.page === "wifi" && qs.netDetails === "" && !qs.netAdding
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: {
                    if (!Net.enabled) return [];
                    const n = Net.nets, out = [];
                    const put = (title, arr) => { if (arr.length) { out.push({ header: title }); out.push(...arr); } };
                    put(L.t("подключено"), n.filter(x => x.active));
                    put(L.t("сохранённые"), n.filter(x => !x.active && x.saved));
                    put(L.t("доступные"), n.filter(x => !x.active && !x.saved));
                    return out;
                }
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    StaggerIn { index: parent.index; active: qs.visible }
                    readonly property bool isHeader: modelData.header !== undefined
                    readonly property bool asking: !isHeader && Net.asking === modelData.ssid
                    width: ListView.view.width
                    Text {
                        visible: row.isHeader
                        x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                        font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent
                        text: row.modelData.header ?? ""
                    }
                    height: isHeader ? 30 : asking ? 96 : 54
                    radius: 18
                    color: isHeader ? "transparent" : modelData.active ? Theme.tonalHi : (nm.containsMouse ? Theme.surfaceHi : Theme.surface)
                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    RowLayout {
                        visible: !row.isHeader
                        x: 10; width: parent.width - 24; height: 54
                        spacing: 12
                        // сила сигнала — четыре полоски в плашке, как на телефоне
                        // signal strength: four bars in a chip, as on a phone
                        Rectangle {
                            width: 36; height: 36; radius: 12
                            color: row.modelData.active ? Theme.accent : Theme.surfaceHi
                            Row {
                                anchors.centerIn: parent
                                spacing: 2
                                Repeater {
                                    model: 4
                                    delegate: Rectangle {
                                        required property int index
                                        anchors.bottom: parent.bottom
                                        width: 4; height: 5 + index * 4; radius: 2
                                        readonly property bool lit: (row.modelData.signal ?? 0) > index * 25
                                        color: row.modelData.active ? Theme.onAccent : Theme.accent
                                        opacity: lit ? 1 : 0.25
                                    }
                                }
                            }
                        }
                        Column {
                            Layout.fillWidth: true
                            Text { font.family: Theme.font; width: parent.width; elide: Text.ElideRight
                                   text: row.modelData.ssid ?? ""; font.pixelSize: 13
                                   color: row.modelData.active ? Theme.accent : Theme.text }
                            Text { font.family: Theme.font; font.pixelSize: 10; color: Theme.textDim
                                   text: row.modelData.active ? L.t("подключено") : row.modelData.saved ? L.t("сохранена") : row.modelData.secure ? L.t("защищена") : L.t("открытая") }
                        }
                        Icon { visible: !!row.modelData.secure; name: row.modelData.saved ? "unlock" : "lock"; size: 11; color: Theme.textDim }
                    }
                    MouseArea {
                        id: nm; visible: !row.isHeader; width: parent.width; height: 46; hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (m) => {
                            if (m.button === Qt.LeftButton) { Net.choose(row.modelData); return; }
                            const n = row.modelData;
                            qs.openMenu(row, (n.active ? [{ icon: "close", text: L.t("отключиться"), action: () => Net.disconnect(n.ssid) }]
                                                       : [{ icon: "wifi", text: L.t("подключиться"), action: () => Net.choose(n) }])
                                .concat(n.saved ? [
                                    { icon: "star", text: L.t("использовать по умолчанию"), action: () => Net.setDefault(n.ssid, true) },
                                    { icon: "settings", text: L.t("настройки сети"), action: () => { qs.netDetails = n.ssid; Net.loadInfo(n.ssid); } },
                                    { icon: "bin", text: L.t("забыть"), danger: true, action: () => Net.forget(n.ssid) }
                                ] : []), m);
                        }
                    }
                    Rectangle {
                        visible: row.asking
                        x: 14; y: 48; width: parent.width - 28; height: 32; radius: 16
                        color: Theme.surface
                        border.color: Theme.outline
                        TextInput {
                            font.family: Theme.font
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: Theme.text; font.pixelSize: 12
                            onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                            Keys.onReturnPressed: Net.connect(row.modelData.ssid, text)
                            Keys.onEscapePressed: Net.asking = ""
                        }
                    }
                }
            }

            // ─── bluetooth ───
            // адаптера нет — предлагаем перезапустить службу
            // ─── bluetooth ───
            // no adapter: offer to restart the service
            Column {
                visible: qs.page === "bt" && !Bt.present
                Layout.fillWidth: true
                spacing: 10
                Text { width: parent.width; wrapMode: Text.Wrap; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                       color: Theme.textDim; text: L.t("адаптер bluetooth не найден — похоже, служба не поднялась при старте") }
                Rectangle {
                    width: rt.implicitWidth + 40; height: 36; radius: 18; color: Theme.accent
                    Text { id: rt; anchors.centerIn: parent; font.family: Theme.font; font.bold: true; font.pixelSize: Tokens.font.small
                           color: Theme.onAccent; text: L.t("перезапустить bluetooth") }
                    StateLayer { radius: 18; tint: Theme.onAccent; onClicked: Bt.restartService() }
                }
            }

            // сведения об устройстве
            // device details
            Column {
                visible: qs.page === "bt" && qs.btDetails !== ""
                Layout.fillWidth: true
                spacing: 8
                Row {
                    spacing: 10
                    Rectangle {
                        width: 30; height: 30; radius: 15; color: Theme.surface
                        Icon { anchors.centerIn: parent; name: "chevron_left"; size: 11; color: Theme.text }
                        StateLayer { radius: 15; onClicked: qs.btDetails = "" }
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.bold: true
                           font.pixelSize: Tokens.font.larger; color: Theme.text; text: Bt.info.name ?? "" }
                }
                Repeater {
                    model: [["MAC", qs.btDetails], [L.t("батарея"), (Bt.info.battery ?? -1) >= 0 ? Bt.info.battery + "%" : ""],
                            [L.t("состояние"), Bt.info.connected ? L.t("подключено") : L.t("не подключено")]]
                    delegate: Row {
                        required property var modelData
                        visible: modelData[1] !== ""
                        spacing: 10
                        Text { width: 80; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: modelData[0] }
                        Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.text; text: modelData[1] }
                    }
                }
                Rectangle {
                    width: parent.width; height: 42; radius: 21
                    color: tm2.containsMouse ? Theme.hover : "transparent"
                    Text { x: 14; anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font
                           font.pixelSize: Tokens.font.smaller; color: Theme.text; text: L.t("подключаться автоматически (доверять)") }
                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                        width: 42; height: 24; radius: 12
                        color: Bt.info.trusted ? Theme.accent : Theme.surfaceHi
                        Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter
                                    x: Bt.info.trusted ? parent.width - width - 4 : 4
                                    color: Bt.info.trusted ? Theme.onAccent : Theme.textDim
                                    Behavior on x { Anim { kind: "fastSpatial" } } }
                    }
                    MouseArea { id: tm2; anchors.fill: parent; hoverEnabled: true; onClicked: Bt.trust(qs.btDetails, !Bt.info.trusted) }
                }
                Rectangle {
                    width: ft2.implicitWidth + 36; height: 34; radius: 17; color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.15)
                    Text { id: ft2; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.danger; text: L.t("забыть устройство") }
                    StateLayer { radius: 17; onClicked: { Bt.forget(qs.btDetails); qs.btDetails = ""; } }
                }
            }

            ListView {
                SmoothWheel {}
                visible: qs.page === "bt" && Bt.present && qs.btDetails === ""
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: {
                    if (!Bt.powered) return [];
                    const out = Bt.devices.map(d => ({ kind: "dev", d: d }));
                    if (Bt.scanning || Bt.found.length) {
                        out.push({ kind: "head", t: Bt.scanning ? L.t("ищу устройства…") : L.t("найдено рядом") });
                        for (const f of Bt.found) out.push({ kind: "new", d: f });
                    }
                    return out;
                }
                delegate: Rectangle {
                    id: brow
                    required property var modelData
                    required property int index
                    StaggerIn { index: parent.index; active: qs.visible }
                    readonly property var dv: modelData.d ?? {}
                    width: ListView.view.width
                    height: modelData.kind === "head" ? 30 : 54
                    radius: 18
                    color: modelData.kind === "head" ? "transparent"
                         : dv.connected ? Theme.tonalHi : (dm.containsMouse ? Theme.surfaceHi : Theme.surface)
                    // тип устройства — по имени (наушники, клавиатура, телефон, геймпад…)
                    // device type from the name (headphones, keyboard, phone, gamepad…)
                    readonly property string kindIcon: {
                        const n = (dv.name || "").toLowerCase();
                        if (modelData.kind === "new") return "plus";
                        if (/buds|pods|head|phone(s)? |ear|audio|sound|speaker|jbl|sony wh|wh-|wf-|cmf|nothing ear/.test(n)) return "headphones";
                        if (/keyboard|keys|kbd/.test(n)) return "keyboard";
                        if (/controller|gamepad|xbox|dualsense|dualshock|joy/.test(n)) return "sports_esports";
                        if (/phone|iphone|galaxy|pixel|redmi|xiaomi|poco/.test(n)) return "phone";
                        if (/tv|tele/.test(n)) return "tv";
                        if (/laptop|book|pc|desktop/.test(n)) return "laptop";
                        return "bluetooth";
                    }
                    Text { visible: brow.modelData.kind === "head"; x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                           font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent; text: brow.modelData.t ?? "" }
                    RowLayout {
                        visible: brow.modelData.kind !== "head"
                        x: 10; width: parent.width - 24; height: parent.height
                        spacing: 12
                        Rectangle {
                            width: 36; height: 36; radius: 12
                            color: brow.dv.connected ? Theme.accent : Theme.surfaceHi
                            Icon { anchors.centerIn: parent; name: brow.kindIcon; size: 15
                                   color: brow.dv.connected ? Theme.onAccent : Theme.accent }
                        }
                        Text { font.family: Theme.font; Layout.fillWidth: true; elide: Text.ElideRight
                               text: brow.dv.name ?? ""; font.pixelSize: 13
                               color: brow.dv.connected ? Theme.accent : Theme.text }
                        Text { font.family: Theme.font; font.pixelSize: 10; color: Theme.textDim
                               text: Bt.busy === brow.dv.mac ? "…" : brow.dv.connected ? L.t("подключено")
                                   : brow.modelData.kind === "new" ? L.t("сопрячь") : "" }
                    }
                    MouseArea {
                        id: dm
                        anchors.fill: parent
                        visible: brow.modelData.kind !== "head"
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (m) => {
                            const d = brow.dv;
                            if (brow.modelData.kind === "new") { Bt.pair(d.mac); return; }
                            if (m.button === Qt.LeftButton) { Bt.choose(d); return; }
                            qs.openMenu(brow, [
                                { icon: d.connected ? "close" : "bluetooth", text: d.connected ? L.t("отключиться") : L.t("подключиться"), action: () => Bt.choose(d) },
                                { icon: "star", text: L.t("подключаться автоматически"), action: () => Bt.trust(d.mac, true) },
                                { icon: "settings", text: L.t("сведения"), action: () => { qs.btDetails = d.mac; Bt.loadInfo(d.mac); } },
                                { icon: "bin", text: L.t("забыть"), danger: true, action: () => Bt.forget(d.mac) }
                            ], m);
                        }
                    }
                }
                Text {
                    font.family: Theme.font
                    anchors.centerIn: parent
                    visible: Bt.powered && Bt.devices.length === 0 && !Bt.scanning && !Bt.found.length
                    text: L.t("устройств нет — нажми «+», чтобы найти новые")
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.textDim
                    font.pixelSize: 11
                }
            }

            // ─── батарея ───
            // ─── battery ───
            Column {
                visible: qs.page === "battery"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                Row {
                    spacing: 16
                    // большая батарейка с заливкой
                    // a big filled battery
                    Rectangle {
                        width: 70; height: 36; radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: "transparent"
                        border.width: 2
                        border.color: Power.pct < 20 && !Power.charging ? Theme.danger : Theme.textDim
                        PlugIcon { visible: !Power.present; anchors.centerIn: parent; width: 40; color: Theme.accent }
                        Rectangle {
                            visible: Power.present
                            x: 4; y: 4
                            height: parent.height - 8; radius: 6
                            width: Math.max(4, (parent.width - 8) * Power.pct / 100)
                            color: Power.charging ? Theme.accent : Power.pct < 20 ? Theme.danger : Theme.text
                            Behavior on width { Anim { kind: "effects" } }
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { font.family: Theme.font; font.pixelSize: 30; font.bold: true; color: Theme.text
                               text: Power.present ? Math.round(Power.pct) + "%" : L.t("Питание") }
                        Text { font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.textDim
                               text: Power.stateText }
                    }
                }

                Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                       text: Power.profiles.length ? L.t("режим питания") : L.t("режимы питания недоступны (нужен power-profiles-daemon)") }

                Row {
                    spacing: 8
                    Repeater {
                        model: [["power-saver", L.t("экономия"), "w_night"], ["balanced", L.t("баланс"), "tune"], ["performance", L.t("мощность"), "bolt"]]
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            StaggerIn { index: parent.index; active: qs.visible }
                            readonly property bool sel: Power.profile === modelData[0]
                            visible: Power.profiles.includes(modelData[0])
                            width: 110; height: 64; radius: sel ? 20 : 32
                            color: sel ? Theme.accent : Theme.surface
                            border.color: sel ? "transparent" : Theme.outline
                            Behavior on radius { Anim { kind: "fastSpatial" } }
                            Behavior on color { CAnim {} }
                            Column {
                                anchors.centerIn: parent
                                spacing: 4
                                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: modelData[2]; size: 15
                                       color: parent.parent.sel ? Theme.onAccent : Theme.accent }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.font
                                       font.pixelSize: Tokens.font.small; text: modelData[1]
                                       color: parent.parent.sel ? Theme.onAccent : Theme.text }
                            }
                            StateLayer { radius: parent.radius; onClicked: Power.setProfile(modelData[0]) }
                        }
                    }
                }

                // не гасить экран — тут же, в менеджере батареи
                // keep the screen awake: right here, in the battery manager
                Rectangle {
                    width: parent.width
                    height: 56
                    radius: 28
                    color: ShellState.caffeine ? Theme.tonalHi : Theme.surface
                    Behavior on color { CAnim {} }
                    StaggerIn { index: 3; active: qs.visible }
                    Row {
                        x: 18; anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        Icon { name: ShellState.caffeine ? "eye" : "moon"; size: 16; color: Theme.accent }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { font.family: Theme.font; font.pixelSize: Tokens.font.normal; color: Theme.text; text: L.t("Не гасить") }
                            Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                                   text: ShellState.caffeine ? L.t("экран не гаснет") : L.t("гаснет через 5 мин") }
                        }
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: 48; height: 28; radius: 14
                        color: ShellState.caffeine ? Theme.accent : Theme.surfaceHi
                        border.color: ShellState.caffeine ? "transparent" : Theme.textDim
                        Behavior on color { CAnim {} }
                        Rectangle {
                            width: ShellState.caffeine ? 20 : 14; height: width; radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: ShellState.caffeine ? parent.width - width - 4 : 6
                            color: ShellState.caffeine ? Theme.onAccent : Theme.textDim
                            Behavior on x { Anim { kind: "fastSpatial" } }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!ShellState.caffeine && Power.low) return;
                            ShellState.caffeine = !ShellState.caffeine;
                        }
                    }
                }
            }

            // ─── уведомления ───
            // приложения, которым запрещены уведомления: клик по чипсу — снова разрешить
            // ─── notifications ───
            // apps blocked from sending notifications: click a chip to allow them again
            Row {
                visible: qs.page === "notifs" && (ShellState.settings.mutedApps ?? []).length > 0
                Layout.fillWidth: true
                spacing: 6
                Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: L.t("заглушены:"); height: 24
                       verticalAlignment: Text.AlignVCenter }
                Repeater {
                    model: ShellState.settings.mutedApps ?? []
                    delegate: Rectangle {
                        required property string modelData
                        width: mt.implicitWidth + 30; height: 24; radius: 12; color: Theme.surfaceHi
                        Text { id: mt; x: 10; anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font
                               font.pixelSize: Tokens.font.small; color: Theme.text; text: modelData }
                        Icon { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                               name: "close"; size: 8; color: Theme.textDim }
                        MouseArea { anchors.fill: parent; onClicked: Notifs.unmute(modelData) }
                    }
                }
            }
            ListView {
                SmoothWheel {}
                visible: qs.page === "notifs"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: Notifs.history
                delegate: NotifCard {
                    required property var modelData
                    required property int index
                    StaggerIn { index: parent.index; active: qs.visible }
                    width: ListView.view.width
                    entry: modelData
                    onCloseRequested: Notifs.remove(modelData.key)
                    onDismissRequested: Notifs.remove(modelData.key)
                }
                Text {
                    anchors.centerIn: parent
                    visible: Notifs.history.length === 0
                    font.family: Theme.font
                    font.pixelSize: Tokens.font.smaller
                    color: Theme.textDim
                    text: L.t("тут пусто")
                }
            }

            // ─── звук: выходы, входы, приложения ───
            // ─── sound: outputs, inputs, apps ───
            Flickable {
                SmoothWheel {}
                visible: qs.page === "audio"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: acol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: acol
                    width: parent.width
                    spacing: 4

                    Head { text: L.t("выход") }
                    BigSlider {
                        width: acol.width
                        icon: Audio.icon()
                        value: Audio.muted ? 0 : Audio.volume
                        onMoved: (v) => { if (Audio.muted) Audio.toggleMute(); Audio.setVolume(v); }
                        onIconClicked: Audio.toggleMute()
                    }
                    Repeater {
                        model: Audio.outputs
                        delegate: DevRow { required property var modelData; required property int index; StaggerIn { index: parent.index + 1; active: qs.visible }
                                           width: acol.width; node: modelData; current: modelData === Audio.sink
                                           onPicked: Audio.use(modelData) }
                    }

                    Head { text: L.t("вход"); visible: Audio.inputs.length > 0 }
                    BigSlider {
                        visible: !!Audio.source?.audio
                        width: acol.width
                        icon: "music"
                        value: Audio.source?.audio?.volume ?? 0
                        onMoved: (v) => Audio.setNodeVolume(Audio.source, v)
                    }
                    Repeater {
                        model: Audio.inputs
                        delegate: DevRow { required property var modelData; required property int index; StaggerIn { index: parent.index + 4; active: qs.visible }
                                           width: acol.width; node: modelData; icon: "music"
                                           current: modelData === Audio.source; onPicked: Audio.useInput(modelData) }
                    }

                    Head { text: Audio.streams.length ? L.t("приложения") : L.t("сейчас ничего не играет") }
                    Repeater {
                        model: Audio.streams
                        delegate: Row {
                            required property var modelData
                            required property int index
                            StaggerIn { index: parent.index; active: qs.visible }
                            width: acol.width
                            spacing: 10
                            Item {
                                width: 28; height: 40
                                AppIcon { anchors.centerIn: parent; size: 20; icon: Audio.iconOf(modelData) }
                            }
                            Column {
                                width: acol.width - 38
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.font
                                       font.pixelSize: Tokens.font.small; color: Theme.text
                                       text: Audio.label(modelData) + "  ·  " + Math.round((modelData.audio?.volume ?? 0) * 100) + "%" }
                                Slider {
                                    width: parent.width
                                    value: modelData.audio?.volume ?? 0
                                    onMoved: (v) => Audio.setNodeVolume(modelData, v)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
