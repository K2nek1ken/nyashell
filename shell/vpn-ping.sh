#!/bin/sh
# пинг серверов: vpn-ping.sh CONFIG URL_ENC TAG...
# TAG «nN» — настоящий запрос через узел N (временный sing-box на порту 9091, API /proxies/nN/delay);
# TAG «xray|N|config|port» — узел через Xray: временный xray с socks на port, настоящий запрос через него;
# TAG «tcp|N|host|port» — если Xray не установлен: время TCP-соединения с сервером.
# вывод: «N задержка_мс» (-1 — недоступен), по строке на узел.
# на каждый узел — не больше 5000 мс: не ответил за это время — недоступен
# server ping: vpn-ping.sh CONFIG URL_ENC TAG...
# TAG "nN"                — a real request through node N (temporary sing-box on port 9091, API /proxies/nN/delay);
# TAG "xray|N|config|port" — a node via Xray: a temporary xray with socks on port, a real request through it;
# TAG "tcp|N|host|port"    — if Xray isn't installed: the TCP connect time to the server.
# output: "N latency_ms" (-1 = unreachable), one line per node.
# at most 5000 ms per node: no answer in that time means unreachable
cfg=$1; url=$2; plain=$3; shift 3
need_box=0; for t in "$@"; do case "$t" in tcp\|*|xray\|*) ;; *) need_box=1 ;; esac; done
if [ "$need_box" = 1 ]; then
    sing-box run -c "$cfg" >/dev/null 2>&1 & pid=$!
    trap 'kill $pid 2>/dev/null' EXIT INT TERM
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do curl -s -o /dev/null http://127.0.0.1:9091/ && break; sleep 0.2; done
fi
one() {
    case "$1" in
        xray\|*)
            n=$(printf %s "$1" | cut -d'|' -f2); c=$(printf %s "$1" | cut -d'|' -f3); p=$(printf %s "$1" | cut -d'|' -f4)
            xray run -c "$c" >/dev/null 2>&1 & xp=$!
            sleep 0.6
            s=$(curl -s -o /dev/null -m 4.4 -x "socks5h://127.0.0.1:$p" -w '%{time_starttransfer}' "$plain" 2>/dev/null)
            kill $xp 2>/dev/null
            ms=$(awk -v s="${s:-0}" 'BEGIN{ if (s+0 > 0) printf "%d", s*1000; else print -1 }')
            echo "$n $ms" ;;
        tcp\|*)
            n=$(printf %s "$1" | cut -d'|' -f2); h=$(printf %s "$1" | cut -d'|' -f3); p=$(printf %s "$1" | cut -d'|' -f4)
            s=$(curl -s -o /dev/null -m 5 -w '%{time_connect}' "telnet://$h:$p" </dev/null 2>/dev/null)
            ms=$(awk -v s="${s:-0}" 'BEGIN{ if (s+0 > 0) printf "%d", s*1000; else print -1 }')
            echo "$n $ms" ;;
        *)
            # sing-box сам прекращает попытку через 4.5 с; curl страхует на 5 с
            # sing-box gives up by itself after 4.5 s; curl backs it up at 5 s
            r=$(curl -s -m 5 "http://127.0.0.1:9091/proxies/$1/delay?timeout=4500&url=$url")
            d=$(printf %s "$r" | sed -n 's/.*"delay":\([0-9][0-9]*\).*/\1/p')
            echo "${1#n} ${d:--1}" ;;
    esac
}
# по 8 узлов разом. Ждём только СВОИ проверки: простое «wait» ждало ещё и временный sing-box,
# который сам не завершается, — из-за этого проверка пинга висела бесконечно
# 8 nodes at a time. We wait only for OUR checks: a plain "wait" also waited for the temporary sing-box,
# which never exits by itself, so the ping check hung forever
jobs_=""; k=0
for t in "$@"; do
    one "$t" & jobs_="$jobs_ $!"
    k=$((k + 1))
    if [ $((k % 8)) = 0 ]; then for j in $jobs_; do wait "$j"; done; jobs_=""; fi
done
for j in $jobs_; do wait "$j"; done
