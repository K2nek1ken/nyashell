import Quickshell
import Quickshell.Io
import QtQuick

// блокировка перед сном (крышка, кнопка питания, сон по таймеру) и по «loginctl lock-session».
// держим «задерживающую» блокировку сна у logind: получив сигнал «сейчас усну», успеваем
// сделать снимок и закрыть экран, потом отпускаем — и система засыпает
// locking before sleep (lid, power button, idle sleep) and on "loginctl lock-session".
// we hold a "delay" sleep inhibitor with logind: on the "about to sleep" signal there's time
// to take a snapshot and cover the screen, then we release it and the system sleeps
Scope {
    id: sw

    // задержка сна (systemd или elogind)
    // sleep delay (systemd or elogind)
    Process {
        id: inhibit
        running: true
        command: ["sh", "-c",
            'exec systemd-inhibit --what=sleep --mode=delay --who=nyashell --why="lock screen" sleep infinity 2>/dev/null ' +
            '|| exec elogind-inhibit --what=sleep --mode=delay --who=nyashell --why="lock screen" sleep infinity']
    }

    // сигналы logind: PrepareForSleep(true/false) и Lock для нашего сеанса
    // logind signals: PrepareForSleep(true/false) and Lock for our session
    Process {
        id: watch
        running: true
        command: ["dbus-monitor", "--system",
                  "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'",
                  "type='signal',interface='org.freedesktop.login1.Session',member='Lock'"]
        property string last: ""
        stdout: SplitParser {
            onRead: (line) => {
                if (line.includes("member=PrepareForSleep")) watch.last = "sleep";
                else if (line.includes("member=Lock")) { watch.last = ""; ShellState.lock(); }
                else if (watch.last === "sleep" && line.includes("boolean true")) { watch.last = ""; sw.goingToSleep(); }
                else if (watch.last === "sleep" && line.includes("boolean false")) {
                    watch.last = ""; inhibit.running = true; ShellState.woke();     // проснулись — экран проявляется / woke up: the screen fades back in
                }
            }
        }
        onExited: again.restart()
    }
    Timer { id: again; interval: 2000; onTriggered: watch.running = true }

    function goingToSleep(): void {
        ShellState.sleepPending = true;
        ShellState.lock();
        release.restart();       // страховка, если вуаль так и не опустится / a safety net in case the veil never comes down
    }
    // вуаль опустилась — отпускаем задержку, и logind усыпляет систему
    // the veil has come down: release the delay and logind puts the system to sleep
    Connections { target: ShellState; function onSleepReady() { release.stop(); inhibit.running = false; } }
    // даём экрану блокировки появиться, потом отпускаем задержку — сон продолжается
    // let the lock screen appear, then release the delay and sleep continues
    Timer { id: release; interval: 4000; onTriggered: inhibit.running = false }
}
