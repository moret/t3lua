require("t3lua")
require("posix")
require("t3utils")

local counter = 1
local chatter = {}

__bogus = false
__debug = false

function sayRandomNumber()
	local randomNumber = counter
	counter = counter + 1
	local randomGroup = chatter.groups[getRandom(#chatter.groups)]
	t3lua.sendTotal(randomGroup, chatter.name .. "," .. randomNumber)
end

function listenFunction(msgs)
	local reply = false
	for _, msg in pairs(msgs) do
		print("received," .. msg.group .. "," .. msg.data)
		logfile:write(msg.data .. "\n")
		logfile:flush()
		if not (msg.src == t3lua.id) then
			reply = true
		end
	end
	if reply then
		if getRandom(3) == 1 then
			sleep(1)
		end
		sayRandomNumber()
	end
end

function initcb()
	for _, group in ipairs(chatter.groups) do
		t3lua.join(group, sayRandomNumber)
	end
end

for i, param in pairs(arg) do
	if i > 0 then
		if param == "-debug" then
			__debug = true
			log("debug mode")
		elseif param == "-bogus" then
			__bogus = true
			log("bogus mode")
		elseif not chatter.name then
			chatter.name = param
			chatter.groups = {}
			print("chatter.name: " .. chatter.name)
		else
			chatter.groups[#chatter.groups + 1] = param
		end
	end
end

math.randomseed(os.time())

logfile = io.open("../results/logs/" .. chatter.name .. ".log", "w+")
t3lua.init(listenFunction, initcb, __debug, __bogus)
os.exit()

