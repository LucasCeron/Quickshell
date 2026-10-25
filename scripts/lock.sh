#!/usr/bin/env bash
set -euo pipefail

if ! command -v hyprlock >/dev/null 2>&1; then
    notify-send -a Quickshell -u critical "Bloqueio de tela indisponível" \
        "Instale o Hyprlock com: sudo pacman -S --needed hyprlock"
    exit 1
fi

# Repeated shortcuts must not start competing session lockers.
if pgrep -x hyprlock >/dev/null; then
    exit 0
fi

config_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
exec hyprlock --config "$config_dir/config/hyprlock.conf"
