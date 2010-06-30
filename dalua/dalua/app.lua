-- DALua Application Module
-- Part of DALua Library v2.1
-- Written by Ricardo Costa (rcosta@inf.puc-rio.br)

-- Imports --

local _G = _G
local assert = assert
local ipairs = ipairs
local io = io
local loadstring = loadstring
local pairs = pairs
local print = print
local require = require
local string = string
local table = table

-- End Imports --

module(...)
local dalua = require(string.sub(_PACKAGE, 1, #_PACKAGE - 1))
local alua = dalua.alua
__dalua = dalua

-------------------------------------

-- Enable/Disable debug messages
    debug = false

-------------------------------------

loaded = false

local network = {}
local apps = {}
local appsdaemon = {} --> used in daemon only

local create_daemon_reply_count --> used in daemon only
local create_from 		--> used in daemon only
local link_daemon_reply_count 	--> used in daemon only
local destroy_daemon_reply_count --> used in daemon only
local destroy_from 		--> used in daemon only

---- INIT ----

function init()
	print("init", dalua.daemon())
	network = {dalua.daemon()}
	dalua.send(dalua.daemon(), "__dalua.app.__daemon_init", alua.id)
end

function __daemon_init(id)
	if loaded then
		dalua.send(id, "__dalua.app.__init_reply", true)
		return
	end
	local function mutex_create_cb( event, result, mutexid )
		if mutexid == "__dalua_app_daemons" then
			if not result == "success" then
				if dalua.debug then
					print("[dalua.app][error] Cannot create mutex for daemon.")
				end
				dalua.send(id, "__dalua.app.__init_reply", false)
			end
			loaded = true
			network = {dalua.self()}
			dalua.send(id, "__dalua.app.__init_reply", true)
		end
	end
	dalua.events.monitor("dalua_mutex_create", mutex_create_cb)
	if not dalua.mutex.create("__dalua_app_daemons", {dalua.self()}) then
		-- already created
		if dalua.debug then
			print("[dalua.app][error] Cannot create mutex for daemon (already created).")
		end
		dalua.send(id, "__dalua.app.__init_reply", false)
	end
end

function __init_reply(result)
	if debug then
		if result then
			print("[dalua.app][info] Application module initialized.")
		else
			print("[dalua.app][error] Application module initialization failed.")
		end
	end
	if result then
		loaded = true
		dalua.events.raise("dalua_app_init", dalua.self(), "success")
	else
		loaded = false
		dalua.events.raise("dalua_app_init", dalua.self(), "error")
	end
end

---- CREATE ----

function create(app)
	if apps[app] then
		if debug then
			print("[dalua.app][error] Application '"..app.."' already created.")
		end
		dalua.events.raise("dalua_app_create", dalua.self(), "error", app, 
					"ERROR_ALREADY_CREATED")
		return
	end
	dalua.send(dalua.daemon(), "__dalua.app.__daemon_create", dalua.self(), app)
end

function __daemon_create(from, app)
	local function daemons_cs()
		create_daemon_reply_count = #network
		create_from = from
		dalua.send(network, "__dalua.app.__daemon_create_request", dalua.self(), app)
	end
	if not dalua.mutex.enter("__dalua_app_daemons", daemons_cs) then
		dalua.send(from, "__create_failed", app, "ERROR_ENTER_MUTEX")
	end
end

function __create_failed(app, reason)
	if debug then
		print("[dalua.app][error] Could not create application '" .. app .. "': " .. reason)
	end
	dalua.events.raise("dalua_app_create", dalua.self(), "error", app, reason)
end

function __daemon_create_request(from, app)
	if appsdaemon[app] then
		dalua.send(from, "__dalua.app.__daemon_create_request_reply", dalua.self(), app, false)
	else
		dalua.send(from, "__dalua.app.__daemon_create_request_reply", dalua.self(), app, true)
	end
end

function __daemon_create_request_reply(id, app, result)
	if not create_daemon_reply_count then
		return
	end
	if result == false then
		dalua.send(create_from, "__dalua.app.__create_failed", app, "ERROR_ALREADY_EXISTS")
		if debug then
			print("[dalua.app][error] Application '"..app..
				"' already created on daemon '" .. id .. "'.")
		end
		create_daemon_reply_count = nil
		create_from = nil
		return
	end
	create_daemon_reply_count = create_daemon_reply_count - 1
	if create_daemon_reply_count == 0 then
		create_daemon_reply_count = #network
		dalua.send(network, "__dalua.app.__daemon_create_confirm", dalua.self(), 
				create_from, app)
	end
end

function __daemon_create_confirm(fromdaemon, fromproc, app)
	appsdaemon[app] = {}
	if dalua.self() == fromdaemon then
		appsdaemon[app].localprocs = {fromproc}
	else
		appsdaemon[app].localprocs = {}
	end
	appsdaemon[app].globalprocs = {fromproc}
	dalua.send(fromdaemon, "__dalua.app.__daemon_create_confirm_reply", app)
end

function __daemon_create_confirm_reply(app)
	create_daemon_reply_count = create_daemon_reply_count - 1
	if create_daemon_reply_count == 0 then
		dalua.send(create_from, "__dalua.app.__create_completed", app)
		create_daemon_reply_count = nil
		create_from = nil
		dalua.mutex.leave("__dalua_app_daemons")
	end
end

function __create_completed(app)
	apps[app] = {}
	apps[app].procs = {dalua.self()}
	apps[app].state = "CREATED"
	if debug then
		print("[dalua.app][info] Application '"..app.."' created.")
	end
	dalua.events.raise("dalua_app_create", dalua.self(), "success", app)
end

---- JOIN ----

function join(app)
	if apps[app] then
		if debug then
			print("[dalua.app][error] Process '"..dalua.self()..
				"' is already part of '"..app.."'.")
		end
		dalua.events.raise("dalua_app_join", dalua.self(), "error", app, 
					"ERROR_ALREADY_JOINED")
		return
	end
	dalua.send(dalua.daemon(), "__dalua.app.__daemon_query_join_app", dalua.self(), app)
end

function __daemon_query_join_app(from, app)
	if appsdaemon[app] then
		for _, p in ipairs(appsdaemon[app].localprocs) do
			if from == p then
				dalua.send(from, "__dalua.app.__join_failed", app,
						"ERROR_ALREADY_PART")
				return
			end
		end
		dalua.send(from, "__dalua.app.__query_join_app_reply", app, 
				appsdaemon[app].globalprocs)
	else
		dalua.send(from, "__dalua.app.__join_failed", app, "ERROR_NOT_EXISTS")
	end
end

function __join_failed(app, reason)
	if debug then
		if reason == "ERROR_ALREADY_PART" then
			print("[dalua.app][error] Process '"..dalua.self()..
				"' is already part of '"..app.."'.")
		elseif reason == "ERROR_NOT_EXISTS" then
			print("[dalua.app][error] Application '"..app..
				"' does not exist.")
		end
	end
	dalua.events.raise("dalua_app_join", dalua.self(), "error", app, reason)
end

function __query_join_app_reply(app, procs)
	apps[app] = {}
	apps[app].state = "JOINING"
	apps[app].procs = procs
	apps[app].daemons_reply_count = #network
	dalua.send(network, "__dalua.app.__daemon_join_request", dalua.daemon(), dalua.self(), app)
end

function __daemon_join_request(fromdaemon, from, app)
	table.insert(appsdaemon[app].globalprocs, from)
	if fromdaemon == dalua.self() then
		table.insert(appsdaemon[app].localprocs, from)
	end
	if #appsdaemon[app].localprocs > 0 then
		dalua.send(appsdaemon[app].localprocs, "__dalua.app.__join_request", from, app)
	end
	dalua.send(from, "__dalua.app.__join_reply", app)
end

function __join_request(from, app)
	table.insert(apps[app].procs, from)
	if from ~= dalua.self() then
		dalua.events.raise("dalua_app_join", dalua.self(), "success", app, from)
	end
end

function __join_reply( app )
	apps[app].daemons_reply_count = apps[app].daemons_reply_count - 1
	if apps[app].daemons_reply_count == 0 then
		apps[app].state = "JOINED"
		if debug then
			print("[dalua.app][info] Joined application '"..app.."'.")
		end
		dalua.events.raise("dalua_app_join", dalua.self(), "success", app, dalua.self())
	end
end

---- LEAVE ----

function leave(app)
	if not apps[app] then
		if debug then
			print("[dalua.app][error] Process '"..dalua.self().. 
				"' is not part of '"..app.."'.")
		end
		dalua.events.raise("dalua_app_leave", dalua.self(), "error", app, 
					"ERROR_NOT_PART")
		return
	end
	dalua.send(dalua.daemon(), "__dalua.app.__daemon_query_leave_app", dalua.self(), app)
end

function __daemon_query_leave_app(from, app)
	if appsdaemon[app] then
		for _, p in ipairs(appsdaemon[app].localprocs) do
			if from == p then
				dalua.send(from, "__dalua.app.__query_leave_app_reply", app)
				return
			end
		end
		--precisa?
		--dalua.send(from, "__dalua.app.__leave_failed", app, "ERROR_NOT_PART")		
	else
		dalua.send(from, "__dalua.app.__leave_failed", app, "ERROR_NOT_EXISTS")
	end
end

function __leave_failed(app, reason)
	if debug then
		if reason == "ERROR_NOT_PART" then
			print("[dalua.app][error] Process '"..dalua.self()..
				"' is not part of '"..app.."'.")
		elseif reason == "ERROR_NOT_EXISTS" then
			print("[dalua.app][error] Application '"..app..
				"' does not exist.")
		end
	end
	dalua.events.raise("dalua_app_leave", dalua.self(), "error", app, reason)
end

function __query_leave_app_reply(app)
	apps[app].state = "LEAVING"
	apps[app].daemons_reply_count = #network
	dalua.send(network, "__dalua.app.__daemon_leave_request", dalua.self(), app)
end

function __daemon_leave_request(from, app)
	if #appsdaemon[app].localprocs > 0 then
		dalua.send(appsdaemon[app].localprocs, "__dalua.app.__leave_request", from, app)
	end
	for i, p in ipairs(appsdaemon[app].localprocs) do
		if p == from then
			table.remove(appsdaemon[app].localprocs, i)
			break
		end
	end
	for i, p in ipairs(appsdaemon[app].globalprocs) do
		if p == from then
			table.remove(appsdaemon[app].globalprocs, i)
			break
		end
	end
	dalua.send(from, "__dalua.app.__leave_reply", app)
end

function __leave_request(from, app)
	for i, p in ipairs(apps[app].procs) do
		if p == from then
			table.remove(apps[app].procs, i)
			break
		end
	end
	if from ~= dalua.self() then
		dalua.events.raise("dalua_app_leave", dalua.self(), "success", app, from)
	end
end

function __leave_reply(app)
	apps[app].daemons_reply_count = apps[app].daemons_reply_count - 1
	if apps[app].daemons_reply_count == 0 then
		apps[app] = nil
		if debug then
			print("[dalua.app][info] Left application '"..app.."'.")
		end
		dalua.events.raise("dalua_app_leave", dalua.self(), "success", app, dalua.self())
	end
end

---- DESTROY ----

function destroy(app)
	if not apps[app] then
		if debug then
			print("[dalua.app][error] Could not destroy '"..app..
				"': Application does not exist.")
			return
		end
		dalua.events.raise("dalua_app_destroy", dalua.self(), "error", app,
					"ERROR_NOT_EXISTS")
	end
	dalua.send(dalua.daemon(), "__dalua.app.__daemon_destroy", dalua.self(), app)
end

function __daemon_destroy(from, app)
	local function mutexcs()
		destroy_daemons_reply_count = #network
		destroy_from = from
		dalua.send(network, "__dalua.app.__daemon_destroy_request", dalua.self(), app)
	end
	if not dalua.mutex.enter("__dalua_app_daemons", mutexcs) then
		dalua.send(from, "__dalua.app.__destroy_failed", app, "ERROR_ENTER_MUTEX")
	end
end

function __destroy_failed(app, reason)
	if debug then
		print("[dalua.app][error] Could not destroy '"..app..
			"': " .. reason)
	end
	dalua.events.raise("dalua_app_destroy", dalua.self(), "error", app, reason)
end

function __daemon_destroy_request(from, app)
	if not appsdaemon[app] then
		if debug then
			print("[dalua.app][warning] Application '"..app..
				"'does not exist on daemon '"..dalua.self().."'.")
		end
	else
		dalua.send(appsdaemon[app].localprocs, "__dalua.app.__destroy_request", app)
	end
	appsdaemon[app] = nil
	dalua.send(from, "__dalua.app.__daemon_destroy_request_reply")
end

function __destroy_request(app)
	if not apps[app] then
		if debug then
			print("[dalua.app][warning] Application '"..app..
				"'does not exist on process '"..dalua.self().."'.")
		end
		return
	end
	apps[app] = nil
	dalua.events.raise("dalua_app_destroy", dalua.self(), "success", "local", app)
end

function __daemon_destroy_request_reply()
	destroy_daemons_reply_count = destroy_daemons_reply_count - 1
	if destroy_daemons_reply_count == 0 then
		destroy_daemons_reply_count = nil
		dalua.events.raise("dalua_app_destroy", destroy_from, "success", "global", app)
		destroy_from = nil
		dalua.mutex.leave("__dalua_app_daemons")
	end
end

---- LINK ----

function link(arg1, arg2)
	local daemonid = (arg2 and arg1..":"..arg2) or arg1
	dalua.send(daemonid, "__dalua.app.__daemon_link_request", dalua.self(), dalua.daemon())
end

function __daemon_link_request(fromproc, fromdaemon)
	local function mutex_cs()
		link_daemon_leave_pending = true
		dalua.send(fromdaemon, "__dalua.app.__daemon_link_daemons_cs", dalua.self())
	end
	local function mutex_add_done()
		dalua.events.ignore("dalua_mutex_add", mutex_add_done)
		if not dalua.mutex.enter("__dalua_app_daemons", mutex_cs) then
			if debug then
				print("[dalua.app][error] Link failed: could not enter daemon's critical section.")
			end
			dalua.events.raise("dalua_app_link", fromproc, "error", "ERROR_MUTEX_ENTER")
		end
	end
	dalua.events.monitor("dalua_mutex_add", mutex_add_done)
	dalua.mutex.add("__dalua_app_daemons", fromdaemon)
end

function __daemon_link_daemons_cs(todaemon)
	dalua.send(todaemon, "__dalua.app.__daemon_link_applist_request", dalua.self())
end

function __daemon_link_applist_request(from)
	local list = {}
	for app, procs in pairs(appsdaemon) do
		list[app] = procs.globalprocs
	end
	dalua.send(from, "__dalua.app.__daemon_link_applist_reply", network, list)
end

function __daemon_link_applist_reply(daemonlist, applist)
	local myapps = {}
	for myapp, myprocs in pairs(appsdaemon) do
		if not applist[myapp] then
			myapps[myapp] = myprocs.globalprocs
		end
	end
	for _, d in ipairs(daemonlist) do
		table.insert(network, d)
	end
	dalua.send(dalua.__daemon_procs(), "__dalua.app.__link_applist_merge", daemonlist, applist)
	link_daemon_reply_count = #daemonlist
	for app, procs in pairs(applist) do
		if appsdaemon[app] then
			-- Application already exists, will be overridden
			if debug then
				print("[dalua.app][warning] Application '"..app..
					"' is being overridden due to app.link.")
			end			
		end
		appsdaemon[app] = {}
		appsdaemon[app].globalprocs = procs
		appsdaemon[app].localprocs = {}
	end
	dalua.send(daemonlist, "__dalua.app.__daemon_link_applist_merge", dalua.self(), myapps)
end

function __daemon_link_applist_merge(from, list)
	table.insert(network, from)
	dalua.send(dalua.__daemon_procs(), "__dalua.app.__link_applist_merge", {from}, list)
	for app, procs in pairs(list) do
		appsdaemon[app] = {}
		appsdaemon[app].globalprocs = procs
		appsdaemon[app].localprocs = {}
	end
	dalua.send(from, "__dalua.app.__daemon_link_applist_merge_reply")
end

function __link_applist_merge(daemonlist, applist)
	for _, d in ipairs(daemonlist) do
		table.insert(network, d)
	end
	for app, procs in pairs(applist) do
		if apps[app] then
			apps[app] = {}
			apps[app].state = "LINKED"
			apps[app].procs = procs
		end
	end
end

function __daemon_link_applist_merge_reply()
	link_daemon_reply_count = link_daemon_reply_count - 1
	if link_daemon_reply_count == 0 then
		dalua.send(network, "__dalua.app.__daemon_link_completed", dalua.self())
	end
end

function __daemon_link_completed(daemon)
	if link_daemon_leave_pending then
		link_daemon_leave_pending = nil	
		dalua.mutex.leave("__dalua_app_daemons")
	end
	dalua.events.raise("dalua_app_link", dalua.__daemon_procs(), "success", daemon)
end

---- OTHER -----

function processes( app )
	if apps[app] then
		return apps[app].procs
	end
end

function applications( )
	local ret = {}
	for k in pairs(apps) do
		table.insert(ret, k)
	end
	return ret
end

