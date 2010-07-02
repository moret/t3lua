require("t3lua")

function listenFunction(msg)
	print("from " .. msg.src .. ": " .. msg.data)

	if not (msg.src == t3lua.id) then
		if msg.data == "Hello Bob!" then
			t3lua.send("chat", "Bye Alice!")
		elseif msg.data == "Bye Bob!" then
			t3lua.leave("chat", leaveFunction)
		end
	end
end

function leaveFunction()
	print("bye bye...")
	alua.quit()
	os.exit()
end

function greetEveryone()
	t3lua.send("chat", "Hello Alice!")
end

t3lua.initAndJoin("chat", listenFunction, greetEveryone)
os.exit()

