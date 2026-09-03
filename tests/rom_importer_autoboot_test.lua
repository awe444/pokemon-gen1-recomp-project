-- ANDROID AUTOBOOT: a provisioned phone boots the game it holds instead of
-- showing the launcher, and every way back to the launcher still works.
--
-- The marker is cache readiness, not a file in the save directory: upstream's
-- importer deletes the consumed cart, so the ROM cannot be the signal the way
-- it was before the merge.
--   luajit tests/rom_importer_autoboot_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local S = require("tests.harness").suite("rom importer autoboot")
local eq = S.eq

local RomImporter = require("src.import.RomImporter")

love.system = love.system or {}
local savedOS = love.system.getOS
local osName = "Android"
love.system.getOS = function() return osName end

-- stub readiness rather than build six real caches; autobootVersion's whole
-- job is the decision on top of it
local realIsReady = RomImporter.isReady
local ready = {}
RomImporter.isReady = function(v) return ready[v] == true end

local function only(...)
  ready = {}
  for _, v in ipairs({ ... }) do ready[v] = true end
end

-- first run: nothing imported, so the launcher has to come up
only()
eq(RomImporter.autobootVersion(), nil, "no cart means the launcher")

-- provisioned with one cart: nothing to ask about
only("blue")
eq(RomImporter.autobootVersion(), "blue", "the one imported cart boots")
only("red")
eq(RomImporter.autobootVersion(), "red", "routes by what is actually ready")

-- clearing that game's data is the way back to the launcher
only()
eq(RomImporter.autobootVersion(), nil, "clearing the cache returns to launcher")

-- two carts IS a question, so the player answers it
only("red", "blue")
eq(RomImporter.autobootVersion(), nil, "several carts show the launcher")

-- ...unless the device is pinned to one
eq(RomImporter.autobootVersion({ autoboot = "blue" }), "blue", "a pin wins")
eq(RomImporter.autobootVersion({ autoboot = "red" }), "red", "pin routes")
-- a pin for a game that is not imported must not boot into nothing
only("blue")
eq(RomImporter.autobootVersion({ autoboot = "yellow" }), nil,
  "a pin for an unimported game falls back to the launcher")
-- an explicit "auto" is the same as no pin
eq(RomImporter.autobootVersion({ autoboot = "auto" }), "blue", "auto means auto")
eq(RomImporter.autobootVersion({ autoboot = "" }), "blue", "empty pin means auto")
eq(RomImporter.autobootVersion({}), "blue", "absent key means auto")

-- desktop keeps its launcher: the ROM columns and Play button are the point
osName = "Linux"
eq(os.getenv("POKEPORT_AUTOBOOT"), nil,
  "POKEPORT_AUTOBOOT must be unset for the desktop case to mean anything")
eq(RomImporter.autobootVersion(), nil, "desktop never autoboots")
osName = "iOS"
eq(RomImporter.autobootVersion(), nil, "iOS keeps the launcher too")

osName = "Android"
RomImporter.isReady = realIsReady
love.system.getOS = savedOS

S.finish()
