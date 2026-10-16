import Quickshell
import QtQuick

// окно настроек (Super+I, шестерёнка в шторке): слева разделы, справа содержимое
// settings window (Super+I, the gear in quick settings): sections on the left, content on the right
CenterPopup {
    id: sw
    open: ShellState.settingsOpen
    onDismissed: ShellState.settingsOpen = false
    // пока открыт диалог выбора файла шрифта — прячемся, как выбор обоев: иначе диалог оказывается под нами
    // while the font file dialog is open we hide, like the wallpaper picker, otherwise the dialog ends up under us
    visible: (open || card.opacity > 0.01) && !ShellState.fileDialog
    cardWidth: 960
    cardHeight: 640
    property int section: 0
    // поиск по всем настройкам: строки, где нет искомого, сворачиваются, разделы показываются все сразу
    // строка поиска живёт в ShellState: встроенные компоненты (Row2, SGroup) не видят id этого файла
    // search across all settings: rows without the query collapse, all sections are shown at once
    // the search string lives in ShellState: inline components (Row2, SGroup) can't see this file's ids
    readonly property string query: ShellState.settingsQuery
    // японская, китайская, корейская… раскладка — только расположение клавиш, иероглифы печатает метод ввода
    // a Japanese, Chinese, Korean… layout is only the key positions; the characters are typed by an input method
    readonly property string imeNote: (ShellState.settings.kbLayouts ?? ["us"]).some(c => ["jp", "cn", "kr", "tw", "in", "th", "vn"].includes(c.split("(")[0]))
        ? "\n" + L.t("японский, китайский, корейский и т. п. — это только расположение клавиш; чтобы печатать иероглифы, нужен метод ввода (fcitx5 + mozc, rime, hangul)") : ""
    function schemeHint(k: string): string {
        return ({ tonal: "один цвет обоев и его оттенки", neutral: "почти серая, с лёгким намёком на цвет обоев",
                  vibrant: "насыщенные, яркие цвета", expressive: "главный цвет сдвинут — неожиданное, но гармоничное сочетание",
                  fidelity: "цвет ровно как на обоях", content: "главный и второй цвета обоев вместе",
                  rainbow: "цветной акцент на нейтральном сером", fruit: "несколько сочных цветов вокруг цвета обоев" })[k] ?? "";
    }
    readonly property var sections: [["palette", L.t("Вид"), L.t("цвета, обои, форма, значки")],
                                      ["wallpaper", L.t("Рабочий стол"), L.t("частицы, визуализатор, гифки")],
                                      ["description", L.t("Текст и язык"), L.t("шрифты, эмодзи, язык")],
                                      ["apps", L.t("Панель и меню"), L.t("панель, меню, борд")],
                                      ["l_grid", L.t("Окна"), L.t("сетка, лента, страницы")],
                                      ["keyboard", L.t("Ввод"), L.t("клавиатура, мышь, тачпад, углы")],
                                      ["tv", L.t("Экраны"), L.t("разрешение, масштаб, яркость")],
                                      ["bolt", L.t("Питание"), L.t("сон, батарея, крышка")],
                                      ["music", L.t("Звук"), L.t("музыка, запись экрана")],
                                      ["memory", L.t("Система"), L.t("время, погода, сеанс, программы")],
                                      ["key", L.t("Клавиши"), L.t("все сочетания")],
                                      ["pets", L.t("О шелле"), L.t("что тут есть")]]

    // ─── элементы ───
    // строка настройки: значок в кружке, название и подсказка слева, переключатель справа; между строками — тонкая линия
    // ряд вариантов-«таблеток» для одной настройки: opts = [[значение, подпись], …]
    // ─── elements ───
    // a settings row: icon in a circle, title and hint on the left, control on the right; a thin line between rows
    // a row of option "pills" for one setting: opts = [[value, label], …]
    component Chips: Flow {
        id: ch
        property string key: ""
        property var def: null
        property var opts: []
        width: 380; spacing: 4
        Repeater {
            model: ch.opts
            delegate: Rectangle {
                required property var modelData
                readonly property bool sel: (ShellState.settings[ch.key] ?? ch.def) === modelData[0]
                width: cht.implicitWidth + 20; height: 28; radius: 14
                color: sel ? Theme.accent : Theme.surfaceHi
                Behavior on color { CAnim {} }
                Text { id: cht; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                       color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                StateLayer { radius: 14; onClicked: ShellState.set(ch.key, parent.modelData[0]) }
            }
        }
    }
    component Row2: Item {
        id: r2
        property string title: ""
        property string hint: ""
        property string icon: ""
        default property alias control: slot.data
        width: parent ? parent.width : 400
        readonly property bool hit: ShellState.settingsQuery === "" || (title + " " + hint).toLowerCase().includes(ShellState.settingsQuery.toLowerCase())
        height: hit ? Math.max(60, col.implicitHeight + 20, slot.height + 20) : 0
        opacity: hit ? 1 : 0
        clip: !hit
        Rectangle { visible: r2.y > 0; width: parent.width; height: 1; color: Theme.line; opacity: 0.6 }
        Rectangle {
            id: bub
            visible: r2.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 34; height: 34; radius: 12
            color: Theme.tonal
            Icon { anchors.centerIn: parent; name: r2.icon; size: 14; color: Theme.accent }
        }
        Column {
            id: col
            x: r2.icon ? 48 : 0
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(120, parent.width - x - slot.width - 20)
            spacing: 2
            Text { font.family: Theme.font; font.pixelSize: Tokens.font.normal; color: Theme.text; text: r2.title }
            Text { visible: r2.hint !== ""; width: parent.width; wrapMode: Text.Wrap
                   font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: r2.hint }
        }
        Item { id: slot; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
               width: Math.min(childrenRect.width, r2.width * 0.6); height: childrenRect.height }
    }
    // группа настроек: заголовок и карточка со строками
    // a settings group: a heading and a card with rows
    component SGroup: Column {
        id: sg
        property string title: ""
        default property alias rows: box.data
        width: parent ? parent.width : 400
        spacing: 6
        // при поиске группа без совпадений прячется целиком
        // while searching, a group with no matches hides entirely
        visible: ShellState.settingsQuery === "" || box.implicitHeight > 2
        Text { leftPadding: 6; font.family: Theme.font; font.pixelSize: Tokens.font.small; font.bold: true
               color: Theme.accent; text: sg.title.toUpperCase() }
        Rectangle {
            width: sg.width; height: box.implicitHeight + 8
            radius: Tokens.rounding.large
            color: Theme.surface
            Column { id: box; x: 16; y: 4; width: parent.width - 32 }
        }
    }
    component Toggle: Rectangle {
        id: tg
        property bool checked: false
        signal toggled()
        width: 52; height: 30; radius: 15
        color: checked ? Theme.accent : Theme.surfaceHi
        border.color: checked ? "transparent" : Theme.textDim
        Behavior on color { CAnim {} }
        Rectangle {
            width: tg.checked ? 22 : 16; height: width; radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: tg.checked ? parent.width - width - 4 : 7
            color: tg.checked ? Theme.onAccent : Theme.textDim
            Behavior on x { Anim { kind: "fastSpatial" } }
            Behavior on width { Anim { kind: "fastSpatial" } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tg.toggled() }
    }
    component Stepper: Row {
        id: stp
        property int value: 0
        property int step: 1
        property int from: 0
        property int to: 100
        property string suffix: ""
        property string zeroText: L.t("никогда")
        signal changed(int v)
        spacing: 6
        Repeater {
            model: [-1, 0, 1]
            delegate: Item {
                required property int modelData
                width: modelData === 0 ? Math.max(64, vt.implicitWidth + 16) : 32
                height: 32
                Rectangle { visible: modelData !== 0; anchors.fill: parent; radius: 16; color: Theme.surfaceHi }
                Text {
                    id: vt
                    anchors.centerIn: parent
                    font.family: Theme.font
                    font.pixelSize: modelData === 0 ? Tokens.font.normal : 18
                    color: modelData === 0 ? Theme.text : Theme.accent
                    text: modelData === 0 ? (stp.value === 0 && stp.from === 0 ? stp.zeroText : stp.value + stp.suffix)
                                          : (modelData < 0 ? "−" : "+")
                }
                StateLayer {
                    visible: modelData !== 0
                    radius: 16
                    onClicked: stp.changed(Math.max(stp.from, Math.min(stp.to, stp.value + modelData * stp.step)))
                }
            }
        }
    }
    component Field: Rectangle {
        id: fl
        property string text: ""
        property string placeholder: ""
        signal accepted(string v)
        width: 240; height: 36; radius: 18
        color: Theme.surface
        border.color: ti.activeFocus ? Theme.accent : Theme.outline
        TextInput {
            id: ti
            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
            verticalAlignment: TextInput.AlignVCenter
            font.family: Theme.font; font.pixelSize: Tokens.font.normal; color: Theme.text
            text: fl.text
            onEditingFinished: fl.accepted(text.trim())
            Text { anchors.verticalCenter: parent.verticalCenter; visible: !ti.text
                   font.family: Theme.font; font.pixelSize: Tokens.font.normal; color: Theme.textDim; text: fl.placeholder }
        }
    }

    property var capturing: null          // строка, которой сейчас назначаем сочетание / the row we're assigning a shortcut to right now
    readonly property string capturingSig: capturing ? capturing.sig : ""
    property string captureMsg: ""
    Item {
        id: keys
        focus: true
        Keys.onPressed: (e) => {
            if (!sw.capturing) {
                if (e.key === Qt.Key_Escape) { ShellState.settingsOpen = false; e.accepted = true; }
                return;
            }
            e.accepted = true;
            if (e.key === Qt.Key_Escape && e.modifiers === Qt.NoModifier) { sw.capturing = null; return; }
            const key = Binds.keyName(e);
            if (!key) {   // только модификатор или неизвестная клавиша (например, русская раскладка) / only a modifier or an unknown key (e.g. the Russian layout)
                if (e.key < Qt.Key_Shift || e.key > Qt.Key_Meta) sw.captureMsg = L.t("эту клавишу не распознать — переключи раскладку на EN");
                return;
            }
            const mods = Binds.modsOf(e);
            // сочетание для правила «глушить в программах» — без проверки занятости (настоящее сочетание всё равно важнее)
            // a shortcut for a "mute in apps" rule: no conflict check (a real binding wins anyway)
            if (sw.capturing.block !== undefined) {
                const r = (ShellState.settings.keyBlocks ?? []).slice(), i = sw.capturing.block;
                if (r[i]) { r[i] = Object.assign({}, r[i], { mods: mods, key: key }); ShellState.set("keyBlocks", r); }
                sw.capturing = null; sw.captureMsg = "";
                return;
            }
            const c = Binds.conflict(mods, key, sw.capturing);
            if (c) { sw.captureMsg = L.t("уже занято: ") + c.text; return; }
            Binds.set(sw.capturing, mods, key);
            sw.capturing = null;
            sw.captureMsg = "";
        }
    }
    onOpenChanged: { if (open) keys.forceActiveFocus(); }

    // ─── разделы ───
    // ─── sections ───
    Column {
        id: side
        x: 16; y: 16
        width: 210
        spacing: 6
        Text { leftPadding: 12; font.family: Theme.font; font.pixelSize: Tokens.font.large
               font.bold: true; color: Theme.text; text: L.t("Настройки") }
        Rectangle {
            width: 210; height: 34; radius: 17; color: Theme.surface
            border.color: findIn.activeFocus ? Theme.accent : "transparent"
            Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 11; color: Theme.textDim }
            TextInput {
                id: findIn
                anchors.fill: parent; anchors.leftMargin: 32; anchors.rightMargin: 10; clip: true
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text
                onTextChanged: ShellState.settingsQuery = text.trim()
                Keys.onEscapePressed: { text = ""; keys.forceActiveFocus(); }
                Text { anchors.verticalCenter: parent.verticalCenter; visible: !findIn.text; font.family: Theme.font
                       font.pixelSize: Tokens.font.smaller; color: Theme.textDim; text: L.t("найти настройку…") }
            }
        }
    }
    Flickable {
        SmoothWheel {}
        x: 16; y: side.y + side.height + 8
        width: 210; height: parent.height - y - 16
        clip: true
        contentHeight: secCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: secCol
            width: 210
            spacing: 2
            Repeater {
                model: sw.sections
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool sel: sw.section === index && sw.query === ""
                    width: 210; height: 48; radius: 16
                    color: sel ? Theme.tonalHi : "transparent"
                    Behavior on color { CAnim {} }
                    Rectangle {
                        x: 8; anchors.verticalCenter: parent.verticalCenter
                        width: 32; height: 32; radius: 11
                        color: parent.sel ? Theme.accent : Theme.surface
                        Icon { anchors.centerIn: parent; name: modelData[0]; size: 13; color: parent.parent.sel ? Theme.onAccent : Theme.accent }
                    }
                    Column {
                        x: 50; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 58
                        Text { font.family: Theme.font; font.pixelSize: Tokens.font.smaller; font.bold: parent.parent.sel
                               color: parent.parent.sel ? Theme.accent : Theme.text; text: modelData[1] }
                        Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Tokens.font.small
                               color: Theme.textDim; text: modelData[2] }
                    }
                    StateLayer { radius: 16; onClicked: { findIn.text = ""; sw.section = index; } }
                }
            }
        }
    }
    Rectangle { x: 242; y: 16; width: 1; height: parent.height - 32; color: Theme.line }

    // ─── содержимое ───
    // ─── content ───
    Flickable {
        SmoothWheel {}
        x: 262; y: 20
        width: parent.width - 282
        height: parent.height - 40
        clip: true
        contentHeight: page.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: page
            width: parent.width
            spacing: 4

            // Вид
            // Look
            Column {
                visible: sw.section === 0 || sw.query !== ""
                width: parent.width
                spacing: 14
                SGroup {
                    title: L.t("Цвета и обои")
    Row2 { icon: "palette"; title: L.t("Цвета"); hint: L.t("neko — палитра с телефона, от обоев — подстраивается под обои, монохром — без цвета")
        Row {
            spacing: 6
            Repeater {
                model: [["neko", "neko"], ["adaptive", L.t("от обоев")], ["mono", L.t("монохром")]]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool sel: ShellState.accent === modelData[0]
                    readonly property bool off: modelData[0] === "adaptive" && !ShellState.wallpaper
                    width: ct.implicitWidth + 28; height: 32; radius: 16
                    opacity: off ? 0.4 : 1
                    color: sel ? Theme.accent : Theme.surfaceHi
                    Behavior on color { CAnim {} }
                    Text { id: ct; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                           color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                    StateLayer { radius: 16; disabled: parent.off || parent.sel; onClicked: ShellState.setAccent(modelData[0]) }
                }
            }
        }
    }
    Row2 { icon: "palette"; title: L.t("Схема цветов из обоев"); hint: L.t(schemeHint(ShellState.settings.scheme ?? "tonal"))
        visible: ShellState.accent === "adaptive"
        Flow {
            width: 360; spacing: 6
            Repeater {
                model: [["tonal", L.t("тональная")], ["neutral", L.t("нейтральная")], ["vibrant", L.t("яркая")], ["expressive", L.t("выразительная")],
                        ["fidelity", L.t("точная")], ["content", L.t("содержательная")], ["rainbow", L.t("радужная")], ["fruit", L.t("фруктовый салат")]]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool sel: (ShellState.settings.scheme ?? "tonal") === modelData[0]
                    width: sct.implicitWidth + 22; height: 30; radius: 15
                    color: sel ? Theme.accent : Theme.surfaceHi
                    Behavior on color { CAnim {} }
                    Text { id: sct; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                           color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                    StateLayer { radius: 15; onClicked: ShellState.set("scheme", modelData[0]) }
                }
            }
        }
    }
    Row2 { icon: "palette"; title: L.t("Акцент из обоев"); hint: L.t("для адаптивных цветов: какой из главных цветов обоев взять")
        visible: ShellState.accent === "adaptive" && ShellState.wallSeeds.length > 0
        Row {
            spacing: 6
            Rectangle {
                readonly property bool sel: (ShellState.settings.seedHue ?? -1) < 0
                width: aat.implicitWidth + 22; height: 30; radius: 15; color: sel ? Theme.accent : Theme.surfaceHi
                Behavior on color { CAnim {} }
                Text { id: aat; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                       color: parent.sel ? Theme.onAccent : Theme.text; text: L.t("авто") }
                StateLayer { radius: 15; onClicked: ShellState.set("seedHue", -1) }
            }
            Repeater {
                model: ShellState.wallSeeds
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool sel: (ShellState.settings.seedHue ?? -1) === modelData.hue
                    width: 30; height: 30; radius: 15
                    color: modelData.color
                    border.width: sel ? 3 : 0; border.color: Theme.text
                    scale: sel ? 1.12 : 1
                    Behavior on scale { Anim { kind: "fastSpatial" } }
                    MouseArea { anchors.fill: parent; onClicked: ShellState.set("seedHue", modelData.hue) }
                }
            }
        }
    }
    Row2 { icon: "wallpaper"; title: L.t("Обои"); hint: L.t("карусель с твоими картинками")
                        Rectangle {
                            width: wt.implicitWidth + 28; height: 32; radius: 16; color: Theme.tonal
                            Text { id: wt; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                                   color: Theme.accent; text: L.t("выбрать…") }
                            StateLayer { radius: 16; onClicked: { ShellState.settingsOpen = false; ShellState.pickerOpen = true; } }
                        }
                    }
                }
                SGroup {
                    title: L.t("Форма")
                    // живой образец: окно, карточка и панель с текущими скруглениями, шрифтом и высотой панели
                    // a live sample: a window, a card and the bar with the current rounding, font and bar height
                    Item {
                        width: parent.width; height: 150
                        Rectangle {
                            anchors.centerIn: parent
                            width: 300; height: 136
                            radius: Math.min(20, (ShellState.settings.screenRadius ?? 0) / 2)
                            color: Theme.frame
                            clip: true
                            Rectangle {          // «окно» / "window"
                                x: 10; y: 10; width: 170; height: parent.height - 10 - Math.round(Tokens.barHeight / 2) - 10
                                radius: ShellState.settings.windowRadius ?? 5
                                color: Theme.surfaceHi
                                Text { x: 10; y: 8; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.text; text: L.t("окно") }
                            }
                            Rectangle {          // «карточка» интерфейса / UI "card"
                                x: 190; y: 10; width: 100; height: 64
                                radius: Tokens.rounding.large
                                color: Theme.surface; border.color: Theme.line
                                Text { anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.normal; color: Theme.accent; text: "Aa" }
                            }
                            Rectangle {          // «панель» / "bar"
                                anchors.bottom: parent.bottom; width: parent.width; height: Math.round(Tokens.barHeight / 2)
                                color: Theme.frame; border.color: Theme.line
                                Row { anchors.centerIn: parent; spacing: 6
                                    Repeater { model: 4; delegate: Rectangle { width: 10 * Tokens.iconK; height: width; radius: width / 2; color: Theme.accent; opacity: 0.6 } } }
                            }
                        }
                    }
    Row2 { icon: "palette"; title: L.t("Скругление интерфейса"); hint: L.t("карточки, выпадашки, борд, меню")
                        Stepper { from: 40; to: 200; step: 10; suffix: "%"; value: ShellState.settings.uiRound ?? 100
                                  onChanged: (v) => ShellState.set("uiRound", v) }
                    }
    Row2 { icon: "palette"; title: L.t("Скругление рамки экрана"); hint: L.t("внутренние углы рамки вокруг окон")
                        Stepper { from: 0; to: 64; step: 4; suffix: " px"; zeroText: "0 px"; value: ShellState.settings.frameRadius ?? 24
                                  onChanged: (v) => ShellState.set("frameRadius", Math.max(1, v)) }
                    }
    Row2 { icon: "palette"; title: L.t("Скругление углов экрана"); hint: L.t("как у телефона: чёрные уголки поверх всего, 0 — выкл")
                        Stepper { from: 0; to: 64; step: 4; suffix: " px"; zeroText: L.t("выкл"); value: ShellState.settings.screenRadius ?? 0
                                  onChanged: (v) => ShellState.set("screenRadius", v) }
                    }
    Row2 { icon: "l_grid"; title: L.t("Скругление окон")
                        Stepper { from: 0; to: 32; step: 1; suffix: " px"; zeroText: "0 px"; value: ShellState.settings.windowRadius ?? 5
                                  onChanged: (v) => ShellState.set("windowRadius", v) }
                    }
    Row2 { icon: "eye"; title: L.t("Непрозрачность активного окна"); hint: L.t("100% — совсем непрозрачное; игры и видео всегда непрозрачные")
        Stepper { from: 30; to: 100; step: 5; suffix: "%"; value: ShellState.settings.winOpacity ?? 90
                  onChanged: (v) => ShellState.set("winOpacity", v) } }
    Row2 { icon: "eye"; title: L.t("Непрозрачность остальных окон")
        Stepper { from: 30; to: 100; step: 5; suffix: "%"; value: ShellState.settings.winOpacityInactive ?? 90
                  onChanged: (v) => ShellState.set("winOpacityInactive", v) } }
    Row2 { icon: "eye"; title: L.t("Сила размытия окон"); hint: L.t("0 — без размытия; больше — мягче, но тяжелее для видеокарты")
                        Stepper { from: 0; to: 10; step: 1; zeroText: L.t("выкл"); value: ShellState.settings.blurStrength ?? 1
                                  onChanged: (v) => ShellState.set("blurStrength", v) }
                    }
    Row2 { icon: "eye"; title: L.t("Настоящая прозрачность"); hint: L.t("за окнами видно размытые окна, а не только обои; тяжелее для видеокарты, пока что-то двигается")
        Toggle { checked: ShellState.settings.realBlur ?? true; onToggled: ShellState.set("realBlur", !checked) } }
                }
                SGroup {
                    title: L.t("Значки")
    Row2 { icon: "apps"; title: L.t("Тема значков"); hint: L.t("смена перезапустит шелл; для Gruvbox лучше выключить «в цвет акцента»")
                        Flow {
                            width: 320
                            spacing: 6
                            Repeater {
                                model: ShellState.iconThemes
                                delegate: Rectangle {
                                    required property string modelData
                                    readonly property bool sel: (ShellState.settings.iconTheme || "breeze-dark") === modelData
                                    width: itx.implicitWidth + 24; height: 32; radius: 16
                                    color: sel ? Theme.accent : Theme.surfaceHi
                                    Text { id: itx; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                                           color: parent.sel ? Theme.onAccent : Theme.text; text: modelData }
                                    StateLayer { radius: 16; onClicked: ShellState.set("iconTheme", modelData) }
                                }
                            }
                        }
                    }
    Row2 { icon: "palette"; title: L.t("Значки в цвет акцента"); hint: L.t("монохромные версии значков, остальные — ч/б с оттенком акцента")
                        Toggle { checked: ShellState.settings.themedIcons ?? true; onToggled: ShellState.set("themedIcons", !checked) }
                    }
                }
                SGroup {
                    title: L.t("Курсор")
                    Row2 { icon: "apps"; title: L.t("Тема курсора"); hint: L.t("применяется сразу в шелле и mango; открытые программы подхватят после перезапуска")
                        Flow {
                            width: 340; spacing: 6
                            Repeater {
                                model: ShellState.cursorThemes
                                delegate: Rectangle {
                                    required property string modelData
                                    readonly property bool sel: (ShellState.settings.cursorTheme ?? "") === modelData
                                    width: cth.implicitWidth + 24; height: 30; radius: 15
                                    color: sel ? Theme.accent : Theme.surfaceHi
                                    Behavior on color { CAnim {} }
                                    Text { id: cth; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                           color: parent.sel ? Theme.onAccent : Theme.text; text: modelData }
                                    StateLayer { radius: 15; onClicked: ShellState.set("cursorTheme", modelData) }
                                }
                            }
                        }
                    }
                    Row2 { icon: "apps"; title: L.t("Размер курсора")
                        Stepper { from: 16; to: 64; step: 4; suffix: " px"; value: ShellState.settings.cursorSize ?? 24
                                  onChanged: (v) => ShellState.set("cursorSize", v) }
                    }
                }
            }

            // Рабочий стол
            // Desktop
            Column {
                visible: sw.section === 1 || sw.query !== ""
                width: parent.width
                spacing: 14
                SGroup {
                    title: L.t("На рабочем столе")
    Row2 { icon: "sparkle"; title: L.t("Частицы на рабочем столе"); hint: L.t("ещё — ПКМ по рабочему столу")
                        Flow {
                            width: 380; spacing: 4
                            Repeater {
                                model: [["petals", L.t("лепестки")], ["stars", L.t("звёзды")], ["snow", L.t("снег")], ["bubbles", L.t("пузырьки")], ["off", L.t("выкл")]]
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool sel: ShellState.particles === modelData[0]
                                    width: pt.implicitWidth + 20; height: 28; radius: 14
                                    color: sel ? Theme.accent : Theme.surfaceHi
                                    Behavior on color { CAnim {} }
                                    Text { id: pt; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                           color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                                    StateLayer { radius: 14; onClicked: ShellState.setParticles(parent.modelData[0]) }
                                }
                            }
                        }
                    }
    Row2 { visible: ShellState.particles !== "off"; icon: "sparkle"; title: L.t("Количество частиц"); hint: L.t("100% — как задумано, плотность подстраивается под размер экрана")
                        Stepper { from: 25; to: 400; step: 25; suffix: "%"; value: ShellState.settings.partCount ?? 100; onChanged: (v) => ShellState.set("partCount", v) } }
    Row2 { visible: ShellState.particles !== "off"; icon: "sparkle"; title: L.t("Размер частиц")
                        Stepper { from: 4; to: 48; step: 1; suffix: " px"; value: ShellState.settings.partSize ?? 13; onChanged: (v) => ShellState.set("partSize", v) } }
    Row2 { visible: ShellState.particles !== "off"; icon: "sparkle"; title: L.t("Разброс размеров"); hint: L.t("0 — все одного размера; 100% — от крошечных до вдвое больших")
                        Stepper { from: 0; to: 100; step: 5; suffix: "%"; value: ShellState.settings.partSizeVar ?? 45; onChanged: (v) => ShellState.set("partSizeVar", v) } }
    Row2 { visible: ShellState.particles !== "off"; icon: "sparkle"; title: L.t("Прозрачность частиц"); hint: L.t("насколько частицы видны; у каждой своя — чуть больше или меньше")
                        Stepper { from: 5; to: 100; step: 5; suffix: "%"; value: ShellState.settings.partOpacity ?? 22; onChanged: (v) => ShellState.set("partOpacity", v) } }
    Row2 { visible: ShellState.particles !== "off"; icon: "sparkle"; title: L.t("Скорость падения")
                        Stepper { from: 25; to: 400; step: 25; suffix: "%"; value: ShellState.settings.partSpeed ?? 100; onChanged: (v) => ShellState.set("partSpeed", v) } }
    Row2 { visible: ShellState.particles !== "off"; icon: "sparkle"; title: L.t("Скорость вращения"); hint: L.t("0 — не вращаются")
                        Stepper { from: 0; to: 400; step: 25; suffix: "%"; zeroText: L.t("выкл"); value: ShellState.settings.partSpin ?? 100; onChanged: (v) => ShellState.set("partSpin", v) } }
    Row2 { visible: ShellState.particles !== "off"; icon: "sparkle"; title: L.t("Покачивание"); hint: L.t("насколько частицы сносит в стороны; 0 — падают прямо")
                        Stepper { from: 0; to: 300; step: 25; suffix: "%"; zeroText: L.t("выкл"); value: ShellState.settings.partSway ?? 100; onChanged: (v) => ShellState.set("partSway", v) } }
    Row2 { visible: ShellState.particles !== "off"; icon: "palette"; title: L.t("Цвет частиц"); hint: L.t("«сам» — акцент, а снег — цветом текста")
                        Chips { key: "partColor"; def: "auto"; opts: [["auto", L.t("сам")], ["accent", L.t("акцент")], ["accent2", L.t("второй акцент")], ["text", L.t("как текст")], ["mix", L.t("вперемешку")]] } }
    Row2 { visible: ShellState.particles !== "off"; icon: "sparkle"; title: L.t("Пауза, когда есть окна"); hint: L.t("пока на странице открыты окна, стол почти не виден — частицы замирают и не тратят видеокарту")
                        Toggle { checked: ShellState.settings.partPauseWindows ?? true; onToggled: ShellState.set("partPauseWindows", !checked) } }
    Row2 { icon: "bars"; title: L.t("Визуализатор"); hint: L.t("волны музыки над обоями, под окнами; нужен пакет cava. В полноэкранных играх не рисуется")
                        Toggle { checked: ShellState.settings.visualizer ?? false; onToggled: ShellState.set("visualizer", !checked) } }
    Row2 { visible: ShellState.settings.visualizer ?? false; title: L.t("Вид визуализатора")
                        Column {
                            spacing: 6
                            Row {
                                spacing: 6
                                Repeater {
                                    model: [["wave", L.t("волна")], ["bars", L.t("столбики")]]
                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool sel: (ShellState.settings.vizStyle ?? "wave") === modelData[0]
                                        width: vsx.implicitWidth + 24; height: 30; radius: 15; color: sel ? Theme.accent : Theme.surfaceHi
                                        Text { id: vsx; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                                               color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                                        StateLayer { radius: 15; onClicked: ShellState.set("vizStyle", modelData[0]) }
                                    }
                                }
                            }
                            Row {
                                spacing: 6
                                Repeater {
                                    model: [["bottom", L.t("снизу")], ["top", L.t("сверху")], ["both", L.t("сверху и снизу")]]
                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool sel: (ShellState.settings.vizPlace ?? "bottom") === modelData[0]
                                        width: vpx.implicitWidth + 24; height: 30; radius: 15; color: sel ? Theme.accent : Theme.surfaceHi
                                        Text { id: vpx; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                                               color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                                        StateLayer { radius: 15; onClicked: ShellState.set("vizPlace", modelData[0]) }
                                    }
                                }
                            }
                            Row {
                                spacing: 10
                                Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                                       color: Theme.text; text: L.t("высота") }
                                Stepper { from: 40; to: 400; step: 20; suffix: " px"; value: ShellState.settings.vizHeight ?? 140
                                          onChanged: (v) => ShellState.set("vizHeight", v) }
                                Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                                       color: Theme.text; text: L.t("яркость") }
                                Stepper { from: 10; to: 100; step: 10; suffix: "%"; value: ShellState.settings.vizOpacity ?? 60
                                          onChanged: (v) => ShellState.set("vizOpacity", v) }
                            }
                        }
                    }
    Row2 { icon: "hand_pointer"; title: L.t("Рамка выделения на рабочем столе"); hint: L.t("зажать ЛКМ на пустом месте и вести — как в обычных DE. Ничего не выделяет, просто приятно")
                        Toggle { checked: ShellState.settings.desktopSelect ?? true; onToggled: ShellState.set("desktopSelect", !checked) } }
    Row2 { visible: ShellState.settings.desktopSelect ?? true; icon: "hand_pointer"; title: L.t("Как долго гаснет рамка"); hint: L.t("после того как отпустишь кнопку; 0 — исчезает сразу")
                        Stepper { from: 0; to: 3000; step: 100; suffix: L.lang === "en" ? " ms" : " мс"; zeroText: L.t("сразу")
                                  value: ShellState.settings.desktopSelectFade ?? 420; onChanged: (v) => ShellState.set("desktopSelectFade", v) } }
    Row2 { icon: "image"; title: L.t("Гифки на экране"); hint: L.t("GIF, WebP, APNG поверх экрана или на рабочем столе; клики проходят насквозь. Ctrl+Alt+G — двигать мышью, колесо — размер, ПКМ — спрятать; ещё раз Ctrl+Alt+G — готово")
                        Rectangle {
                            width: gax.implicitWidth + 24; height: 32; radius: 16; color: Theme.surfaceHi
                            Text { id: gax; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                                   color: Theme.text; text: L.t("добавить…") }
                            StateLayer { radius: 16; onClicked: ShellState.pickGif() }
                        }
                    }
    Repeater {
        model: ShellState.settings.gifs ?? []
        delegate: Row2 {
            id: gr
            required property var modelData
            title: modelData.file.split("/").pop().replace(/^[0-9]+-/, "")
            hint: (modelData.top ? L.t("поверх всего") : L.t("на рабочем столе")) + " · " + (modelData.op ?? 100) + "%"
            Row {
                spacing: 6
                Rectangle {
                    width: 44; height: 32; radius: 8; color: Theme.surface; clip: true
                    AnimatedImage { anchors.fill: parent; source: "file://" + modelData.file; playing: false; fillMode: Image.PreserveAspectFit }
                }
                Toggle { anchors.verticalCenter: parent.verticalCenter; checked: !!modelData.on
                         onToggled: ShellState.updateGif(modelData.id, { on: !checked }) }
                Repeater {
                    model: [[false, L.t("стол")], [true, L.t("поверх")]]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool sel: !!gr.modelData.top === modelData[0]
                        anchors.verticalCenter: parent.verticalCenter
                        width: glx.implicitWidth + 20; height: 28; radius: 14; color: sel ? Theme.accent : Theme.surfaceHi
                        Text { id: glx; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                               color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                        StateLayer { radius: 14; onClicked: ShellState.updateGif(gr.modelData.id, { top: modelData[0] }) }
                    }
                }
                Stepper { anchors.verticalCenter: parent.verticalCenter; from: 10; to: 100; step: 10; suffix: "%"; value: modelData.op ?? 100
                          onChanged: (v) => ShellState.updateGif(modelData.id, { op: v }) }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 28; radius: 14; color: modelData.flip ? Theme.accent : Theme.surfaceHi
                    Icon { anchors.centerIn: parent; name: "sync"; size: 10; color: modelData.flip ? Theme.onAccent : Theme.text }
                    StateLayer { radius: 14; onClicked: ShellState.updateGif(modelData.id, { flip: !modelData.flip }) }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 28; radius: 14; color: Theme.surfaceHi
                    Icon { anchors.centerIn: parent; name: "bin"; size: 10; color: Theme.danger }
                    StateLayer { radius: 14; onClicked: ShellState.removeGif(modelData.id) }
                }
            }
        }
    }
                }
                SGroup {
                    title: L.t("Пластинка в плеере")
    Row2 { icon: "music"; title: L.t("Узоры на пластинке"); hint: L.t("наклейка для треков без обложки; выключи лишние узоры или все сразу")
                        Toggle { checked: ShellState.settings.vinylLabels ?? true; onToggled: ShellState.set("vinylLabels", !checked) } }
    Row2 { visible: ShellState.settings.vinylLabels ?? true; title: L.t("Какие узоры")
                        Flow {
                            width: 340; spacing: 6
                            Repeater {
                                model: ShellState.vinylKindsAll
                                delegate: Rectangle {
                                    required property string modelData
                                    readonly property var cur: ShellState.settings.vinylKinds ?? ShellState.vinylKindsAll
                                    readonly property bool sel: cur.includes(modelData)
                                    width: vkx.implicitWidth + 24; height: 30; radius: 15; color: sel ? Theme.accent : Theme.surfaceHi
                                    Text { id: vkx; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                                           color: parent.sel ? Theme.onAccent : Theme.text
                                           text: L.t(({ split: "доли", triangles: "треугольники", rings: "кольца", squares: "квадраты", flowers: "цветы",
                                                        moons: "луны", stars: "звёзды", plus: "плюсы", hexes: "соты", paws: "лапки" })[modelData]) }
                                    StateLayer { radius: 15; onClicked: ShellState.set("vinylKinds", parent.sel ? parent.cur.filter(k => k !== modelData) : parent.cur.concat([modelData])) }
                                }
                            }
                        }
                    }
                }
            }

            // Текст и язык
            // Text and language
            Column {
                visible: sw.section === 2 || sw.query !== ""
                width: parent.width
                spacing: 14
                SGroup {
                    title: L.t("Шрифты")
    Row2 { icon: "music"; title: L.t("Шрифт шелла"); hint: L.t("значки всегда из Nyaspace. Свой шрифт — любой установленный (начни вводить название) или файлом .ttf/.otf")
                        Column {
                            spacing: 6
                            Row {
                                spacing: 6
                                Repeater {
                                    model: [["Nyaspace", "Nyaspace"], ["MonaspiceXe Nerd Font", "Xenon"], ["MonaspiceAr Nerd Font", "Argon"]]
                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool have: Theme.families.includes(modelData[0])
                                        readonly property bool sel: Theme.font === modelData[0]
                                        visible: have
                                        width: fx.implicitWidth + 24; height: 32; radius: 16
                                        color: sel ? Theme.accent : Theme.surfaceHi
                                        Text { id: fx; anchors.centerIn: parent; font.family: modelData[0]
                                               font.pixelSize: Tokens.font.smaller; color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                                        StateLayer { radius: 16; onClicked: { ShellState.set("uiFontFile", ""); ShellState.set("uiFont", modelData[0]); } }
                                    }
                                }
                                Rectangle {
                                    width: ffx.implicitWidth + 24; height: 32; radius: 16; color: Theme.surfaceHi
                                    Text { id: ffx; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                                           color: Theme.text; text: L.t("файл…") }
                                    StateLayer { radius: 16; onClicked: ShellState.pickFont("text") }
                                }
                            }
                            Rectangle {
                                width: 260; height: 30; radius: 15; color: Theme.surface; border.color: fontIn.activeFocus ? Theme.accent : Theme.line
                                TextInput { id: fontIn; anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; clip: true
                                            verticalAlignment: TextInput.AlignVCenter; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.text
                                            Text { anchors.verticalCenter: parent.verticalCenter; visible: !fontIn.text; font.family: Theme.font
                                                   font.pixelSize: Tokens.font.small; color: Theme.textDim; text: Theme.font } }
                            }
                            Flow {
                                width: 260; spacing: 4
                                Repeater {
                                    model: fontIn.text.length < 2 ? [] : Theme.families.filter(f => f.toLowerCase().includes(fontIn.text.toLowerCase())).slice(0, 8)
                                    delegate: Rectangle {
                                        required property string modelData
                                        width: Math.min(260, fft.implicitWidth + 18); height: 26; radius: 13; color: Theme.surfaceHi
                                        Text { id: fft; anchors.centerIn: parent; width: Math.min(implicitWidth, 242); elide: Text.ElideRight
                                               font.family: modelData; font.pixelSize: Tokens.font.small; color: Theme.text; text: modelData }
                                        StateLayer { radius: 13; onClicked: { ShellState.set("uiFontFile", ""); ShellState.set("uiFont", modelData); fontIn.text = ""; } }
                                    }
                                }
                            }
                        }
                    }
    Row2 { icon: "sparkle"; title: L.t("Эмодзи"); hint: (ShellState.settings.emojiFont || "Noto Color Emoji") + " — " + L.t("свой цветной шрифт эмодзи файлом; меняется для всех программ")
                        Row {
                            spacing: 6
                            Rectangle {
                                width: efx.implicitWidth + 24; height: 32; radius: 16; color: Theme.surfaceHi
                                Text { id: efx; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                                       color: Theme.text; text: L.t("файл…") }
                                StateLayer { radius: 16; onClicked: ShellState.pickFont("emoji") }
                            }
                            Rectangle {
                                visible: !!ShellState.settings.emojiFont
                                width: erx.implicitWidth + 24; height: 32; radius: 16; color: Theme.surfaceHi
                                Text { id: erx; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                                       color: Theme.text; text: L.t("стандартные") }
                                StateLayer { radius: 16; onClicked: ShellState.resetEmoji() }
                            }
                        }
                    }
    Row2 { icon: "music"; title: L.t("Размер шрифта")
                        Stepper { from: 70; to: 160; step: 5; suffix: "%"; value: ShellState.settings.fontScale ?? 100
                                  onChanged: (v) => ShellState.set("fontScale", v) }
                    }
                }
                SGroup {
                    title: L.t("Язык и имя")
    Row2 { icon: "public"; title: L.lang === "en" ? "Language" : "Язык"; hint: "Super+G"
                        Row {
                            spacing: 6
                            Repeater {
                                model: [["en", "English"], ["ru", "Русский"]]
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool sel: L.lang === modelData[0]
                                    width: lt.implicitWidth + 24; height: 32; radius: 16
                                    color: sel ? Theme.accent : Theme.surfaceHi
                                    Text { id: lt; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                                           color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                                    StateLayer { radius: 16; onClicked: ShellState.set("lang", modelData[0]) }
                                }
                            }
                        }
                    }
    Row2 { icon: "user"; title: L.t("Как тебя называть"); hint: L.t("в приветствии, на блокировке и в меню питания")
                        Field { text: ShellState.settings.userName ?? ""; placeholder: ShellState.sysUser; onAccepted: (v) => ShellState.set("userName", v) }
                    }
                }
            }

            // Панель и меню
            // Bar and menu
            Column {
                visible: sw.section === 3 || sw.query !== ""
                width: parent.width
                spacing: 14
                SGroup {
                    title: L.t("Панель")
    Row2 { icon: "apps"; title: L.t("Высота панели")
                        Stepper { from: 40; to: 80; step: 2; suffix: " px"; value: ShellState.settings.barHeight ?? 54
                                  onChanged: (v) => ShellState.set("barHeight", v) }
                    }
    Row2 { icon: "apps"; title: L.t("Размер значков")
                        Stepper { from: 60; to: 160; step: 5; suffix: "%"; value: ShellState.settings.iconScale ?? 100
                                  onChanged: (v) => ShellState.set("iconScale", v) }
                    }
    Row2 { icon: "apps"; title: L.t("Порядок значков на панели"); hint: L.t("сверху вниз — это слева направо; перетащи строку на новое место, глаз — спрятать значок")
                        DragList {
                            model: {
                                const o = (ShellState.settings.trayOrder ?? ["tray", "kb", "battery", "audio", "bt", "wifi", "vpn", "clock", "notifs"]).slice();
                                if (!o.includes("vpn")) o.splice(Math.max(0, o.indexOf("wifi") + 1), 0, "vpn");
                                return o;
                            }
                            names: ({ tray: L.t("фоновые приложения"), kb: L.t("раскладка"), battery: Power.present ? L.t("батарея") : L.t("питание"),
                                      audio: L.t("звук"), bt: "Bluetooth", wifi: "Wi-Fi", vpn: "VPN", clock: L.t("часы"), notifs: L.t("уведомления") })
                            onReordered: (o) => ShellState.set("trayOrder", o)
                            canHide: true
                            hidden: ShellState.settings.trayHidden ?? []
                            onToggled: (k) => { const h = ShellState.settings.trayHidden ?? [];
                                                ShellState.set("trayHidden", h.includes(k) ? h.filter(x => x !== k) : h.concat([k])); }
                        }
                    }
    Row2 { icon: "power_settings_new"; title: L.t("Порядок кнопок меню питания"); hint: L.t("Super+Space; перетащи строку на новое место")
                        DragList {
                            model: ShellState.settings.powerOrder ?? ["lock", "sleep", "logout", "reboot", "poweroff"]
                            names: ({ lock: L.t("блокировка"), sleep: L.t("сон"), logout: L.t("выход"), reboot: L.t("ребут"), poweroff: L.t("выкл") })
                            onReordered: (o) => ShellState.set("powerOrder", o)
                        }
                    }
    Row2 { icon: "pets"; title: L.t("Значок меню приложений"); hint: L.t("кнопка слева на панели")
                        Row {
                            spacing: 6
                            Repeater {
                                model: ["pets", "apps", "star", "coffee", "magic", "moon", "bolt", "sparkle"]
                                delegate: Rectangle {
                                    required property string modelData
                                    readonly property bool sel: (ShellState.settings.launcherIcon || "pets") === modelData
                                    width: 32; height: 32; radius: 16; color: sel ? Theme.accent : Theme.surfaceHi
                                    Icon { anchors.centerIn: parent; name: modelData; size: 13; color: parent.sel ? Theme.onAccent : Theme.text }
                                    StateLayer { radius: 16; onClicked: ShellState.set("launcherIcon", modelData) }
                                }
                            }
                        }
                    }
                }
                SGroup {
                    title: L.t("Меню приложений")
                    Row2 { icon: "search"; title: L.t("Поиск всегда на виду"); hint: L.t("иначе строка поиска появляется, только когда начинаешь печатать")
                        Toggle { checked: ShellState.settings.launcherSearchAlways ?? false; onToggled: ShellState.set("launcherSearchAlways", !checked) } }
                    Row2 { icon: "power_settings_new"; title: L.t("Кнопки питания в меню"); hint: L.t("выход, перезагрузка и выключение рядом с поиском")
                        Toggle { checked: ShellState.settings.launcherPower ?? true; onToggled: ShellState.set("launcherPower", !checked) } }
                }
                SGroup {
                    title: L.t("Борд")
    Row2 { icon: "dashboard"; title: L.t("Борд ждёт курсор"); hint: L.t("через сколько закрываться, если увести курсор")
                        Stepper { from: 0; to: 1500; step: 50; suffix: L.lang === "en" ? " ms" : " мс"; zeroText: "0"
                                  value: ShellState.settings.dashDelay ?? 150; onChanged: (v) => ShellState.set("dashDelay", v) }
                    }
    Row2 { icon: "dashboard"; title: L.t("Вкладки борда"); hint: L.t("ненужные можно спрятать; хотя бы одна остаётся. Браузер — это отдельный Firefox, он заметно ест память")
                        Flow {
                            width: 380; spacing: 4
                            Repeater {
                                model: [["home", L.t("Главная")], ["player", L.t("Плеер")], ["music", L.t("Музыка")], ["eq", L.t("Эквалайзер")],
                                        ["weather", L.t("Погода")], ["browser", L.t("Браузер")]]
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property var on: ShellState.settings.dashTabs ?? ["home", "player", "music", "eq", "weather"]
                                    readonly property bool sel: on.includes(modelData[0])
                                    width: dtx.implicitWidth + 18; height: 26; radius: 13; color: sel ? Theme.accent : Theme.surfaceHi
                                    Text { id: dtx; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                           color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                                    StateLayer { radius: 13; onClicked: {
                                        const k = parent.modelData[0], cur = parent.on;
                                        const next = parent.sel ? cur.filter(x => x !== k) : cur.concat([k]);
                                        if (next.length) ShellState.set("dashTabs", next);
                                    } }
                                }
                            }
                        }
                    }
                }
            }

            // Окна
            // Windows
            Column {
                visible: sw.section === 4 || sw.query !== ""
                width: parent.width
                spacing: 14
                SGroup {
                    title: L.t("Сетка")
    Row2 { icon: "l_grid"; title: L.t("Окон на странице в сетке"); hint: L.t("лишние уезжают на следующую свободную страницу (с последней — по кругу); если заняты все — новое окно сворачивается")
                        Stepper { from: 2; to: 6; value: ShellState.settings.treeLimit ?? 4; onChanged: (v) => ShellState.set("treeLimit", v) }
                    }
    Row2 { icon: "dashboard"; title: L.t("Число страниц"); hint: L.t("точки на панели становятся мельче, когда страниц больше девяти")
                        Stepper { from: 2; to: 31; value: ShellState.pageCount; onChanged: (v) => ShellState.set("pageCount", v) }
                    }
    Row2 { icon: "l_grid"; title: L.t("Минимальная ширина окна в сетке")
                        Stepper { from: 320; to: 1200; step: 40; suffix: " px"; value: ShellState.settings.minW; onChanged: (v) => ShellState.set("minW", v) }
                    }
    Row2 { icon: "l_grid"; title: L.t("Минимальная высота окна в сетке")
                        Stepper { from: 240; to: 900; step: 40; suffix: " px"; value: ShellState.settings.minH; onChanged: (v) => ShellState.set("minH", v) }
                    }
    Row2 { icon: "l_grid"; title: L.t("Режим «мастер + стек»"); hint: L.t("добавляет его в переключение Super+Tab")
                        Toggle { checked: ShellState.settings.masterStack; onToggled: ShellState.set("masterStack", !checked) }
                    }
                }
                SGroup {
                    title: L.t("Лента и полный экран")
    Row2 { icon: "l_scroller"; title: L.t("Два окна в ленте — по половине"); hint: L.t("с третьим окном все снова по 1/3")
                        Toggle { checked: ShellState.settings.halfForTwo; onToggled: ShellState.set("halfForTwo", !checked) }
                    }
                }
            }

            // Ввод
            // Input
            Column {
                visible: sw.section === 5 || sw.query !== ""
                width: parent.width
                spacing: 14
                SGroup {
                    title: L.t("Клавиатура")
    Row2 { icon: "keyboard"; title: L.t("Раскладки клавиатуры"); hint: L.t("× — убрать; начни вводить язык или код (German, de, us(dvorak)…) и выбери из подсказок") + sw.imeNote
        Column {
            spacing: 6
            Flow {
                width: 340; spacing: 6
                Repeater {
                    model: ShellState.settings.kbLayouts ?? ["us"]
                    delegate: Rectangle {
                        required property string modelData
                        width: Math.min(340, kbt.implicitWidth + 34); height: 30; radius: 15; color: Theme.surfaceHi
                        Text { id: kbt; x: 12; anchors.verticalCenter: parent.verticalCenter; width: Math.min(implicitWidth, 300); elide: Text.ElideRight
                               font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.text
                               text: "<b>" + modelData.toUpperCase() + "</b>  " + ShellState.layoutName(modelData) }
                        Icon { anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter
                               name: "close"; size: 8; color: Theme.textDim }
                        MouseArea { anchors.fill: parent; onClicked: {
                            const l = (ShellState.settings.kbLayouts ?? ["us"]).filter(x => x !== modelData);
                            if (l.length) ShellState.set("kbLayouts", l); } }
                    }
                }
            }
            Rectangle {
                width: 260; height: 30; radius: 15; color: Theme.surface; border.color: kbIn.activeFocus ? Theme.accent : Theme.line
                TextInput {
                    id: kbIn
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; clip: true
                    verticalAlignment: TextInput.AlignVCenter; maximumLength: 40
                    font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.text
                    // только раскладки, которые есть в системе (список xkb) — иначе mango молча оставит прежнюю
                    // only layouts that exist in the system (the xkb list), otherwise mango silently keeps the old one
                    readonly property var found: ShellState.findLayouts(text)
                    function add(code: string): void {
                        const l = (ShellState.settings.kbLayouts ?? ["us"]).slice();
                        if (code && !l.includes(code)) { l.push(code); ShellState.set("kbLayouts", l); }
                        text = "";
                    }
                    Keys.onReturnPressed: if (found.length) add(found[0][0])
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: !kbIn.text; font.family: Theme.font
                           font.pixelSize: Tokens.font.small; color: Theme.textDim; text: L.t("+ язык или код") }
                }
            }
            Text { visible: kbIn.text.length >= 2 && kbIn.found.length === 0; font.family: Theme.font; font.pixelSize: Tokens.font.small
                   color: Theme.danger; text: L.t("такой раскладки в системе нет") }
            Flow {
                width: 340; spacing: 4
                Repeater {
                    model: kbIn.found
                    delegate: Rectangle {
                        required property var modelData
                        width: Math.min(340, kbs.implicitWidth + 18); height: 26; radius: 13; color: Theme.surfaceHi
                        Text { id: kbs; anchors.centerIn: parent; width: Math.min(implicitWidth, 322); elide: Text.ElideRight
                               font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.text
                               text: "<b>" + modelData[0] + "</b>  " + modelData[1] }
                        StateLayer { radius: 13; onClicked: kbIn.add(modelData[0]) }
                    }
                }
            }
        }
    }
    Row2 { icon: "keyboard"; title: L.t("Переключение раскладки")
        Flow {
            width: 340; spacing: 6
            Repeater {
                model: [["grp:alt_shift_toggle", "Alt+Shift"], ["grp:ctrl_shift_toggle", "Ctrl+Shift"],
                        ["grp:win_space_toggle", "Super+Space"], ["grp:caps_toggle", "Caps Lock"]]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool sel: (ShellState.settings.kbToggle ?? "grp:alt_shift_toggle") === modelData[0]
                    width: kst.implicitWidth + 24; height: 30; radius: 15
                    color: sel ? Theme.accent : Theme.surfaceHi
                    Behavior on color { CAnim {} }
                    Text { id: kst; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                           color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                    StateLayer { radius: 15; onClicked: ShellState.set("kbToggle", modelData[0]) }
                }
            }
        }
    }
    Row2 { icon: "keyboard"; title: L.t("Задержка перед повтором"); hint: L.t("сколько держать клавишу, пока она не начнёт повторяться")
                        Stepper { from: 150; to: 1000; step: 50; suffix: L.lang === "en" ? " ms" : " мс"; value: ShellState.mangoOpt("repeat_delay", 600)
                                  onChanged: (v) => ShellState.setMango("repeat_delay", v) } }
    Row2 { icon: "keyboard"; title: L.t("Скорость повтора"); hint: L.t("символов в секунду, пока клавиша зажата")
                        Stepper { from: 5; to: 80; step: 5; value: ShellState.mangoOpt("repeat_rate", 25)
                                  onChanged: (v) => ShellState.setMango("repeat_rate", v) } }
    Row2 { icon: "keyboard"; title: L.t("NumLock при входе")
                        Toggle { checked: ShellState.mangoOpt("numlockon", 0) == 1; onToggled: ShellState.setMango("numlockon", checked ? 0 : 1) } }
    Row2 { icon: "keyboard"; title: L.t("Глушить сочетания в программах")
           hint: L.t("например, Ctrl+Q, от которого DeltaChat или Telegram закрываются целиком. Когда в фокусе эти программы, сочетание ничего не делает; в остальных окнах работает как обычно. Программы — по имени пакета (app id), через пробел")
                        Column {
                            spacing: 6
                            readonly property var rules: ShellState.settings.keyBlocks ?? []
                            function put(i: int, patch): void {
                                const r = rules.slice(); r[i] = Object.assign({}, r[i], patch); ShellState.set("keyBlocks", r);
                            }
                            id: kbr
                            Repeater {
                                model: kbr.rules
                                delegate: Row {
                                    id: kbRow
                                    required property var modelData
                                    required property int index
                                    spacing: 6
                                    // сочетание: клик — нажать новое
                                    // shortcut: click and press a new one
                                    Rectangle {
                                        readonly property bool active: sw.capturingSig === "block" + kbRow.index
                                        width: Math.max(96, kbc.implicitWidth + 24); height: 36; radius: 18
                                        color: active ? Theme.accent : Theme.surfaceHi
                                        Text { id: kbc; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                               color: parent.active ? Theme.onAccent : Theme.text
                                               text: parent.active ? L.t("нажми…") : kbRow.modelData.key ? Binds.pretty(kbRow.modelData.mods || "NONE", kbRow.modelData.key, "bind") : L.t("сочетание") }
                                        StateLayer { radius: 18; onClicked: { sw.captureMsg = ""; sw.capturing = { block: kbRow.index, sig: "block" + kbRow.index }; keys.forceActiveFocus(); } }
                                    }
                                    Field { width: 200; text: kbRow.modelData.apps ?? ""; placeholder: "deltachat"
                                            onAccepted: (v) => kbr.put(kbRow.index, { apps: v }) }
                                    Rectangle {
                                        width: 36; height: 36; radius: 18; color: Theme.surfaceHi
                                        Icon { anchors.centerIn: parent; name: "close"; size: 11; color: Theme.textDim }
                                        StateLayer { radius: 18; onClicked: ShellState.set("keyBlocks", kbr.rules.filter((_, k) => k !== kbRow.index)) }
                                    }
                                }
                            }
                            Rectangle {
                                width: kba.implicitWidth + 30; height: 32; radius: 16; color: Theme.surfaceHi
                                Text { id: kba; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.text
                                       text: "+ " + L.t("правило") }
                                StateLayer { radius: 16; onClicked: ShellState.set("keyBlocks", kbr.rules.concat([{ mods: "CTRL", key: "q", apps: "" }])) }
                            }
                            // подсказка: пакеты открытых окон — клик добавляет в последнее правило
                            // a hint: packages of open windows, a click adds one to the last rule
                            Text { visible: kbr.rules.length > 0 && kbOpen.model.length > 0; font.family: Theme.font
                                   font.pixelSize: Tokens.font.smaller; color: Theme.textDim; text: L.t("открытые окна — клик добавит в последнее правило:") }
                            Flow {
                                width: 380; spacing: 4
                                visible: kbr.rules.length > 0
                                Repeater {
                                    id: kbOpen
                                    model: [...new Set(ShellState.mangoClients.map(c => c.appid || "").filter(x => x))].sort()
                                    delegate: Rectangle {
                                        required property string modelData
                                        width: kbo.implicitWidth + 18; height: 26; radius: 13; color: Theme.surfaceHi
                                        Text { id: kbo; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                               color: Theme.text; text: parent.modelData }
                                        StateLayer { radius: 13; onClicked: {
                                            const i = kbr.rules.length - 1, cur = String(kbr.rules[i].apps ?? "").split(/\s+/).filter(x => x);
                                            if (!cur.includes(parent.modelData)) kbr.put(i, { apps: cur.concat([parent.modelData]).join(" ") });
                                        } }
                                    }
                                }
                            }
                        }
                    }
                }
                SGroup {
                    title: L.t("Тачпад")
    Row2 { icon: "hand_pointer"; title: L.t("Касание — клик")
                        Toggle { checked: ShellState.mangoOpt("tap_to_click", 1) == 1; onToggled: ShellState.setMango("tap_to_click", checked ? 0 : 1) } }
    Row2 { icon: "hand_pointer"; title: L.t("Перетаскивание касанием"); hint: L.t("двойное касание и вести палец — тащит, как зажатая кнопка")
                        Toggle { checked: ShellState.mangoOpt("tap_and_drag", 1) == 1; onToggled: ShellState.setMango("tap_and_drag", checked ? 0 : 1) } }
    Row2 { icon: "hand_pointer"; title: L.t("Естественная прокрутка"); hint: L.t("содержимое едет за пальцами, как на телефоне")
                        Toggle { checked: ShellState.mangoOpt("trackpad_natural_scrolling", 0) == 1; onToggled: ShellState.setMango("trackpad_natural_scrolling", checked ? 0 : 1) } }
    Row2 { icon: "keyboard"; title: L.t("Выключать, пока печатаешь")
                        Toggle { checked: ShellState.mangoOpt("trackpad_disable_while_typing", 1) == 1; onToggled: ShellState.setMango("trackpad_disable_while_typing", checked ? 0 : 1) } }
    Row2 { icon: "hand_pointer"; title: L.t("Скорость указателя"); hint: L.t("0 — как задумано устройством; меньше — медленнее, больше — быстрее")
                        Stepper { from: -10; to: 10; step: 1; value: Math.round(ShellState.mangoOpt("trackpad_accel_speed", 0) * 10)
                                  onChanged: (v) => ShellState.setMango("trackpad_accel_speed", (v / 10).toFixed(1)) } }
    Row2 { icon: "hand_pointer"; title: L.t("Скорость прокрутки")
                        Stepper { from: 2; to: 30; step: 1; value: Math.round(ShellState.mangoOpt("trackpad_scroll_factor", 1) * 10)
                                  onChanged: (v) => ShellState.setMango("trackpad_scroll_factor", (v / 10).toFixed(1)) } }
                }
                SGroup {
                    title: L.t("Мышь")
    Row2 { icon: "hand_pointer"; title: L.t("Естественная прокрутка")
                        Toggle { checked: ShellState.mangoOpt("mouse_natural_scrolling", 0) == 1; onToggled: ShellState.setMango("mouse_natural_scrolling", checked ? 0 : 1) } }
    Row2 { icon: "hand_pointer"; title: L.t("Скорость указателя"); hint: L.t("0 — как задумано устройством; меньше — медленнее, больше — быстрее")
                        Stepper { from: -10; to: 10; step: 1; value: Math.round(ShellState.mangoOpt("mouse_accel_speed", 0) * 10)
                                  onChanged: (v) => ShellState.setMango("mouse_accel_speed", (v / 10).toFixed(1)) } }
    Row2 { icon: "hand_pointer"; title: L.t("Ускорение указателя"); hint: L.t("выключено — указатель едет ровно на столько, на сколько сдвинул мышь (удобно в играх)")
                        Toggle { checked: ShellState.mangoOpt("mouse_accel_profile", 2) == 2; onToggled: ShellState.setMango("mouse_accel_profile", checked ? 1 : 2) } }
    Row2 { icon: "hand_pointer"; title: L.t("Левша"); hint: L.t("поменять местами левую и правую кнопки")
                        Toggle { checked: ShellState.mangoOpt("mouse_left_handed", 0) == 1; onToggled: ShellState.setMango("mouse_left_handed", checked ? 0 : 1) } }
    Row2 { icon: "hand_pointer"; title: L.t("Прятать курсор без движения"); hint: L.t("через столько секунд; 0 — не прятать")
                        Stepper { from: 0; to: 30; step: 1; suffix: L.lang === "en" ? " s" : " с"; zeroText: L.t("выкл"); value: ShellState.mangoOpt("cursor_hide_timeout", 0)
                                  onChanged: (v) => ShellState.setMango("cursor_hide_timeout", v) } }
                }
                SGroup {
                    title: L.t("Углы экрана")
    Row2 { icon: "dashboard"; title: L.t("Что делает угол"); hint: L.t("довести курсор до угла экрана и чуть задержать; в играх на весь экран углы не срабатывают")
                        Item { width: 1; height: 1 } }
                    Repeater {
                        model: [["tl", L.t("левый верхний")], ["tr", L.t("правый верхний")], ["bl", L.t("левый нижний")], ["br", L.t("правый нижний")]]
                        delegate: Row2 {
                            id: cr
                            required property var modelData
                            title: modelData[1]
                            Flow {
                                width: 380; spacing: 4
                                Repeater {
                                    model: ShellState.cornerActions
                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool sel: ((ShellState.settings.corners ?? {})[cr.modelData[0]] ?? "none") === modelData[0]
                                        width: cax.implicitWidth + 18; height: 26; radius: 13; color: sel ? Theme.accent : Theme.surfaceHi
                                        Text { id: cax; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                               color: parent.sel ? Theme.onAccent : Theme.text; text: L.t(modelData[1]) }
                                        StateLayer { radius: 13; onClicked: { const c = Object.assign({}, ShellState.settings.corners ?? {});
                                                                              c[cr.modelData[0]] = modelData[0]; ShellState.set("corners", c); } }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Экраны
            // Displays
            Column {
                visible: sw.section === 6 || sw.query !== ""
                width: parent.width
                spacing: 14
                SGroup {
                    title: L.t("Экраны")
                    Repeater {
                        model: Displays.outputs
                        delegate: Column {
                            id: outCol
                            required property var modelData
                            width: parent.width
                            readonly property var cur: Displays.current(modelData)
                            Row2 { icon: "laptop"; title: outCol.modelData.description
                                   hint: outCol.modelData.name + " · " + outCol.cur.w + "×" + outCol.cur.h + " · " + outCol.cur.r + " " + L.t("Гц")
                                   Item { width: 1; height: 1 } }
                            Row2 { icon: "apps"; title: L.t("Масштаб")
                                Row {
                                    spacing: 4
                                    Repeater {
                                        model: [1, 1.25, 1.5, 1.75, 2]
                                        delegate: Rectangle {
                                            required property real modelData
                                            readonly property bool sel: Math.abs(outCol.modelData.scale - modelData) < 0.01
                                            width: sct2.implicitWidth + 20; height: 30; radius: 15
                                            color: sel ? Theme.accent : Theme.surfaceHi
                                            Behavior on color { CAnim {} }
                                            Text { id: sct2; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                                   color: parent.sel ? Theme.onAccent : Theme.text; text: Math.round(modelData * 100) + "%" }
                                            StateLayer { radius: 15; onClicked: Displays.apply(outCol.modelData, null, modelData) }
                                        }
                                    }
                                }
                            }
                            Row2 { icon: "tv"; title: L.t("Разрешение и частота")
                                Flow {
                                    width: 360; spacing: 4
                                    Repeater {
                                        // по одному варианту на разрешение (самая высокая частота) + все частоты текущего разрешения
                                        // one option per resolution (the highest refresh rate) + every refresh rate of the current resolution
                                        model: {
                                            const ms = outCol.modelData.modes, seen = {}, out = [];
                                            for (const m of ms.slice().sort((a, b) => b.w * b.h - a.w * a.h || b.r - a.r)) {
                                                const k = m.w + "x" + m.h;
                                                if (m.w === outCol.cur.w && m.h === outCol.cur.h) { if (!seen[k + "@" + m.r]) { seen[k + "@" + m.r] = 1; out.push(m); } }
                                                else if (!seen[k]) { seen[k] = 1; out.push(m); }
                                            }
                                            return out.slice(0, 10);
                                        }
                                        delegate: Rectangle {
                                            required property var modelData
                                            readonly property bool sel: modelData.w === outCol.cur.w && modelData.h === outCol.cur.h && modelData.r === outCol.cur.r
                                            width: rmt.implicitWidth + 18; height: 28; radius: 14
                                            color: sel ? Theme.accent : Theme.surfaceHi
                                            Text { id: rmt; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                                   color: parent.sel ? Theme.onAccent : Theme.text; text: modelData.w + "×" + modelData.h + " " + modelData.r }
                                            StateLayer { radius: 14; onClicked: Displays.apply(outCol.modelData, modelData, 0) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Row2 { visible: Displays.outputs.length === 0; icon: "tv"; title: L.t("Экраны не найдены")
                           hint: L.t("нужен wlr-randr: sudo pacman -S wlr-randr"); Item { width: 1; height: 1 } }
                }
                SGroup {
                    title: L.t("Яркость")
                    Row2 { icon: "bolt"; title: L.t("Яркость экрана")
                        Rectangle {
                            width: 260; height: 30; radius: 15; color: Theme.surfaceHi
                            Rectangle { width: Math.max(30, parent.width * Brightness.value); height: parent.height; radius: 15; color: Theme.accent }
                            Text { anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.text
                                   text: Math.round(Brightness.value * 100) + "%" }
                            MouseArea { anchors.fill: parent
                                onPressed: (e) => Brightness.set(Math.max(0.03, Math.min(1, e.x / width)))
                                onPositionChanged: (e) => { if (pressed) Brightness.set(Math.max(0.03, Math.min(1, e.x / width))); }
                                onWheel: (w) => Brightness.set(Math.max(0.03, Math.min(1, Brightness.value + (w.angleDelta.y > 0 ? 0.05 : -0.05)))) }
                        }
                    }
                }
            }

            // Питание
            // Power
            Column {
                visible: sw.section === 7 || sw.query !== ""
                width: parent.width
                spacing: 14
                SGroup {
                    title: L.t("Экран и сон")
    Row2 { icon: "sleep"; title: L.t("Гасить экран через"); hint: L.t("кнопка «не гасить» в шторке отключает это")
                        Stepper { from: 0; to: 60; value: ShellState.settings.idleDim; suffix: L.t(" мин"); onChanged: (v) => ShellState.set("idleDim", v) }
                    }
    Row2 { icon: "lock"; title: L.t("Блокировать через")
                        Stepper { from: 0; to: 120; value: ShellState.settings.idleLock; suffix: L.t(" мин"); onChanged: (v) => ShellState.set("idleLock", v) }
                    }
    Row2 { icon: "bolt"; title: L.t("Режим питания"); hint: Power.profiles.length ? "" : L.t("нужен power-profiles-daemon")
                        Row {
                            spacing: 6
                            Repeater {
                                model: [["power-saver", L.t("экономия")], ["balanced", L.t("баланс")], ["performance", L.t("мощность")]]
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool sel: Power.profile === modelData[0]
                                    visible: Power.profiles.includes(modelData[0])
                                    width: pp.implicitWidth + 24; height: 32; radius: 16
                                    color: sel ? Theme.accent : Theme.surfaceHi
                                    Text { id: pp; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                                           color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                                    StateLayer { radius: 16; onClicked: Power.setProfile(modelData[0]) }
                                }
                            }
                        }
                    }
                }
                SGroup {
                    title: L.t("Ноутбук")
                    Row2 { icon: "laptop"; title: L.t("Когда закрываешь крышку"); hint: L.t("системная настройка — спросит пароль")
                        Row {
                            spacing: 4
                            Repeater {
                                model: [["suspend", L.t("сон")], ["lock", L.t("блокировка")], ["ignore", L.t("ничего")]]
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool sel: (ShellState.settings.lidAction ?? "suspend") === modelData[0]
                                    width: lat.implicitWidth + 22; height: 30; radius: 15
                                    color: sel ? Theme.accent : Theme.surfaceHi
                                    Behavior on color { CAnim {} }
                                    Text { id: lat; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                           color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                                    StateLayer { radius: 15; onClicked: ShellState.setLid(modelData[0]) }
                                }
                            }
                        }
                    }
                    Row2 { visible: Power.present; icon: "bolt"; title: L.t("Предупредить, когда заряд ниже")
                        Stepper { from: 5; to: 50; step: 5; suffix: "%"; value: ShellState.settings.batteryLow ?? 15
                                  onChanged: (v) => ShellState.set("batteryLow", v) } }
                    Row2 { visible: Power.present; icon: "sleep"; title: L.t("Уснуть, когда заряд ниже"); hint: L.t("чтобы ноутбук не выключился посреди работы")
                        Stepper { from: 0; to: 20; step: 1; suffix: "%"; zeroText: L.t("никогда"); value: ShellState.settings.batteryCritical ?? 5
                                  onChanged: (v) => ShellState.set("batteryCritical", v) } }
                }
            }

            // Звук
            // Sound
            Column {
                visible: sw.section === 8 || sw.query !== ""
                width: parent.width
                spacing: 14
                SGroup {
                    title: L.t("Звук и запись")
    Row2 { icon: "music"; title: L.t("Кроссфейд треков"); hint: L.t("плавный переход между треками в MPD — и в конце трека, и при переключении")
                        Stepper { from: 0; to: 12; step: 1; suffix: L.lang === "en" ? " s" : " с"; zeroText: L.t("выкл")
                                  value: ShellState.settings.crossfade ?? 3; onChanged: (v) => ShellState.set("crossfade", v) }
                    }
    Row2 { icon: "videocam"; title: L.t("Звук в записи экрана")
                        Row {
                            spacing: 4
                            Repeater {
                                model: [["none", L.t("без звука")], ["system", L.t("звук системы")], ["mic", L.t("микрофон")], ["both", L.t("система + микрофон")]]
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool sel: (ShellState.settings.recAudio ?? "system") === modelData[0]
                                    width: rat.implicitWidth + 22; height: 30; radius: 15
                                    color: sel ? Theme.accent : Theme.surfaceHi
                                    Text { id: rat; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                           color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                                    MouseArea { anchors.fill: parent; onClicked: ShellState.set("recAudio", modelData[0]) }
                                }
                            }
                        }
                    }
    Row2 { icon: "videocam"; title: L.t("Кадров в секунду"); hint: L.t("«как экран» — сколько успевает выдать экран; меньше — файл легче")
                        Chips { key: "recFps"; def: 0; opts: [[0, L.t("как экран")], [24, "24"], [30, "30"], [60, "60"]] } }
    Row2 { icon: "videocam"; title: L.t("Разрешение записи"); hint: L.t("уменьшает кадр по высоте, пропорции сохраняются")
                        Chips { key: "recHeight"; def: 0; opts: [[0, L.t("исходное")], [1080, "1080p"], [720, "720p"], [480, "480p"]] } }
    Row2 { icon: "videocam"; title: L.t("Битрейт видео"); hint: L.t("больше — чётче и тяжелее файл; «авто» — решает кодировщик")
                        Chips { key: "recBitrate"; def: 0; opts: [[0, L.t("авто")], [2000, "2 Mbps"], [4000, "4 Mbps"], [8000, "8 Mbps"], [16000, "16 Mbps"], [32000, "32 Mbps"]] } }
                }
            }

            // Система
            // System
            Column {
                visible: sw.section === 9 || sw.query !== ""
                width: parent.width
                spacing: 14
                SGroup {
                    title: L.t("Дата и время")
                    Row2 { icon: "w_partly"; title: L.t("Часы на панели")
                        Row {
                            spacing: 4
                            Repeater {
                                model: [["clock24", L.t("24 часа")], ["clockSeconds", L.t("секунды")]]
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool sel: modelData[0] === "clock24" ? (ShellState.settings.clock24 ?? true) : !!ShellState.settings.clockSeconds
                                    width: ckt.implicitWidth + 22; height: 30; radius: 15
                                    color: sel ? Theme.accent : Theme.surfaceHi
                                    Behavior on color { CAnim {} }
                                    Text { id: ckt; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                           color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                                    StateLayer { radius: 15; onClicked: ShellState.set(modelData[0], !parent.sel) }
                                }
                            }
                        }
                    }
                    Row2 { icon: "refresh"; title: L.t("Синхронизировать время по сети"); visible: ShellState.ntpControl
                        Toggle { checked: ShellState.ntp; onToggled: ShellState.setNtp(!checked) } }
                    Row2 { icon: "place"; title: L.t("Часовой пояс"); hint: ShellState.timezone + " — " + L.t("начни вводить город и выбери")
                        Column {
                            spacing: 4
                            Rectangle {
                                width: 260; height: 30; radius: 15; color: Theme.surface; border.color: tzIn.activeFocus ? Theme.accent : Theme.line
                                TextInput { id: tzIn; anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                            verticalAlignment: TextInput.AlignVCenter; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.text
                                            Text { anchors.verticalCenter: parent.verticalCenter; visible: !tzIn.text; font.family: Theme.font
                                                   font.pixelSize: Tokens.font.small; color: Theme.textDim; text: "Europe/Berlin" } }
                            }
                            Flow {
                                width: 260; spacing: 4
                                Repeater {
                                    model: tzIn.text.length < 2 ? [] : ShellState.timezones.filter(z => z.toLowerCase().includes(tzIn.text.toLowerCase())).slice(0, 6)
                                    delegate: Rectangle {
                                        required property string modelData
                                        width: tzt.implicitWidth + 18; height: 26; radius: 13; color: Theme.surfaceHi
                                        Text { id: tzt; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.text; text: modelData }
                                        StateLayer { radius: 13; onClicked: { ShellState.setTimezone(modelData); tzIn.text = ""; } }
                                    }
                                }
                            }
                        }
                    }
                }
                SGroup {
                    title: L.t("Погода")
                    Row2 { icon: "w_partly"; title: L.t("Поставщик"); hint: L.t("«авто» — по очереди, пока кто-то не ответит")
                        Row {
                            spacing: 4
                            Repeater {
                                model: [["auto", L.t("авто")], ["openmeteo", "Open-Meteo"], ["wttr", "wttr.in"], ["metno", "MET Norway"]]
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool sel: (ShellState.settings.weatherProvider ?? "auto") === modelData[0]
                                    width: wp.implicitWidth + 20; height: 30; radius: 15
                                    color: sel ? Theme.accent : Theme.surfaceHi
                                    Text { id: wp; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                           color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                                    MouseArea { anchors.fill: parent; onClicked: ShellState.set("weatherProvider", modelData[0]) }
                                }
                            }
                        }
                    }
    Row2 { icon: "place"; title: L.t("Город"); hint: L.t("пусто — определять по Wi-Fi вокруг (как на телефоне), если не выйдет — по IP")
                        Field { text: ShellState.settings.weatherCity; placeholder: L.t("по Wi-Fi"); onAccepted: (v) => ShellState.set("weatherCity", v) }
                    }
    Row2 { icon: "w_partly"; title: L.t("Сейчас"); hint: Weather.ok ? Weather.city + " · " + Weather.temp + "° · " + Weather.desc + " · " + (Weather.names[Weather.usedProvider] ?? "")
                                                                        : (Weather.lastError || L.t("жду данные…"))
                        Rectangle {
                            width: 30; height: 30; radius: 15; color: Theme.surfaceHi
                            Icon { anchors.centerIn: parent; name: "refresh"; size: 11; color: Theme.accent }
                            StateLayer { radius: 15; onClicked: { Weather.tryIdx = 0; Weather.fetch(); } }
                        }
                    }
                }
                SGroup {
                    title: L.t("Сеанс")
    Row2 { icon: "refresh"; title: L.t("Восстанавливать приложения"); hint: L.t("после входа снова открыть то, что было открыто, на тех же страницах")
                        Toggle { checked: ShellState.settings.restoreSession ?? true; onToggled: ShellState.set("restoreSession", !checked) }
                    }
                    Row2 { icon: "public"; title: "VPN"; hint: L.t("значок-ключ на панели и менеджер VPN; выключи, если VPN не нужен")
                        Toggle { checked: ShellState.settings.vpnEnabled ?? true
                                 onToggled: { if (checked && Vpn.running) Vpn.disconnect(); ShellState.set("vpnEnabled", !checked); } }
                    }
                }
                SGroup {
                    title: L.t("Другие программы")
    Row2 { icon: "palette"; title: L.t("Акцент в программах"); hint: L.t("цвет акцента в программах GTK и KDE (применится при их перезапуске)")
                        Toggle { checked: ShellState.settings.appAccent ?? true; onToggled: ShellState.set("appAccent", !checked) }
                    }
    Row2 { icon: "public"; title: L.t("Тема Firefox"); hint: L.t("цвета и форма шелла в твоём Firefox; применяется при его следующем запуске")
                        Toggle { checked: ShellState.settings.firefoxTheme ?? true; onToggled: ShellState.set("firefoxTheme", !checked) }
                    }
    Row2 { icon: "sports_esports"; title: L.t("Тема Steam"); hint: L.t("для скина Minimal Dark (Millennium): цвета палитры и компактная панель в узком окне")
                        Toggle { checked: ShellState.settings.steamTheme ?? true; onToggled: ShellState.set("steamTheme", !checked) }
                    }
    Row2 { icon: "chat"; title: L.t("Тема DeltaChat"); hint: L.t("в DeltaChat: Настройки → Оформление → тема «nyashell»")
                        Toggle { checked: ShellState.settings.deltaTheme ?? true; onToggled: ShellState.set("deltaTheme", !checked) }
                    }
                }
            }

            Column {
                visible: sw.section === 10 && sw.query === ""
                width: parent.width
                spacing: 2
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    bottomPadding: 8
                    font.family: Theme.font; font.pixelSize: Tokens.font.small
                    color: sw.captureMsg ? Theme.danger : Theme.textDim
                    text: sw.captureMsg || (sw.capturing ? L.t("нажми новое сочетание… Esc — отмена")
                                                         : L.t("ЛКМ — назначить новое, ПКМ — снять (освободить), СКМ — вернуть стандартное. Чтобы отдать сочетание другому действию, сначала сними его там"))
                }
                Repeater {
                    model: Binds.groups
                    delegate: Column {
                        id: bg
                        required property var modelData
                        width: page.width
                        spacing: 2
                        Text { topPadding: 10; bottomPadding: 2; leftPadding: 14; font.family: Theme.font; font.pixelSize: Tokens.font.small
                               font.bold: true; color: Theme.accent; text: L.t(bg.modelData.title).toUpperCase() }
                        Repeater {
                            model: bg.modelData.items
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: sw.capturingSig === modelData.sig
                                readonly property bool custom: Binds.overrides[modelData.sig] !== undefined
                                readonly property bool editable: modelData.kind !== "mousebind" && modelData.kind !== "axisbind"
                                width: page.width
                                height: 46
                                radius: 20
                                color: active ? Theme.tonalHi : (bm2.containsMouse && editable ? Theme.hover : "transparent")
                                Text {
                                    x: 14; anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width * 0.5
                                    elide: Text.ElideRight
                                    font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text
                                    text: Binds.describe(modelData.kind, modelData.action)    // живой перевод / live translation
                                }
                                Rectangle {
                                    anchors.right: parent.right; anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: ct2.implicitWidth + 20; height: 28; radius: 14
                                    color: parent.active ? Theme.accent : parent.modelData.off ? "transparent" : Theme.surfaceHi
                                    border.color: parent.custom && !parent.active ? Theme.accent : "transparent"
                                    Text { id: ct2; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                           color: parent.parent.active ? Theme.onAccent : Theme.text
                                           text: parent.parent.active ? "…" : modelData.off ? "—" : Binds.pretty(modelData.mods, modelData.key, modelData.kind) }
                                }
                                MouseArea {
                                    id: bm2
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: parent.editable
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                    onClicked: (m) => {
                                        // во время прослушивания ПКМ/СКМ просто отменяют ввод
                                        // while listening, right/middle click just cancel the input
                                        if (parent.active && m.button !== Qt.LeftButton) { sw.capturing = null; sw.captureMsg = ""; return; }
                                        if (m.button === Qt.RightButton) { sw.capturing = null; Binds.clear(modelData); return; }
                                        if (m.button === Qt.MiddleButton) { sw.capturing = null; Binds.restore(modelData); return; }
                                        sw.captureMsg = "";
                                        sw.capturing = modelData;
                                        keys.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Column {
                visible: sw.section === 11 && sw.query === ""
                width: parent.width
                spacing: 10
                Rectangle {
                    width: parent.width; height: hero.implicitHeight + 36
                    radius: Tokens.rounding.large
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.tonalHi }
                        GradientStop { position: 1; color: Theme.surface }
                    }
                    Row {
                        id: hero
                        x: 18; y: 18; width: parent.width - 36
                        spacing: 16
                        Rectangle { width: 64; height: 64; radius: 20; color: Theme.accent
                                    Icon { anchors.centerIn: parent; name: "pets"; size: 28; color: Theme.onAccent } }
                        Column {
                            width: parent.width - 80; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                            Text { font.family: Theme.font; font.pixelSize: 26; font.bold: true; color: Theme.accent; text: "nyashell" }
                            Text { width: parent.width; wrapMode: Text.Wrap; font.family: Theme.font; font.pixelSize: Tokens.font.normal
                                   color: Theme.text; text: L.t("шелл для MangoWC на Quickshell. Идеи и концепция — ") + "neko" + L.t(", код — вместе с Сайей") }
                        }
                    }
                }
                Text { width: parent.width; wrapMode: Text.Wrap; font.family: Theme.font; font.pixelSize: Tokens.font.small
                       color: Theme.textDim; text: L.t("дизайн-токены и общая идея — из caelestia-shell (GPL-3.0), поэтому nyashell тоже под GPL-3.0") }
                Text { width: parent.width; wrapMode: Text.Wrap; font.family: Theme.font; font.pixelSize: Tokens.font.small
                       color: Theme.textDim; text: L.t("конфиги: ~/.config/quickshell/nyashell (шелл), ~/.config/mango/config.conf (композитор)") }

                // что вообще есть — чек-лист, чтобы ничего не забыть проверить
                // what's there at all: a checklist so nothing gets forgotten when testing
                Text { topPadding: 10; font.family: Theme.font; font.pixelSize: Tokens.font.normal; font.bold: true
                       color: Theme.accent; text: L.lang === "en" ? "What's inside" : "Что тут есть" }
                Repeater {
                    model: L.lang === "en" ? [
                        ["Bar", "pages (wheel, click; Ctrl+Shift+A/D wrap around), layout icon + toast, CPU/GPU/temp (click or Super+W — system monitor), taskbar grouped by app (click: minimize others / restore; MMB new window; RMB menu; wheel app volume; hover previews), pinned apps, tray apps with their own menus, layout, battery (bolt when charging, eye for keep-awake), sound, Bluetooth, Wi-Fi, clock (quick settings), notifications; RMB on empty space — menu; icon order in settings"],
                        ["Managers", "Wi-Fi (RMB: disconnect, default, settings: IP/MAC/DNS/metered/random MAC, forget; + add network), Bluetooth (RMB: connect, trust, details, forget; + scan & pair; restart service), sound (outputs, inputs, per-app volume), battery (power modes, keep awake), notifications (DND, history)"],
                        ["Dashboard (Super+S or top edge)", "home, media, system graphs, weather, an optional browser tab (Firefox); tabs can be hidden"],
                        ["Menus", "apps (Super: fuzzy search, favourites grid, MMB favourite, RMB menu: pin, files, uninstall), power (Super+Space), calculator (Super+R), clipboard (Super+V), settings (Super+I), language (Super+G)"],
                        ["Screenshots", "Print / Super+Shift+S — full screen; hold Super+Shift and drag — area (RMB cancels; everything stays frozen); notification: open, folder, delete"],
                        ["Windows", "strip / grid (Super+Tab), grid: 4 per page, extra ones move to the next page, even grid, Super+RMB outwards pushes a neighbour away, inwards pulls one back; drag with Super+LMB (Ctrl+Super+LMB — to other pages via screen edge); Alt+Q close, Ctrl+Q minimize; fullscreen apps never move between pages by themselves; Ctrl+Super+LMB drag onto a page dot on the bar moves a window there"],
                        ["Lock & login", "Super+L or lid: windows slide away, lock over blurred wallpaper, Pixel-style password, Nothing-style clockface; fade to black before sleep; greetd login screen in the same style"],
                        ["Look", "neko / adaptive colours, wallpaper carousel, particles, fonts, rounding, icon theme and accent-tinted icons, Firefox/kitty/fish colours follow the palette"],
                        ["Session", "apps reopen after login on their pages; Super+Ctrl+R restarts the shell without closing apps"],
                        ["Music & sound", "MPD player tab (queue: drag, RMB remove, Ctrl+RMB undo, MMB play next; scratch the record), music library and playlists, crossfade, parametric EQ (import/export Poweramp files); Ctrl+Alt+A/D tracks, Ctrl+Shift+Space pause"],
                        ["VPN (key icon)", "subscriptions with custom headers and auto-update (base64, links, Clash YAML, sing-box JSON), groups, ping and sorting, chains, routes by sites/addresses/apps, DNS/FakeDNS/TUN settings; sing-box + Xray"],
                        ["Recording", "Ctrl+Print — record screen, Ctrl+Shift+Print — area, again — stop (red timer on the bar); screen sharing in apps via portals"],
                        ["Desktop extras", "on-screen GIFs (Ctrl+Alt+G to move and resize), music visualizer above the wallpaper; screen corners with actions"],
                        ["Keyboard in the dashboard", "A/D — tabs, S or Space — into the tab, WASD/arrows — buttons, lists and fields, Space/Enter — press, Esc — back to the tabs"]
                    ] : [
                        ["Панель", "страницы (колесо, клик; Ctrl+Shift+A/D по кругу), значок режима и тост, CPU/GPU/температура (клик или Super+W — монитор системы), панель задач по приложениям (клик: свернуть лишнее / развернуть; СКМ новое окно; ПКМ меню; колесо — громкость приложения; превью), закреплённые, трей с меню приложений, раскладка, батарея (молния при зарядке, глаз «не гасить»), звук, Bluetooth, Wi-Fi, часы (шторка), уведомления; ПКМ по пустому месту — меню; порядок значков в настройках"],
                        ["Менеджеры", "Wi-Fi (ПКМ: отключиться, по умолчанию, настройки: IP/MAC/DNS/лимит/случайный MAC, забыть; «+» — новая сеть), Bluetooth (ПКМ: подключить, доверять, сведения, забыть; «+» — поиск и сопряжение; перезапуск службы), звук (выходы, входы, громкость приложений), батарея (режимы, «не гасить»), уведомления (не беспокоить, история)"],
                        ["Борд (Super+S или верхний край)", "главная, медиа, графики системы, погода, браузер по желанию (Firefox); ненужные вкладки прячутся"],
                        ["Меню", "приложения (Super: нечёткий поиск, избранное сеткой, СКМ — в избранное, ПКМ — меню: закрепить, файлы, удалить), питание (Super+Space), калькулятор (Super+R), буфер (Super+V), настройки (Super+I), язык (Super+G)"],
                        ["Скриншоты", "Print / Super+Shift+S — весь экран; зажать Super+Shift и тянуть — область (ПКМ — отмена; всё замирает); в уведомлении: открыть, папка, удалить"],
                        ["Окна", "лента / сетка (Super+Tab), в сетке 4 на страницу, лишние уезжают на следующую, сетка ровная, Super+ПКМ наружу — вытолкнуть соседа, внутрь — забрать; перетаскивание Super+ЛКМ (Ctrl+Super+ЛКМ — на другие страницы через край); Alt+Q закрыть, Ctrl+Q свернуть; полноэкранные сами никуда не переезжают; Ctrl+Super+ЛКМ и отпустить над точкой страницы на панели — перенести окно туда"],
                        ["Блокировка и вход", "Super+L или крышка: окна уезжают, блокировка на размытых обоях, пароль как на Pixel, циферблат как в Nothing; перед сном — плавно в чёрное; экран входа greetd в том же стиле"],
                        ["Вид", "neko / адаптивные цвета, карусель обоев, частицы, шрифты, скругления, тема значков и значки в цвет акцента; цвета Firefox, kitty и fish следуют за палитрой"],
                        ["Сеанс", "после входа приложения открываются снова на своих страницах; Super+Ctrl+R перезапускает шелл, не закрывая приложения"],
                        ["Музыка и звук", "плеер на MPD (очередь: тянуть, ПКМ — убрать, Ctrl+ПКМ — вернуть, СКМ — далее; пластинку можно скретчить), библиотека и плейлисты, кроссфейд, параметрический эквалайзер (импорт/экспорт файлов Poweramp); Ctrl+Alt+A/D — треки, Ctrl+Shift+Space — пауза"],
                        ["VPN (значок-ключ)", "подписки со своими заголовками и автообновлением (base64, ссылки, Clash YAML, sing-box JSON), группы, пинг и сортировка, цепочки, маршруты по сайтам/адресам/приложениям, DNS/FakeDNS/TUN; sing-box + Xray"],
                        ["Запись", "Ctrl+Print — запись экрана, Ctrl+Shift+Print — области, ещё раз — стоп (красный таймер на панели); демонстрация экрана в приложениях через порталы"],
                        ["Рабочий стол", "гифки поверх экрана (Ctrl+Alt+G — двигать и менять размер), визуализатор музыки над обоями; углы экрана с действиями"],
                        ["Клавиши в борде", "A/D — вкладки, S или пробел — внутрь вкладки, WASD/стрелки — кнопки, списки и поля, пробел/Enter — нажать, Esc — обратно к вкладкам"]
                    ]
                    // раздел — карточка со значком; значок по порядку разделов
                    // a section is a card with an icon; icons follow the order of the sections
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property var icons: ["apps", "wifi", "dashboard", "search", "wallpaper", "l_grid", "lock", "palette", "refresh", "music", "public", "videocam"]
                        width: parent.width; height: abt.implicitHeight + 24
                        radius: Tokens.rounding.large
                        color: Theme.surface
                        Rectangle { x: 12; y: 12; width: 34; height: 34; radius: 11; color: Theme.tonal
                                    Icon { anchors.centerIn: parent; name: parent.parent.icons[parent.parent.index] ?? "pets"; size: 14; color: Theme.accent } }
                        Column {
                            id: abt
                            x: 58; y: 12; width: parent.width - 72
                            spacing: 3
                            Text { font.family: Theme.font; font.pixelSize: Tokens.font.smaller; font.bold: true; color: Theme.text; text: modelData[0] }
                            Text { width: parent.width; wrapMode: Text.Wrap; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                   color: Theme.textDim; text: modelData[1] }
                        }
                    }
                }
            }
        }
    }
}
