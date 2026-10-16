#!/bin/sh
# перезапуск системной службы при любом init: systemd, openrc, runit, dinit, s6 (запускать от root, через pkexec)
# имён можно дать несколько — у одной службы они в разных системах разные (bluetooth / bluetoothd)
# запуск: svc.sh restart имя [имя…]
# restarting a system service with any init: systemd, openrc, runit, dinit, s6 (run as root, via pkexec)
# several names can be given, one service is named differently on different systems (bluetooth / bluetoothd)
# usage: svc.sh restart name [name…]
[ "$1" = restart ] || exit 2
shift
for s in "$@"; do
    if [ -d /run/systemd/system ]; then
        systemctl restart "$s" 2>/dev/null && exit 0
    elif command -v rc-service >/dev/null 2>&1 && [ -x "/etc/init.d/$s" ]; then
        rc-service "$s" restart && exit 0
    elif [ -d "/etc/runit/sv/$s" ] && command -v sv >/dev/null 2>&1; then
        sv restart "$s" && exit 0
    elif command -v dinitctl >/dev/null 2>&1 && [ -f "/etc/dinit.d/$s" ]; then
        dinitctl restart "$s" && exit 0
    elif command -v s6-rc >/dev/null 2>&1; then
        # Artix: скрипты — /etc/s6/sv/имя-srv, s6-rc зовёт службу «имя» (wiki.artixlinux.org/Main/S6)
        # Artix: scripts are /etc/s6/sv/name-srv, s6-rc calls the service "name" (wiki.artixlinux.org/Main/S6)
        [ -d "/etc/s6/sv/$s-srv" ] || continue
        s6-svc -r "/run/service/$s-srv" 2>/dev/null || s6-svc -r "/run/service/$s" 2>/dev/null ||
            { s6-rc -d change "$s" && s6-rc -u change "$s"; } && exit 0
    fi
done
exit 1
