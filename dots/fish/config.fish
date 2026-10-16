# fish для nyashell: подсказки из истории (→ принять), подсветка, дополнения — встроены в fish
# fish for nyashell: history suggestions (→ to accept), highlighting and completions are built into fish
if status is-interactive
    set -g fish_greeting                      # своё приветствие ниже / our own greeting is below
    set -gx EDITOR nano
    set -gx MANPAGER "less -R --use-color -Dd+m -Du+b"

    # короткие команды: пишешь «ll» + пробел — разворачивается в полную
    # abbreviations: type "ll" + space and it expands to the full command
    abbr -a ll  'ls -lh --group-directories-first --color=auto'
    abbr -a la  'ls -lAh --group-directories-first --color=auto'
    abbr -a upd 'sudo pacman -Syu'
    abbr -a ins 'sudo pacman -S'
    abbr -a rem 'sudo pacman -Rns'
    abbr -a yu  'yay -Syu'
    abbr -a g   git
    abbr -a gs  'git status -sb'
    abbr -a gc  'git commit -m'
    abbr -a ..  'cd ..'
    abbr -a ... 'cd ../..'
    abbr -a nyashdbg 'sh ~/.config/quickshell/nyashell/debug.sh'   # шелл заново + только ошибки / restart the shell, errors only

    # ctrl+r — поиск по истории, alt+→ — принять одно слово подсказки
    # ctrl+r: history search, alt+→: accept one word of the suggestion
    bind \cr history-pager
    bind \e\[1\;3C forward-word

    # zoxide — «умный cd» (z проект), если установлен
    # zoxide: a "smart cd" (z project), if installed
    type -q zoxide; and zoxide init fish | source

    # приветствие в стиле pfetch. Терминал, восстановленный после входа (Session.qml), уже показывает свой
    # прошлый экран — второй fastfetch поверх него не нужен
    # greeting; a terminal restored after login already shows its old screen, so no second fastfetch there
    if not set -q NYASH_RESTORED
        type -q fastfetch; and fastfetch
    end
    set -e NYASH_RESTORED
end
