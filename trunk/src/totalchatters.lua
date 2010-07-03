require("t3lua")
require("posix")

local pid = nil
local pids = {}

local chatter = nil

function sayRandomNumber()
	local randomNumber = getRandom(1000)
	local randomGroup = chatter.groups[getRandom(#chatter.groups)]
	print("send," .. chatter.name .. "," .. randomGroup .. "," .. randomNumber)
	t3lua.send(randomGroup, chatter.name .. "," .. randomNumber)
end

function listenFunction(msg)
	print("received," .. chatter.name .. "," .. msg.group .. "," .. msg.data)
	sleep(2 + getRandom(3))
	sayRandomNumber()
end

function initcb()
	for _, group in ipairs(chatter.groups) do
		t3lua.join(group, sayRandomNumber)
	end
end


math.randomseed(os.time())

local chatters = {
	{name = "Alice", groups = {"chat1", "chat2"}},
	{name = "Bob", groups = {"chat1", "chat2"}},
	{name = "Carl", groups = {"chat1", "chat3"}},
	{name = "Dan", groups = {"chat1", "chat3"}}
}

for _, who in pairs(chatters) do
    pid = posix.fork()
    if pid == 0 then -- Child process, create and loop
    	chatter = who
		t3lua.init(listenFunction, initcb)
		os.exit()
	else -- Father process, register child
		pids[#pids + 1] = pid
    end
end

sleep(1)

for _, pid in ipairs(pids) do
	posix.wait(pid)
end

