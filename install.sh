#!/usr/bin/env bash
# nyashell installer for Arch Linux, Artix and other Arch-based distros (any init system).
#
#   ./install.sh                     everything except the login screen (asks about it)
#   ./install.sh -y                  the same, no questions
#   ./install.sh --terminal          ONLY the listed parts (any number of flags: --shell --mango …)
#   ./install.sh --terminal=0        everything EXCEPT the listed parts (=0, =false, =no)
#   ./install.sh --greeter=1 --vpn=0 flags of both kinds can be mixed
#   ./install.sh --list              show the parts
#   ./install.sh --help
#
# Parts: shell mango terminal prompt files music vpn apps icons fonts greeter (see --list).
# Old flags still work: --no-dots (= --terminal=0 --prompt=0 --files=0 --fonts=0), --no-build (= --mango=0).
#
# Everything it adds is recorded in ~/.local/state/nyashell so that ./uninstall.sh can undo it, part by part:
# packages it installed, files it replaced (backed up), services it enabled.
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"
set -uo pipefail

# mango commit the patch is made for. Newer mango may refactor the code the patch touches,
# so the installer always builds exactly this one
MANGO_REPO="https://github.com/mangowm/mango"
MANGO_COMMIT="19d2c4a061077944e5a6f2bb9152567b5ad622d5"

HERE=$(cd "$(dirname "$0")" && pwd)
[ -f "$HERE/lib/common.sh" ] || { echo "missing lib/common.sh next to install.sh: run it from the unpacked repo"; exit 1; }
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"

# legacy flags → part flags
args=()
for a in "$@"; do
    case "$a" in
        --no-dots)  args+=(--terminal=0 --prompt=0 --files=0 --fonts=0) ;;
        --no-build) args+=(--mango=0) ;;
        *) args+=("$a") ;;
    esac
done
parse_components "shell mango terminal prompt files music vpn apps icons fonts" ${args[@]+"${args[@]}"}
for a in ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}; do
    case "$a" in
        -y|--yes) yes=1 ;;
        --list)   for c in $COMPONENTS; do printf '  --%-9s %s\n' "$c" "$(describe "$c")"; done; exit 0 ;;
        -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option: $a (see --help)" ;;
    esac
done
# the login screen isn't installed by default: ask, unless the flags already decided
if [ -z "$POSITIVE" ] && ! case " $NEGATIVE " in *" greeter "*) true ;; *) false ;; esac; then
    ask "Also install the nyagreet login screen (greetd)?" n && WANT="$WANT greeter"
fi
[ -n "$WANT" ] || die "nothing to install: every part is turned off by the flags (see --list)"
info "parts: $WANT"

# ─── sanity checks ───
[ "$(id -u)" -ne 0 ] || die "run it as your normal user, not root (it uses sudo where needed)"
command -v pacman >/dev/null || die "this installer is for Arch Linux and Arch-based distros (needs pacman)"
for d in shell greeter mango patch dots; do [ -e "$HERE/$d" ] || die "missing $d/ next to install.sh: run it from the unpacked repo"; done
sudo -v || die "sudo is needed to install packages"
mkdir -p "$STATE/pkgs" "$STATE/dots" "$BACKUP"
touch "$STATE/services"
# a copy of the uninstaller, so it keeps working after the repo folder is deleted
mkdir -p "$STATE/bin/lib"; cp "$HERE/uninstall.sh" "$STATE/bin/"; cp "$HERE/lib/common.sh" "$STATE/bin/lib/"

# ─── packages per part ───
# only packages that are missing get installed, and only those are written to $STATE/pkgs/<part>:
# the uninstaller removes exactly them (and the dependencies pulled in with them), nothing you had before
declare -A PKGS OPT
PKGS[mango]="base-devel git meson ninja pkgconf cmake wayland-protocols wayland libinput libxkbcommon libdrm pixman pcre2
             cjson pango libxcb xcb-util-wm xorg-xwayland hwdata seatd libdisplay-info libliftoff wlroots0.20 scenefx|scenefx0.5:scenefx"
# plasma-integration: every Qt app in the session uses the KDE platform theme (colours and accent from
# kdeglobals, written by the shell — like on KDE); xdg-desktop-portal-kde hands the accent to GTK4/Flatpak apps
PKGS[shell]="quickshell qt6-declarative qt6-svg qt6-imageformats networkmanager bluez bluez-utils upower polkit
             brightnessctl curl libnotify wl-clipboard cliphist grim slurp wf-recorder ffmpeg sox
             pipewire pipewire-pulse wireplumber libpulse playerctl python zenity
             xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-desktop-portal-kde xdg-user-dirs wlr-randr
             noto-fonts noto-fonts-emoji plasma-integration kconfig"
OPT[shell]="cava"           # the music visualizer on the desktop
PKGS[terminal]="kitty"
PKGS[prompt]="fish fastfetch zoxide"
PKGS[files]="nemo nemo-fileroller nemo-terminal nemo-python file-roller gvfs gvfs-mtp ffmpegthumbnailer adw-gtk-theme"
OPT[files]="fuse-archive"         # archives open in nemo as folders (copy / drag files out)
PKGS[music]="mpd mpc";            OPT[music]="mpd-mpris"
# scenefx used to be scenefx0.5 in the AUR, now it is plain scenefx in the repos: either one will do
# "what is needed:what to install" — any package that provides sing-box / xray counts (sing-box, sing-box-bin, …);
# if there is none, the prebuilt -bin from the AUR goes in (the source builds often fail)
PKGS[vpn]="sing-box:sing-box-bin"; OPT[vpn]="xray:xray-bin"
PKGS[apps]="firefox mpv btop"
PKGS[icons]="";                   OPT[icons]="gruvbox-plus-icon-theme-git"
PKGS[fonts]="noto-fonts-emoji"
PKGS[greeter]="greetd"
# without systemd greetd needs its init script package (greetd-openrc, greetd-runit, …)
case "$INIT" in openrc|runit|dinit|s6) PKGS[greeter]="greetd greetd-$INIT" ;; esac
# PulseAudio users keep PulseAudio (pipewire-pulse would replace it); pactl comes from libpulse either way
pacman -Qq pulseaudio >/dev/null 2>&1 && PKGS[shell]=${PKGS[shell]/pipewire-pulse/}
# power profiles: TLP or power-profiles-daemon — keep whichever you have, add ppd only if there is neither
pacman -Qq tlp >/dev/null 2>&1 || pacman -Qq power-profiles-daemon >/dev/null 2>&1 || PKGS[shell]="${PKGS[shell]} power-profiles-daemon"

record() { local f="$STATE/pkgs/$1" p; shift; touch "$f"; for p in "$@"; do grep -qxF "$p" "$f" || echo "$p" >> "$f"; done; }
# a package is there if pacman knows something that provides it (pacman -T resolves "provides", -Q doesn't:
# with sing-box-bin installed, "pacman -Q sing-box" says no — and pacman then offered to replace it)
# "a|b:pkg" — counts as installed if anything provides a OR b; otherwise pkg is installed
have() {
    local c
    for c in $(printf '%s' "${1%%:*}" | tr '|' ' '); do
        pacman -T "$c" >/dev/null 2>&1 || pacman -Qqg "$c" >/dev/null 2>&1 && return 0
    done
    return 1
}
missing() { for p in "$@"; do have "$p" || echo "${p#*:}"; done; }
in_repo() { pacman -Si "$1" >/dev/null 2>&1 || pacman -Sg "$1" >/dev/null 2>&1; }

AUR=""
aur_helper() {
    [ -n "$AUR" ] && return 0
    for h in paru yay; do command -v $h >/dev/null && { AUR=$h; return 0; }; done
    info "no AUR helper found: installing yay-bin"
    local t; t=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$t/yay-bin" && (cd "$t/yay-bin" && makepkg -si --noconfirm) \
        || { rm -rf "$t"; return 1; }
    rm -rf "$t"; record aur-helper yay-bin; AUR=yay
}

# the AUR itself is sometimes down or blocked ("EOF", "TLS connect error"): then the same PKGBUILD comes from the
# official AUR mirror on GitHub (github.com/archlinux/aur, one branch per package) and is built with makepkg
aur_mirror() {
    local t r=1
    pacman -Qq "$1" >/dev/null 2>&1 && return 0
    warn "the AUR didn't answer, taking $1 from the AUR mirror on GitHub"
    t=$(mktemp -d) || return 1
    if git clone -q --depth 1 -b "$1" https://github.com/archlinux/aur.git "$t/$1" 2>/dev/null && [ -f "$t/$1/PKGBUILD" ]; then
        (cd "$t/$1" && makepkg -si --needed --noconfirm) && r=0
    fi
    rm -rf "$t"; return $r
}

# install_pkgs <part> <required> packages… — repo packages with pacman, the rest from the AUR
install_pkgs() {
    local part=$1 required=$2; shift 2
    local need repo=() aur=() p
    need=$(missing "$@")
    [ -n "$need" ] || return 0
    for p in $need; do if in_repo "$p"; then repo+=("$p"); else aur+=("$p"); fi; done
    if [ ${#repo[@]} -gt 0 ]; then
        info "pacman ($part): ${repo[*]}"
        sudo pacman -S --needed --noconfirm "${repo[@]}" || { [ "$required" = 1 ] && die "pacman failed"; warn "some packages failed"; }
    fi
    if [ ${#aur[@]} -gt 0 ]; then
        aur_helper || { [ "$required" = 1 ] && die "couldn't get an AUR helper for: ${aur[*]}"; warn "skipped AUR: ${aur[*]}"; aur=(); }
        for p in ${aur[@]+"${aur[@]}"}; do
            info "AUR ($part): $p"
            $AUR -S --needed --noconfirm "$p" || aur_mirror "$p" || { [ "$required" = 1 ] && die "couldn't build $p from the AUR"; warn "skipped $p"; }
        done
    fi
    # record what actually got installed
    for p in $need; do pacman -Qq "$p" >/dev/null 2>&1 && record "$part" "$p"; done
}

info "refreshing package databases"
sudo pacman -Sy --noconfirm >/dev/null || warn "pacman -Sy failed, using the current databases"
# Artix: службы живут в отдельных пакетах «имя-init» (networkmanager-openrc, bluez-runit, …) — ставим их,
# если такие есть в репозиториях, иначе NetworkManager и bluetooth просто нечем включить
# Artix: services live in separate "name-init" packages (networkmanager-openrc, bluez-runit, …); we install them
# when the repos have them, otherwise there's nothing to enable NetworkManager and bluetooth with
case "$INIT" in openrc|runit|dinit|s6)
    for p in networkmanager bluez power-profiles-daemon; do
        in_repo "$p-$INIT" && PKGS[shell]="${PKGS[shell]} $p-$INIT"
    done ;;
esac
for c in $WANT; do
    # shellcheck disable=SC2086
    [ -n "${PKGS[$c]:-}" ] && install_pkgs "$c" 1 ${PKGS[$c]}
    # shellcheck disable=SC2086
    [ -n "${OPT[$c]:-}" ] && install_pkgs "$c" 0 ${OPT[$c]}
done
ok "packages ready"

for p in mangowm mangowm-git mangowc mangowc-git; do
    pacman -Qq "$p" >/dev/null 2>&1 && want mango && warn "the $p package is installed: the patched build goes to /usr/local and takes priority in PATH"
done
{ want shell || want greeter; } && ! want mango && ! command -v mango >/dev/null && \
    warn "mango isn't installed and the mango part is off: the shell and the login screen need it"

# ─── backups: the first time we replace one of your files, a copy goes to $BACKUP ───
backup() {   # backup <file> <name-in-backup>
    local f=$1 b="$BACKUP/$2"
    mkdir -p "$(dirname "$b")"
    [ -e "$f" ] || { [ -e "$b" ] || [ -e "$b.none" ] || : > "$b.none"; return; }   # .none: it didn't exist before
    [ -e "$b" ] || [ -e "$b.none" ] || cp -a "$f" "$b"
}
# put_dots <part> <dir…>: copy dots/<dir> into ~/.config/<dir>, backing up what was there
put_dots() {
    local part=$1 d f t; shift
    for d in "$@"; do
        [ -d "$HERE/dots/$d" ] || continue
        while read -r f; do
            f=${f#./}; t="$HOME/.config/$d/$f"
            backup "$t" "dots/$d/$f"
            mkdir -p "$(dirname "$t")"; cp "$HERE/dots/$d/$f" "$t"
            grep -qxF "$d/$f" "$STATE/dots/$part" 2>/dev/null || echo "$d/$f" >> "$STATE/dots/$part"
        done < <(cd "$HERE/dots/$d" && find . -type f)
    done
}
svc_user() {   # svc_user <part> <unit>: enable a user service and remember it, if it wasn't enabled before
    [ "$INIT" = systemd ] || return 0
    systemctl --user cat "$2" >/dev/null 2>&1 || return 0
    systemctl --user is-enabled "$2" >/dev/null 2>&1 && return 0
    systemctl --user enable --now "$2" >/dev/null 2>&1 && echo "$1:user:$2" >> "$STATE/services"
}

# ─── patched mango ───
if want mango; then
    info "building mango $MANGO_COMMIT with the nyashell patch"
    mkdir -p "$(dirname "$SRC")"
    [ -d "$SRC/.git" ] || git clone "$MANGO_REPO" "$SRC" || die "couldn't clone $MANGO_REPO"
    # an earlier "sudo ninja install" can leave root-owned files in build/
    [ -n "$(find "$SRC" ! -user "$(id -un)" -print -quit 2>/dev/null)" ] && sudo chown -R "$(id -u):$(id -g)" "$SRC"
    (
        cd "$SRC" || exit 1
        git fetch --quiet origin 2>/dev/null || warn "git fetch failed, trying the local copy"
        git checkout --quiet --force "$MANGO_COMMIT" || die "commit $MANGO_COMMIT not found"
        git reset --quiet --hard && git clean -qfd -e build
        git apply "$HERE/patch/nyashell-mango.diff" || die "the patch doesn't apply to $MANGO_COMMIT"
        if [ -d build ]; then meson setup --reconfigure build --prefix=/usr/local --buildtype=release >/dev/null
        else meson setup build --prefix=/usr/local --buildtype=release >/dev/null; fi || die "meson setup failed"
        ninja -C build || die "build failed (see above)"
        # remove the files of a previous build first, so nothing stale stays in /usr/local
        [ -f "$STATE/mango-files" ] && xargs -r -d '\n' sudo rm -f < "$STATE/mango-files"
        sudo ninja -C build install >/dev/null || die "ninja install failed"
        grep -v '^#' build/meson-logs/install-log.txt > "$STATE/mango-files"
        sudo chown -R "$(id -u):$(id -g)" "$SRC"
    ) || exit 1
    echo "$MANGO_COMMIT" > "$STATE/mango-commit"
    ok "mango installed: /usr/local/bin/mango"
fi

# ─── keyboard layouts: take the system ones, add "us" in front of non-Latin layouts ───
detect_layouts() {
    local l="" f k
    # systemd: localectl
    command -v localectl >/dev/null 2>&1 && l=$(localectl status 2>/dev/null | sed -n 's/.*X11 Layout: *//p' | tr -d ' ')
    # Xorg keyboard config (localectl writes it too; on Artix it's set by hand)
    [ -n "$l" ] || for f in /etc/X11/xorg.conf.d/*.conf; do
        [ -f "$f" ] || continue
        l=$(sed -n 's/^[[:space:]]*Option[[:space:]]*"XkbLayout"[[:space:]]*"\([^"]*\)".*/\1/p' "$f" | head -1 | tr -d ' ')
        [ -n "$l" ] && break
    done
    # console keymap: /etc/vconsole.conf (systemd and Artix) or /etc/conf.d/keymaps (openrc)
    if [ -z "$l" ]; then
        k=$(sed -n 's/^KEYMAP=//p' /etc/vconsole.conf 2>/dev/null | tr -d '"' | head -1)
        [ -n "$k" ] || k=$(sed -n 's/^keymap=//p' /etc/conf.d/keymaps 2>/dev/null | tr -d '"' | head -1)
        k=${k%%-*}; k=${k%%_*}
        case "$k" in ruwin*|ru*) l=ru ;; uk) l=gb ;; dvorak|"") l=us ;; *) l=$k ;; esac
    fi
    echo "${l:-us}"
}
layouts=$(detect_layouts)
# reinstall / update: keep the layouts already set in your mango config (or chosen in the shell)
oldlay=$(sed -n 's/^xkb_rules_layout=//p' "$HOME/.config/mango/config.conf" 2>/dev/null | head -1)
oldopt=$(sed -n 's/^xkb_rules_options=//p' "$HOME/.config/mango/config.conf" 2>/dev/null | head -1)
[ -f "$STATE/installed" ] && [ -n "$oldlay" ] && layouts=$oldlay
case ",$layouts," in
    *,us,*) ;;
    *) first=${layouts%%,*}
       case "$first" in ru|ua|by|bg|gr|il|ara|ir|kz|mk|mn|rs|am|ge|th|kg|tj) layouts="us,$layouts" ;; esac ;;
esac

# ─── the shell ───
if want shell; then
    info "installing the shell to $SHELL_DIR"
    # your own data stays: settings, favourites, pins, wallpaper, colours, saved layouts
    KEEP="settings.json favorites.json usage.json pinned.json layouts.json session.json palette.json accent.txt wallpaper.txt particles.txt"
    if [ -d "$SHELL_DIR" ] && [ ! -f "$STATE/shell" ]; then
        # someone else's config under the same name — keep a full copy
        [ -e "$BACKUP/nyashell-dir" ] || cp -a "$SHELL_DIR" "$BACKUP/nyashell-dir"
    fi
    mkdir -p "$SHELL_DIR"
    for f in "$SHELL_DIR"/* "$SHELL_DIR"/.[!.]*; do
        [ -e "$f" ] || continue
        case " $KEEP " in *" $(basename "$f") "*) ;; *) rm -rf "$f" ;; esac
    done
    cp -r "$HERE/shell/." "$SHELL_DIR/"
    rm -rf "$SHELL_DIR/fonts"
    mkdir -p "$FONT_DIR"
    cp "$HERE"/shell/fonts/*.ttf "$FONT_DIR/" 2>/dev/null
    cp "$HERE"/shell/fonts/LICENSE* "$HERE"/shell/fonts/OFL* "$FONT_DIR/" 2>/dev/null
    fc-cache -f >/dev/null 2>&1
    # first install: start with your keyboard layouts
    if [ ! -f "$SHELL_DIR/settings.json" ]; then
        printf '{\n  "kbLayouts": [%s]\n}\n' "$(echo "$layouts" | sed 's/[^,][^,]*/"&"/g; s/,/, /g')" > "$SHELL_DIR/settings.json"
    fi
    # the shell writes its colour scheme into kdeglobals: keep a copy of yours
    backup "$HOME/.config/kdeglobals" kdeglobals
    # portals (file dialogs, accent for GTK4/Flatpak) and screen sharing
    put_dots shell xdg-desktop-portal xdg-desktop-portal-wlr
    # mango config
    mkdir -p "$HOME/.config/mango"
    backup "$HOME/.config/mango/config.conf" mango-config.conf
    cp "$HERE/mango/config.conf" "$HOME/.config/mango/config.conf"
    sed -i "s/^xkb_rules_layout=.*/xkb_rules_layout=$layouts/" "$HOME/.config/mango/config.conf"
    [ -f "$STATE/installed" ] && [ -n "$oldopt" ] && sed -i "s/^xkb_rules_options=.*/xkb_rules_options=$oldopt/" "$HOME/.config/mango/config.conf"
    # NetworkManager and bluetooth: offer to enable them at boot with whatever init this is
    if ! pgrep -x NetworkManager >/dev/null; then
        if svc_exists NetworkManager && ask "NetworkManager isn't running (Wi-Fi in the shell needs it). Enable it at boot?" y; then
            svc_on NetworkManager || warn "couldn't enable NetworkManager, enable it by hand"
        else warn "NetworkManager isn't running: Wi-Fi in the shell needs it"; fi
    fi
    if ! pgrep -x bluetoothd >/dev/null; then
        b=bluetooth; [ "$INIT" = systemd ] || { svc_exists bluetoothd && b=bluetoothd; }
        if svc_exists "$b" && ask "the bluetooth service is off. Enable it at boot?" y; then
            svc_on "$b" || warn "couldn't enable bluetooth, enable it by hand"
        else info "the bluetooth service is off; enable it to use bluetooth in the shell"; fi
    fi
    echo shell > "$STATE/shell"
    ok "shell installed (keyboard: $layouts)"
fi

# ─── terminal, prompt, fonts ───
want terminal && { put_dots terminal kitty; ok "kitty set up"; }
want prompt && { put_dots prompt fish fastfetch; ok "fish set up (to make it your shell: chsh -s /usr/bin/fish)"; }
want fonts && { put_dots fonts fontconfig; fc-cache -f >/dev/null 2>&1; ok "Nyaspace is the system font (fontconfig)"; }

# ─── files: nemo + dark GTK ───
if want files; then
    if command -v gsettings >/dev/null; then
        if [ ! -f "$BACKUP/gsettings" ]; then
            for k in color-scheme gtk-theme font-name monospace-font-name; do
                echo "$k=$(gsettings get org.gnome.desktop.interface $k 2>/dev/null)" >> "$BACKUP/gsettings"
            done
        fi
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null
        want fonts && gsettings set org.gnome.desktop.interface font-name 'Nyaspace 10' 2>/dev/null
        want fonts && gsettings set org.gnome.desktop.interface monospace-font-name 'Nyaspace 10' 2>/dev/null
        gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty 2>/dev/null
    fi
    for v in gtk-3.0 gtk-4.0; do
        f="$HOME/.config/$v/settings.ini"; backup "$f" "$v-settings.ini"; mkdir -p "$(dirname "$f")"
        [ -f "$f" ] || printf '[Settings]\n' > "$f"
        grep -q '^gtk-application-prefer-dark-theme' "$f" || echo 'gtk-application-prefer-dark-theme=1' >> "$f"
    done
    f="$HOME/.config/gtk-3.0/settings.ini"
    grep -q '^gtk-theme-name' "$f" && sed -i 's/^gtk-theme-name=.*/gtk-theme-name=adw-gtk3-dark/' "$f" || echo 'gtk-theme-name=adw-gtk3-dark' >> "$f"
    echo files > "$STATE/files"
    ok "nemo and the dark GTK theme set up"
fi
{ want shell || want files; } && command -v systemctl >/dev/null && systemctl --user restart xdg-desktop-portal-wlr xdg-desktop-portal >/dev/null 2>&1

# ─── music ───
if want music; then
    mus=$(xdg-user-dir MUSIC 2>/dev/null); mus=${mus:-$HOME/Music}
    put_dots music mpd
    sed -i "s|^music_directory .*|music_directory     \"$mus\"|" "$HOME/.config/mpd/mpd.conf" 2>/dev/null
    mkdir -p "$HOME/.local/share/mpd/playlists" "$HOME/.local/state/mpd"
    # MPD: a systemd user service where there is systemd; elsewhere the mango config starts mpd itself
    svc_user music mpd.service
    svc_user music mpd-mpris.service
    ok "MPD set up (music folder: $mus)"
fi

# ─── VPN: let sing-box create the TUN device without asking for a password ───
if want vpn; then
    sb=$(readlink -f "$(command -v sing-box 2>/dev/null)" 2>/dev/null)
    [ -n "$sb" ] && sudo setcap cap_net_admin,cap_net_bind_service,cap_net_raw+ep "$sb" && ok "sing-box can create the VPN interface"
fi

# ─── login screen ───
if want greeter; then
    info "installing nyagreet"
    G=/etc/greetd/nyagreet
    sudo mkdir -p "$G" /var/lib/nyagreet
    sudo rm -rf "${G:?}"/*
    sudo cp -r "$HERE/greeter/." "$G/"
    for f in Anim CAnim Icon KbLayout LockShape StateLayer; do sudo cp "$HERE/shell/$f.qml" "$G/"; done
    sudo sed -i "s/^xkb_rules_layout=.*/xkb_rules_layout=$layouts/" "$G/mango-greeter.conf"
    sudo chmod 755 "$G/greeter.sh" "$G/session.sh"
    sudo mkdir -p /usr/share/fonts/nyashell
    sudo cp "$HERE"/shell/fonts/*.ttf /usr/share/fonts/nyashell/ && sudo fc-cache -f >/dev/null 2>&1
    # the shell shares its colours, wallpaper and language with the login screen through this folder
    sudo chown -R greeter:"$(id -gn)" /var/lib/nyagreet && sudo chmod 2775 /var/lib/nyagreet
    sudo chmod -R a+rX "$G"
    if [ ! -f "$STATE/greetd-config" ]; then
        if [ -f /etc/greetd/config.toml ]; then sudo cp /etc/greetd/config.toml "$STATE/greetd-config"; sudo chown "$(id -u)" "$STATE/greetd-config"
        else : > "$STATE/greetd-config"; fi
    fi
    sudo tee /etc/greetd/config.toml >/dev/null <<'TOML'
[terminal]
vt = 1

[default_session]
# nyagreet runs in its own small mango session; when it closes, greetd starts the chosen session
command = "/etc/greetd/nyagreet/greeter.sh"
user = "greeter"
TOML
    echo greeter > "$STATE/greeter"
    ok "nyagreet installed (preview it: qs -p /etc/greetd/nyagreet/shell.qml)"
    cur=$(dm_current)
    if [ "$INIT" = unknown ]; then
        info "unknown init system: enable the greetd service yourself"
    elif [ "$cur" != greetd ] && ask "Switch the display manager${cur:+ ($cur)} to greetd now? (takes effect after a reboot)" n; then
        [ -f "$STATE/previous-dm" ] || echo "${cur:-}" > "$STATE/previous-dm"
        dm_switch "$cur" greetd && ok "greetd enabled ($INIT); reboot to see it" || warn "couldn't switch the display manager"
    elif [ "$cur" != greetd ]; then
        info "to switch later: disable ${cur:-your display manager} and enable the greetd service"
    fi
fi

date -Is > "$STATE/installed"
echo
ok "done (◕ᴗ◕✿)"
if want shell; then
    info "log out and pick the \"Mango\" session (or run mango from a TTY)."
    info "Super opens the app menu, Super+I the settings, Super+G switches the language."
fi
info "to remove it later: $STATE/bin/uninstall.sh (or ./uninstall.sh here)"
if want shell && pgrep -x mango >/dev/null; then
    info "mango is running right now: the new build and the session settings start with the next login; restarting the shell…"
    sh "$SHELL_DIR/restart.sh" >/dev/null 2>&1 &
fi
exit 0
