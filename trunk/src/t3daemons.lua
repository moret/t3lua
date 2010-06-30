require("alua")
require("posix")
require("t3hosts")
require("socket")

local pid = nil
local pids = {}

function testFunction(...)
	print("Teste")
end

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
		end
		alua.quit()
	end
end

for _, host in ipairs(t3hosts) do
    pid = posix.fork()
    if pid == 0 then -- Child process, create and loop
		alua.create(host.addr, host.port)
		print(alua.id)
		alua.loop()
		os.exit()
	else -- Father process, register child
		pids[#pids + 1] = pid
    end
end

-- Non-blocking sleep, allow daemons to start
sleep(2)
-- Resume and link them all!
local firstKnownHost = t3hosts[1]
alua.connect(firstKnownHost.addr, firstKnownHost.port, connectCB)
alua.loop()

for _, pid in ipairs(pids) do
	posix.wait(pid)
end
