require "posix"
require "socket"


local pids = {}


print("\n=== Testing with true mutex ===\n")

for i = 1, 3 do
	local pid = posix.fork()
	
	if pid == 0 then
		os.execute("lua testmutex.lua " .. i .. i .. i)
		os.exit()
	else
		table.insert(pids, pid)
	end
	
	socket.select(nil, nil, 3)
end

for _, pid in ipairs(pids) do
	posix.wait(pid)
end

print("\n=== Testing with false mutex ===\n")

for i = 1, 3 do
	local pid = posix.fork()
	
	if pid == 0 then
		os.execute("lua testmutex-fake.lua " .. i .. i .. i)
		os.exit()
	else
		table.insert(pids, pid)
	end
end

for _, pid in ipairs(pids) do
	posix.wait(pid)
end

print("\n=== End of tests ===")