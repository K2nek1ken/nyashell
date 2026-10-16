#!/bin/sh
# запуск сеанса с экрана входа: вывод сеанса — в файл, а не на экран (без мелькания логов при входе).
# отдельный файл, а не «sh -c '…'»: greetd склеивает команду через пробелы и запускает её через оболочку
# пользователя (у тебя fish) — кавычки при этом теряются, и вход срывался
# starting the session from the login screen: session output goes to a file, not the screen (no log flashes on login).
# a separate file rather than "sh -c '…'": greetd joins the command with spaces and runs it through the user's
# shell (fish in your case), the quotes get lost and the login failed
mkdir -p "$HOME/.local/state" 2>/dev/null
log="$HOME/.local/state/session.log"
[ -n "$HOME" ] || log=/dev/null
# без systemd (Artix: openrc, runit, dinit, s6) шины D-Bus сеанса никто не поднимает — без неё не работают
# порталы, уведомления, MPRIS, трей. Тогда сеанс запускается внутри dbus-run-session
# without systemd (Artix: openrc, runit, dinit, s6) nobody starts the session D-Bus bus, and without it portals,
# notifications, MPRIS and the tray don't work. Then the session runs inside dbus-run-session
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ] && [ ! -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus" ] && command -v dbus-run-session >/dev/null; then
    exec dbus-run-session "$@" >"$log" 2>&1
fi
exec "$@" >"$log" 2>&1
