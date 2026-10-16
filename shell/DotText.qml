import QtQuick

// точечная матрица 5×7 в духе Nothing: цифры, двоеточие, %, пробел, точка, минус.
// горящие точки — цветом, негорящие — едва заметны, как на Glyph-экранах
// a Nothing-style 5×7 dot matrix: digits, colon, %, space, dot, minus.
// lit dots in colour, unlit ones barely visible, like on Glyph screens
Canvas {
    id: dt
    property string text: ""
    property real dot: 4              // диаметр точки / dot diameter
    property real gap: 1.5            // промежуток между точками / gap between dots
    property real charGap: 2          // лишние точки между символами (в размерах шага) / extra dots between characters (in steps)
    property color color: Theme.accent
    property color dimColor: Qt.rgba(color.r, color.g, color.b, 0.10)

    readonly property var glyphs: ({
        "0": ["01110","10001","10011","10101","11001","10001","01110"],
        "1": ["00100","01100","00100","00100","00100","00100","01110"],
        "2": ["01110","10001","00001","00010","00100","01000","11111"],
        "3": ["11111","00010","00100","00010","00001","10001","01110"],
        "4": ["00010","00110","01010","10010","11111","00010","00010"],
        "5": ["11111","10000","11110","00001","00001","10001","01110"],
        "6": ["00110","01000","10000","11110","10001","10001","01110"],
        "7": ["11111","00001","00010","00100","01000","01000","01000"],
        "8": ["01110","10001","10001","01110","10001","10001","01110"],
        "9": ["01110","10001","10001","01111","00001","00010","01100"],
        ":": ["000","010","010","000","010","010","000"],
        ".": ["00","00","00","00","00","00","10"],
        "-": ["000","000","000","111","000","000","000"],
        "%": ["11000","11001","00010","00100","01000","10011","00011"],
        " ": ["00","00","00","00","00","00","00"]
    })
    readonly property real step: dot + gap
    readonly property var chars: text.split("").map(c => glyphs[c] ?? glyphs[" "])
    implicitWidth: chars.reduce((w, g) => w + g[0].length * step, 0) + Math.max(0, chars.length - 1) * charGap * step - gap
    implicitHeight: 7 * step - gap

    onTextChanged: requestPaint()
    onColorChanged: requestPaint()
    onDotChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        let x0 = 0;
        const r = dot / 2;
        for (const g of chars) {
            for (let row = 0; row < 7; row++)
                for (let col = 0; col < g[row].length; col++) {
                    ctx.fillStyle = g[row][col] === "1" ? dt.color : dt.dimColor;
                    ctx.beginPath();
                    ctx.arc(x0 + col * step + r, row * step + r, r, 0, 2 * Math.PI);
                    ctx.fill();
                }
            x0 += g[0].length * step + charGap * step;
        }
    }
}
