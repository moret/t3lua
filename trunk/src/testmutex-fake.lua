require "t3lua"
require "t3lua-mutex"
require "socket"


local _ID   = arg[1]
local group = arg[2] or "grupoA"
local mutex = arg[3] or "mutexI"
local sleep = arg[4] or 15
local msg   = arg[5] or "Hello!"


-- Redefine with fake funcitons
function t3lua.mutex.enter(group, mutex, crcb, crerrcb)
	crcb()
end

function t3lua.mutex.leave()
end
---

local function ID()
	return _ID or alua.id
end


local function crcb(time, message)
	print(ID(), "Entered critical region.")
	
	print(ID(), "Waiting for:", time)
	socket.select(nil, nil, time)
	print(ID(), "Woke up and said:", message)
	t3lua.mutex.leave(group, mutex)
	
	print(ID(), "Left critical region.")
	
	t3lua.leave(group)
	alua.quit()
end


local function crerrcb()
	print(ID(), "Could not get access to critical region. Leaving group.")
	t3lua.leave(group)
	alua.quit()
end


local function conncb()
	print(ID(), "Entering critical region...")
	
	local crcb = t3lua.mutex.wrap(crcb, sleep, msg)
	t3lua.mutex.enter(group, mutex, crcb, crerrcb)
end

t3lua.initAndJoin(group, nil, conncb)