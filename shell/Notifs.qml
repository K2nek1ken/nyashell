pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

// сервер уведомлений: всплывашки + история + «не беспокоить»
// notification server: popups + history + "do not disturb"
Singleton {
    id: ns
    property bool dnd: false
    property var popups: []         // то, что сейчас всплыло: [{key, n, ...}] / what has popped up right now: [{key, n, ...}]
    property var history: []        // последние 60, новые сверху / the last 60, newest on top
    // непрочитанные считаются из истории, а не отдельным счётчиком — поэтому всегда совпадают с ней
    // unread ones are counted from the history, not a separate counter, so they always match it
    readonly property int unread: history.filter(e => !e.read).length
    property int seq: 0

    function ago(t: real): string {
        const m = Math.floor((Date.now() - t) / 60000);
        if (m < 1) return L.t("сейчас");
        if (m < 60) return m + L.t(" мин назад");
        const h = Math.floor(m / 60);
        if (h < 24) return h + L.t(" ч назад");
        return L.locale.toString(new Date(t), "d MMM, HH:mm");
    }

    NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: (n) => {
            // приложению запретили присылать уведомления (ПКМ по уведомлению) — молча закрываем
            // the app was blocked from sending notifications (right-click a notification): close silently
            if ((ShellState.settings.mutedApps ?? []).includes(n.appName || "")) { try { n.dismiss(); } catch (err) {} return; }
            n.tracked = true;
            const e = {
                key: ++ns.seq, n: n,
                app: n.appName || L.t("приложение"), icon: n.appIcon || "", image: n.image || "",
                summary: n.summary || "", body: n.body || "",
                critical: n.urgency === NotificationUrgency.Critical,
                actions: (n.actions || []).map(a => ({ id: a.identifier, text: a.text })),
                time: Date.now(), read: false
            };
            ns.history = [e].concat(ns.history).slice(0, 60);
            if (!ns.dnd || e.critical) ns.popups = ns.popups.concat([e]).slice(-4);
            // если приложение само закрыло уведомление — убираем всплывашку
            // if the app closed the notification itself, remove the popup
            n.closed.connect(() => ns.drop(e.key, false));
        }
    }

    function mute(app: string): void {
        const m = (ShellState.settings.mutedApps ?? []).slice();
        if (!m.includes(app)) m.push(app);
        ShellState.set("mutedApps", m);
        for (const e of history.filter(x => x.app === app)) remove(e.key);
    }
    function unmute(app: string): void { ShellState.set("mutedApps", (ShellState.settings.mutedApps ?? []).filter(x => x !== app)); }

    function drop(key: int, dismiss: bool): void {
        const e = popups.find(x => x.key === key);
        popups = popups.filter(x => x.key !== key);
        if (dismiss && e?.n) { try { e.n.dismiss(); } catch (err) {} }
    }
    function remove(key: int): void {
        const e = history.find(x => x.key === key);
        history = history.filter(x => x.key !== key);
        drop(key, false);
        if (e?.n) { try { e.n.dismiss(); } catch (err) {} }
    }
    function clearAll(): void {
        for (const e of history) if (e.n) { try { e.n.dismiss(); } catch (err) {} }
        history = []; popups = [];
    }
    function invoke(e, actionId: string): void {
        const a = (e.n?.actions || []).find(x => x.identifier === actionId);
        if (a) a.invoke();
        drop(e.key, false);
    }
    function markRead(): void { history = history.map(e => e.read ? e : Object.assign({}, e, { read: true })); }
}
