#!/bin/sh
# отладка: гасим работающий шелл, запускаем новый в этом терминале и показываем ТОЛЬКО проблемы.
# полный вывод сохраняется в ~/.cache/nyashell/debug.log. Ctrl+C — выйти; шелл перезапустится как обычно
# debugging: stop the running shell, start a new one in this terminal and show ONLY problems.
# the full output is saved to ~/.cache/nyashell/debug.log. Ctrl+C to quit; the shell restarts as usual
log="$HOME/.cache/nyashell/debug.log"
mkdir -p "$(dirname "$log")"
pat='(^|/)(qs|quickshell)( .*)? -c nyashell'
for i in 1 2 3 4 5 6 7 8 9 10; do qs -c nyashell kill >/dev/null 2>&1 || break; done
pkill -f "$pat" 2>/dev/null; sleep 0.4; pkill -9 -f "$pat" 2>/dev/null
# не проблемы: служебные строки запуска и «уже занято», если где-то осталась вторая копия
# not problems: startup housekeeping lines and "already taken" if a second copy is left somewhere
noise='INFO: |Launching config|Shell ID|Saving logs|Registration will be attempted again'
echo "── nyashell debug; full log: $log; Ctrl+C to quit ──"
trap 'echo; echo "── sending the shell back to the background ──"; sh "$HOME/.config/quickshell/nyashell/restart.sh" >/dev/null 2>&1 &' INT TERM
qs -c nyashell 2>&1 | tee "$log" | grep --line-buffered -vE "$noise"
