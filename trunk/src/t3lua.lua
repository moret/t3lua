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
local logicClock
local totalsequence = nil
local totalholdback = {}

local __bogus = false
local __debug = false


function __callCallback(cbf)
	if cbf then
		cbf()
	end
end

function __handleListen(msg)
	log("listen - " .. msg.data.data)
	if msg.data.seq then
		-- sequenced message, totally ordered
		-- checking if it's the first message received
		if not totalsequence then
			totalsequence = msg.data.seq
		end
		log("sequenced message arrived, current seq: " .. totalsequence .. ", msg.data.seq: " .. msg.data.seq)
		totalholdback[msg.data.seq] = msg
		poppedmsgs = {}
		while totalholdback[totalsequence] do
			poppedmsgs[#poppedmsgs + 1] = totalholdback[totalsequence].data
			totalholdback[totalsequence] = nil
			totalsequence = totalsequence + 1
		end
		if #poppedmsgs > 0 then
			processListenFunction(poppedmsgs)
		end
	elseif msg.data.timestamp then
		-- timestamped message, causally ordered
		
	else
		-- unsynchronized message
		processListenFunction({msg.data})
	end
	__callCallback(msg.cb)
end


function initAndJoin(group, listenFunction, cbf, debugMode, bogusMode)
	function __cbf()
		join(group, cbf)
	end
	init(listenFunction, __cbf)
end

function init(listenFunction, cbf, debugMode, bogusMode)
	if not id then
		daemonHost = t3hosts[getRandom(#t3hosts)]
		function __initRegEvents(reply)
			if reply.status == alua.ALUA_STATUS_OK then
				alua.reg_event(events.listen, __handleListen)
				processListenFunction = listenFunction
				id = reply.id
				__debug = debugMode
				__bogus = bogusMode
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

function sendTotal(group, data, cbf)
	if not id then
		error("must init first")
	elseif __bogus then
		log("sendTotal bogus - calling send")
		send(group, data, cbf)
	else
		log("sendTotal - group " .. group .. " - " .. data)
		alua.send(alua.daemonid, "sendTotal(\"" .. group .. "\", \"" .. alua.id .. "\", \"" .. data .. "\")")
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

