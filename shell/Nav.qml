pragma Singleton
import Quickshell
import QtQuick

// навигация клавишами (WASD / стрелки + пробел) по кнопкам борда — как пультом по телевизору.
// Кнопки (StateLayer) и отмеченные места (NavPoint) регистрируются сами; ходим «по геометрии»:
// следующая цель — ближайшая видимая в нужную сторону. Списки при этом прокручиваются
// keyboard navigation (WASD / arrows + space) over the dashboard buttons, like a TV remote.
// Buttons (StateLayer) and marked spots (NavPoint) register themselves; movement is "geometric":
// the next target is the nearest visible one in that direction. Lists scroll along
Singleton {
    id: nav
    property var items: []
    property Item scope: null          // в чём ходим (страницы борда); null — навигация выключена / what we move within (dashboard pages); null means navigation is off
    property Item current: null        // выделенная цель / selected target
    property Item home: null           // кому вернуть клавиатуру из поля ввода (Esc) / who gets the keyboard back from an input field (Esc)

    function register(it): void { if (!items.includes(it)) items = items.concat([it]); }
    function unregister(it): void { items = items.filter(x => x !== it); if (current === it) current = null; }

    // цель видна: сама видима, у предков нет нулевой прозрачности, лежит внутри scope и всех обрезающих предков
    // a target is visible: visible itself, no ancestor has zero opacity, it lies inside the scope and all clipping ancestors
    function rectOf(it): var {
        if (!scope || !it || !it.visible || it.width <= 0 || it.height <= 0 || (it.navDisabled ?? false)) return null;
        let p = it, inside = false;
        const tl = it.mapToItem(scope, 0, 0);
        let r = { x: tl.x, y: tl.y, w: it.width, h: it.height };
        while (p) {
            if (p.opacity !== undefined && p.opacity < 0.05) return null;
            if (p === scope) { inside = true; break; }
            if (p.clip && p !== it) {
                const q = p.mapToItem(scope, 0, 0);
                const x1 = Math.max(r.x, q.x), y1 = Math.max(r.y, q.y);
                const x2 = Math.min(r.x + r.w, q.x + p.width), y2 = Math.min(r.y + r.h, q.y + p.height);
                if (x2 - x1 < 4 || y2 - y1 < 4) return null;
                r = { x: x1, y: y1, w: x2 - x1, h: y2 - y1 };
            }
            p = p.parent;
        }
        if (!inside) return null;
        if (r.x + r.w < 2 || r.y + r.h < 2 || r.x > scope.width - 2 || r.y > scope.height - 2) return null;
        return r;
    }
    function targets(): var {
        const out = [];
        for (const it of items) { const r = rectOf(it); if (r) out.push({ it: it, r: r }); }
        return out;
    }
    function centre(r): var { return { x: r.x + r.w / 2, y: r.y + r.h / 2 }; }

    // войти: ближайшая к левому верхнему углу цель (или прежняя, если она ещё видна)
    // enter: the target nearest the top-left corner (or the previous one if it's still visible)
    function enter(s): bool {
        scope = s;
        if (current && rectOf(current)) return true;
        const t = targets();
        if (!t.length) { current = null; return false; }
        t.sort((a, b) => (a.r.y + a.r.x * 0.5) - (b.r.y + b.r.x * 0.5));
        current = t[0].it;
        return true;
    }
    function leave(): void { current = null; scope = null; }

    // шаг в сторону dir ("a" | "d" | "w" | "s"); false — дальше некуда (даже после прокрутки)
    // a step in direction dir ("a" | "d" | "w" | "s"); false means nowhere further (even after scrolling)
    function move(dir: string): bool {
        if (!scope) return false;
        const t = targets();
        const cr = current ? rectOf(current) : null;
        if (!cr) return enter(scope);
        const c = centre(cr);
        let best = null, bestScore = 1e9;
        for (const o of t) {
            if (o.it === current) continue;
            const p = centre(o.r);
            const dx = p.x - c.x, dy = p.y - c.y;
            let main, side;
            if (dir === "d") { if (o.r.x < cr.x + cr.w - 2 && dx <= 4) continue; main = dx; side = dy; }
            else if (dir === "a") { if (o.r.x + o.r.w > cr.x + 2 && dx >= -4) continue; main = -dx; side = dy; }
            else if (dir === "s") { if (o.r.y < cr.y + cr.h - 2 && dy <= 4) continue; main = dy; side = dx; }
            else { if (o.r.y + o.r.h > cr.y + 2 && dy >= -4) continue; main = -dy; side = dx; }
            if (main <= 0) continue;
            const score = main + Math.abs(side) * 2.2;
            if (score < bestScore) { bestScore = score; best = o.it; }
        }
        if (best) { current = best; reveal(best); return true; }
        // вниз/вверх некуда — может, список ещё прокручивается
        // nowhere further down/up: maybe the list still scrolls
        if ((dir === "s" || dir === "w") && scroll(current, dir === "s" ? 1 : -1)) { retry.dir = dir; retry.restart(); return true; }
        return false;
    }
    Timer { id: retry; property string dir: ""; interval: 60; onTriggered: nav.move(dir) }

    // ближайший прокручиваемый предок
    // nearest scrollable ancestor
    function flickOf(it): var {
        let p = it ? it.parent : null;
        while (p && p !== scope) {
            if (p.contentY !== undefined && p.contentHeight !== undefined && p.contentHeight > p.height + 1) return p;
            p = p.parent;
        }
        return null;
    }
    function scroll(it, sign: int): bool {
        const f = flickOf(it);
        if (!f) return false;
        const max = Math.max(0, f.contentHeight - f.height + (f.originY ?? 0)), min = f.originY ?? 0;
        const to = Math.max(min, Math.min(max, f.contentY + sign * f.height * 0.4));
        if (Math.abs(to - f.contentY) < 1) return false;
        f.contentY = to;
        return true;
    }
    // выделенное — целиком в видимой части списка
    // the selection is fully inside the visible part of the list
    function reveal(it): void {
        const f = flickOf(it);
        if (!f) return;
        const p = it.mapToItem(f, 0, 0);
        if (p.y < 0) f.contentY = Math.max(f.originY ?? 0, f.contentY + p.y - 8);
        else if (p.y + it.height > f.height) f.contentY = f.contentY + (p.y + it.height - f.height) + 8;
    }

    function activate(): void {
        if (!current) return;
        if (typeof current.navActivate === "function") current.navActivate();
    }
    function back(): void { if (home) home.forceActiveFocus(); }
}
