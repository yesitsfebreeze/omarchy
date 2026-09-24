-- The main terminal: one fullscreen WezTerm on workspace 1, always running,
-- with the theme wallpaper drawn inside it. Every other window opens on
-- special:desktop, which SUPER+TAB overlays on top of the terminal.
-- Rules: the last match wins, so the main terminal's rule comes second.
o.window(".*", { workspace = "special:desktop" })
o.window("main-terminal", { workspace = "1", fullscreen = true })
-- Keep Omarchy's rule hiding the browser's screen-sharing bar (apps/browser.lua).
o.window({ title = ".*is sharing.*" }, { workspace = "special silent" })

-- Respawned when closed; the sleep stops a tight loop if WezTerm fails.
o.launch_on_start("bash -c 'while :; do wezterm start --always-new-process --class main-terminal; sleep 1; done'")

-- Was: next workspace (SUPER+SHIFT+TAB / SUPER+CTRL+TAB still move between workspaces).
hl.unbind("SUPER + TAB")
o.bind("SUPER + TAB", "Toggle desktop", hl.dsp.workspace.toggle_special("desktop"))
