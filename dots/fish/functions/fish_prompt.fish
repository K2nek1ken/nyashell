# ┃21:45┃02.10.2026┃@neko-desktop ~/папка  ветка ❯   — цвета палитры (conf.d/nyash-colors.fish)
# ┃21:45┃02.10.2026┃@neko-desktop ~/folder  branch ❯   — palette colours (conf.d/nyash-colors.fish)
function fish_prompt
    set -l last $status
    set -l acc (set -q nyash_accent; and echo $nyash_accent; or echo magenta)
    set -l acc2 (set -q nyash_accent2; and echo $nyash_accent2; or echo yellow)
    set -l dim brblack

    # ┃время┃дата┃@машина
    # ┃time┃date┃@host
    set_color $acc;  echo -n '┃'
    set_color normal; echo -n (date +%H:%M)
    set_color $acc;  echo -n '┃'
    set_color $dim;  echo -n (date +%d.%m.%Y)
    set_color $acc;  echo -n '┃'
    set_color $acc2; echo -n '@'(prompt_hostname)' '
    set_color --bold normal; echo -n (prompt_pwd --full-length-dirs 2)
    set_color normal

    # ветка git, если мы в репозитории
    # git branch, if we're in a repository
    set -l branch (command git branch --show-current 2>/dev/null)
    if test -n "$branch"
        set_color $acc2; echo -n "  $branch"
        command git diff --quiet --ignore-submodules HEAD 2>/dev/null; or echo -n '*'
    end

    # стрелка краснеет, если прошлая команда упала
    # the arrow turns red if the last command failed
    if test $last -ne 0
        set_color red; echo -n " [$last] ❯ "
    else
        set_color $acc; echo -n ' ❯ '
    end
    set_color normal
end
