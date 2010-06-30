-- DALua Timer Module
-- Part of DALua Library v2.1
-- Written by Ricardo Costa (rcosta@inf.puc-rio.br)

-- Imports --

local _G = _G
local assert = assert
local ipairs = ipairs
local loadstring = loadstring
local print = print
local require = require
local string = string

-- End Imports --

module(...)
local dalua = require(string.sub(_PACKAGE, 1, #_PACKAGE - 1))
local alua = dalua.alua
__dalua = dalua

-------------------------------------

-- Enable/Disable debug messages
    debug = false

-------------------------------------

local timerCount = 0

local function runtimer (timer)
	if timer == nil then return end
	if timer.count > 0 then
		if timer.current <= 0 then
			alua.timer.cancel(timer.timer)
			if debug then
				print("[dalua.timer][info] Timer "..timer.id.." removed.")
			end
			return
		end
		timer.current = timer.current - 1
	end
	if debug then
		print("[dalua.timer][info] Running timer "..timer.id..": "..timer.cmd)
	end   
	assert(loadstring(timer.cmd))()
end

local function inserttimer (cmd, period, count)
	timerCount = timerCount + 1
	local control = { ["cmd"] = cmd, ["count"] = count, ["current"] = count , ["timer"] = nil, ["id"] = timerCount }
	local timerfunc = function () runtimer(control) end
	control.timer = alua.timer.create(period, timerfunc)
	return control.timer
end

---- Public Functions ----

function add(id, period, count, fc, ...)
	local msg = fc .. "("
	local comma = false
	local v
	for _,v in ipairs(arg) do
		if comma then
			msg = msg .. ", "
		else
			comma = true
		end	
		msg = msg .. dalua.__serialize (v)
	end
	msg = msg .. ")"
	local cmd = 'alua.send("'..id..'",[['..msg..']], nil, '..dalua.timeout..')'
	if debug then
		print("[dalua.timer][info] Created timer "..count.."x "..period.."s: "..cmd)
	end
	return inserttimer(cmd, period, count)
end

function remove(timer)
	if debug then
		print("[dalua.timer][info] Timer "..timer.." removed.")
	end
	alua.timer.cancel(timer)
end
