import QtQuick

// маленький график истории (0..1), залитый под линией
// a small history graph (0..1), filled under the line
Canvas {
    id: sp
    property var values: []
    property color color: Theme.accent
    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const n = values.length;
        if (n < 2) return;
        const w = width, h = height, step = w / 59;
        const x0 = w - (n - 1) * step;
        ctx.beginPath();
        ctx.moveTo(x0, h);
        for (let i = 0; i < n; i++) ctx.lineTo(x0 + i * step, h - Math.max(0, Math.min(1, values[i])) * (h - 4) - 2);
        ctx.lineTo(w, h);
        ctx.closePath();
        ctx.fillStyle = Qt.rgba(sp.color.r, sp.color.g, sp.color.b, 0.18);
        ctx.fill();
        ctx.beginPath();
        for (let i = 0; i < n; i++) {
            const x = x0 + i * step, y = h - Math.max(0, Math.min(1, values[i])) * (h - 4) - 2;
            i ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
        }
        ctx.strokeStyle = sp.color;
        ctx.lineWidth = 2;
        ctx.lineJoin = "round";
        ctx.stroke();
    }
}
