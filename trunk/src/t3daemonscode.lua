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
	groups.group[#groups.group + 1] = processid	
	print("joined " .. processid .. " to group " .. group .. " on daemon " .. alua.daemonid)
end

function send(group, data)
	if groups.group then
		for _, processid in ipairs(groups.group) do
			alua.send_event(processid, t3lua.events.listen, {groupName = group, data = data})
		end
	end
end

