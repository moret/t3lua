require("t3lua")

function listenFunction(msg)
	print("received: " .. msg)
	joincb()
end

function leaveFunction()
	print("bye bye...")
	alua.quit()
	os.exit()
end

function joincb()
	io.write("say something: ")
	local msg = io.read()
	if msg == "bye" then
		t3lua.leave("testGroup", leaveFunction)
	else
		t3lua.send("testGroup", msg)
	end
end

t3lua.join("testGroup", listenFunction, joincb)
os.exit()

