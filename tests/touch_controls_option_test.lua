-- TOUCH option: the on-screen overlay is on by default (a phone with no
-- controller has no other input), can be turned off for good, and when off is
-- both invisible and inert.  The automatic controller-hide is separate and
-- unaffected -- it comes back on the next screen touch, the option does not.
-- Self-contained: `luajit tests/touch_controls_option_test.lua`; also
-- dofile'd by tests/run_tests.lua.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local S = require("tests.harness").suite("touch controls option")
local eq = S.eq
local check = S.check

local TouchControls = require("src.core.TouchControls")

love.system = love.system or {}
local saved = { getOS = love.system.getOS }

local osName = "Android"
love.system.getOS = function() return osName end

-- mobile: the overlay exists, so the option row is worth showing
eq(TouchControls.supported(), true, "overlay is supported on Android")
TouchControls:init()
TouchControls.applyOptions({})
eq(TouchControls:visible(), true, "overlay shows by default")

-- a missing key means "on": an existing save with no touch option must not
-- silently lose its controls
TouchControls.applyOptions({ colors = "gbc" })
eq(TouchControls.enabled, true, "absent option key defaults to on")

-- turning it off hides it and keeps it hidden
TouchControls.applyOptions({ touch = false })
eq(TouchControls:visible(), false, "option off hides the overlay")
TouchControls:touchpressed("t1", 10, 10)
local anyHeld = false
for _, n in pairs(TouchControls.held or {}) do
  if n and n > 0 then anyHeld = true end
end
eq(anyHeld, false, "a tap presses nothing while the option is off")

-- an off overlay stays off across the controller-hide path, which is the
-- thing that used to bring it back on the next touch
TouchControls:noteGamepad()
TouchControls:joystickremoved()
eq(TouchControls:visible(), false, "option off survives controller hide/show")

-- and back on when asked.  Clear the controller-hide flag the way the next
-- screen touch would, so this asserts the option rather than that flag (a
-- joystickremoved with no joystick module cannot confirm the count and
-- deliberately leaves the overlay hidden).
TouchControls.controllerHidden = false
eq(TouchControls:setEnabled(true), true, "setEnabled reports the new state")
eq(TouchControls:visible(), true, "option on shows the overlay again")

-- desktop: no overlay, so no row (OptionsMenu filters on this)
osName = "Linux"
check(os.getenv("POKEPORT_TOUCH") ~= "1",
  "POKEPORT_TOUCH must be unset for the desktop case to be meaningful")
eq(TouchControls.supported(), false, "no overlay on desktop")
TouchControls:init()
eq(TouchControls:visible(), false, "desktop never shows the overlay")

-- restore for suites sharing the module / stub
osName = "Android"
love.system.getOS = saved.getOS
TouchControls.enabled = true
TouchControls:init()

S.finish()
