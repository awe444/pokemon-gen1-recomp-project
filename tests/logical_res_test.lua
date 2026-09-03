-- LOGICAL RES: the render scale comes from a fixed logical frame, so a window
-- that is an exact multiple of that frame renders at exactly that multiple.
-- The window sizes past 2x are larger than a test machine's display, which is
-- why the scale rule is asserted here as arithmetic rather than by opening a
-- window (a driver can only ever probe what the WM actually grants).
--   luajit tests/logical_res_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local S = require("tests.harness").suite("logical res")
local eq = S.eq

local LogicalRes = require("src.render.LogicalRes")

-- auto is the untouched default: no base, so the renderer keeps its own rule
LogicalRes.applyOptions({})
eq(LogicalRes.mode, "auto", "absent option key means auto")
eq(LogicalRes.scaleFor(640, 480), nil, "auto leaves the scale to the caller")
eq(LogicalRes.base(), nil, "auto has no logical frame")

-- an unknown / garbage value must not brick the renderer
LogicalRes.applyOptions({ logicalRes = "banana" })
eq(LogicalRes.mode, "auto", "garbage falls back to auto")

LogicalRes.applyOptions({ logicalRes = "320x240" })
local bw, bh = LogicalRes.base()
eq(bw, 320, "base width")
eq(bh, 240, "base height")

-- exact multiples render at exactly that multiple
eq(LogicalRes.scaleFor(320, 240), 1, "1x")
eq(LogicalRes.scaleFor(640, 480), 2, "2x")
eq(LogicalRes.scaleFor(960, 720), 3, "3x")
eq(LogicalRes.scaleFor(1280, 960), 4, "4x")
eq(LogicalRes.scaleFor(2560, 1920), 8, "8x")

-- the short axis decides, so a wide window does not over-scale and crop
eq(LogicalRes.scaleFor(1920, 480), 2, "wide window scales off height")
eq(LogicalRes.scaleFor(640, 1440), 2, "tall window scales off width")

-- a non-multiple floors; the world view then covers the remainder rather than
-- black-barring it, which is the engine's existing fill behavior
eq(LogicalRes.scaleFor(1024, 700), 2, "non-multiple floors to 2x")
eq(LogicalRes.scaleFor(959, 719), 2, "just under 3x is still 2x")

-- never 0: a window smaller than the frame still draws
eq(LogicalRes.scaleFor(200, 100), 1, "below the base clamps to 1x")
eq(LogicalRes.scaleFor(0, 0), nil, "a degenerate drawable defers to the caller")

-- row plumbing
eq(LogicalRes.label("auto"), "AUTO", "auto label")
eq(LogicalRes.label("320x240"), "320X240", "base label")
eq(LogicalRes.cycle("auto", 1), "320x240", "cycle forward")
eq(LogicalRes.cycle("320x240", 1), "auto", "cycle wraps")
eq(LogicalRes.cycle("auto", -1), "320x240", "cycle backward wraps")

-- The fill override (title screen / intro / BATTLE SIZE "fill") draws at a
-- FRACTIONAL scale to reach the window edge, which breaks the one promise
-- this setting makes.  Renderer:endFrame gates that override on
-- LogicalRes.active the same way it gates on the FAITHFUL RATIO cap, so the
-- flag has to answer true for a base and false for auto.
LogicalRes.applyOptions({ logicalRes = "320x240" })
eq(LogicalRes.active(), true, "a base suppresses the fractional fill")
LogicalRes.applyOptions({})
eq(LogicalRes.active(), false, "auto leaves the fill alone")

-- leave the module on the default for suites sharing it
LogicalRes.applyOptions({})

S.finish()
