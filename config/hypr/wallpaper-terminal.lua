-- The wallpaper terminal (bin/wallpaper-terminal): a fullscreen kitty panel
-- between Omarchy's wallpaper and the windows. Three modes:
--   terminal  the empty `terminal` workspace; the panel has the keyboard (home)
--   windows   SUPER+TAB: your windows over the panel
--   desktop   SUPER+SHIFT+TAB: the panel hidden, windows over the plain wallpaper
-- Pressing a mode's key again goes back to terminal mode.
local bin = os.getenv("HOME") .. "/.local/share/omarchy/bin/wallpaper-terminal"
o.launch_on_start(bin .. " run")
hl.on("hyprland.start", function()
  hl.dispatch(hl.dsp.focus({ workspace = "name:terminal" }))
end)

local desktop = false

local function apply(ws_name)
  if ws_name == "terminal" then
    desktop = false
    hl.exec_cmd(bin .. " mode terminal")
  else
    hl.exec_cmd(bin .. " mode " .. (desktop and "desktop" or "windows"))
  end
end

-- However a workspace is entered (SUPER+1, a launcher), the panel follows it.
hl.on("workspace.active", function(ws)
  apply(ws.name)
end)

local function toggle(want_desktop)
  local ws = hl.get_active_workspace()
  if not ws then
    return
  end
  if ws.name == "terminal" then
    desktop = want_desktop
    hl.dispatch(hl.dsp.focus({ workspace = "previous" }))
  elseif desktop == want_desktop then
    hl.dispatch(hl.dsp.focus({ workspace = "name:terminal" }))
  else
    desktop = want_desktop
    apply(ws.name)
  end
end

-- Also reachable from scripts: hyprctl eval 'wallpaper_terminal.toggle(true)'.
wallpaper_terminal = { toggle = toggle }

-- Was: next / previous workspace (SUPER+CTRL+TAB still goes to the former one).
hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")
hl.bind("SUPER + TAB", function()
  toggle(false)
end, { description = "Windows over the terminal" })
hl.bind("SUPER + SHIFT + TAB", function()
  toggle(true)
end, { description = "Desktop (hide the terminal)" })

-- Omarchy's universal copy/paste (SUPER+C / SUPER+V) looks for a focused
-- terminal window. The panel is a layer surface, not a window, so on the empty
-- `terminal` workspace it found none and sent CTRL+C / CTRL+V, which reached
-- tmux as ^C / ^V. When no window has focus there, send kitty the keys its
-- config maps instead (CTRL+Insert / SHIFT+Insert); everywhere else behave
-- like Omarchy's default/hypr/bindings/clipboard.lua.
local function send_once(mods, key)
  hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
  hl.timer(function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
  end, { timeout = 50, type = "oneshot" })
end

local function clipboard(default_mods, default_key, terminal_mods, terminal_key)
  return function()
    local window = hl.get_active_window()
    local terminal = false
    if window then
      for _, tag in ipairs(window.tags or {}) do
        if tag:gsub("%*$", "") == "terminal" then
          terminal = true
        end
      end
    else
      local ws = hl.get_active_workspace()
      terminal = ws ~= nil and ws.name == "terminal"
    end
    if terminal then
      send_once(terminal_mods, terminal_key)
    else
      send_once(default_mods, default_key)
    end
  end
end

hl.unbind("SUPER + C")
hl.unbind("SUPER + V")
o.bind("SUPER + C", "Universal copy", clipboard("CTRL", "C", "CTRL", "Insert"))
o.bind("SUPER + V", "Universal paste", clipboard("CTRL", "V", "SHIFT", "Insert"))
