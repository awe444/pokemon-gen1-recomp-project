-- --window=WxH / POKEPORT_WINDOW=WxH parsing (src/core/WindowSize.lua).
-- Pure resolution, so this covers it without opening a window -- which is the
-- point: the sizes worth testing (1280x960) are larger than a CI display.
--   luajit tests/engine/window_size_flag.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local S = require("tests.harness").suite("window size flag")
local eq = S.eq

local WindowSize = require("src.core.WindowSize")

local function pair(w, h) return ("%sx%s"):format(tostring(w), tostring(h)) end

-- accepted spellings
eq(pair(WindowSize.parse("640x480")), "640x480", "plain WxH")
eq(pair(WindowSize.parse("1280X960")), "1280x960", "capital X")
eq(pair(WindowSize.parse("  960x720 ")), "960x720", "surrounding space")
eq(pair(WindowSize.parse("320x240")), "320x240", "the logical frame itself")

-- rejected: keep the default rather than failing before there is a window
eq(WindowSize.parse("notasize"), nil, "garbage")
eq(WindowSize.parse("640"), nil, "width only")
eq(WindowSize.parse("640x"), nil, "missing height")
eq(WindowSize.parse("-640x480"), nil, "negative")
eq(WindowSize.parse("640*480"), nil, "wrong separator")
eq(WindowSize.parse(""), nil, "empty string")
eq(WindowSize.parse(nil), nil, "nil")
eq(WindowSize.parse(640), nil, "non-string")
eq(WindowSize.parse("100x100"), nil, "below the Game Boy screen")
eq(WindowSize.parse("99999x99999"), nil, "absurd size LOVE could not open")

-- argv + environment resolution
eq(pair(WindowSize.request({ "--window=640x480" }, nil)), "640x480", "flag alone")
eq(pair(WindowSize.request({}, "800x600")), "800x600", "env alone")
eq(pair(WindowSize.request({ "--window=640x480" }, "800x600")), "640x480",
  "an explicit flag outranks the environment")
eq(WindowSize.request({}, nil), nil, "nothing asked for keeps the default")
eq(WindowSize.request({ "--window=bogus" }, nil), nil, "a bad flag keeps the default")
-- a bad flag must not shadow a good environment value
eq(pair(WindowSize.request({ "--window=bogus" }, "800x600")), "800x600",
  "a bad flag falls through to the environment")
-- unrelated argv (--game=blue, the love path) must not confuse it
eq(pair(WindowSize.request({ ".", "--game=blue", "--window=960x720" }, nil)),
  "960x720", "picks the flag out of a real argv")
eq(WindowSize.request({ ".", "--game=blue" }, nil), nil, "no window flag present")
-- last one wins, like every other repeated flag
eq(pair(WindowSize.request({ "--window=640x480", "--window=1280x960" }, nil)),
  "1280x960", "the last flag wins")

S.finish()
