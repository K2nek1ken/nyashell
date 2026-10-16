import Quickshell.Widgets
import QtQuick
import QtQuick.Shapes

// пластинка. Слои снизу вверх: обложка (круг, гладкий край) → сама пластинка с прозрачной серединой
// (кольцо со сглаженными краями, поэтому обложка не «вырезается по пикселям») → тонкая цветная кромка.
// Без обложки — одна из нескольких наклеек (выбирается по треку, чтобы у каждого была своя)
// the vinyl. Layers bottom to top: the cover (a circle with a smooth edge) → the record itself with a transparent centre
// (a ring with antialiased edges, so the cover isn't "cut out by pixels") → a thin coloured rim.
// Without a cover: one of several labels (chosen from the track, so each has its own)
Item {
    id: root
    property real size: 32
    property string art: ""
    property bool spinning: false
    property string seed: ""                 // от чего зависит вид наклейки (обычно путь к треку) / what the label's look depends on (usually the track path)
    // скретч: пластинку можно крутить мышью — вперёд/назад по треку (полный оборот ≈ 8 с)
    // scratch: the record can be spun with the mouse, forward/back through the track (a full turn ≈ 8 s)
    property bool scratchable: false
    signal scratched(real seconds)
    signal grabbed()
    signal letGo()
    property real scratchRot: 0
    property bool scratching: false
    width: size
    height: size

    readonly property real labelR: size * 0.34          // радиус «яблока» с обложкой / radius of the "apple" with the cover

    Item {
        id: wrap
        anchors.fill: parent
        rotation: root.scratchRot
        Item {
            id: disc
            anchors.fill: parent
            RotationAnimation on rotation {
                from: 0; to: 360; duration: 4000; loops: Animation.Infinite
                running: true
                paused: !root.spinning || !root.visible || root.scratching
            }

            // 1) обложка или наклейка — под пластинкой
            // 1) cover or label: under the record
            ClippingRectangle {
                anchors.centerIn: parent
                width: root.labelR * 2 + 4; height: width; radius: width / 2
                color: Theme.accent
                Image {
                    id: cover
                    anchors.fill: parent
                    source: root.art
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 256
                    asynchronous: true
                    visible: status === Image.Ready
                }
                // наклейка без обложки — генерируется по треку: либо разрезанный круг (половины, трети, четверти),
                // либо 3–5 фигур одного вида в случайных местах и размерах, разной насыщенности акцента;
                // фигуры не наслаиваются и почти не вылезают за край. Один и тот же трек — всегда та же наклейка
                // a label without a cover is generated from the track: either a sliced circle (halves, thirds, quarters)
                // or 3–5 shapes of one kind in random places and sizes, in different accent saturations;
                // the shapes don't overlap and barely go past the edge. The same track always gets the same label
                Canvas {
                    id: label
                    anchors.fill: parent
                    visible: cover.status !== Image.Ready
                    antialiasing: true
                    property var deps: [root.seed, Theme.accent, Theme.accent2, Theme.onAccent, width, ShellState.settings.vinylLabels, ShellState.settings.vinylKinds]
                    onDepsChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d"), w = width, R = w / 2, cx = R, cy = R;
                        c.reset();
                        if (w <= 0) return;
                        // детерминированный «случай» от трека
                        // a deterministic "chance" from the track
                        let h = 2166136261;
                        for (let i = 0; i < root.seed.length; i++) { h ^= root.seed.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; }
                        const rnd = () => { h ^= h << 13; h >>>= 0; h ^= h >> 17; h ^= h << 5; h >>>= 0; return (h % 100000) / 100000; };
                        const acc = Theme.accent, on = Theme.onAccent;
                        // оттенок акцента с другой насыщенностью и яркостью
                        // an accent shade with different saturation and brightness
                        const hue = acc.hslHue, sat = Math.max(0.25, acc.hslSaturation);
                        const tone = (l, sk) => Qt.hsla(hue, Math.max(0, Math.min(1, sat * (sk ?? 1))), l, 1);
                        // фон светлый — фигуры тёмные (и наоборот), чтобы их было хорошо видно
                        // light background: dark shapes (and the other way round), so they're easy to see
                        const light = rnd() < 0.7;
                        c.fillStyle = light ? tone(0.78, 0.9) : tone(0.22, 0.8); c.fillRect(0, 0, w, w);
                        const shapeTone = () => light ? tone(0.28 + rnd() * 0.22, 0.8 + rnd() * 0.4) : tone(0.70 + rnd() * 0.18, 0.7 + rnd() * 0.4);

                        // какие узоры можно (Настройки → Вид → Пластинка); ни одного или узоры выключены — ровная наклейка
                        // which patterns are allowed (Settings → Look → Vinyl); none, or patterns off, gives a plain label
                        const kinds = (ShellState.settings.vinylKinds ?? ShellState.vinylKindsAll).filter(k => ShellState.vinylKindsAll.includes(k));
                        if (!(ShellState.settings.vinylLabels ?? true) || !kinds.length) return;
                        const kind = kinds[Math.floor(rnd() * kinds.length)];
                        if (kind === "split") {
                            // половины / трети / четверти, повёрнутые случайно
                            // halves / thirds / quarters, rotated randomly
                            const n = [2, 3, 4][Math.floor(rnd() * 3)], rot = rnd() * Math.PI * 2;
                            for (let i = 0; i < n; i++) {
                                c.fillStyle = light ? tone(0.78 - i * 0.5 / n, 0.9) : tone(0.22 + i * 0.5 / n, 0.8);
                                c.beginPath(); c.moveTo(cx, cy);
                                c.arc(cx, cy, R * 1.5, rot + i * 2 * Math.PI / n, rot + (i + 1) * 2 * Math.PI / n); c.closePath(); c.fill();
                            }
                            return;
                        }
                        const shape = (x, y, r, a) => {
                            c.save(); c.translate(x, y); c.rotate(a); c.beginPath();
                            switch (kind) {
                            case "triangles": for (let i = 0; i < 3; i++) { const t = i * 2 * Math.PI / 3 - Math.PI / 2; c.lineTo(r * Math.cos(t), r * Math.sin(t)); } c.closePath(); c.fill(); break;
                            case "rings": c.arc(0, 0, r, 0, Math.PI * 2); c.lineWidth = r * 0.38; c.stroke(); break;
                            case "squares": { const q = r * 0.75; c.moveTo(-q + q * 0.3, -q); c.arcTo(q, -q, q, q, q * 0.3); c.arcTo(q, q, -q, q, q * 0.3);
                                              c.arcTo(-q, q, -q, -q, q * 0.3); c.arcTo(-q, -q, q, -q, q * 0.3); c.closePath(); c.fill(); break; }
                            case "flowers": for (let t = 0; t <= Math.PI * 2 + 0.01; t += 0.05) { const rr = r * (0.82 + 0.18 * Math.cos(4 * t)); c.lineTo(rr * Math.cos(t), rr * Math.sin(t)); } c.closePath(); c.fill(); break;
                            case "moons": c.arc(0, 0, r, 0, Math.PI * 2); c.fill(); c.globalCompositeOperation = "destination-out";
                                          c.beginPath(); c.arc(r * 0.45, -r * 0.2, r * 0.85, 0, Math.PI * 2); c.fill(); c.globalCompositeOperation = "source-over"; break;
                            case "stars": for (let i = 0; i < 8; i++) { const t = i * Math.PI / 4, rr = i % 2 ? r * 0.28 : r; c.lineTo(rr * Math.cos(t), rr * Math.sin(t)); } c.closePath(); c.fill(); break;
                            case "plus": { const b = r * 0.32; c.moveTo(-b, -r); c.lineTo(b, -r); c.lineTo(b, -b); c.lineTo(r, -b); c.lineTo(r, b); c.lineTo(b, b); c.lineTo(b, r);
                                           c.lineTo(-b, r); c.lineTo(-b, b); c.lineTo(-r, b); c.lineTo(-r, -b); c.lineTo(-b, -b); c.closePath(); c.fill(); break; }
                            case "hexes": for (let i = 0; i < 6; i++) { const t = i * Math.PI / 3; c.lineTo(r * Math.cos(t), r * Math.sin(t)); } c.closePath(); c.fill(); break;
                            default: { // лапка, как значок в меню приложений: подушечка и четыре пальчика дугой. / a paw, like the icon in the app menu: a pad and four toes in an arc.
                                       // рисуется фигурами в пределах своего радиуса r (шрифт в холсте не знает размеров)
                                       // drawn with shapes within its radius r (a font on a canvas doesn't know its size)
                                c.beginPath(); c.ellipse(-r * 0.48, -r * 0.02, r * 0.96, r * 0.78); c.fill();
                                for (const [tx, ty, sx, sy] of [[-0.70, -0.30, 0.34, 0.44], [-0.26, -0.68, 0.36, 0.48],
                                                                [0.26, -0.68, 0.36, 0.48], [0.70, -0.30, 0.34, 0.44]]) {
                                    c.beginPath(); c.ellipse((tx - sx / 2) * r, (ty - sy / 2) * r, sx * r, sy * r); c.fill(); }
                            }
                            }
                            c.restore();
                        };
                        // раскладка: у каждой фигуры своя доля пластинки (2 — по половине, 3 — по трети, 4 — по четверти…);
                        // случайно только место внутри доли, поэтому фигуры не наслаиваются и стоят ровно
                        // layout: each shape gets its own share of the record (2: a half each, 3: a third each, 4: a quarter each…);
                        // only the position inside the share is random, so the shapes don't overlap and sit evenly
                        const n = 2 + Math.floor(rnd() * 4), rot0 = rnd() * Math.PI * 2, size = R * (n <= 2 ? 0.34 : n === 3 ? 0.27 : n === 4 ? 0.22 : 0.19);
                        for (let i = 0; i < n; i++) {
                            const span = 2 * Math.PI / n;
                            const ang = rot0 + span * i + span * (0.4 + rnd() * 0.2);      // середина доли ± немного / middle of the share ± a little
                            const dist = R * (0.46 + rnd() * 0.12);
                            const r = size * (0.85 + rnd() * 0.25);
                            const col = shapeTone();
                            c.fillStyle = col; c.strokeStyle = col;
                            c.globalAlpha = 0.9;
                            shape(cx + Math.cos(ang) * dist, cy + Math.sin(ang) * dist, r, rnd() * Math.PI * 2);
                        }
                        c.globalAlpha = 1;
                    }
                }
            }

            // 2) сама пластинка: кольцо от края «яблока» до внешнего края, с бороздками и бликом
            // 2) the record itself: a ring from the edge of the "apple" to the outer edge, with grooves and a highlight
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "#101010"
                    strokeWidth: -1
                    fillRule: ShapePath.OddEvenFill
                    PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root.size / 2 - 1; radiusY: root.size / 2 - 1; startAngle: 0; sweepAngle: 360 }
                    PathMove { x: root.size / 2 + root.labelR; y: root.size / 2 }
                    PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root.labelR; radiusY: root.labelR; startAngle: 0; sweepAngle: 360 }
                }
                // бороздки
                // grooves
                ShapePath {
                    fillColor: "transparent"; strokeColor: Qt.rgba(1, 1, 1, 0.06); strokeWidth: 1
                    PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root.size * 0.44; radiusY: root.size * 0.44; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    fillColor: "transparent"; strokeColor: Qt.rgba(1, 1, 1, 0.05); strokeWidth: 1
                    PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root.size * 0.40; radiusY: root.size * 0.40; startAngle: 0; sweepAngle: 360 }
                }
                // блик — светлая дуга, вращается вместе с пластинкой
                // highlight: a light arc that rotates with the record
                ShapePath {
                    fillColor: "transparent"; strokeColor: Qt.rgba(1, 1, 1, 0.10); strokeWidth: root.size * 0.05; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root.size * 0.42; radiusY: root.size * 0.42; startAngle: -60; sweepAngle: 40 }
                }
            }
            // дырочка в центре
            // the hole in the centre
            Rectangle { anchors.centerIn: parent; width: Math.max(4, root.size * 0.04); height: width; radius: width / 2; color: "#101010" }
        }
    }
    // 3) тонкая цветная кромка — не вращается
    // 3) a thin coloured rim: doesn't rotate
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: Math.max(1.5, root.size * 0.012)
        border.color: Theme.accent
        opacity: 0.85
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.scratchable
        cursorShape: root.scratching ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property real a0: 0
        property real acc: 0
        property real last: 0
        function angle(x: real, y: real): real { return Math.atan2(y - height / 2, x - width / 2) * 180 / Math.PI; }
        onPressed: (e) => { root.scratching = true; a0 = angle(e.x, e.y); acc = 0; last = Date.now(); root.grabbed(); }
        onPositionChanged: (e) => {
            const a = angle(e.x, e.y);
            let d = a - a0; if (d > 180) d -= 360; if (d < -180) d += 360;
            a0 = a; root.scratchRot += d; acc += d;
            if (Date.now() - last > 120 && Math.abs(acc) > 4) { root.scratched(acc / 360 * 8); acc = 0; last = Date.now(); }
        }
        onReleased: { if (Math.abs(acc) > 4) root.scratched(acc / 360 * 8); acc = 0; root.scratching = false; root.letGo(); }
    }
}
