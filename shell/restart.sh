#!/bin/sh
# перезапуск nyashell: гасим ВСЕ его экземпляры, ждём, пока исчезнут, и запускаем ровно один.
# (раньше старый экземпляр падал при выходе, встроенный обработчик сбоев поднимал его заново,
#  и вместе с нашим запуском получалось два, потом три шелла)
# restarting nyashell: stop ALL its instances, wait until they're gone, and start exactly one.
# (the old instance used to crash on exit, the built-in crash handler brought it back,
# and together with our launch there were two, then three shells)
pat='(^|/)(qs|quickshell)( .*)? -c nyashell'
for i in 1 2 3 4 5 6 7 8 9 10; do qs -c nyashell kill >/dev/null 2>&1 || break; done
pkill -f "$pat" 2>/dev/null
for i in $(seq 40); do pgrep -f "$pat" >/dev/null || break; sleep 0.1; done
pkill -9 -f "$pat" 2>/dev/null
sleep 0.2
exec qs -c nyashell -d
