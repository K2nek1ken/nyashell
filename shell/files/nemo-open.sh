#!/bin/sh
# Немо с памятью: если окон Немо сейчас нет и папку не передали — открыть окна и вкладки, как были в прошлый раз.
# Что было открыто, запоминает расширение files/nemo-ext/nyash-memory.py (нужен пакет nemo-python).
# Nemo with memory: if no Nemo window is open and no folder was given, reopen the windows and tabs as they were.
# What was open is remembered by the files/nemo-ext/nyash-memory.py extension (needs the nemo-python package).
# запуск / usage: nemo-open.sh [папки или URI… / folders or URIs…]
state="${XDG_STATE_HOME:-$HOME/.local/state}/nyashell/nemo-tabs.json"
if [ $# -eq 0 ] && [ -s "$state" ] && command -v python3 >/dev/null &&
   ! mmsg get all-clients 2>/dev/null | grep -qi '"appid" *: *"nemo"'; then
    # по окну на каждое сохранённое окно, вкладки — по порядку; несуществующие папки пропускаем
    # one window per saved window, tabs in order; folders that no longer exist are skipped
    if python3 - "$state" <<'PY'
import json, os, subprocess, sys, time
from urllib.parse import urlparse, unquote
try:
    wins = json.load(open(sys.argv[1])).get("windows", [])
except Exception:
    wins = []
opened = 0
for w in wins:
    tabs = []
    for u in w.get("tabs", []):
        p = urlparse(u)
        if p.scheme == "file" and not os.path.isdir(unquote(p.path)):
            continue
        tabs.append(u)
    if not tabs:
        continue
    subprocess.Popen(["nemo", "--tabs"] + tabs if len(tabs) > 1 else ["nemo"] + tabs)
    opened += 1
    time.sleep(0.4)      # следующее окно — уже в запущенный Немо / the next window goes to the running Nemo
sys.exit(0 if opened else 1)
PY
    then exit 0; fi
fi
exec nemo "$@"
