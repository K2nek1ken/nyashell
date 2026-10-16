import Quickshell
import Quickshell.Wayland
import QtQuick

// простой: 5 мин — гасим экран, 10 мин — блокировка.
// Кнопка «не гасить» на панели держит IdleInhibitor, и эти таймеры тогда не срабатывают.
// idle: 5 min turns the screen off, 10 min locks.
// The "keep awake" button on the bar holds an IdleInhibitor, and then these timers don't fire.
Scope {
    function screens(cmd: string): void {
        for (const s of Quickshell.screens)
            Quickshell.execDetached(["mmsg", "dispatch", cmd + "," + s.name]);
    }

    IdleMonitor {
        enabled: ShellState.settings.idleDim > 0
        timeout: Math.max(1, ShellState.settings.idleDim) * 60
        respectInhibitors: true
        onIsIdleChanged: screens(isIdle ? "sleep_monitor" : "wakeup_monitor")
    }
    IdleMonitor {
        enabled: ShellState.settings.idleLock > 0
        timeout: Math.max(1, ShellState.settings.idleLock) * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) ShellState.lock()
    }
}
