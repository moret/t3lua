----------------------------------
-- DALua Link Sample  PROCESS 2 --
----------------------------------

-- This sample shows how to link two daemons using dalua.link.
-- Run link1.lua first, then link2.lua.

require("dalua")

function linked(event, status)
	if status == "success" then
		print("Daemons Linked: ", alua.tostring(dalua.daemons()))
	end
end

function init()
	dalua.link("127.0.0.1", 4321)
end

dalua.debug = true
dalua.events.monitor("dalua_init", init)
dalua.events.monitor("dalua_link", linked)
dalua.init("127.0.0.1", 4322)
dalua.loop()
