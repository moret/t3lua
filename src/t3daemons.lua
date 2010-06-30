require("alua")
require("posix")
require("t3hosts")
require("t3utils")
require("socket")

local pid = nil
local pids = {}

function sleep(sec)
	--print("going to sleep for a while...")
	socket.select(nil, nil, sec)
end

function connectCB(reply)
	if reply.status == alua.ALUA_STATUS_OK then
		alua.link(t3hosts.getDaemonsAsString(), linkCB)
	end
end

function linkCB(reply)
	if reply.status == alua.ALUA_STATUS_OK then
		for _, linkedDaemon in ipairs(reply.daemons) do
			print("daemon " .. linkedDaemon .. " linked")
			alua.send(linkedDaemon, io.open("t3daemonscode.lua", "r"):read("*all"))
		end
		
		alua.quit()
	end
end

for _, host in ipairs(t3hosts) do
    pid = posix.fork()
    if pid == 0 then -- Child process, create and loop
		alua.create(host.addr, host.port)
		alua.loop()
		os.exit()
	else -- Father process, register child
		pids[#pids + 1] = pid
    end
end

-- Non-blocking sleep, allow daemons to start
sleep(1)
-- Resume and link them all!
local firstKnownHost = t3hosts[1]
alua.connect(firstKnownHost.addr, firstKnownHost.port, connectCB)
alua.loop()

for _, pid in ipairs(pids) do
	posix.wait(pid)
end
