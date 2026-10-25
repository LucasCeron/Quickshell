#!/usr/bin/env python3
"""Include the reviewed Quickshell config shortcuts in the user's Hyprland Lua config."""
from pathlib import Path
import os
import shutil

root = Path(__file__).resolve().parents[1]
config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
config = config_home / "hypr/hyprland.lua"
include = 'dofile("' + str(root / "config/gadgets-bindings.lua") + '")'
source = config.read_text()
if include in source:
    print("Os atalhos da config já estão instalados.")
else:
    backup = config.with_name("hyprland.lua.bak-config-gadgets")
    if not backup.exists():
        shutil.copy2(config, backup)
    config.write_text(source.rstrip() + "\n\n-- Quickshell config: tabs and wallpaper drawer\n" + include + "\n")
    print("Atalhos instalados. Backup: " + str(backup))
