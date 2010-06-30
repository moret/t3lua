require("t3lua")

groups = {}

function join(group, processid)
	for _, daemon in pairs(alua.getdaemons()) do
		alua.send(daemon, "__join(\"" .. group .. "\", \"" .. processid .. "\")")
	end
end

function __join(group, processid)
	if not groups.group then
		groups.group = {}
	end
	groups.group[processid] = true
	print("joined " .. processid .. " to group " .. group .. " on daemon " .. alua.daemonid)
end

function send(group, data)
	if groups.group then
		for processid in pairs(groups.group) do
			alua.send_event(processid, t3lua.events.listen, {groupName = group, data = data})
		end
	end
end

function leave(group, processid)
	for _, daemon in pairs(alua.getdaemons()) do
		alua.send(daemon, "__leave(\"" .. group .. "\", \"" .. processid .. "\")")
	end
end

function __leave(group, processid)
	if groups.group then
		groups.group[processid] = nil
		print("left " .. processid .. " from group " .. group .. " on daemon " .. alua.daemonid)
	end
end

