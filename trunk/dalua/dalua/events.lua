-- DALua Events Module
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
local table = table
local tonumber = tonumber
local unpack = unpack

-- End Imports --

module(...)
local dalua = require(string.sub(_PACKAGE, 1, #_PACKAGE - 1))
local alua = dalua.alua
__dalua = dalua

-------------------------------------
-- Enable/Disable debug messages
    debug = false
-------------------------------------

local eventtable = {}
local customevents = nil

function raise(event, procs, ...)
	if customevents and customevents[event] then
		event = customevents[event]
	end
	if procs == __dalua.self() then
		__handler(event, arg)
	else
		__dalua.send(procs, "__dalua.events.__handler", event, arg)
	end
end

function monitor(event, callback, count)
	if callback == nil then
		return
	end
	if eventtable[event] == nil then
		eventtable[event] = {}
	end
	for i, v in ipairs(eventtable[event]) do
		if v.callback == callback then
			return
		end
	end	
	table.insert(eventtable[event], {callback = callback, count = count})
end

function ignore(event, callback)
	if eventtable[event] == nil then
		return
	end
	if callback == nil then
		eventtable[event] = nil
		return
	end
	for i, v in ipairs(eventtable[event]) do
		if v.callback == callback then
			table.remove(eventtable[event], i)
			break
		end
	end
end

function customize(arg1, arg2, arg3)
	local func
	if arg3 then
		customevents = { [arg1] = arg2 }
		func = arg3
	else
		customevents = arg1
		func = arg2
	end
	local ce_cpy = customevents
	return	function ( ... )
			customevents = ce_cpy
			local ret = {func(unpack(arg))}
			customevents = nil
			return unpack(ret)
		end
end

function getcustomevents()
	return customevents
end

function __handler(event, args)
	if debug then
		print("[dalua.events][info] Event received: "..event.." "..dalua.__serialize(args))
	end
	if eventtable[event] == nil then
		return
	end
	for i, v in ipairs(eventtable[event]) do
		if v.count then
			if v.count == 0 then
				table.remove(eventtable[event], i)
			else
				v.count = v.count - 1
				v.callback(event, unpack(args))
			end
		else
			v.callback(event, unpack(args))
		end
	end
end

