module("t3lua", package.seeall)

require("alua")
require("t3hosts")


events = {
	join = "__join__"
}


local init = false
local daemonHost = nil


function __init(event, eventData, cbf)
	if not init then
		math.randomseed(os.time())
		daemonHost = t3hosts[math.random(#t3hosts)]
		function __initRegEvents(reply)
			if reply.status == alua.ALUA_STATUS_OK then
				alua.reg_event(events.join, __handleJoin)
				init = true
				alua.send_event(alua.id, event, eventData, cbf)
			end
		end
		alua.connect(daemonHost.addr, daemonHost.port, __initRegEvents)
		alua.loop()
	end
end

function __handleJoin(msg)
	print("NYE - join - " .. msg.data)
	msg.cb()
end


function join(groupName, cbf)
	if not init then
		__init(events.join, groupName, cbf)
	else
		alua.send_event(events.join, groupName, cbf)
	end
end

function leave(groupName, cbf)
	print("NYE - leave - groupName: " .. groupName)
end
