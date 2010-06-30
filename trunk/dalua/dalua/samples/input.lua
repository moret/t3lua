----------------------------
---- DALua Input Sample ----
----------------------------

-- This sample shows a way to simulate a loop 
-- without completely blocking the ALua loop.

require("dalua")

local cmd = "Type your command here:"

function input()
	os.execute("cls")
	print(cmd)
	io.write("> ")
	cmd = io.read()
	if cmd == "quit" then
		dalua.exit()
	end
	dalua.send(dalua.self(), "input")
end

dalua.events.monitor("dalua_init", input)
dalua.init("127.0.0.1", 4321)
dalua.loop()
