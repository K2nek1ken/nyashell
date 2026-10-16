#!/bin/sh
# перемешивание в плеере — режим, а не разовая кнопка:
#   on    — запомнить порядок очереди и перемешать её (текущий трек — первым; список показывает настоящий порядок)
#   off   — вернуть запомненный порядок, не прерывая музыку; добавленные за это время треки — в конце
#   ifon  — очередь заменили (папка, плейлист…): если режим включён — перемешать уже новую
# player shuffle is a mode, not a one-off button:
# on    — remember the queue order and shuffle it (current track first; the list shows the real order)
# off   — restore the remembered order without interrupting the music; tracks added meanwhile go to the end
# ifon  — the queue was replaced (folder, playlist…): if the mode is on, shuffle the new one
st="${XDG_STATE_HOME:-$HOME/.local/state}/nyashell"; mkdir -p "$st"
order="$st/mpd-order.txt"; flag="$st/mpd-shuffle-on"

shuffle_now() {
    mpc -f "%file%" playlist > "$order"
    mpc -q random off; mpc -q shuffle
    p=$(mpc -f "%position%" current); [ -n "$p" ] && [ "$p" != 1 ] && mpc -q move "$p" 1
    : > "$flag"
}

case "${1:-}" in
    on) shuffle_now ;;
    ifon) [ -e "$flag" ] && shuffle_now ;;
    off)
        rm -f "$flag"
        [ -s "$order" ] || exit 0
        # считаем перестановки локально (awk), потом выполняем их по одной — музыка не прерывается
        # compute the moves locally (awk), then run them one by one, so the music isn't interrupted
        mpc -f "%file%" playlist | awk -v saved="$order" '
            BEGIN { n = 0; while ((getline l < saved) > 0) { n++; want[n] = l } }
            { cur[NR] = $0 }
            END {
                m = NR; k = 0
                for (i = 1; i <= m; i++) { if (!(cur[i] in first)) first[cur[i]] = ""; first[cur[i]] = first[cur[i]] " " i }
                # желаемый порядок: треки в сохранённом порядке (если ещё в очереди), потом новые
                # desired order: tracks in the saved order (if still in the queue), then the new ones
                for (j = 1; j <= n; j++) {
                    f = want[j]; if (!(f in first) || first[f] == "") continue
                    split(substr(first[f], 2), ix, " "); i = ix[1]
                    sub(/^ [0-9]+/, "", first[f]); used[i] = 1; k++; ord[k] = i
                }
                for (i = 1; i <= m; i++) if (!(i in used)) { k++; ord[k] = i }
                for (i = 1; i <= m; i++) { pos[i] = i; at[i] = i }
                for (t = 1; t <= k; t++) {
                    o = ord[t]; p = pos[o]
                    if (p != t) {
                        print p, t
                        for (q = p; q > t; q--) { at[q] = at[q - 1]; pos[at[q]] = q }
                        at[t] = o; pos[o] = t
                    }
                }
            }' | while read -r a b; do mpc -q move "$a" "$b"; done
        rm -f "$order" ;;
esac
exit 0
