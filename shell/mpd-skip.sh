#!/bin/sh
# переключение трека с плавным переходом: громкость mpd плавно вниз → next/prev → плавно вверх.
# (сам MPD делает кроссфейд только когда трек доигрывает до конца; на ручное переключение — этот скрипт)
# mpd-skip.sh next|prev|play N
# track change with a smooth transition: mpd volume fades down → next/prev → fades up.
# (MPD itself only crossfades when a track plays to the end; manual skipping uses this script)
# mpd-skip.sh next|prev|play N
v=$(mpc volume 2>/dev/null | sed -n 's/.*volume: *\([0-9]*\)%.*/\1/p')
playing=$(mpc status 2>/dev/null | grep -c '^\[playing\]')
if [ -z "$v" ] || [ "$playing" = 0 ]; then
    [ "$1" = play ] && exec mpc -q play "$2"; exec mpc -q "$1"
fi
for k in 85 70 55 40 25 10; do mpc -q volume $((v * k / 100)); sleep 0.035; done
if [ "$1" = play ]; then mpc -q play "$2"; else mpc -q "$1"; fi
for k in 10 25 40 55 70 85 100; do mpc -q volume $((v * k / 100)); sleep 0.035; done
