import Quickshell
import QtQuick
import "CalcMath.js" as M

// калькулятор (Super+R): только клавиатура. Понимает уравнения (2x+3=7, x^2-5x+6=0),
// сравнения (== != <= >= < >), ^ **, ! (факториал), проценты: 10%100 = 10, 50+10% = 55,
// функции sqrt abs round floor ceil ln log exp sin cos tan (в градусах), константы pi и e
// calculator (Super+R): keyboard only. Understands equations (2x+3=7, x^2-5x+6=0),
// comparisons (== != <= >= < >), ^ **, ! (factorial), percentages: 10%100 = 10, 50+10% = 55,
// functions sqrt abs round floor ceil ln log exp sin cos tan (in degrees), constants pi and e
CenterPopup {
    id: calc
    open: ShellState.calcOpen
    onDismissed: ShellState.calcOpen = false
    cardWidth: 580
    cardHeight: 330
    property var history: []          // [{expr, res}]
    property int histPos: -1

    function trErr(e: string): string {
        const m = e.match(/^(символ |неизвестно: |лишний )(.*)$/);
        return m ? L.t(m[1]) + m[2] : L.t(e);
    }
    readonly property var out: {
        try { return M.calculate(input.text); }
        catch (e) { return input.text.trim() ? { text: "", err: String(e) } : null; }
    }

    onOpenChanged: {
        if (!open) return;
        histPos = -1;
        input.selectAll();
        input.forceActiveFocus();
    }

    function commit(): void {
        if (!out || !out.text) return;
        history = [{ expr: input.text, res: out.text }].concat(history).slice(0, 5);
        histPos = -1;
        if (out.kind === "num") input.text = out.text;       // можно считать дальше от результата / you can keep calculating from the result
        else input.selectAll();
    }

    // поле ввода
    // input field
    Rectangle {
        x: 18; y: 18
        width: parent.width - 36
        height: 56
        radius: 28
        color: Theme.surface
        border.color: input.activeFocus ? Theme.outline : "transparent"
        Icon { x: 20; anchors.verticalCenter: parent.verticalCenter; name: "calculator"; size: 16; color: Theme.accent }
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 52
            anchors.rightMargin: 20
            verticalAlignment: TextInput.AlignVCenter
            font.family: Theme.font
            font.pixelSize: 20
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccent
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Escape) ShellState.calcOpen = false;
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) calc.commit();
                else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_C && !input.selectedText) {
                    if (calc.out?.text) Quickshell.execDetached(["wl-copy", calc.out.text]);
                }
                else if (e.key === Qt.Key_Up && calc.history.length) {
                    calc.histPos = Math.min(calc.histPos + 1, calc.history.length - 1);
                    input.text = calc.history[calc.histPos].expr;
                }
                else if (e.key === Qt.Key_Down && calc.histPos >= 0) {
                    calc.histPos--;
                    input.text = calc.histPos >= 0 ? calc.history[calc.histPos].expr : "";
                }
                else return;
                e.accepted = true;
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text.length === 0
                font.family: Theme.font
                font.pixelSize: Tokens.font.normal
                color: Theme.textDim
                text: "2+2*3,  10%100,  2x+3=7,  5!=120 …"
            }
        }
    }

    // большой результат
    // big result
    Text {
        x: 34; y: 90
        width: parent.width - 68
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
        font.family: Theme.font
        font.pixelSize: calc.out?.text ? (calc.out.text.length > 22 ? 28 : 44) : 16
        font.bold: !!calc.out?.text
        color: !calc.out ? Theme.textDim
             : calc.out.kind === "bool" ? (calc.out.text === "верно" ? Theme.accent : Theme.danger)
             : calc.out.text ? Theme.accent : Theme.textDim
        text: !calc.out ? "= …" : calc.out.text ? (calc.out.kind === "num" ? "= " + calc.out.text
                    : calc.out.kind === "bool" ? L.t(calc.out.text)
                    : calc.out.text.replace("корней нет", L.t("корней нет")).replace("— любое", L.lang === "en" ? "— any" : "— любое"))
                                                : "… (" + calc.trErr(calc.out.err) + ")"
        Behavior on font.pixelSize { Anim { kind: "fastSpatial" } }
    }

    // история
    // history
    Column {
        x: 34; y: 158
        width: parent.width - 68
        spacing: 4
        Repeater {
            model: calc.history
            delegate: Item {
                required property var modelData
                width: parent.width
                height: 22
                Text {
                    anchors.left: parent.left
                    width: parent.width * 0.55
                    elide: Text.ElideRight
                    font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.textDim
                    text: modelData.expr
                }
                Text {
                    anchors.right: parent.right
                    width: parent.width * 0.42
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                    font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text
                    text: modelData.res
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { input.text = modelData.expr; input.forceActiveFocus(); } }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
        text: L.t("Enter — зафиксировать · ↑↓ — история · Ctrl+C — скопировать · Esc — закрыть")
    }
}
