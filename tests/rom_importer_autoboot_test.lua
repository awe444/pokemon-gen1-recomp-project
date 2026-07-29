-- Android autoboot: an imported cart left in the save directory is what tells
-- the next launch to skip the launcher and boot that game.  First run (no
-- ROM) and a deleted ROM must both fall back to the launcher.
-- Self-contained: `luajit tests/rom_importer_autoboot_test.lua`; also
-- dofile'd by tests/run_tests.lua.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local S = require("tests.harness").suite("rom importer autoboot")
local eq = S.eq
local check = S.check

local GameVersion = require("src.core.GameVersion")
local RomImporter = require("src.import.RomImporter")

local MiB = 1024 * 1024
local redData = string.rep("R", MiB)
local blueData = string.rep("B", MiB)

love.data = love.data or {}
love.system = love.system or {}
-- the love stub is shared with every later suite in run_tests.lua;
-- restore whatever this file overrides
local saved = {
  hash = love.data.hash,
  encode = love.data.encode,
  getOS = love.system.getOS,
}
-- Map the fake 1 MiB blobs onto the real Red/Blue SHA-1 ids without needing a
-- crypto library in the headless stub (same trick as the android pick suite).
love.data.hash = function(_, data)
  return { tag = data:sub(1, 1) }
end
love.data.encode = function(_, _, digest)
  if type(digest) == "table" and digest.tag == "R" then
    return GameVersion.info("red").sha1
  end
  if type(digest) == "table" and digest.tag == "B" then
    return GameVersion.info("blue").sha1
  end
  return "0000000000000000000000000000000000000000"
end

local osName = "Android"
love.system.getOS = function() return osName end

local function clearRoms()
  for _, name in ipairs(love.filesystem.getDirectoryItems("")) do
    if name:lower():match("%.gb$") then love.filesystem.remove(name) end
  end
end

-- 1. First run: nothing to boot, so the launcher must come up.
clearRoms()
eq(RomImporter.autobootVersion(), nil, "no ROM in the save dir -> launcher")

-- 2. Provisioned: the retained SAF pick decides the game, routed by SHA-1.
love.filesystem.write("picked_rom.gb", blueData)
local version, name = RomImporter.autobootVersion()
eq(version, "blue", "picked_rom.gb holding a Blue cart autoboots Blue")
eq(name, "picked_rom.gb", "reports the file it routed from")

-- 3. Routing is by content, not by the filename or a remembered setting.
love.filesystem.write("picked_rom.gb", redData)
eq(RomImporter.autobootVersion(), "red", "a Red cart in the same file boots Red")

-- 4. Deleting the ROM is the way back to the launcher.
love.filesystem.remove("picked_rom.gb")
eq(RomImporter.autobootVersion(), nil, "deleted ROM -> launcher again")

-- 5. A USB-copied cart (any .gb basename) provisions the device too.
love.filesystem.write("pokemon_blue.gb", blueData)
version, name = RomImporter.autobootVersion()
eq(version, "blue", "a USB-copied .gb also autoboots")
eq(name, "pokemon_blue.gb", "reports the USB copy it routed from")

-- 6. The SAF basename outranks a leftover USB copy, so the last real pick wins.
love.filesystem.write("picked_rom.gb", redData)
version, name = RomImporter.autobootVersion()
eq(version, "red", "picked_rom.gb wins over another .gb present")
eq(name, "picked_rom.gb", "preferred the SAF basename")
love.filesystem.remove("pokemon_blue.gb")

-- 7. Junk never autoboots: a short file, and a cart-sized blob we do not know.
love.filesystem.write("picked_rom.gb", "not a rom")
eq(RomImporter.autobootVersion(), nil, "undersized file is ignored")
love.filesystem.write("picked_rom.gb", string.rep("X", MiB))
eq(RomImporter.autobootVersion(), nil, "unknown cart-sized ROM is ignored")

-- 8. Desktop keeps its launcher: same files, non-Android OS, no autoboot.
love.filesystem.write("picked_rom.gb", blueData)
osName = "Linux"
eq(RomImporter.autobootVersion(), nil, "desktop still shows the launcher")
check(os.getenv("POKEPORT_AUTOBOOT") ~= "1",
  "POKEPORT_AUTOBOOT must be unset for the desktop case to be meaningful")
osName = "Android"

-- Cleanup so other suites sharing the stub see neither leftover ROMs nor
-- this file's function stubs.
clearRoms()
love.data.hash = saved.hash
love.data.encode = saved.encode
love.system.getOS = saved.getOS

S.finish()
