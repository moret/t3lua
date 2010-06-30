require("alua")

require("known-hosts")

local alice

function aliceCallback(reply)
	alice = reply
	if reply.status == alua.ALUA_STATUS_OK then
		print("Created Alice at " .. reply.id)
		alua.send(reply.id, "greet()")
	end
end

function connectCallback(reply)
	if reply.status == alua.ALUA_STATUS_OK then
		-- Creating process alice
		local aliceCode = [[
			function greet()
				print(alua.id .. " ~ Hello, I'm Alice!")
			end
			
			function reply(name, remoteId)
				print(alua.id .. " ~ No way " .. name .. "!")
			end
		]]
		alua.spawn(aliceCode, false, aliceCallback)
	else
		
	end
end

alua.connect("127.0.0.1", 11111, connectCallback)
alua.loop()
