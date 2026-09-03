-- Logical resolution: pick the render scale from a FIXED logical frame
-- instead of from the Game Boy's 160x144 screen.
--
-- The default (auto) derives the scale from the UI size, so a window is
-- "however many whole 160x144 screens fit".  That makes the scale jump on an
-- axis the player is not thinking about: a 640x480 window fits 4 screens
-- across but only 3 down, so it renders at 3x -- and 640/3 is not a whole
-- number of world pixels, so the expanded world view lands at 214x160 rather
-- than the half of 640x480 the window actually is.
--
-- With a base set, the scale is `floor(min(pw/BASE_W, ph/BASE_H))`: a window
-- that is an exact multiple of the base renders at exactly that multiple.
-- 640x480 -> 2x, 960x720 -> 3x, 1280x960 -> 4x, and the world view is the
-- base size every time.  The whole picture -- world, UI, title screen,
-- battles -- shares that one scale, because every consumer of the scale reads
-- Renderer:fitScale (Renderer:uiScale returns it unchanged for the centered
-- layout, and worldViewSize divides the drawable by it).
--
-- The UI is still 160x144 and still centered by endFrame's letterbox origin,
-- so it sits in the middle of the larger frame with the extra area showing
-- more world -- the expanded frame the base implies.
--
-- A window that is NOT an exact multiple keeps the engine's fill behavior:
-- the scale floors and the world view grows to cover the remainder rather
-- than black-barring it, so nothing breaks on a hand-dragged window.
--
-- Persisted as save.options.logicalRes; "auto" is the untouched default, so
-- an install that never sets it renders exactly as it always did.

local LogicalRes = {}

LogicalRes.DEFAULT = "auto"
-- Order is the OPTIONS row's cycle order.
LogicalRes.MODES = { "auto", "320x240" }

-- Live mode, set by applyOptions (boot + the OPTIONS row) and read by
-- Renderer:fitScale every frame.
LogicalRes.mode = LogicalRes.DEFAULT

local BASES = {
  ["320x240"] = { 320, 240 },
}

function LogicalRes.normalize(v)
  return BASES[v] and v or LogicalRes.DEFAULT
end

function LogicalRes.label(v)
  v = LogicalRes.normalize(v or LogicalRes.mode)
  return v == "auto" and "AUTO" or v:upper()
end

function LogicalRes.cycle(v, dir)
  v = LogicalRes.normalize(v)
  local i = 1
  for idx, m in ipairs(LogicalRes.MODES) do
    if m == v then i = idx; break end
  end
  local n = #LogicalRes.MODES
  i = ((i - 1 + (dir and dir < 0 and -1 or 1)) % n) + 1
  return LogicalRes.MODES[i]
end

-- The logical frame in world pixels, or nil for auto (scale from the UI size).
function LogicalRes.base()
  local b = BASES[LogicalRes.mode]
  if not b then return nil end
  return b[1], b[2]
end

-- Integer scale for a drawable of pw x ph, or nil when auto leaves the
-- choice to the caller.  Never returns 0: a window smaller than the base
-- still draws, at 1x, with the view covering what it can.
function LogicalRes.scaleFor(pw, ph)
  local bw, bh = LogicalRes.base()
  if not bw then return nil end
  if not (pw and ph) or pw <= 0 or ph <= 0 then return nil end
  return math.max(1, math.floor(math.min(pw / bw, ph / bh)))
end

-- Whether a fixed logical frame is in force.  Callers that must not draw at a
-- fractional scale (endFrame's fill override) gate on this the same way they
-- gate on the FAITHFUL RATIO cap.
function LogicalRes.active()
  return LogicalRes.base() ~= nil
end

function LogicalRes.applyOptions(opts)
  LogicalRes.mode = LogicalRes.normalize(opts and opts.logicalRes)
  return LogicalRes.mode
end

return LogicalRes
