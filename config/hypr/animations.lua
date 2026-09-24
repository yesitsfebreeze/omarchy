-- Every Omarchy animation runs 250 ms (speed is in deciseconds) on one
-- ease-in-out quadratic curve. Styles and the enabled/disabled set stay
-- Omarchy's ($OMARCHY_PATH/default/hypr/looknfeel.lua); each leaf Omarchy sets
-- is restated, since a child's own setting overrides `global`.
hl.curve("easeInOutQuad", { type = "bezier", points = { { 0.45, 0 }, { 0.55, 1 } } })

local function quad(leaf, style)
  hl.animation({ leaf = leaf, enabled = true, speed = 2.5, bezier = "easeInOutQuad", style = style })
end

quad("global")
quad("border")
quad("windows")
quad("windowsIn", "popin 87%")
quad("windowsOut", "popin 87%")
quad("fadeIn")
quad("fadeOut")
quad("fade")
quad("layers")
quad("layersIn", "fade")
quad("layersOut", "fade")
quad("fadeLayersIn")
quad("fadeLayersOut")
quad("specialWorkspace", "slidevert")
