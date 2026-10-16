pragma Singleton
import Quickshell
import Quickshell.Wayland
import QtQuick

// «насколько окном пользуются»: Wayland не показывает шеллу клики и ввод в чужие окна,
// поэтому считаем самое близкое, что видно, — время в фокусе. Короткие заходы (<2 с,
// например курсор пролетел мимо) не считаются, старое постепенно забывается (полураспад ~5 мин)
// "how much a window is used": Wayland doesn't show the shell clicks and input in other windows,
// so we count the closest visible thing: time in focus. Short visits (<2 s,
// e.g. the cursor flew past) don't count, old data is gradually forgotten (half-life ~5 min)
Singleton {
    id: u
    property var scores: new Map()      // Toplevel -> очки / Toplevel -> score
    property int rev: 0                 // чтобы привязки знали, что очки обновились / so bindings know the scores were updated
    property var current: null
    property int held: 0                // сколько секунд текущее окно в фокусе / how many seconds the current window has been focused

    function score(t): real { rev; return scores.get(t) ?? 0; }
    function mostUsed(list) {
        let best = null, bs = -1;
        for (const t of list) { const s = score(t); if (s > bs) { bs = s; best = t; } }
        return best;
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            const a = ToplevelManager.activeToplevel;
            if (a !== u.current) { u.current = a; u.held = 0; }
            else u.held++;
            const decay = Math.pow(0.5, 1 / 300);
            for (const [t, s] of u.scores) u.scores.set(t, s * decay);
            if (a && u.held >= 2) u.scores.set(a, (u.scores.get(a) ?? 0) + (u.held === 2 ? 3 : 1));
            // забываем закрытые окна
            // forget closed windows
            const alive = new Set(ToplevelManager.toplevels.values);
            for (const t of Array.from(u.scores.keys())) if (!alive.has(t)) u.scores.delete(t);
            u.rev++;
        }
    }
}
