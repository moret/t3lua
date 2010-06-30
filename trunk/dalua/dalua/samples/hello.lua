----------------------------------
---- DALua Hello World Sample ----
----------------------------------

-- This sample is the simplest DALua application.
-- The process sends a 'print' message to itself.

require("dalua")

function init()
	print("hello world!")
	dalua.send(dalua.self(), "alua.exit")
end

dalua.debug = true
dalua.events.monitor("dalua_init", init)
dalua.init("127.0.0.1", 4321)
dalua.loop()
