module("t3lua", package.seeall)

require("alua")
require("t3hosts")
require("t3utils")


events = {
	join = "__join__",
	listen = "__listen__",
}


id = nil
local daemonHost = nil
local processListenFunction = nil


function __callCallback(cbf)
	if cbf then
		cbf()
	end
end

function __handleListen(msg)
	log("listen - " .. msg.data.data)
	processListenFunction(msg.data)
	__callCallback(msg.cb)
end


function initAndJoin(group, listenFunction, cbf)
	function __cbf()
		join(group, cbf)
	end
	init(listenFunction, __cbf)
end

function init(listenFunction, cbf)
	if not id then
		math.randomseed(os.time())
		daemonHost = t3hosts[math.random(#t3hosts)]
		function __initRegEvents(reply)
			if reply.status == alua.ALUA_STATUS_OK then
				alua.reg_event(events.listen, __handleListen)
				processListenFunction = listenFunction
				id = reply.id
				__callCallback(cbf)
			end
		end
		alua.connect(daemonHost.addr, daemonHost.port, __initRegEvents)
		alua.loop()
	end
end

function join(group, cbf)
	if not id then
		error("must init first")
	else
		log("join - " .. group)
		alua.send(alua.daemonid, "join(\"" .. group .. "\", \"" .. alua.id .. "\")")
		__callCallback(cbf)
	end
end

function send(group, data, cbf)
	if not id then
		error("must init first")
	else
		log("send - group " .. group .. " - " .. data)
		alua.send(alua.daemonid, "send(\"" .. group .. "\", \"" .. alua.id .. "\", \"" .. data .. "\")")
		__callCallback(cbf)
	end
end

function leave(group, cbf)
	if not id then
		error("must init first")
	else
		log("join - " .. group)
		alua.send(alua.daemonid, "leave(\"" .. group .. "\", \"" .. alua.id .. "\")")
		__callCallback(cbf)
	end
end

