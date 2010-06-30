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

local processes = { "1@127.0.0.1:4321", "2@127.0.0.1:4321" }
local pendingRequests

function main()
	-- First we save the number of processes that
	-- are target of this broadcast, including self
	pendingRequests = #processes
	-- then we broadcast the request and wait for all replies
	dalua.send(processes, "execute_request", dalua.self())
end

function execute_request(from)
	-- request code here --
	-- now we confirm if it executed successfully or not
	dalua.send(from, "execute_request_reply", dalua.self(), true)
end


function execute_request_reply(from, result)
	if result == true then
		print("Process "..from.." executed request successfully!")
	else
		print("Process "..from.." failed to execute request!")
	end
	pendingRequests = pendingRequests - 1
	if pendingRequests == 0 then
		print("All processes received the request!")
		-- continue application logic from this point --
	end
end

dalua.debug = true
dalua.events.monitor("dalua_init", main)
dalua.init("127.0.0.1", 4321)
dalua.loop()

