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

MyPort = arg[1] or 4322

function join(app)
	dalua.app.join("App")
end

function leave(app)
	-- broadcast message to all members of 'App' before leaving
	print("Leaving...")
	dalua.send(dalua.app.processes("App"), "print", "Goodbye, "..dalua.self().." is leaving!")
	dalua.app.leave("App")
end

function onJoin(event, status, app, id)
	if status == "error" then -- on error, 'id' is the error message
			print("Failed to join application '"..app.."': "..id)
	elseif id == dalua.self() then -- on success, 'id' is the process id
		print("Joined application "..app)
		-- we're going to leave the application in 2 seconds
		dalua.timer.add(dalua.self(), 2, 1, "leave", app)
	else -- someone else joined the application
		dalua.send(id, "print", "Hello from "..dalua.self().."!")
	end
end

function onLeave(event, status, app, id)
	if id == dalua.self() then
		-- I'll be back!
		dalua.timer.add(dalua.self(), 3, 1, "join", app)
	end
end

function linked()
	function applinked()
		dalua.events.ignore("dalua_app_link", applinked)
		print("Application Network is linked!")
		-- we can only join an application created on another daemon
		-- after linking the daemons and calling dalua.app.link
		join("App")
	end
	print"linked"
	dalua.events.ignore("dalua_link", linked)
	dalua.events.monitor("dalua_app_link", applinked)
	dalua.app.link("127.0.0.1", 4321)
end

function appinit()
   dalua.events.monitor("dalua_link", linked)
   dalua.link("127.0.0.1", 4321)
end

function init()
	dalua.app.init()
end

dalua.debug = true
dalua.app.debug = true
dalua.events.monitor("dalua_init", init)
dalua.events.monitor("dalua_app_init", appinit)
dalua.events.monitor("dalua_app_join", onJoin)
dalua.events.monitor("dalua_app_leave", onLeave)
dalua.init("127.0.0.1", MyPort)
dalua.loop()

