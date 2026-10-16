//@ pragma IconTheme breeze-dark
//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import QtQuick

// nyagreet — экран входа для greetd в стиле nyashell.
// запускается внутри маленького mango (см. /etc/greetd/config.toml); без greetd работает в тестовом режиме
// nyagreet: a greetd login screen in the nyashell style.
// runs inside a small mango (see /etc/greetd/config.toml); without greetd it runs in test mode
ShellRoot {
    id: root

    property var users: []            // [{name, full}]
    property var sessions: []         // [{name, exec}]
    property int userIdx: 0
    property int sessionIdx: 0
    property bool manual: false       // «другой пользователь» / "other user"
    property string status: ""        // "" | "check" | "fail" | "test" | "go"
    property string message: ""
    property int shakes: 0
    property string password: ""

    readonly property string curUser: manual ? manualName : (users[userIdx]?.name ?? "")
    property string manualName: ""

    // ─── пользователи, сеансы, последний выбор ───
    // ─── users, sessions, last choice ───
    Process {
        running: true
        command: ["sh", "-c", "awk -F: '$3>=1000 && $3<60000 && $7 !~ /(nologin|false)$/ {print $1\":\"$5}' /etc/passwd"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.users = text.split("\n").filter(l => l).map(l => {
                    const i = l.indexOf(":");
                    return { name: l.slice(0, i), full: l.slice(i + 1).split(",")[0] };
                });
                root.restore();
            }
        }
    }
    Process {
        running: true
        // как в XDG: /usr/local важнее /usr. Один и тот же файл сеанса (например, mango.desktop от пакета mango
        // и от нашей сборки в /usr/local) показываем один раз; скрытые сеансы (Hidden/NoDisplay) не показываем
        // as in XDG: /usr/local wins over /usr. The same session file (e.g. mango.desktop from the mango package
        // and from our build in /usr/local) is shown once; hidden sessions (Hidden/NoDisplay) are not shown
        command: ["sh", "-c", "seen=' '; for f in /usr/local/share/wayland-sessions/*.desktop /usr/share/wayland-sessions/*.desktop; do [ -f \"$f\" ] || continue; " +
                  "b=${f##*/}; case \"$seen\" in *\" $b \"*) continue ;; esac; seen=\"$seen$b \"; " +
                  "grep -qiE '^(Hidden|NoDisplay)=true' \"$f\" && continue; " +
                  "n=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); e=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2-); " +
                  "printf '%s\\t%s\\n' \"$n\" \"$e\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.sessions = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const p = l.split("\t");
                    return { name: p[0], exec: p[1] };
                });
                root.restore();
            }
        }
    }
    FileView {
        id: state
        path: "/var/lib/nyagreet/state.json"
        blockLoading: true
        printErrors: false
    }
    function restore(): void {
        let st = {};
        try { st = JSON.parse(state.text()); } catch (e) {}
        const u = users.findIndex(x => x.name === st.user);
        if (u >= 0) userIdx = u;
        const s = sessions.findIndex(x => x.name === st.session);
        if (s >= 0) sessionIdx = s;
        else { const m = sessions.findIndex(x => /mango/i.test(x.name)); if (m >= 0) sessionIdx = m; }
    }

    // ─── вход через greetd ───
    // ─── login through greetd ───
    function login(): void {
        if (!curUser || status === "check" || status === "go") return;
        if (!Greetd.available) { status = "test"; message = Theme.tr("test mode: greetd is not running, can't log in", "тестовый режим: greetd не запущен, вход не выполняется"); shakes++; return; }
        status = "check";
        message = "";
        Greetd.createSession(curUser);
    }
    Connections {
        target: Greetd
        function onAuthMessage(msg, error, responseRequired, echoResponse) {
            if (responseRequired) Greetd.respond(root.password);
            else if (error) root.message = msg;
        }
        function onAuthFailure(msg) {
            root.status = "fail";
            root.message = Theme.tr("wrong password", "неверный пароль");
            root.password = "";
            root.shakes++;
            Greetd.cancelSession();
        }
        function onStateChanged() {
            if (Greetd.state === GreetdState.ReadyToLaunch) {
                root.status = "go";
                try { state.setText(JSON.stringify({ user: root.curUser, session: root.sessions[root.sessionIdx]?.name ?? "" })); } catch (e) {}
                leave.restart();          // сначала анимация ухода, потом запуск сеанса / the leaving animation first, then the session starts
            }
        }
    }
    Timer {
        id: leave
        interval: 420
        onTriggered: {
            const s = root.sessions[root.sessionIdx];
            // поля %U/%f из .desktop выкидываем
            // drop the %U/%f fields from the .desktop file
            const cmd = (s?.exec ?? "mango").split(/\s+/).filter(x => x && !x.startsWith("%"));
            // всё, что сеанс пишет в консоль, — в файл, а не на экран: при входе больше не мелькают логи
            // обёртка — отдельным файлом без кавычек в команде (см. session.sh)
            // everything the session prints to the console goes to a file, not the screen: no more log flashes on login
            // the wrapper is a separate file with no quotes in the command (see session.sh)
            Greetd.launch(["/etc/greetd/nyagreet/session.sh"].concat(cmd), ["XDG_SESSION_TYPE=wayland"]);
        }
    }

    Greeter { greeter: root }
}
