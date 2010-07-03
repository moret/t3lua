require("t3lua")

function listenFunction(msg)
	print("from " .. msg.src .. ": " .. msg.data)

	if not (msg.src == t3lua.id) then
		if msg.data == "Hello Alice!" then
			t3lua.sendTotal("chat", "Hello Bob!")
		elseif msg.data == "Bye Alice!" then
			t3lua.sendTotal("chat", "Bye Bob!")
		end
	end
end

function leaveFunction()
	print("bye bye...")
	alua.quit()
	os.exit()
end

function greetEveryone()
	t3lua.sendTotal("chat", "Hello everyone!")
end

t3lua.initAndJoin("chat", listenFunction, greetEveryone)
os.exit()

