require("alua")

local bob

local remoteName = arg[1]
local remoteId = arg[2]

function bobCallback(reply)
	bob = reply
	if reply.status == alua.ALUA_STATUS_OK then
		print("Created Bob at " .. reply.id)
		alua.send(reply.id, "greet()")
		local inviteCode = "invite('" .. remoteName .. "', '" .. remoteId .. "')"
		alua.send(bob.id, inviteCode)
	end
end

function connectCallback(reply)
	if reply.status == alua.ALUA_STATUS_OK then
		-- Creating process bob
		local bobCode = [[
			function greet()
				print(alua.id .. " ~ Hello, I'm Bob!")
			end
			
			function invite(name, id)
				print(alua.id .. " ~ Hello " .. name .. ", let's make out!")
				alua.send(id, "reply('Bob', '" .. alua.id .. "')")
			end
		]]
		alua.spawn(bobCode, false, bobCallback)
	end
end

alua.connect("127.0.0.1", 11111, connectCallback)
alua.loop()
