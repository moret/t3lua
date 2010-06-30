require("t3lua")

function listenFunction(msg)
	print("received: " .. msg)
	joincb()
end

function joincb()
	io.write("say something: ")
	local msg = io.read()
	t3lua.send("testGroup", msg)
end

t3lua.join("testGroup", listenFunction, joincb)

