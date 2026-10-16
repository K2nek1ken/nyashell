#!/bin/sh
# запись экрана: record.sh full|area [none|system|mic|both] [кадров/с] [высота кадра] [битрейт, кбит/с]
# (0 в последних трёх — как есть: частота экрана, исходный размер, битрейт на усмотрение кодировщика)
# повторный вызов (любой) — остановить запись. Файл — в «Видео/Recordings», по окончании — уведомление.
# видео кодирует встроенная видеокарта (VAAPI), если она есть, — так запись почти не грузит процессор
# screen recording: record.sh full|area [none|system|mic|both] [fps] [frame height] [bitrate, kbit/s]
# (0 in the last three means as is: the screen's refresh rate, original size, bitrate up to the encoder)
# calling it again (any way) stops the recording. The file goes to Videos/Recordings, with a notification at the end.
# video is encoded by the integrated GPU (VAAPI) if there is one, so recording barely loads the CPU
if pgrep -x wf-recorder >/dev/null; then pkill -INT -x wf-recorder; exit 0; fi
[ "$1" = stop ] && exit 0
dir="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")/Recordings"
mkdir -p "$dir"
f="$dir/$(date +%Y-%m-%d_%H-%M-%S).mp4"
mode=${1:-full}; audio=${2:-system}; fps=${3:-0}; height=${4:-0}; kbps=${5:-0}
set --
if [ "$mode" = area ]; then
    acc=$(sed -n 's/.*"accent":"#\([0-9a-fA-F]\{6\}\)".*/\1/p' "$HOME/.config/quickshell/nyashell/palette.json" 2>/dev/null)
    g=$(slurp -d -b 00000055 -c "${acc:-dfbfbe}ff" -w 2) || exit 0
    set -- -g "$g"
fi
mods=""
case "$audio" in
    system) set -- "$@" "--audio=$(pactl get-default-sink 2>/dev/null).monitor" ;;
    mic)    set -- "$@" "--audio=$(pactl get-default-source 2>/dev/null)" ;;
    both)
        # звук системы и микрофон вместе: временный «смеситель» (пустой выход), в него — звук системы
        # и микрофон, запись — с него. После записи всё убирается
        # system sound and mic together: a temporary "mixer" (a null sink), system sound
        # and the mic go into it, and we record from it. Everything is removed after recording
        sink=$(pactl get-default-sink 2>/dev/null); mic=$(pactl get-default-source 2>/dev/null)
        m1=$(pactl load-module module-null-sink sink_name=nyash_rec_mix sink_properties=device.description=nyash-rec-mix)
        m2=$(pactl load-module module-loopback source="$sink.monitor" sink=nyash_rec_mix latency_msec=30)
        m3=$(pactl load-module module-loopback source="$mic" sink=nyash_rec_mix latency_msec=30)
        mods="$m3 $m2 $m1"
        set -- "$@" "--audio=nyash_rec_mix.monitor" ;;
esac
# частота кадров: постоянная, лишние кадры отбрасываются, недостающие повторяются
# frame rate: constant, extra frames are dropped, missing ones repeated
[ "$fps" -gt 0 ] 2>/dev/null && set -- "$@" -r "$fps"
# размер: уменьшаем по высоте, ширина — по пропорциям (чётная, этого требует h264)
# size: scale down by height, width follows the proportions (even, h264 requires it)
[ "$height" -gt 0 ] 2>/dev/null && set -- "$@" -F "scale=-2:$height"
# битрейт — общий параметр кодировщика «b» (работает и для VAAPI, и для x264)
# bitrate is the encoder's generic "b" option (works for both VAAPI and x264)
codec_b=""
[ "$kbps" -gt 0 ] 2>/dev/null && codec_b="b=${kbps}k"
cleanup() { for m in $mods; do pactl unload-module "$m" 2>/dev/null; done; }
trap cleanup EXIT
if [ -e /dev/dri/renderD128 ]; then
    # если видеокарта не справилась (например, с масштабом) — запасной путь через процессор
    # if the GPU couldn't cope (e.g. with scaling): a fallback through the CPU
    wf-recorder "$@" -c h264_vaapi -d /dev/dri/renderD128 ${codec_b:+-p "$codec_b"} -f "$f" 2>/dev/null || \
        { [ -s "$f" ] || wf-recorder "$@" -c libx264 -p preset=veryfast ${codec_b:+-p "$codec_b"} -f "$f"; }
else
    wf-recorder "$@" -c libx264 -p preset=veryfast ${codec_b:+-p "$codec_b"} -f "$f"
fi
[ -s "$f" ] || { notify-send -a "Recording" "Recording failed" "wf-recorder could not start"; exit 1; }
act=$(notify-send -a "Recording" -A open="Open" -A folder="Folder" -A delete="Delete" "Recording saved" "$(basename "$f")")
case "$act" in
    open) xdg-open "$f" ;;
    folder) nemo "$dir" ;;
    delete) rm -f "$f" ;;
esac
