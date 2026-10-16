#!/bin/sh
# синхронизация времени без systemd: ntp.sh on|off (от root, через pkexec) | probe (есть ли чем управлять)
# ищет chronyd / ntpd / openntpd и включает-выключает его в openrc, runit, s6 или dinit
# time sync without systemd: ntp.sh on|off (as root, via pkexec) | probe (is there anything to manage)
# looks for chronyd / ntpd / openntpd and enables/disables it in openrc, runit, s6 or dinit
mode=$1
for s in chronyd ntpd openntpd; do
    if command -v rc-service >/dev/null 2>&1 && [ -x "/etc/init.d/$s" ]; then
        [ "$mode" = probe ] && exit 0
        if [ "$mode" = on ]; then rc-update add "$s" default && rc-service "$s" start
        else rc-service "$s" stop; rc-update del "$s" default; fi
        exit 0
    fi
    # runit: включённые службы — ссылки в /etc/runit/runsvdir/default (переживают перезагрузку)
    # runit: enabled services are links in /etc/runit/runsvdir/default (they survive a reboot)
    if [ -d "/etc/runit/sv/$s" ]; then
        [ "$mode" = probe ] && exit 0
        if [ "$mode" = on ]; then ln -sf "/etc/runit/sv/$s" /etc/runit/runsvdir/default/
        else rm -f "/etc/runit/runsvdir/default/$s"; fi
        exit 0
    fi
    # s6 (Artix, wiki.artixlinux.org/Main/S6): скрипты — /etc/s6/sv/имя-srv, а s6-rc зовёт службу просто «имя»;
    # при загрузке стартует то, для чего есть пустой файл в contents.d набора default
    # s6 (Artix, wiki.artixlinux.org/Main/S6): scripts are /etc/s6/sv/name-srv, while s6-rc calls the service just "name";
    # at boot whatever has an empty file in the default bundle's contents.d starts
    if command -v s6-rc >/dev/null 2>&1 && [ -d "/etc/s6/sv/$s-srv" ]; then
        [ "$mode" = probe ] && exit 0
        on=/etc/s6/adminsv/default/contents.d
        if [ "$mode" = on ]; then mkdir -p "$on" && touch "$on/$s" && s6-db-reload && s6-rc -u change "$s"
        else s6-rc -d change "$s"; rm -f "$on/$s"; s6-db-reload; fi
        exit 0
    fi
    if command -v dinitctl >/dev/null 2>&1 && [ -f "/etc/dinit.d/$s" ]; then
        [ "$mode" = probe ] && exit 0
        if [ "$mode" = on ]; then dinitctl enable "$s"; else dinitctl disable "$s"; fi
        exit 0
    fi
done
exit 1
