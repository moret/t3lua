require "t3lua"
require "t3lua-mutex"
require "socket"


group = arg[1] or "grupoA"
mutex = arg[2] or "mutexI"


local function crcb()
	print("Entered critical region.")
	socket.select(nil, nil, 15)
	t3lua.mutex.leave(group, mutex)
	print("Left critical region.")
	t3lua.leave(group)
	alua.quit()
end


local function crerrcb()
	print("Could not get access to critical region. Leaving group.")
	t3lua.leave(group)
	alua.quit()
end


local function conncb()
	print("alua.id", alua.id, "alua.daemonid", alua.daemonid)
	print("Entering critical region...")
	t3lua.mutex.enter(group, mutex, crcb, crerrcb)
end

t3lua.initAndJoin(group, nil, conncb)