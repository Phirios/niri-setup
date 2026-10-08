-- Hyprland profile migrated from hyprland.conf and minimal.conf.
-- Keep the old files as a rollback reference.

-- Prefer RX 9070 rendering; stable PCI symlinks survive DRM card renumbering.
hl.env("AQ_DRM_DEVICES", "/home/phirios/.config/hypr/gpu-rx9070:/home/phirios/.config/hypr/gpu-ryzen")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("DMS_SHELL_DIR", "/home/phirios/.local/share/dms-shell-custom")
hl.env("QT_QPA_PLATFORMTHEME", "kde")

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
hl.monitor({ output = "DP-1", mode = "2560x1440@200", position = "0x0", scale = 1 })

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start hyprland-session.target")
    hl.exec_cmd("dms run")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("kdeconnectd")
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
    hl.exec_cmd("/home/phirios/.local/bin/hypr-dms-lock --startup")
    hl.exec_cmd("swayidle -w timeout 600 '/home/phirios/.local/bin/hypr-dms-lock' timeout 900 'hyprctl dispatch dpms off' resume 'hyprctl dispatch dpms on' timeout 1800 'systemctl suspend' before-sleep '/home/phirios/.local/bin/hypr-dms-lock'")
end)

hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = { natural_scroll = false },
    },
    cursor = {
        inactive_timeout = 5,
    },
    general = {
        gaps_in = 6,
        gaps_out = 14,
        border_size = 2,
        col = {
            active_border = "rgba(8aadf4ee)",
            inactive_border = "rgba(363a4f99)",
        },
        resize_on_border = true,
        layout = "dwindle",
    },
    decoration = {
        rounding = 9,
        shadow = {
            enabled = true,
            range = 14,
            render_power = 3,
            color = "rgba(00000066)",
        },
        blur = {
            enabled = true,
            size = 5,
            passes = 2,
            new_optimizations = true,
            ignore_opacity = true,
        },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        animate_manual_resizes = true,
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("minimalOut", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("minimalInOut", { type = "bezier", points = { {0.65, 0}, {0.35, 1} } })
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "minimalOut", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "minimalInOut", style = "popin 85%" })
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "minimalOut" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "minimalOut" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "minimalOut", style = "slide" })

-- DMS reads these includes for its shortcut cheatsheet and active bindings.
require("dms.binds")
require("dms.binds-user")
require("custom.smart-resize")

-- Follow the active DMS wallpaper palette for window and group borders.
require("dms.colors")

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})
hl.window_rule({
    name = "emoji-picker-popup",
    match = { class = "^org\\.kde\\.plasma\\.emojier$" },
    float = true,
    size = "640 520",
    center = true,
})
require("dms.outputs")

-- Keep the temporary Sunshine display mode through wallpaper/theme reloads.
-- This rule configures the output only when the Mac Desktop helper creates it.
hl.monitor({ output = "MAC-DESKTOP", mode = "2560x1664@60", position = "auto", scale = 1.3333333333 })

-- Open the translator as a compact centered popup.
hl.window_rule({
    name = "translation-popup",
    match = { class = "^app\\.drey\\.Dialect$" },
    float = true,
    size = "820 460",
    center = true,
})
