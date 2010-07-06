require("t3lua")
require("t3utils")

sequencer = nil
seq = 1
groups = {}


--[[
| Get the ids of all members of the group.
| Table with members is returned as a string argument to the callback funciton.
|
| @param group Name of the group. [string]
| @param src ID (as alua.id) of the caller process.
| @param cb Name of the caller's callback to handle the returned values. [string]
|			Must have the following interface: cb(group, table_as_string[, extra_args])
| @param extra_args Extra arguments to be passed to the callback function. [string]
--]]
function getMembers(group, src, cb, extra_args)
	local table_as_string = table.tostring(groups[group] or {})
	
	local msg
	if extra_args then
		msg = cb .. "('" .. group .. "', " ..
		             "'" .. table_as_string .. "', " ..
		             "'" .. extra_args .. "')"
	else
		msg =  cb .. "('" .. group .. "', '" .. table_as_string .. "')"
	end
	
	alua.send(src, msg)
end

function join(group, src)
	for _, daemon in pairs(alua.getdaemons()) do
		alua.send(daemon, "__join(\"" .. group .. "\", \"" .. src .. "\")")
	end
end

function __join(group, src)
	if not groups[group] then
		groups[group] = {}
	end
	groups[group][src] = true
	print("joined " .. src .. " to group " .. group .. " on daemon " .. alua.daemonid)
end

function __handleRelay(msg)
	if groups[msg.data.group] then
		for dst in pairs(groups[msg.data.group]) do
			alua.send_event(dst, t3lua.events.listen, {data = msg.data.data, group = msg.data.group, src = msg.data.src})
		end
	end	
end

function __handleRelayTotalLocal(msg)
	alua.send_event(sequencer, t3lua.events.relayTotalSequencer, msg.data)
end

function __handleRelayTotalSequencer(msg)
	if groups[msg.data.group] then
		for dst in pairs(groups[msg.data.group]) do
			alua.send_event(dst, t3lua.events.listen, {data = msg.data.data, group = msg.data.group, src = msg.data.src, seq = seq})
		end
		seq = seq + 1
	end
end

function leave(group, src)
	for _, daemon in pairs(alua.getdaemons()) do
		alua.send(daemon, "__leave(\"" .. group .. "\", \"" .. src .. "\")")
	end
end

function __leave(group, src)
	if groups[group] then
		groups[group][src] = nil
		print("left " .. src .. " from group " .. group .. " on daemon " .. alua.daemonid)
	end
end

alua.reg_event(t3lua.events.relay, __handleRelay)
alua.reg_event(t3lua.events.relayTotal, __handleRelayTotalLocal)
alua.reg_event(t3lua.events.relayTotalSequencer, __handleRelayTotalSequencer)

