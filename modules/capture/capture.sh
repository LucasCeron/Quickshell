#!/usr/bin/env bash
# Screenshots and screen recordings for the capture pill.
#
#   capture.sh shot <screen|window|area> <output> <both|copy|save> <delay> <cursor:0|1>
#   capture.sh rec  <screen|area>        <output> <none|system|mic> <delay>
#
# A recording prints "recording" once it starts and stops cleanly on SIGINT.
# Exits non-zero when the selection is cancelled.
set -u

# Quickshell hands us a pipe that never closes; slurp would wait on it for boxes.
exec </dev/null

kind=$1 target=$2 output=$3
stamp=$(date '+%Y-%m-%d às %H.%M.%S')

target_dir() {
    local base
    base=$(xdg-user-dir "$1" 2>/dev/null)
    [ -n "$base" ] && [ "$base" != "$HOME" ] || base=$HOME/$2
    printf '%s/%s' "$base" "$3"
}

# In the background: without a notification daemon notify-send blocks until it times out.
notify() {
    (notify-send -a Quickshell "$@" >/dev/null 2>&1 &)
}

# Windows on the workspaces currently shown, as slurp boxes.
window_boxes() {
    local workspaces
    workspaces=$(hyprctl -j monitors | jq -c '[.[].activeWorkspace.id]')
    hyprctl -j clients | jq -r --argjson ws "$workspaces" '
        .[] | select(.mapped and (.hidden | not) and (.workspace.id as $id | $ws | index($id)))
            | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"'
}

# Let the pill fade out before anything reads the screen.
sleep 0.25

geometry=""
case $target in
    area)   geometry=$(slurp -d) || exit 1 ;;
    window) geometry=$(window_boxes | slurp -r) || exit 1 ;;
esac

if [ -n "$geometry" ]; then
    region=(-g "$geometry")
else
    region=(-o "$output")
fi

case $kind in
shot)
    destination=$4 delay=$5 cursor=$6
    sleep "$delay"

    args=("${region[@]}")
    [ "$cursor" = 1 ] && args+=(-c)

    tmp=$(mktemp --suffix=.png)
    if ! grim "${args[@]}" "$tmp"; then
        rm -f "$tmp"
        notify -u critical "Captura de tela" "Falha ao capturar a tela."
        exit 1
    fi

    [ "$destination" != save ] && wl-copy -t image/png < "$tmp"

    if [ "$destination" = copy ]; then
        rm -f "$tmp"
        notify "Captura de tela" "Copiada para a área de transferência."
    else
        dir=$(target_dir PICTURES Pictures "Capturas de tela")
        mkdir -p "$dir"
        file="$dir/Captura de tela $stamp.png"
        mv "$tmp" "$file"
        chmod 644 "$file"
        body="Salva em $dir"
        [ "$destination" = both ] && body="Copiada e salva em $dir"
        notify -i "$file" "Captura de tela" "$body"
    fi
    ;;

rec)
    audio=$4 delay=$5

    if ! command -v wf-recorder >/dev/null; then
        notify -u critical "Gravação de tela" "wf-recorder não está instalado."
        exit 1
    fi

    sleep "$delay"

    args=("${region[@]}")
    case $audio in
        system) args+=("--audio=$(pactl get-default-sink).monitor") ;;
        mic)    args+=("--audio=$(pactl get-default-source)") ;;
    esac

    dir=$(target_dir VIDEOS Videos "Gravações de tela")
    mkdir -p "$dir"
    file="$dir/Gravação de tela $stamp.mp4"

    wf-recorder -y "${args[@]}" -f "$file" &
    pid=$!
    trap 'kill -INT "$pid" 2>/dev/null' INT TERM
    echo recording

    # The first wait returns early when the trap fires; the second one lets
    # wf-recorder finish writing the file.
    wait "$pid"
    wait "$pid"

    if [ -s "$file" ]; then
        wl-copy -t text/uri-list "file://$file"
        notify "Gravação de tela" "Salva em $dir"
    else
        rm -f "$file"
        notify -u critical "Gravação de tela" "A gravação falhou."
        exit 1
    fi
    ;;
esac
