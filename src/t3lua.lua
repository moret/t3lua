module("t3lua", package.seeall)

require("alua")
require("t3hosts")
require("t3utils")


events = {
	join = "__join__",
	send = "__send__",
	listen = "__listen__",
	leave = "__leave__"
}


local init = false
local daemonHost = nil
local processListenFunction = nil


function __init(event, eventData, listenFunction, cbf)
	if not init then
		math.randomseed(os.time())
		daemonHost = t3hosts[math.random(#t3hosts)]
		function __initRegEvents(reply)
			if reply.status == alua.ALUA_STATUS_OK then
				alua.reg_event(events.join, __handleJoin)
				alua.reg_event(events.send, __handleSend)
				alua.reg_event(events.listen, __handleListen)
				alua.reg_event(events.leave, __handleLeave)

				init = true
				processListenFunction = listenFunction
				alua.send_event(alua.id, event, eventData, cbf)
			end
		end
		alua.connect(daemonHost.addr, daemonHost.port, __initRegEvents)
		alua.loop()
	end
end

function __handleJoin(msg)
	log("join - " .. msg.data)
	alua.send(alua.daemonid, "join(\"" .. msg.data .. "\", \"" .. msg.dst .. "\")")
	__handleCallback(msg.cb)
end

function __handleSend(msg)
	log("send - group " .. msg.data.groupName .. " - " .. msg.data.data)
	alua.send(alua.daemonid, "send(\"" .. msg.data.groupName .. "\", \"" .. msg.data.data .. "\")")
	__handleCallback(msg.cb)
end

function __handleListen(msg)
	log("listen - group " .. msg.data.groupName .. " - " .. msg.data.data)
	processListenFunction(msg.data.data)
	__handleCallback(msg.cb)
end

function __handleLeave(msg)
	log("join - " .. msg.data)
	alua.send(alua.daemonid, "leave(\"" .. msg.data .. "\", \"" .. msg.dst .. "\")")
	__handleCallback(msg.cb)
end

function __handleCallback(cbf)
	if cbf then
		cbf()
	end
end


function join(groupName, listenFunction, cbf)
	if not init then
		__init(events.join, groupName, listenFunction, cbf)
	else
		alua.send_event(alua.id, events.join, groupName, cbf)
	end
end

function send(groupName, data, cbf)
	if not init then
		error("must join group first")
	else
		alua.send_event(alua.id, events.send, {groupName = groupName, data = data}, cbf)
	end
end

function leave(groupName, cbf)
	if not init then
		error("must join group first")
	else
		alua.send_event(alua.id, events.leave, groupName, cbf)
	end
end
