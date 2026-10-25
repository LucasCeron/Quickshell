#!/usr/bin/env python3
"""Discover local wallpapers and apply them through Hyprpaper's IPC."""
import json
import os
from pathlib import Path
import subprocess
import sys

EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".avif", ".bmp"}


def scan(folder=""):
    home = Path.home()
    config = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
    roots = [Path(folder).expanduser()] if folder else [
        home / "Pictures" / "Wallpapers", home / "Pictures" / "wallpapers",
        home / "Imagens" / "Wallpapers", home / "Imagens" / "wallpapers",
        home / "Wallpapers", config / "hypr", home / ".local/share/backgrounds",
        Path("/usr/share/backgrounds"),
    ]
    if folder and not roots[0].is_dir():
        raise ValueError("Pasta não encontrada. Confira o caminho informado.")
    found = {}
    for root in roots:
        for directory, dirs, files in os.walk(root):
            dirs[:] = sorted(d for d in dirs if not d.startswith("."))
            for name in sorted(files):
                path = Path(directory) / name
                if path.suffix.lower() in EXTENSIONS and path.is_file():
                    resolved = path.resolve()
                    found[str(resolved)] = {"path": str(resolved), "url": resolved.as_uri(), "name": path.stem}
                    if len(found) >= 500:
                        return list(found.values())
    return sorted(found.values(), key=lambda item: item["name"].casefold())


def apply(path):
    image = Path(path).expanduser().resolve()
    if not image.is_file() or image.suffix.lower() not in EXTENSIONS:
        raise ValueError("A imagem não está mais disponível.")
    if any(char in str(image) for char in ",\n\r"):
        raise ValueError("Renomeie a imagem sem vírgulas ou quebras de linha.")
    monitors = subprocess.run(["hyprctl", "-j", "monitors"], capture_output=True, text=True, timeout=5, check=True)
    names = [monitor["name"] for monitor in json.loads(monitors.stdout)]
    if not names:
        raise ValueError("Nenhuma tela disponível.")
    for name in names:
        result = subprocess.run(["hyprctl", "hyprpaper", "wallpaper", f"{name},{image},cover"],
                                capture_output=True, text=True, timeout=8)
        # Hyprpaper 0.8.x can acknowledge a successful request with an empty reply.
        # Other versions return "ok"; textual error replies must still fail.
        reply = result.stdout.strip().lower()
        if result.returncode or (reply and reply != "ok"):
            raise ValueError("O Hyprpaper não aplicou a imagem. Verifique se ele está em execução.")
    return str(image)


def main():
    try:
        if sys.argv[1] == "scan":
            result = {"items": scan(sys.argv[2] if len(sys.argv) > 2 else ""), "error": ""}
        elif sys.argv[1] == "apply":
            result = {"path": apply(sys.argv[2]), "error": ""}
        else:
            raise ValueError("Operação desconhecida.")
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        result = {"error": str(error)}
    print(json.dumps(result, ensure_ascii=False))
    return 1 if result.get("error") else 0


if __name__ == "__main__":
    sys.exit(main())
