import Quickshell
import QtQuick

// вкладка «эквалайзер»: сверху — АЧХ с точками полос (тянуть: частота/усиление, колесо: Q),
// снизу — полосы карточками (тип, частота, усиление, Q, вкл/выкл, удалить), слева — вкл, преамп, пресеты
// equaliser tab: on top the frequency response with band points (drag: frequency/gain, wheel: Q),
// below the bands as cards (type, frequency, gain, Q, on/off, delete), on the left on/off, preamp, presets
Item {
    id: e
    property var dash
    property int sel: 0
    readonly property real fMin: 20
    readonly property real fMax: 20000
    readonly property real dbMax: 15
    readonly property var typeNames: ({ peak: L.t("пик"), lowshelf: L.t("полка низ"), highshelf: L.t("полка верх"),
                                        lowpass: L.t("срез верхов"), highpass: L.t("срез низов"), notch: L.t("режекция"), bandpass: L.t("полосовой") })
    function fmtF(f: real): string { return f >= 1000 ? (f / 1000).toFixed(f >= 10000 ? 0 : 1) + "k" : Math.round(f) + ""; }

    // ── левая колонка ──
    // ── left column ──
    Column {
        id: side
        x: Tokens.gap.large; y: 4
        width: 120
        spacing: 8
        Rectangle {
            width: parent.width; height: 34; radius: 17
            color: Eq.enabled ? Theme.accent : Theme.surfaceHi
            Text { anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.smaller; font.bold: true
                   color: Eq.enabled ? Theme.onAccent : Theme.text; text: Eq.enabled ? L.t("включён") : L.t("выключен") }
            StateLayer { radius: 17; onClicked: Eq.setEnabled(!Eq.enabled) }
        }
        Knob {
            anchors.horizontalCenter: parent.horizontalCenter
            size: 58; from: -24; to: 12; value: Eq.preamp; step: 0.5 / 36
            label: L.t("преамп"); text: Eq.preamp.toFixed(1) + " dB"
            onMoved: (v) => Eq.setPreamp(Math.round(v * 2) / 2)
        }
        // импорт и экспорт (формат совместим с Poweramp Equalizer)
        // import and export (format compatible with Poweramp Equalizer)
        Row {
            spacing: 4
            Repeater {
                model: [["download", L.t("импорт"), () => Eq.importDialog()], ["upload", L.t("экспорт"), () => Eq.exportDialog()]]
                delegate: Rectangle {
                    required property var modelData
                    width: 58; height: 26; radius: 13; color: Theme.surface
                    Text { anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent; text: modelData[1] }
                    StateLayer { radius: 13; onClicked: modelData[2]() }
                }
            }
        }
        // пресеты: клик — загрузить, ПКМ — удалить; «+» — сохранить текущее
        // presets: click to load, right-click to delete; "+" saves the current one
        Rectangle {
            width: parent.width; height: 30; radius: 15; color: Theme.surface
            TextInput {
                id: pname
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 28
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.text
                Keys.onReturnPressed: { Eq.savePreset(text.trim()); text = ""; Nav.back(); }
                Keys.onEscapePressed: Nav.back()
                Text { anchors.verticalCenter: parent.verticalCenter; visible: !pname.text; font.family: Theme.font
                       font.pixelSize: Tokens.font.small; color: Theme.textDim; text: L.t("пресет…") }
            }
            Icon { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                   name: "plus"; size: 10; color: Theme.accent
                   MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: { Eq.savePreset(pname.text.trim()); pname.text = ""; } } }
            NavPoint { radius: 15; action: () => pname.forceActiveFocus() }
        }
        Flickable {
            width: parent.width; height: 66; clip: true
            contentHeight: pcol.implicitHeight
            SmoothWheel {}
            Column {
                id: pcol
                width: parent.width; spacing: 3
                Repeater {
                    model: Object.keys(Eq.presets)
                    delegate: Rectangle {
                        required property string modelData
                        width: pcol.width; height: 24; radius: 12
                        color: Eq.preset === modelData ? Theme.tonalHi : "transparent"
                        Text { x: 10; width: parent.width - 16; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                               font.family: Theme.font; font.pixelSize: Tokens.font.small
                               color: Eq.preset === modelData ? Theme.accent : Theme.text; text: modelData }
                        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (m) => m.button === Qt.RightButton ? Eq.deletePreset(modelData) : Eq.loadPreset(modelData)
                                    NavPoint { radius: 12; action: () => Eq.loadPreset(modelData) } }
                    }
                }
            }
        }
    }

    // ── график ──
    // ── graph ──
    Rectangle {
        id: graph
        x: side.x + side.width + Tokens.gap.medium; y: 4
        width: e.width - x - Tokens.gap.large
        height: 128
        radius: Tokens.rounding.large
        color: Theme.surface
        clip: true
        function xOf(f: real): real { return width * Math.log(f / e.fMin) / Math.log(e.fMax / e.fMin); }
        function fOf(x: real): real { return e.fMin * Math.pow(e.fMax / e.fMin, Math.max(0, Math.min(1, x / width))); }
        function yOf(db: real): real { return height / 2 - db / e.dbMax * (height / 2 - 10); }
        function dbOf(y: real): real { return Math.max(-e.dbMax, Math.min(e.dbMax, (height / 2 - y) / (height / 2 - 10) * e.dbMax)); }

        Canvas {
            id: curve
            anchors.fill: parent
            property var deps: [Eq.bands, Eq.preamp, e.sel]
            onDepsChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d"); ctx.reset();
                // сетка: 100 Гц, 1 кГц, 10 кГц и 0 дБ
                // grid: 100 Hz, 1 kHz, 10 kHz and 0 dB
                ctx.strokeStyle = Theme.line; ctx.lineWidth = 1;
                for (const f of [100, 1000, 10000]) { const x = graph.xOf(f); ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke(); }
                ctx.beginPath(); ctx.moveTo(0, graph.yOf(0)); ctx.lineTo(width, graph.yOf(0)); ctx.stroke();
                const N = 160;
                // каждая полоса своим цветом
                // each band in its own colour
                Eq.bands.forEach((b, i) => {
                    if (!b.on) return;
                    ctx.beginPath();
                    for (let k = 0; k <= N; k++) { const f = graph.fOf(k / N * width); const y = graph.yOf(Eq.response(b, f));
                                                   k ? ctx.lineTo(k / N * width, y) : ctx.moveTo(0, y); }
                    ctx.lineTo(width, graph.yOf(0)); ctx.lineTo(0, graph.yOf(0)); ctx.closePath();
                    const h = String(b.color).replace("#", "");
                    ctx.fillStyle = Qt.rgba(parseInt(h.slice(0, 2), 16) / 255, parseInt(h.slice(2, 4), 16) / 255,
                                            parseInt(h.slice(4, 6), 16) / 255, i === e.sel ? 0.28 : 0.12);
                    ctx.fill();
                });
                // итоговая кривая
                // resulting curve
                ctx.beginPath(); ctx.lineWidth = 2.5; ctx.strokeStyle = Theme.accent;
                for (let k = 0; k <= N; k++) { const y = graph.yOf(Eq.total(graph.fOf(k / N * width))); k ? ctx.lineTo(k / N * width, y) : ctx.moveTo(0, y); }
                ctx.stroke();
            }
        }
        Repeater {
            model: ["100", "1k", "10k"]
            delegate: Text { required property string modelData; required property int index
                             x: graph.xOf([100, 1000, 10000][index]) + 3; y: graph.height - 16
                             font.family: Theme.font; font.pixelSize: 9; color: Theme.textDim; text: modelData }
        }
        // точки полос: тянуть — частота и усиление, колесо — Q
        // band points: drag for frequency and gain, wheel for Q
        Repeater {
            model: Eq.bands
            delegate: Rectangle {
                id: dot
                required property var modelData
                required property int index
                visible: modelData.on
                width: e.sel === index ? 16 : 12; height: width; radius: width / 2
                color: modelData.color
                border.color: Theme.text; border.width: e.sel === index ? 2 : 0
                x: graph.xOf(modelData.freq) - width / 2
                y: graph.yOf(["lowpass", "highpass", "notch", "bandpass"].includes(modelData.type) ? 0 : modelData.gain) - height / 2
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    cursorShape: Qt.SizeAllCursor
                    onPressed: e.sel = dot.index
                    onPositionChanged: (m) => {
                        const p = mapToItem(graph, m.x, m.y);
                        Eq.setBand(dot.index, "freq", Math.round(graph.fOf(p.x)));
                        if (!["lowpass", "highpass", "notch", "bandpass"].includes(dot.modelData.type))
                            Eq.setBand(dot.index, "gain", Math.round(graph.dbOf(p.y) * 10) / 10);
                    }
                    onWheel: (w) => Eq.setBand(dot.index, "q", Math.max(0.1, Math.min(10, dot.modelData.q * (w.angleDelta.y > 0 ? 1.1 : 0.9))))
                }
            }
        }
    }

    // ── полосы карточками ──
    // ── bands as cards ──
    ListView {
        x: graph.x; y: graph.y + graph.height + 8
        width: graph.width; height: e.height - y - 4
        orientation: ListView.Horizontal
        spacing: 6
        clip: true
        model: Eq.bands.length + 1
        delegate: Rectangle {
            id: card
            required property int index
            readonly property bool add: index === Eq.bands.length
            readonly property var b: add ? null : Eq.bands[index]
            width: add ? 44 : 196
            height: ListView.view.height
            radius: Tokens.rounding.large
            color: add ? Theme.surface : (e.sel === index ? Theme.tonalHi : Theme.surface)
            border.color: !add && e.sel === index ? card.b.color : "transparent"
            MouseArea { anchors.fill: parent; onClicked: if (!card.add) e.sel = card.index
                        NavPoint { radius: Tokens.rounding.large; action: () => { if (card.add) { Eq.addBand(); e.sel = Eq.bands.length - 1; } else e.sel = card.index; } } }
            Icon { visible: card.add; anchors.centerIn: parent; name: "plus"; size: 14; color: Theme.accent
                   MouseArea { anchors.fill: parent; anchors.margins: -14; onClicked: { Eq.addBand(); e.sel = Eq.bands.length - 1; } } }

            Item {
                visible: !card.add
                anchors.fill: parent; anchors.margins: 8
                // тип (клик — следующий), вкл/выкл, удалить
                // type (click for the next one), on/off, delete
                Row {
                    spacing: 6
                    Rectangle { width: 10; height: 10; radius: 5; color: card.b?.color ?? "transparent"; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        width: tt.implicitWidth + 16; height: 22; radius: 11; color: Theme.surfaceHi
                        Text { id: tt; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                               color: Theme.text; text: e.typeNames[card.b?.type ?? "peak"] }
                        MouseArea { anchors.fill: parent; onClicked: {
                            const t = Eq.types; Eq.setBand(card.index, "type", t[(t.indexOf(card.b.type) + 1) % t.length]); } }
                    }
                }
                Row {
                    anchors.right: parent.right
                    spacing: 4
                    Rectangle { width: 22; height: 22; radius: 11; color: card.b?.on ? Theme.accent : Theme.surfaceHi
                                Icon { anchors.centerIn: parent; name: "power_settings_new"; size: 9; color: card.b?.on ? Theme.onAccent : Theme.textDim }
                                MouseArea { anchors.fill: parent; onClicked: Eq.setBand(card.index, "on", !card.b.on)
                                            NavPoint { radius: 11; action: () => Eq.setBand(card.index, "on", !card.b.on) } } }
                    Rectangle { width: 22; height: 22; radius: 11; color: Theme.surfaceHi
                                Icon { anchors.centerIn: parent; name: "close"; size: 9; color: Theme.textDim }
                                MouseArea { anchors.fill: parent; onClicked: { Eq.removeBand(card.index); e.sel = Math.max(0, e.sel - 1); } } }
                }
                Row {
                    y: 30
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    Knob { size: 46; from: 20; to: 20000; log: true; value: card.b?.freq ?? 1000; color: card.b?.color ?? Theme.accent
                           label: L.t("част."); text: e.fmtF(card.b?.freq ?? 0); onMoved: (v) => Eq.setBand(card.index, "freq", Math.round(v)) }
                    Knob { size: 46; from: -e.dbMax; to: e.dbMax; step: 0.5 / 30; value: card.b?.gain ?? 0; color: card.b?.color ?? Theme.accent
                           visible: !["lowpass", "highpass", "notch", "bandpass"].includes(card.b?.type ?? "")
                           label: L.t("усил."); text: (card.b?.gain ?? 0).toFixed(1); onMoved: (v) => Eq.setBand(card.index, "gain", Math.round(v * 10) / 10) }
                    Knob { size: 46; from: 0.1; to: 10; log: true; value: card.b?.q ?? 1; color: card.b?.color ?? Theme.accent
                           label: "Q"; text: (card.b?.q ?? 1).toFixed(2); onMoved: (v) => Eq.setBand(card.index, "q", Math.round(v * 100) / 100) }
                }
            }
        }
    }
}
