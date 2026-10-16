#!/bin/sh
# процесс эквалайзера.
# eq.sh run CONF — убрать все старые копии фильтра (они оставались от прошлых запусков шелла,
#                  и выходов «nyash EQ» становилось два, три…) и запустить один новый
# eq.sh stop     — убрать все копии и, если выходом по умолчанию остался «nyash EQ», вернуть настоящий выход
# the equaliser process.
# eq.sh run CONF — remove all old copies of the filter (they were left from previous shell runs
#                  and there ended up being two, three "nyash EQ" outputs…) and start one new one
# eq.sh stop     — remove all copies and, if "nyash EQ" is still the default output, restore the real one
pat='pipewire -c .*/nyashell-eq/eq\.conf'
case "$1" in
    run)
        pkill -f "$pat" 2>/dev/null
        for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -f "$pat" >/dev/null || break; sleep 0.1; done
        exec pipewire -c "$2" ;;
    stop)
        pkill -f "$pat" 2>/dev/null
        sleep 0.5
        if wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q 'effect_input.nyash_eq'; then
            # первый «настоящий» выход из списка (не наш эквалайзер)
            # the first "real" output in the list (not our equaliser)
            id=$(wpctl status 2>/dev/null | sed -n '/Sinks:/,/Sources:/p' | grep -v 'nyash EQ' | grep -oE '[0-9]+\.' | head -1 | tr -d .)
            [ -n "$id" ] && wpctl set-default "$id"
        fi ;;
esac
