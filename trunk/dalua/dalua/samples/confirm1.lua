--------------------------------------
---- DALua Confirm Request Sample ----
--------------------------------------

-- This sample shows how to multicast reliable
-- requests that are confirmed by all processes
-- before continuing the application.

-- Run confirm1.lua, then confirm2.lua.

-- Hint: this sample can be adapted to processes
-- that use dalua.app and dalua.mutex modules.

require("dalua")

function execute_request(from)
	-- request code here --
	-- now we confirm if it executed successfully or not
	dalua.send(from, "execute_request_reply", dalua.self(), true)
end

dalua.debug = true
dalua.init("127.0.0.1", 4321)
dalua.loop()
