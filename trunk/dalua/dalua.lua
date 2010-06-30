-- DALua Main Module
-- Part of DALua Library v2.1
-- Written by Ricardo Costa (rcosta@inf.puc-rio.br)
-- Requires ALua 6.0

-- Imports --

local __G = _G
local assert = assert
local error = error
local ipairs = ipairs
local loadfile = loadfile
local pairs = pairs
local print = print
local require = require
local setmetatable = setmetatable
local setfenv = setfenv
local string = string
local table = table
local type = type
local tonumber = tonumber
local tostring = tostring

-- End Imports --

module(...)

__dalua = _M
__G.__dalua = _M
local _G = __G._G

alua = require("alua")
require(_NAME..".app")
require(_NAME..".causal")
require(_NAME..".events")
require(_NAME..".mutex")
require(_NAME..".timer")
require(_NAME..".total")

---- Local Variables ----

  local procs = {}
  local network
  local link_callback
  local link_callback_reply

---- End Local Variables ----


---- Public Properties ----

  -- Send timeout in seconds, set as nil to disable
  timeout = 30

  -- Enable/disable debug messages
  debug = false

---- End Public Properties ----

---- Public Methods ----

function __daemon_addproc(id)
	table.insert(procs, id)
end

function __daemon_removeproc(id)
	for i, p in ipairs(procs) do
		if p == id then
			table.remove(procs, i)
			break
		end
	end
end

function __daemon_updatenetwork(linkevent)
	local daemons = {}
	table.insert(daemons, alua.id)
	for d in alua.daemon.context.dmn_iter() do
		table.insert(daemons, d)
	end
	send(procs, "__dalua.__updatenetwork", daemons, linkevent)
end

function __updatenetwork(ids, linkevent)
	network = ids
	events.raise(linkevent, alua.id, "success", network)
end

function __daemon_procs()
	return procs
end

function __serialize(o)
	local s = ""
	if type(o) == "number" then
		s = s..o
	elseif type(o) == "string" then
		s = s..string.format("%q", o)
	elseif type(o) == "table" then
		s = s.."{\n"
		for k,v in pairs(o) do
			s = table.concat{s, " [", __serialize(k), "] = ", __serialize(v), ",\n"}
		end
		s = s.."}\n"
	elseif type(o) == "boolean" then
		s = s..tostring(o)
	else
		print("[dalua][error] Cannot serialize a " .. type(o) .. ".")
	end
	return s
end

function __validateArgs(args, types)
	for i, v in ipairs(args) do
		if type(v) ~= types[i] then
			return false, "Argument #" .. (i+1) .. " is a " .. type(v) .. ", but " .. types[i] .. " was expected."
		end
	end
	return true
end

function daemon()
	return alua.daemonid
end

function daemons()
	return network
end

function exit()
	local function send_cb()
		alua.exit()
	end
	alua.send(alua.daemonid, [[__dalua.__daemon_removeproc("]]..alua.id..[[")]], send_cb)
end

function getindex(id)
	-- get index of the process with the specified ALua ID
	if id == nil then
		return -1
	end
	local k = string.match(id, "(%d+)@")
	return tonumber(k)
end

function init(addr, port)
	local function connect_cb(reply)
		local function open_cb(reply)
			if reply.status == "error" then
				if debug then
					print("[dalua][error] Cannot create daemon: " .. reply.error)
				end
				events.raise("dalua_init", alua.id, "error", reply.error)
			else
				if debug then
					print("[dalua][info] Daemon '"..alua.daemonid.."' has been created.")
				end
				network = { alua.daemonid }
				alua.send(alua.daemonid, [[if not __dalua then
								__dalua = require("dalua")
							end
							__dalua.__daemon_addproc("]]..alua.id..[[")
							]])
				events.raise("dalua_init", alua.id, "success", "created")
			end
		end
		if reply.status == "error" then
			if debug then
				print("[dalua][info] Unable to connect ("..reply.error.."), creating daemon...")
			end
			local d = { addr = addr, port = port, log = "daemon.log" }
			alua.open(d, open_cb)
		else
			if debug then
				print("[dalua][info] Connected to daemon '"..alua.daemonid.."'.")
			end
			network = { alua.daemonid }
			alua.send(alua.daemonid, [[	if not __dalua then
											__dalua = require("dalua")
										end
										__dalua.__daemon_addproc("]]..alua.id..[[")
									]])
			events.raise("dalua_init", alua.id, "success", "connected")
		end
	end
	addr = addr or "127.0.0.1"
	port = port or 4321
	alua.open(string.format("%s:%u", addr, port), connect_cb)
end

function link(arg1, arg2)
	local todaemon = (arg2 and arg1 .. ":" .. arg2) or arg1
	link_callback_reply = false
	link_callback = function (reply)
		if not reply.status == "ok" then
			if debug then
				print("[dalua][error] Link failed: " .. reply.error)
			end
			events.raise("dalua_link", alua.id, "error", reply.error)
			return
		end
		if link_callback_reply == false then
			send(todaemon, "__dalua.__daemon_link_getdaemons", alua.id)
		else
			network = {}
			for _, d in ipairs(reply.daemons) do
				table.insert(network, d)
			end
			local customlinkevent = events.getcustomevents() and events.getcustomevents()["dalua_link"]
			send(network, "__dalua.__daemon_updatenetwork", customlinkevent or "dalua_link")
			if debug then
				print("[dalua][info] Link estabilished between daemons: " .. alua.tostring(network))
			end
		end
	end
	link_callback = events.customize(events.getcustomevents(), link_callback)
	alua.link({ alua.daemonid, todaemon }, link_callback)
end

function __daemon_link_getdaemons(from)
	local daemons = {}
	table.insert(daemons, alua.id)
	for d in alua.daemon.context.dmn_iter() do
		table.insert(daemons, d)
	end
	send(from, "__dalua.__link_getdaemons_reply", daemons)
end

function __link_getdaemons_reply(daemonlist)
	link_callback_reply = true
	alua.link(daemonlist, link_callback)
end

function loop()
	if debug then
		print("[dalua][info] Entering ALua loop...")
	end
	send(alua.id, "__dalua.events.raise", "dalua_loop", alua.id, "success")
	alua.loop()
end

function send(dest, fc, ...)
	if type(dest) == "table" and #dest == 0 then
		if debug then
			print("[dalua][warning] Empty destination on send.")
		end
		return
	end
	local send_callback = function (reply)
		local id, sent
		for id, sent in pairs(reply) do
			if sent.status ~= "ok" then
				events.raise("dalua_send", alua.id, "error", sent.error, id)
			else
				events.raise("dalua_send", alua.id, "success", id)
			end
		end
	end
	send_callback = events.customize(events.getcustomevents(), send_callback)

	local msg = fc .. "("
	local comma = false
	local v
	for _, v in ipairs(arg) do
		if comma then
			msg = msg .. ", "
		else
			comma = true
		end
		msg = msg .. __serialize (v)
	end
	msg = msg .. ")"
	--print(alua.tostring(dest), msg)
	--print(dest..":"..msg)
	alua.send(dest, msg, send_callback, timeout)
end

function self()
	return alua.id
end

-- TODO: Refazer spawn!!!
function spawn (daemons, qty, spawned, code)

end

---- End Public Methods ----
