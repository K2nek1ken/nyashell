#!/bin/sh
# звук скретча: scratch.sh 1|2|3 (медленно/средне/быстро). Это звуковой эффект, а не сам трек:
# MPD не умеет играть трек «рукой» с переменной скоростью. Сэмплы делаются один раз через sox
# scratch sound: scratch.sh 1|2|3 (slow/medium/fast). It's a sound effect, not the track itself:
# MPD can't play a track "by hand" at a variable speed. The samples are made once with sox
d="$HOME/.cache/nyashell/scratch"; f="$d/s$1.wav"
if [ ! -s "$f" ]; then
    command -v sox >/dev/null || exit 0
    mkdir -p "$d"
    sox -n -r 48000 -c 2 "$d/s1.wav" synth 0.11 pinknoise band 520 380 tremolo 22 85 fade t 0.004 0.11 0.04 gain -4 2>/dev/null
    sox -n -r 48000 -c 2 "$d/s2.wav" synth 0.09 pinknoise band 1100 700 tremolo 34 85 fade t 0.004 0.09 0.035 gain -5 2>/dev/null
    sox -n -r 48000 -c 2 "$d/s3.wav" synth 0.07 pinknoise band 2200 1300 tremolo 48 85 fade t 0.003 0.07 0.03 gain -6 2>/dev/null
fi
[ -s "$f" ] && exec pw-play --volume 0.7 "$f"
