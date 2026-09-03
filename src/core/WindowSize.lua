-- --window=WxH / POKEPORT_WINDOW=WxH: the requested startup window size.
--
-- ZERO REQUIRES, like src/core/Version.lua: conf.lua loads this before the
-- game is mounted, and anything it pulled in would have to be loadable that
-- early too.
--
-- Pure parsing and validation with no love.* at all, so the engine test tier
-- covers it without opening a window -- the same reason LaunchOptions keeps
-- its resolution pure.
--
-- Only the "=" spelling is reachable from argv: LOVE's boot.lua takes the
-- first bare argument as a path to a game, so `--window 640x480` dies before
-- conf.lua ever runs.

local WindowSize = {}

-- The Game Boy screen is the floor; past 16384 is a typo, not a window, and
-- LOVE would fail to create it.
WindowSize.MIN_W, WindowSize.MIN_H = 160, 144
WindowSize.MAX = 16384

-- "640x480" -> 640, 480.  Anything else -> nil, so the caller keeps its
-- default rather than dying before there is a window to show an error on.
function WindowSize.parse(value)
  if type(value) ~= "string" then return nil end
  local w, h = value:match("^%s*(%d+)%s*[xX]%s*(%d+)%s*$")
  w, h = tonumber(w), tonumber(h)
  if not (w and h) then return nil end
  if w < WindowSize.MIN_W or h < WindowSize.MIN_H then return nil end
  if w > WindowSize.MAX or h > WindowSize.MAX then return nil end
  return w, h
end

-- The size an argv + environment pair asks for, or nil for "keep the default".
-- An explicit flag outranks the environment.
function WindowSize.request(argv, env)
  local w, h = WindowSize.parse(env)
  if type(argv) == "table" then
    for _, a in ipairs(argv) do
      if type(a) == "string" then
        local flag = a:match("^%-%-window=(.+)$")
        local fw, fh = WindowSize.parse(flag)
        if fw then w, h = fw, fh end
      end
    end
  end
  return w, h
end

return WindowSize
