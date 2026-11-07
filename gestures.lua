-- Optional Hyprland 0.56 Lua integration. Loading this file registers nothing.
local M = {}
local configured = false

function M.setup(options)
  assert(not configured, "Spaces gestures have already been configured")
  assert(type(hl) == "table" and type(hl.gesture) == "function" and type(hl.timer) == "function", "Spaces gestures require Hyprland Lua gesture and timer support")
  local opts = options or {}
  local fingers = opts.fingers or 3
  local opening = opts.open or "down"
  local horizontal = opts.horizontal == true
  assert(type(fingers) == "number" and fingers % 1 == 0 and fingers >= 3 and fingers <= 5, "fingers must be 3, 4, or 5")
  assert(opening == "up" or opening == "down", "open must be up or down")
  -- Hyprland offers no gesture introspection. Require the owner to specify
  -- what to restore instead of guessing and overwriting a custom binding.
  assert(not horizontal or type(opts.restore) == "function", "horizontal gestures require a restore callback")
  configured = true
  local closing = opening == "down" and "up" or "down"
  local active, deadline, cumulative = false, 0, 0
  omarchy_spaces_gesture_active = false

  local function emit(phase, event)
    hl.dispatch(hl.dsp.event(string.format("predmore.spaces:swipe,%s,%.3f,%.0f,%d",
      phase, cumulative, tonumber(event.time_ms) or 0, event.cancelled and 1 or 0)))
  end
  local function unset()
    hl.gesture({ fingers = fingers, direction = "horizontal", action = "unset" })
  end
  function omarchy_spaces_gesture(enabled)
    enabled = enabled == true and horizontal
    hl.dispatch(hl.dsp.event(horizontal and "predmore.spaces:bridge,ready" or "predmore.spaces:bridge,unavailable"))
    if enabled then deadline = os.time() + 4 end
    if active == enabled then return end
    unset()
    active = enabled
    omarchy_spaces_gesture_active = active
    if active then
      hl.gesture({ fingers = fingers, direction = "horizontal", action = {
        start = function(event) cumulative = 0; emit("start", event) end,
        update = function(event)
          local dx = event.delta and tonumber(event.delta.x) or 0
          if dx == dx and math.abs(dx) < math.huge then cumulative = math.max(-100000, math.min(100000, cumulative + dx)) end
          emit("update", event)
        end,
        finish = function(event) emit("finish", event) end,
      } })
    else
      opts.restore()
    end
  end

  local function overview(mode)
    return function()
      local command = mode == "show" and "omarchy-shell shell summon predmore.spaces '{}'" or "omarchy-shell shell hide predmore.spaces"
      hl.exec_cmd(command)
    end
  end
  hl.gesture({ fingers = fingers, direction = opening, action = overview("show") })
  hl.gesture({ fingers = fingers, direction = closing, action = overview("hide") })
  if opts.pinch ~= false then
    for _, count in ipairs({ 3, 4 }) do
      hl.gesture({ fingers = count, direction = "pinchin", action = overview("show") })
      hl.gesture({ fingers = count, direction = "pinchout", action = overview("hide") })
    end
  end
  if horizontal then
    omarchy_spaces_gesture_timer = hl.timer(function()
      if active and os.time() > deadline then omarchy_spaces_gesture(false) end
    end, { timeout = 1000, type = "repeat" })
  end
end

return M
