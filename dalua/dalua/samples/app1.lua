----------------
-- App Sample --
----------------

-- This sample creates a group of processes (application).
-- The processes join and leave the application periodically,
-- and also broadcast messages to the group.

-- Run app1.lua first, then run app2.lua
-- You may run multiple instances of app2.lua on different
-- daemons for testing larger groups of processes, just pass
-- the port number as an argument when launching from terminal:
-- > lua app2.lua 4322

require("dalua")

function appinit()
	local function created(event, status, app, err)
		if status == "error" then
			print("Error while creating application '"..app.."': "..err)
		else
			print("Application '"..app.."' created!")
		end
	end
	print("appinit")
	dalua.events.monitor("dalua_app_create", created)
	dalua.app.create("App")
end

function onJoin(event, status, app, id)
	print("Process "..id.." is joining the application...")
	dalua.send(id, "print", "Hello from "..dalua.self().."!")
end

function init()
	dalua.app.init()
end

dalua.debug = true
dalua.app.debug = true
dalua.events.monitor("dalua_init", init)
dalua.events.monitor("dalua_app_init", appinit)
dalua.events.monitor("dalua_app_join", onJoin)
dalua.init("127.0.0.1", 4321)
dalua.loop()

