require("alua")
require("t3hosts")
require("t3utils")
require("posix")

local pid = nil
local pids = {}

function connectCB(reply)
	if reply.status == alua.ALUA_STATUS_OK then
		alua.link(t3hosts.getDaemonsAsString(), linkCB)
	end
end

function linkCB(reply)
	if reply.status == alua.ALUA_STATUS_OK then
		-- choosing one of the daemons as the total sequencer
		sequencer = "sequencer = \"" .. t3hosts.getDaemonString(t3hosts[getRandom(#t3hosts)]) .. "\""
		print("chosen " .. sequencer)
		for _, linkedDaemon in ipairs(reply.daemons) do
			print("daemon " .. linkedDaemon .. " linked")
			alua.send(linkedDaemon, io.open("t3daemonscode.lua", "r"):read("*all"))
			alua.send(linkedDaemon, sequencer)
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
local randomKnownHost = t3hosts[getRandom(#t3hosts)]
alua.connect(randomKnownHost.addr, randomKnownHost.port, connectCB)
alua.loop()

for _, pid in ipairs(pids) do
	posix.wait(pid)
end

