----------------------------
---- DALua Mutex Sample ----
----------------------------

-- This sample shows how to create a Mutex 
-- object and enter the critical section
-- each 2 seconds with the aid of a timer.
-- It also updates the Mutex object when
-- another process is linked (mutex2.lua).

-- Run mutex1.lua first, then mutex2.lua.


require("dalua")

local numRequest = 0

function onLink(event, status)
	if status == "success" then
		dalua.events.ignore("dalua_link", onLink)
		dalua.send("1@127.0.0.1:4321", "dalua.mutex.add", "Mutex", dalua.self())
	end
end

function onMutexAdd(event, status, mtx, proc)
	if status == "success" then
		print("Added "..proc.." to "..mtx.." successfully!")
		dalua.timer.add(dalua.self(), 2, 1, "onTimerTick")
	end
end

function leaveCS()
	dalua.mutex.leave("Mutex")
	print("Left critical section...")
	dalua.timer.add(dalua.self(), 2, 1, "onTimerTick")
end

function onTimerTick()
	local function critical_section()
		print("In Critical Section...")
		dalua.timer.add(dalua.self(), 1, 1, "leaveCS")
	end
	print("Doing request #"..numRequest)
	numRequest = numRequest + 1
	dalua.mutex.enter("Mutex", critical_section)
end

function main()
	print("My PID = " .. dalua.self())
	dalua.link("127.0.0.1", 4321)
end

dalua.debug = true
-- To disable mutex debug messages, set this to false
dalua.mutex.debug = true
dalua.events.monitor("dalua_init", main)
dalua.events.monitor("dalua_link", onLink)
dalua.events.monitor("dalua_mutex_add", onMutexAdd)
dalua.init("127.0.0.1", 4322)
dalua.loop()

