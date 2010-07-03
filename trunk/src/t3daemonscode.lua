require("t3lua")

sequencer = nil
groups = {}

function join(group, src)
	for _, daemon in pairs(alua.getdaemons()) do
		alua.send(daemon, "__join(\"" .. group .. "\", \"" .. src .. "\")")
	end
end

function __join(group, src)
	if not groups.group then
		groups.group = {}
	end
	groups.group[src] = true
	print("joined " .. src .. " to group " .. group .. " on daemon " .. alua.daemonid)
end

function send(group, src, data)
	if groups.group then
		for dst in pairs(groups.group) do
			alua.send_event(dst, t3lua.events.listen, {data = data, group = group, src = src})
		end
	end
end

function sendTotal(group, src, data)
	alua.send(sequencer, "send(\"" .. group .. "\", \"" .. alua.id .. "\", \"" .. data .. "\")")
end

function leave(group, src)
	for _, daemon in pairs(alua.getdaemons()) do
		alua.send(daemon, "__leave(\"" .. group .. "\", \"" .. src .. "\")")
	end
end

function __leave(group, src)
	if groups.group then
		groups.group[src] = nil
		print("left " .. src .. " from group " .. group .. " on daemon " .. alua.daemonid)
	end
end

