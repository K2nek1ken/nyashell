#!/bin/sh
# завершить приложение целиком.
# kill-app.sh PID       — по процессу окна (Super+Q, меню панели задач)
# kill-app.sh -t ID [НАЗВАНИЕ] — значок в трее: по его Id через D-Bus находим владельца (имя на шине → PID);
#                        не нашли — ищем процесс по Id и названию (deltachat_status_icon_1 → deltachat)
# kill-app.sh -n NAME   — по имени процесса
# 1) от процесса окна поднимаемся к «корню» приложения: у Steam окно рисует steamwebhelper, а главный —
#    процесс steam выше по дереву; если убить только окно, Steam перезапускает его пустым (data:text/html…)
#    и без темы. Подъём останавливается на оболочке, терминале или самом композиторе — их не трогаем
# 2) Steam закрываем его же командой (steam -shutdown) — так он не перезапускается и не теряет тему
# 3) остальное: сначала вежливо (TERM), через 2 с — что осталось, принудительно (KILL)
# kill an app entirely.
# kill-app.sh PID       — by the window's process (Super+Q, taskbar menu)
# kill-app.sh -t ID [TITLE] — a tray icon: by its Id via D-Bus we find the owner (bus name → PID);
#                        if not found, look for the process by Id and title (deltachat_status_icon_1 → deltachat)
# kill-app.sh -n NAME   — by process name
# 1) from the window's process we climb to the app's "root": in Steam the window is drawn by steamwebhelper, and the main
#    process steam is higher up the tree; kill only the window and Steam restarts it empty (data:text/html…)
#    and unthemed. The climb stops at a shell, a terminal or the compositor itself, those are left alone
# 2) Steam is closed with its own command (steam -shutdown), so it doesn't restart and keeps its theme
# 3) everything else: politely first (TERM), whatever is left after 2 s is forced (KILL)
comm() { cat "/proc/$1/comm" 2>/dev/null; }
ppid() { awk '{print $4}' "/proc/$1/stat" 2>/dev/null; }
stop_at='^(mango|systemd|init|kitty|foot|alacritty|konsole|wezterm|ghostty|fish|zsh|bash|login|greetd|qs|quickshell|sshd|tmux|screen)$'
root_of() {
    p=$1
    while :; do
        pp=$(ppid "$p"); [ -n "$pp" ] && [ "$pp" -gt 1 ] || break
        c=$(comm "$pp")
        printf %s "$c" | grep -Eq "$stop_at" && break
        p=$pp
    done
    echo "$p"
}
tree() { echo "$1"; for c in $(pgrep -P "$1"); do tree "$c"; done; }

# значок в трее → PID: список значков есть у StatusNotifierWatcher (это сам шелл), у каждого — имя на шине
# и путь; спрашиваем у значка его Id, у шины — PID владельца. gdbus есть везде, где есть glib (и без systemd)
# tray icon → PID: StatusNotifierWatcher (the shell itself) has the list of icons, each with a bus name
# and a path; we ask the icon for its Id and the bus for the owner's PID. gdbus is everywhere glib is (systemd or not)
tray_pid() {
    gdbus call --session --dest org.kde.StatusNotifierWatcher --object-path /StatusNotifierWatcher \
        --method org.freedesktop.DBus.Properties.Get org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null |
    grep -o "'[^']*'" | tr -d "'" | while IFS= read -r e; do
        svc=${e%%/*}; path=/${e#*/}; [ "$path" = "/$e" ] && path=/StatusNotifierItem
        id=$(gdbus call --session --dest "$svc" --object-path "$path" --method org.freedesktop.DBus.Properties.Get \
             org.kde.StatusNotifierItem Id 2>/dev/null | sed -n "s/.*<'\(.*\)'>.*/\1/p")
        [ "$id" = "$1" ] || continue
        gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
            --method org.freedesktop.DBus.GetConnectionUnixProcessID "$svc" 2>/dev/null | grep -o '[0-9]\+' | tail -1
        break
    done
}
# по имени: точное имя процесса, потом — без регистра по командной строке (только свои процессы)
# by name: the exact process name, then case-insensitively by command line (own processes only)
by_name() {
    [ -n "$1" ] || return
    p=$(pgrep -x "$1"); [ -n "$p" ] || p=$(pgrep -u "$(id -u)" -if -- "$1")
    # сам этот скрипт (и его подоболочки) тоже подходит по командной строке — его не трогаем
    # this very script (and its subshells) matches by command line too, leave it alone
    for q in $p; do tr '\0' ' ' < "/proc/$q/cmdline" 2>/dev/null | grep -q 'kill-app\.sh' || echo "$q"; done
}

case "$1" in
    -t)
        pid=$(tray_pid "$2")
        if [ -n "$pid" ]; then pids=$(root_of "$pid")
        else
            # запасной путь: Id без хвоста «_status_icon_1», «-tray» и т.п., потом название значка
            # fallback: the Id without a "_status_icon_1", "-tray" etc. tail, then the icon title
            base=$(printf %s "$2" | sed -E 's/[_-](status[_-]?icon|tray(icon)?|indicator|systray)([_-]?[0-9]+)?$//I; s/[_-][0-9]+$//')
            pids=$(by_name "$base"); [ -n "$pids" ] || pids=$(by_name "$3")
        fi ;;
    -n) pids=$(by_name "$2") ;;
    *)  pids=$(root_of "$1") ;;
esac
[ -n "$pids" ] || exit 0
all=$(for p in $pids; do tree "$p"; done | sort -u)

# Steam — своей командой
# Steam: with its own command
if for p in $all; do comm "$p"; done | grep -qx 'steam'; then
    steam -shutdown >/dev/null 2>&1 &
    for i in 1 2 3 4 5 6 7 8 9 10; do sleep 0.5; pgrep -x steam >/dev/null || exit 0; done
fi
kill -TERM $all 2>/dev/null
sleep 2
for p in $all; do kill -0 "$p" 2>/dev/null && kill -KILL "$p" 2>/dev/null; done
exit 0
