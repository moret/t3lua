module("t3lua", package.seeall)

require("alua")
require("t3hosts")
require("t3utils")


events = {
	join = "__join__",
	listen = "__listen__",
	relay = "__relay__",
	relayTotal = "__relaytotal__",
	relayTotalSequencer = "__relaytotalsteptwo__"
}


id = nil
local daemonHost = nil
local processListenFunction = nil

local totalsequence = nil
local totalholdback = {}

local causalclocks = {}
local causalholdback = {}

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
		
		local poppedmsgs = {}
		while totalholdback[totalsequence] do
			poppedmsgs[#poppedmsgs + 1] = totalholdback[totalsequence].data
			totalholdback[totalsequence] = nil
			totalsequence = totalsequence + 1
		end
		
		if #poppedmsgs > 0 then
			processListenFunction(poppedmsgs)
		end
	elseif msg.data.clocks then
		-- timestamped message, causally ordered
		-- checking if it's there are unknown clocks to set our own vector
		for src, clock in pairs(msg.data.clocks) do
			if not causalclocks[src] then
				causalclocks[src] = clock
			end
		end
		log("causally message arrived, local clock: " .. causalclocks[id] .. ", src timestamp: " .. causalclocks[msg.data.src])	
		causalholdbacks[#causalholdbacks + 1] = msg
		
		local poppedmsgs = {}
		local thereMightBeMoreMessages = true
		while thereMightBeMoreMessages do
			thereMightBeMoreMessages = false
			for i, possiblepoppedmsg in ipairs(causalholdbacks) do
				local diff = 0
				for src, clock in pairs(causalclocks) do
					diff = diff + clock - possiblepoppedmsg.data.clocks[src]
				end
				if diff == 1 then
					poppedmsgs[#poppedmsgs + 1] = possiblepoppedmsg.data
					causalclocks[possiblepoppedmsg.data.src] = possiblepoppedmsg.data.clocks[src]
					causalholdbacks[i] = nil
					thereMightBeMoreMessages = true
				end
			end
		end
		
		if #poppedmsgs > 0 then
			processListenFunction(poppedmsgs)
		end
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
				causalclocks[id] = 1
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
		alua.send_event(alua.daemonid, t3lua.events.relay, {group = group, src = alua.id, data = data}, cbf)
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
		alua.send_event(alua.daemonid, t3lua.events.relayTotal, {group = group, src = alua.id, data = data}, cbf)
	end
end

function sendCausal(group, data, cbf)
	if not id then
		error("must init first")
	elseif __bogus then
		log("sendCausal bogus - calling send")
		send(group, data, cbf)
	else
		log("sendTotal - group " .. group .. " - " .. data)
		alua.send_event(alua.daemonid, t3lua.events.relayCausal, {group = group, src = alua.id, data = data}, cbf)
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

