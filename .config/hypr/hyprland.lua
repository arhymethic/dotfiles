-- =============================================================================
-- MY PROGRAMS
-- =============================================================================
---
---
---

local mainMod     = "SUPER"

local terminal    = "alacritty"
local fileManager = "nautilus"
-- local menu     = "hyprlauncher"


-- =============================================================================
-- MONITORS
-- =============================================================================

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
require("monitors")

-- Lid Switch Triggers
hl.bind("switch:on:Lid Switch", function()
    hl.exec_cmd("hyprctl dispatch dpms off")
end, { locked = true })

hl.bind("switch:off:Lid Switch", function()
    hl.exec_cmd("hyprctl dispatch dpms on")
end, { locked = true })


-- =============================================================================
-- AUTOSTART
-- =============================================================================

hl.on("hyprland.start", function()
    hl.exec_cmd("~/.config/hypr/scripts/reload.sh")
    hl.exec_cmd("bluetoothctl power off")
    hl.exec_cmd("~/.config/hypr/scripts/turbo-sync.sh")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
end)
hl.exec_cmd("~/.local/bin/snappy-switcher --daemon")


-- =============================================================================
-- ENVIRONMENT VARIABLES
-- =============================================================================

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
hl.env("XCURSOR_SIZE", "18")
hl.env("HYPRCURSOR_SIZE", "18")


-- =============================================================================
-- PERMISSIONS
-- =============================================================================



-- =============================================================================
-- LOOK AND FEEL (GENERAL, DECORATION, ANIMATIONS)
-- =============================================================================

-- General Appearance & Window Layout
hl.config({
    general = {
        gaps_in          = 3,
        gaps_out         = 5,
        border_size      = 1,
        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
        col = {
            -- Change active border from a gradient to solid white (or semi-transparent white)
            active_border   = "rgba(ffffffff)",    -- Pure solid white
            inactive_border = "rgba(595959aa)",    -- Muted gray
        },
        
    },
})

-- Decoration (Rounding, Opacity, Shadows, Blur)
hl.config({
    decoration = {
        rounding         = 15,
        rounding_power   = 3,
        active_opacity   = 0.95,
        inactive_opacity = 0.8,
        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },
        blur = {
            enabled = true,
            size = 10,           -- High blur radius for heavy frosting
            passes = 4,          -- 4 passes for ultra-smooth iOS feel
            vibrancy = 0.6,      -- Boosts wallpaper colors underneath
            vibrancy_darkness = 0.2,
            contrast = 1.2,      -- Enhances light/dark dynamics under the bar
            brightness = 1.15,   -- Brightens the backdrop so white glass glows

        },
    },
})

-- Enable blur on Firefox
hl.window_rule({
    name = "firefox-glass",
    match = { class = "firefox" },
    opacity = 0.96,
})

-- Enable blur on Waybar
hl.layer_rule({
    match = { namespace = "^waybar$" },
    blur = true,
    ignore_alpha = 0.1, -- Ignores fully transparent pixels (0.0 to 1.0)
})

-- Enable heavy glass blur on Rofi
hl.layer_rule({
    match = { namespace = "^rofi$" },
    blur = true,
    ignore_alpha = 0.2,
})

-- Enable heavy glass blur on Snappy Switcher
hl.layer_rule({
    match = { namespace = "^snappy-switcher$" },
    blur = true,
    ignore_alpha = 0.2,
})

-- Enable blur on Nautilus
hl.window_rule({
    name = "nautilus-glass",
    match = { class = "org.gnome.Nautilus" },
    opacity = 0.80, -- Set to 0.80 for clean glass blur
})

-- Enable Hyprland Blur on Dunst Popups
hl.layer_rule({
    match = { namespace = "^dunst$" },
    blur = true,
    ignore_alpha = 0.2,
})

-- Master Animation Toggle
hl.config({
    animations = {
        enabled = true,
    },
})

-- Animation Curves & Springs
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

-- Animation Definitions
hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })


-- =============================================================================
-- LAYOUT CONFIGURATIONS
-- =============================================================================

-- Dwindle Layout
hl.config({
    dwindle = {
        preserve_split = true,
    },
})

-- Master Layout
hl.config({
    master = {
        new_status = "master",
    },
})

-- Scrolling Layout
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})


-- =============================================================================
-- MISCELLANEOUS
-- =============================================================================

hl.config({
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = true,
    },
})


-- =============================================================================
-- INPUT & DEVICES
-- =============================================================================

hl.config({
    input = {
        kb_layout    = "us",
        kb_variant   = "",
        kb_model     = "",
        kb_options   = "altwin:prtsc_rwin",
        kb_rules     = "",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad     = {
            natural_scroll       = true,
            clickfinger_behavior = false,
            tap_to_click         = true,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


-- =============================================================================
-- KEYBINDINGS
-- =============================================================================

-- Core Application & Window Controls
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + W", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)

hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + Q", hl.dsp.layout("togglesplit"))

-- Rofi & Utility Launchers
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("~/.config/rofi/launchers/launcher.sh"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("~/.config/rofi/control_center/control_center.sh"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("~/.config/rofi/bluetooth/blt-connect.sh"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("~/.config/rofi/clipboard/clipboard.sh"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/rofi/emoji/emoji.sh"))

-- Screenshots & Media / Custom Utilities
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("grimblast copy area"))
-- hl.bind(mainMod .. " + L", hl.plugin.hyprcapture.open)

-- Focus Navigation & Resize
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
-- Resize Tiled Windows (SUPER + SHIFT + Arrow Keys)
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.resize({ x = -30, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = 30,  y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.resize({ x = 0,   y = -30, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.resize({ x = 0,   y = 30, relative = true }), { repeating = true })

-- Fullscreen
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Workspaces Navigation & Window Movement (Numeric 1-0)
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Special Workspace (Scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
-- hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Mouse Binds (Workspace Scrolling, Window Drag & Resize)
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })

-- Function Keys & Hardware Controls
-- Function Keys & Hardware Controls (with HUD Notifications)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/sys_hud.sh volume 5%+"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/sys_hud.sh volume 5%-"),   { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("~/.config/hypr/scripts/sys_hud.sh volume toggle"), { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("~/.config/hypr/scripts/sys_hud.sh mic"),           { locked = true })

hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("~/.config/hypr/scripts/sys_hud.sh brightness 5%+"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("~/.config/hypr/scripts/sys_hud.sh brightness 5%-"),   { locked = true, repeating = true })

-- Direct F-keys & Custom Keybinds
hl.bind("F4",  hl.dsp.exec_cmd("~/.config/hypr/scripts/sys_hud.sh mic"),            { locked = true })
hl.bind("F7",  hl.dsp.exec_cmd("~/.config/hypr/scripts/sys_hud.sh monique"),        { locked = true })
hl.bind("F8",  hl.dsp.exec_cmd("~/.config/hypr/scripts/sys_hud.sh wifi"),           { locked = true })
hl.bind("XF86NotificationCenter", hl.dsp.exec_cmd("~/.config/hypr/scripts/sys_hud.sh control_center"), { locked = true })
hl.bind("F10", hl.dsp.exec_cmd("~/.config/hypr/scripts/sys_hud.sh bluetooth"),      { locked = true })
hl.bind("F12", hl.dsp.exec_cmd("~/.config/hypr/scripts/sys_hud.sh power_profile"),  { locked = true })

hl.bind("XF86Tools",     hl.dsp.exec_cmd("~/.config/hypr/scripts/sys_hud.sh control_center"), { locked = true })
hl.bind("XF86Bluetooth", hl.dsp.exec_cmd("~/.config/hypr/scripts/sys_hud.sh bluetooth"), { locked = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),         { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),     { locked = true })

-- Window Switchers (Snappy-Switcher)
hl.bind("ALT + Tab",   hl.dsp.exec_cmd("~/.local/bin/snappy-switcher next --mod alt"))
hl.bind("SUPER + TAB", hl.dsp.exec_cmd("~/.local/bin/snappy-switcher next --workspace --mod super"))

-- Wallpaper Cycling
hl.bind(mainMod .. " + BracketRight", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/cycle_hyprpaper.sh next"))
hl.bind(mainMod .. " + BracketLeft",  hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/cycle_hyprpaper.sh prev"))

-- Screen Lock
hl.bind(mainMod .. " + L ", hl.dsp.exec_cmd("hyprlock"), {locked = true})

-- Show notification history / popup past notifications (SUPER + SHIFT + N)
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("dunstctl history-pop"))

-- Close all notifications (SUPER + SHIFT + SPACE)
hl.bind(mainMod .. " + SHIFT + SPACE", hl.dsp.exec_cmd("dunstctl close-all"))

-- =============================================================================
-- WINDOW & WORKSPACE RULES
-- =============================================================================

-- Smart Gaps Rules (Removes gaps when 1 window is present, but keeps borders & 15px rounded corners)
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })

-- Suppress Maximize Requests
local suppressMaximizeRule = hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

-- Fix XWayland Dragging
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Layer Rules (Disabled)
-- local overlayLayerRule = hl.layer_rule({
--     name    = "no-anim-overlay",
--     match   = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-Run Position Rule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})
