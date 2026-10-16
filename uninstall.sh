#!/usr/bin/env bash
# nyashell uninstaller: undoes what install.sh did, using its records in ~/.local/state/nyashell.
#
#   ./uninstall.sh                   everything; asks before removing packages
#   ./uninstall.sh -y                no questions: removes packages too, keeps VPN profiles and wallpapers
#   ./uninstall.sh --terminal        ONLY the listed parts (any number of flags)
#   ./uninstall.sh --vpn=0           everything EXCEPT the listed parts (=0, =false, =no)
#   ./uninstall.sh --purge           also delete VPN profiles, EQ presets, wallpapers, added fonts and caches
#   ./uninstall.sh --keep-packages   leave every installed package in place
#   ./uninstall.sh --list | --help
#
# Parts are the same as in install.sh. Packages: only the ones install.sh installed for those parts are removed
# (pacman -Rns, so the dependencies that came with them go too). A package something else still needs stays.
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
[ -f "$HERE/lib/common.sh" ] || { echo "missing lib/common.sh next to uninstall.sh"; exit 1; }
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"

purge=0; keep_pkgs=0
parse_components "$COMPONENTS" "$@"
for a in ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}; do
    case "$a" in
        -y|--yes)         yes=1 ;;
        --purge)          purge=1 ;;
        --keep-packages)  keep_pkgs=1 ;;
        --list)           for c in $COMPONENTS; do printf '  --%-9s %s\n' "$c" "$(describe "$c")"; done; exit 0 ;;
        -h|--help)        sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option: $a (see --help)" ;;
    esac
done
[ -n "$WANT" ] || die "nothing to remove: every part is turned off by the flags (see --list)"
all=0; [ "$WANT" = "$COMPONENTS" ] && all=1

[ "$(id -u)" -ne 0 ] || die "run it as your normal user, not root"
[ -d "$STATE" ] || warn "no install records in $STATE: removing only what can be found"
ask "Remove nyashell parts: $WANT?" y || exit 0
sudo -v || die "sudo is needed"

# records of an older installer (one list for everything) — count them as the shell part
mkdir -p "$STATE/pkgs" "$STATE/dots"
[ -f "$STATE/packages" ] && { cat "$STATE/packages" >> "$STATE/pkgs/shell"; rm -f "$STATE/packages"; }
[ -f "$STATE/dots.list" ] && { cat "$STATE/dots.list" >> "$STATE/dots/terminal"; rm -f "$STATE/dots.list"; }
[ -f "$STATE/services" ] && sed -i 's/^user:/music:user:/' "$STATE/services"

# restore <name-in-backup> <target>: put your old file back, or delete ours if there was none
restore() {
    local b="$BACKUP/$1" t=$2
    if [ -e "$b" ]; then mkdir -p "$(dirname "$t")"; rm -rf "$t"; cp -a "$b" "$t"; return 0; fi
    [ -e "$b.none" ] && rm -rf "$t"
    return 0
}
# take_dots <part>: restore every file the part put into ~/.config, drop folders that only held ours
take_dots() {
    local l="$STATE/dots/$1" f d
    [ -f "$l" ] || return 0
    while read -r f; do [ -n "$f" ] && restore "dots/$f" "$HOME/.config/$f"; done < "$l"
    for d in $(cut -d/ -f1 "$l" | sort -u); do
        [ -d "$HOME/.config/$d" ] && find "$HOME/.config/$d" -depth -type d -empty -delete 2>/dev/null
    done
    rm -f "$l"
}

# ─── stop the shell ───
if want shell; then
    pkill -f 'qs -c nyashell' 2>/dev/null && info "shell stopped"
    pkill -f 'quickshell -c nyashell' 2>/dev/null
    pkill -f 'nyashell/eq.sh' 2>/dev/null
fi

# ─── login screen ───
if want greeter && { [ -f "$STATE/greeter" ] || [ -d /etc/greetd/nyagreet ]; }; then
    info "removing nyagreet"
    if [ -f "$STATE/previous-dm" ] && [ "$(dm_current)" = greetd ]; then
        prev=$(cat "$STATE/previous-dm")
        [ -n "$prev" ] && dm_switch greetd "$prev" && ok "display manager switched back to $prev (after a reboot)"
    fi
    if [ -f "$STATE/greetd-config" ]; then
        if [ -s "$STATE/greetd-config" ]; then sudo cp "$STATE/greetd-config" /etc/greetd/config.toml
        else sudo rm -f /etc/greetd/config.toml; fi
    fi
    sudo rm -rf /etc/greetd/nyagreet /var/lib/nyagreet /usr/share/fonts/nyashell
    sudo fc-cache -f >/dev/null 2>&1
    if [ "$(dm_current)" = greetd ]; then
        if grep -q nyagreet /etc/greetd/config.toml 2>/dev/null || [ ! -f /etc/greetd/config.toml ]; then
            # nothing to fall back to: greetd's own text login keeps the machine usable
            printf '[terminal]\nvt = 1\n\n[default_session]\ncommand = "agreety --cmd /bin/sh"\nuser = "greeter"\n' \
                | sudo tee /etc/greetd/config.toml >/dev/null
        fi
        warn "greetd is still your display manager (with its text login): switch it to another one in your init system"
    fi
    rm -f "$STATE/greeter" "$STATE/greetd-config" "$STATE/previous-dm"
fi

# ─── patched mango ───
if want mango; then
    if [ -f "$STATE/mango-files" ]; then
        info "removing mango from /usr/local"
        xargs -r -d '\n' sudo rm -f < "$STATE/mango-files"
        # empty directories it created (only under /usr/local)
        sed 's|/[^/]*$||' "$STATE/mango-files" | sort -ru | while read -r d; do
            case "$d" in /usr/local/?*) sudo rmdir -p --ignore-fail-on-non-empty "$d" 2>/dev/null ;; esac
        done
    elif [ -d "$SRC/build" ]; then
        sudo ninja -C "$SRC/build" uninstall >/dev/null 2>&1
    fi
    rm -rf "$SRC"; rmdir "$(dirname "$SRC")" 2>/dev/null
    rm -f "$STATE/mango-files" "$STATE/mango-commit"
fi

# ─── shell ───
if want shell; then
    if [ "$purge" = 0 ] && [ -f "$SHELL_DIR/settings.json" ] && ask "Keep a copy of your shell settings in ~/nyashell-settings-backup?" n; then
        mkdir -p "$HOME/nyashell-settings-backup"
        for f in settings.json favorites.json usage.json pinned.json layouts.json session.json palette.json accent.txt wallpaper.txt particles.txt; do
            [ -f "$SHELL_DIR/$f" ] && cp "$SHELL_DIR/$f" "$HOME/nyashell-settings-backup/"
        done
    fi
    rm -rf "$SHELL_DIR"
    [ -e "$BACKUP/nyashell-dir" ] && cp -a "$BACKUP/nyashell-dir" "$SHELL_DIR" && info "your previous ~/.config/quickshell/nyashell is back"
    rmdir "$HOME/.config/quickshell" 2>/dev/null
    rm -rf "$FONT_DIR"; fc-cache -f >/dev/null 2>&1
    restore mango-config.conf "$HOME/.config/mango/config.conf"; rmdir "$HOME/.config/mango" 2>/dev/null
    restore kdeglobals "$HOME/.config/kdeglobals"
    take_dots shell
    # things the shell wrote into other programs' configs
    rm -f "$HOME/.config/kitty/nyash-theme.conf" "$HOME/.config/fish/conf.d/nyash-colors.fish"
    grep -l '^X-Nyashell=1' "${XDG_DATA_HOME:-$HOME/.local/share}"/applications/*.desktop 2>/dev/null | while read -r f; do rm -f "$f"; done
    # nemo actions and "archive as folder" (the templates in ~/Templates are your files now, they stay)
    rm -f "${XDG_DATA_HOME:-$HOME/.local/share}"/nemo/actions/nyash-*.nemo_action "${XDG_DATA_HOME:-$HOME/.local/share}/applications/nyash-archive.desktop"
    grep -q '^X-Nyashell-Nemo=1' "${XDG_DATA_HOME:-$HOME/.local/share}/applications/nemo.desktop" 2>/dev/null && rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/nemo.desktop"
    # расширение памяти Немо и то, что оно запомнило / Nemo's memory extension and what it remembered
    rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/nemo-python/extensions/nyash-memory.py" "${XDG_STATE_HOME:-$HOME/.local/state}/nyashell/nemo-tabs.json"
    sed -i '/nyash-archive\.desktop/d' "${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list" 2>/dev/null
    rm -f "${XDG_STATE_HOME:-$HOME/.local/state}"/nyashell/templates-1 "${XDG_STATE_HOME:-$HOME/.local/state}"/nyashell/archives-1
    for v in gtk-3.0 gtk-4.0; do
        d="$HOME/.config/$v"
        rm -f "$d/nyash-accent.css"
        [ -f "$d/gtk.css" ] && sed -i '/nyash-accent\.css/d' "$d/gtk.css" && [ ! -s "$d/gtk.css" ] && rm -f "$d/gtk.css"
    done
    for p in "$HOME"/.mozilla/firefox/*/ "$HOME"/.config/mozilla/firefox/*/; do
        [ -d "$p/chrome" ] || continue
        rm -f "$p/chrome/nyashell.css"
        [ -f "$p/chrome/userChrome.css" ] && sed -i '/nyashell\.css/d' "$p/chrome/userChrome.css"
    done
    for s in "$HOME/.local/share/Steam/steamui/skins" "$HOME/.steam/steam/steamui/skins" "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamui/skins"; do
        [ -d "$s" ] || continue
        find "$s" -name nyash.css -delete 2>/dev/null
        grep -rl 'nyash-start' "$s" 2>/dev/null | while read -r f; do sed -i '/\/\* nyash-start \*\//,/\/\* nyash-end \*\//d' "$f"; done
    done
    for c in "$HOME/.config/DeltaChat" "$HOME/.var/app/chat.delta.desktop/config/DeltaChat"; do
        rm -f "$c/custom-themes/nyashell.css"
        [ -f "$c/config.json" ] && sed -i 's/"activeTheme": *"custom:nyashell"/"activeTheme": "system"/' "$c/config.json"
    done
    for f in /etc/systemd/logind.conf.d/50-nyash-lid.conf /etc/elogind/logind.conf.d/50-nyash-lid.conf; do
        [ -f "$f" ] && sudo rm -f "$f" && { sudo systemctl kill -s HUP systemd-logind 2>/dev/null || sudo pkill -HUP -x elogind-daemon 2>/dev/null; }
    done
    rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d/60-nyashell-emoji.conf"
    rm -f "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/nyash* 2>/dev/null
    rm -rf "$HOME/.cache/nyashell"
    # your data
    DATA="$HOME/.config/nyashell-vpn $HOME/.config/nyashell-eq ${XDG_DATA_HOME:-$HOME/.local/share}/nyashell ${XDG_DATA_HOME:-$HOME/.local/share}/fonts/nyashell-user"
    if [ "$purge" = 1 ] || { [ "$yes" = 0 ] && ask "Also delete VPN profiles, EQ presets, the wallpaper library and fonts you added?" n; }; then
        for d in $DATA; do rm -rf "$d"; done
        ok "data deleted"
    else
        for d in $DATA; do [ -e "$d" ] && info "kept: $d"; done
    fi
    rm -f "$STATE/shell"
    ok "shell removed"
fi

# ─── the other parts: their configs ───
want terminal && take_dots terminal
want prompt && take_dots prompt
want fonts && { take_dots fonts; fc-cache -f >/dev/null 2>&1; }
want music && take_dots music
if want files && [ -f "$STATE/files" ]; then
    restore gtk-3.0-settings.ini "$HOME/.config/gtk-3.0/settings.ini"
    restore gtk-4.0-settings.ini "$HOME/.config/gtk-4.0/settings.ini"
    if [ -f "$BACKUP/gsettings" ] && command -v gsettings >/dev/null; then
        while IFS='=' read -r k v; do
            [ -n "$v" ] && gsettings set org.gnome.desktop.interface "$k" "$v" 2>/dev/null
        done < "$BACKUP/gsettings"
    fi
    for d in gtk-3.0 gtk-4.0; do [ -d "$HOME/.config/$d" ] && find "$HOME/.config/$d" -depth -type d -empty -delete 2>/dev/null; done
    rm -f "$STATE/files"
fi
{ want shell || want files; } && command -v systemctl >/dev/null && systemctl --user restart xdg-desktop-portal >/dev/null 2>&1
rmdir "$HOME/.local/share/fonts" "$HOME/.local/share/mpd/playlists" "$HOME/.local/share/mpd" "$HOME/.local/state/mpd" 2>/dev/null

# ─── services the installer enabled for these parts ───
if [ -f "$STATE/services" ]; then
    : > "$STATE/services.left"
    while IFS=: read -r part kind unit; do
        [ -n "$part" ] || continue
        if want "$part"; then
            [ "$kind" = user ] && command -v systemctl >/dev/null && systemctl --user disable --now "$unit" >/dev/null 2>&1
        else echo "$part:$kind:$unit" >> "$STATE/services.left"; fi
    done < "$STATE/services"
    mv "$STATE/services.left" "$STATE/services"
fi

# ─── packages of these parts ───
if [ "$keep_pkgs" = 0 ]; then
    pk=()
    for c in $WANT; do
        [ -f "$STATE/pkgs/$c" ] || continue
        # still installed, in reverse install order
        while read -r p; do pacman -Qq "$p" >/dev/null 2>&1 && pk+=("$p"); done < <(tac "$STATE/pkgs/$c")
    done
    # the AUR helper we installed goes only together with everything else
    [ "$all" = 1 ] && [ -f "$STATE/pkgs/aur-helper" ] && while read -r p; do pacman -Qq "$p" >/dev/null 2>&1 && pk+=("$p"); done < "$STATE/pkgs/aur-helper"
    # greetd still being the display manager would leave you without a login screen after a reboot
    if [ ${#pk[@]} -gt 0 ] && [ "$(dm_current)" = greetd ]; then
        mapfile -t pk < <(printf '%s\n' "${pk[@]}" | grep -vx 'greetd\|greetd-openrc\|greetd-runit\|greetd-dinit\|greetd-s6')
        warn "keeping greetd: it is still your display manager"
    fi
    if [ ${#pk[@]} -gt 0 ] && [ -n "${pk[0]}" ]; then
        echo; info "packages installed by nyashell for these parts: ${pk[*]}"
        if ask "Remove them together with the dependencies only they needed?" y; then
            if ! sudo pacman -Rns --noconfirm "${pk[@]}" 2>/dev/null; then
                # something outside this list depends on part of it: remove one by one, skip the needed ones
                left=()
                for p in "${pk[@]}"; do
                    pacman -Qq "$p" >/dev/null 2>&1 || continue
                    sudo pacman -Rns --noconfirm "$p" >/dev/null 2>&1 || left+=("$p")
                done
                # a second pass: some became removable once their dependants were gone
                kept=()
                for p in ${left[@]+"${left[@]}"}; do sudo pacman -Rns --noconfirm "$p" >/dev/null 2>&1 || kept+=("$p"); done
                [ ${#kept[@]} -gt 0 ] && warn "kept (other packages need them): ${kept[*]}"
            fi
            for c in $WANT; do rm -f "$STATE/pkgs/$c"; done
            [ "$all" = 1 ] && rm -f "$STATE/pkgs/aur-helper"
            ok "packages removed"
        fi
    fi
fi
# orphans that were already on the system — only reported
orph=$(pacman -Qdtq 2>/dev/null)
[ -n "$orph" ] && info "other orphaned packages on the system (not touched): $(echo $orph)"

echo
if [ "$all" = 1 ]; then
    rm -rf "$STATE"
    ok "nyashell is gone. Bye ₍ᐢ‥ᐢ₎ ♡"
    pgrep -x mango >/dev/null && warn "you are still in a mango session: log out to finish"
else
    ok "removed: $WANT"
fi
exit 0
