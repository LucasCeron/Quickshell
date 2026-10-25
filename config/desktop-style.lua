-- Quickshell config: shared palette, soft geometry and restrained movement.
local configHome = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local colors = dofile(configHome .. "/palette/generated/palette.lua")

hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 14,
        border_size = 1,
        resize_on_border = true,
        col = {
            active_border = { colors = { colors.primaryBorder, colors.hoverBorder }, angle = 45 },
            inactive_border = colors.inactiveBorder,
        },
    },
    decoration = {
        rounding = 16,
        shadow = { enabled = true, range = 18, render_power = 3, color = 0x55000000 },
        blur = { enabled = true, size = 6, passes = 3, vibrancy = 0.12 },
    },
})

hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.2, bezier = "easeOutQuint", style = "popin 95%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.2, bezier = "quick", style = "popin 97%" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.2, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 3.2, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 3.2, bezier = "easeOutQuint", style = "slide" })

-- Quickshell handles its own entrance animations; avoid a second compositor fade.
hl.layer_rule({ name = "config-surfaces", match = { namespace = "^(config-.*|quickshell)$" },
    blur = true, ignore_alpha = 0.05, no_anim = true })
-- The launcher is see-through without frosted glass: no blur behind it.
hl.layer_rule({ name = "config-launcher", match = { namespace = "^rofi$" },
    blur = false })
hl.env("XCURSOR_THEME", "Breeze_Light")
