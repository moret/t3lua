-- DALua Mutex Module
-- Part of DALua Library v2.1
-- Written by Ricardo Costa (rcosta@inf.puc-rio.br)

-- Imports --

local _G = _G
local assert = assert
local error = error
local ipairs = ipairs
local loadstring = loadstring
local print = print
local require = require
local string = string
local table = table
local tonumber = tonumber
local tostring = tostring
local type = type
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

local mutexes = {}
local createreqs = {}
local addreqs = {}
local removereqs = {}

local function addlog(action, proc, msg)
    if debug == false then return end
    local str = "[dalua.mutex]["..dalua.self().."] "..action.." ["..proc.."]"
    if msg ~= nil then
        str = str..": "..msg
    end
    print(str)
end

function create(id, procs)
	if createreqs[id] then
		return false
	end
	createreqs[id] = { procs = procs, count = 0 }
	dalua.send(procs, "__dalua.mutex.__create_request", dalua.self(), id, procs)
	return true
end

function __create_request(from, id, procs)
	if mutexes[id] then
		dalua.send(from, "__dalua.mutex.__create_reply", dalua.self(), id, false)
	else
		mutexes[id] = { ["clock"] = 0, busy = false, waiting = false, queue = {}, requests = {}, numreqs = 0, procs = procs }
		dalua.send(from, "__dalua.mutex.__create_reply", dalua.self(), id, true)
	end
end

function __create_reply(from, id, result)
	if createreqs[id] == nil then
		return
	end
	if result == true then
		createreqs[id].count = createreqs[id].count + 1
		if createreqs[id].count >= table.getn(createreqs[id].procs) then
			if debug then
				print("[dalua.mutex][info] Mutex created: "..id)
			end
			if dalua.events then
				dalua.events.raise("dalua_mutex_create", dalua.self(), "success", id)
			end
			createreqs[id] = nil
		end
	else
		if debug then
			print("[dalua.mutex][error] Process "..from.." already has a mutex named "..id)
		end
		dalua.send(createreqs[id].procs, "__dalua.mutex.__create_failed", id)
		createreqs[id] = nil
	end
end

function __create_failed(id)
	mutexes[id] = nil
	if dalua.events then
		dalua.events.raise("dalua_mutex_create", dalua.self(), "error", id)
	end
end

function enter(id, func, ...)
	if mutexes[id] == nil then
		if debug then
			print("[dalua.mutex][error] Mutex '"..id.."' does not exist.")
		end	
		if dalua.events then
			dalua.events.raise("dalua_mutex_enter", dalua.self(), "error", id)
		end
		return false
	end
	mutexes[id].clock = mutexes[id].clock + 1
	mutexes[id].waiting = true
	if debug then
		print("["..dalua.self().."] doing request id="..mutexes[id].numreqs)
	end
	local request = {}
	request.id = mutexes[id].numreqs
	request.timestamp = mutexes[id].clock
	request.cs_func = func
	request.cs_args = arg
	request.proc = dalua.self()
	request.pcount = #mutexes[id].procs
	table.insert(mutexes[id].requests, request)
	local msg = {}
	msg.id = request.id
	msg.timestamp = request.timestamp
	msg.proc = request.proc
	msg.pcount = request.pcount
	mutexes[id].numreqs = mutexes[id].numreqs + 1
	mutexes[id].clock = mutexes[id].clock + 1
	dalua.send(mutexes[id].procs, "__dalua.mutex.__enter_request", id, msg)
	return true
end

function __enter_request(id, msg)
	if mutexes[id] == nil then
		if debug then
			print("[dalua.mutex][error] Process "..dalua.self().." is not part of Mutex '"..id.."'.")
		end
		return
	end
	addlog("received from ", msg.proc, "request ( id="..msg.id..", timestamp="..msg.timestamp.." )")
	local timestamp = tonumber(msg.timestamp)
	if timestamp < mutexes[id].clock then
		mutexes[id].clock = mutexes[id].clock + 1
	else
		mutexes[id].clock = timestamp + 1
	end 
	if mutexes[id].busy then
		addlog("added to queue request from", msg.proc)
		table.insert(mutexes[id].queue, msg)    
	elseif mutexes[id].waiting then
		if timestamp < mutexes[id].requests[1].timestamp 
		  or (timestamp == mutexes[id].requests[1].timestamp and msg.proc <= dalua.self()) then
			addlog("sent to", msg.proc, "OK id="..msg.id)
			dalua.send(msg.proc, "__dalua.mutex.__enter_accepted", id, dalua.self(), msg.id, mutexes[id].clock)
		else
			addlog("added to queue request from", msg.proc)
			table.insert(mutexes[id].queue, msg)
		end
	else
		addlog("sent to", msg.proc, "OK id="..msg.id)
		dalua.send(msg.proc, "__dalua.mutex.__enter_accepted", id, dalua.self(), msg.id, mutexes[id].clock)
	end
end

function __enter_accepted(mtx, proc, id, timestamp)
	addlog("received from", proc, "OK id="..id)
	if timestamp < mutexes[mtx].clock then
		mutexes[mtx].clock = mutexes[mtx].clock + 1
	else
		mutexes[mtx].clock = timestamp + 1
	end
	for _,p in ipairs(mutexes[mtx].requests) do
		if p.id == id then
			p.pcount = p.pcount - 1
			break
		end
	end
	if mutexes[mtx].requests[1].pcount == 0 then
		mutexes[mtx].busy = true
		mutexes[mtx].waiting = false
		if debug then
			print("[dalua.mutex]["..dalua.self().."] entered critical section id="..mutexes[mtx].requests[1].id)
		end
		if type(mutexes[mtx].requests[1].cs_func) == "function" then
			mutexes[mtx].requests[1].cs_func(unpack(mutexes[mtx].requests[1].cs_args))
		elseif type(mutexes[mtx].requests[1].cs_func) == "string" then
			local func = mutexes[mtx].requests[1].cs_func .. "("
			local comma = false
			local v
			for _, v in ipairs(mutexes[mtx].requests[1].cs_args) do
				if comma then
					func = func .. ", "
				else
					comma = true
				end
				func = func .. dalua.__serialize(v)
			end
			func = func .. ")"
			assert(loadstring(func))()
		end
		table.remove(mutexes[mtx].requests, 1)	
	end
end

function leave(id)
	if mutexes[id] == nil then
		if debug then
			print("[dalua.mutex][warning] Process "..dalua.self().." is not part of Mutex '"..id.."'")
		end
		return
	end
	if debug then
		print("[dalua.mutex]["..dalua.self().."] leaving critical section")
	end
	mutexes[id].clock = mutexes[id].clock + 1
	mutexes[id].busy = false
	local tmpfila = {}
	for i, p in ipairs(mutexes[id].queue) do
		if mutexes[id].requests[1] == nil or (p.timestamp < mutexes[id].requests[1].timestamp 
									or (p.timestamp == mutexes[id].requests[1].timestamp 
									and p.proc <= dalua.self())) then
			addlog("sent to", p.proc, "OK id="..p.id)
			dalua.send(p.proc, "__dalua.mutex.__enter_accepted", id, dalua.self(), p.id, mutexes[id].clock)
		else
		    table.insert(tmpfila, p)
		end
	end
	mutexes[id].queue = tmpfila
end

function destroy(id)
	if mutexes[id] then
		dalua.send(mutexes[id].procs, "__dalua.mutex.__destroy", id)
	end
end

function __destroy(id)
	mutexes[id] = nil
end

function processes(id)
	return mutexes[id] and mutexes[id].procs
end

function add(id, proc)
	-- Adds process 'proc' to the mutex 'id'
	local function add_cs(id, proc)
		addlog("adding process", proc)
		addreqs[id] = #mutexes[id].procs + 1
		dalua.send(proc, "__dalua.mutex.__add_self", dalua.self(), id, mutexes[id].procs)
		dalua.send(mutexes[id].procs, "__dalua.mutex.__add_request", dalua.self(), id, proc)
	end
	enter(id, add_cs, id, proc)
end

function __add_self(from, id, procs)
	mutexes[id] = { ["clock"] = 0, busy = false, waiting = false, queue = {}, requests = {}, numreqs = 0, procs = procs }
	table.insert(mutexes[id].procs, dalua.self())
	dalua.send(from, "__dalua.mutex.__add_reply", id, dalua.self())
end

function __add_request(from, id, proc)
	table.insert(mutexes[id].procs, proc)
	dalua.send(from, "__dalua.mutex.__add_reply", id, proc)
end

function __add_reply(id, proc)
	addreqs[id] =  addreqs[id] - 1
	if addreqs[id] == 0 then
		addreqs[id] = nil
		leave(id)
		dalua.events.raise("dalua_mutex_add", {dalua.self(), proc}, "success", id, proc)
	end
end

function remove(id, proc)
	-- Removes process 'proc' from the mutex 'id'
	local function remove_cs(id, proc)
		addlog("removing process", proc)
		removereqs[id] = #mutexes[id].procs
		dalua.send(mutexes[id].procs, "__dalua.mutex.__remove_request", dalua.self(), id, proc)
	end
	enter(id, remove_cs, id, proc)
end


function __remove_request(from, id, proc)
	if mutexes[id] then
		for i, p in ipairs(mutexes[id].procs) do
			if p == proc then
				table.remove(mutexes[id].procs, i)
				break
			end
		end
		--if proc == dalua.self() then
		--	mutexes[id] = nil
		--end
	end
	dalua.send(from, "__dalua.mutex.__remove_reply", id, proc)
end

function __remove_reply(id, proc)
	removereqs[id] =  removereqs[id] - 1
	if removereqs[id] == 0 then
		removereqs[id] = nil
		leave(id)
		mutexes[id] = nil
		dalua.events.raise("dalua_mutex_remove", {dalua.self(), proc}, "success", id, proc)
	end
end
