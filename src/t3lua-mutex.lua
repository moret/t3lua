require("t3lua")

require("alua")


t3lua.mutex = {}
local _M = t3lua.mutex

t3lua.events["mutex_enter"] = "__mutex_enter__" -- Event generated when a process requests for entering in a critical region.
t3lua.events["mutex_reply"] = "__mutex_reply__" -- Event generated when a process replies a request for entering in a critical region.


_M.status = { ["FREE"] = "FREE", ["REQUESTING"] = "REQUESTING", ["BLOCKED"] = "BLOCKED" }

--[[ Table structure: Tridimentional array
|	mutex_idx [group name] [mutex name] [status]
|									    [replies]
|										[necessary] [NUMBER] x
|                                                   [list] id1, id2, id3 .. idx
|										[callback]
|										[callback_err]
|				...				...
--]]
local mutexes = {}
local DEFAULT_MUTEX = { ["status"] = _M.status.FREE,
                        ["replies"] = {},
                        ["necessary"] = { ["NUMBER"] = 0,
                                          ["list"] = {}
                                        },
                        ["callback"] = nil,
                        ["callback_err"] = nil
                      }


--[[
| Get the mutex structure. Creates a default mutex if necessary.
|
| @param group String containing the name of the group to which the mutex belongs.
| @param mutex String containing the name of the mutex.
| @return Mutex structure for the requested mutex in the specified group.
--]]
local function getMutex(group, mutex)	
	mutexes[group] = mutexes[group] or {}
	mutexes[group][mutex] = mutexes[group][mutex] or table.copy(DEFAULT_MUTEX)
	
	return mutexes[group][mutex]
end


--[[
| Requests entry to a critical zone by requiring access to a mutex.
|
| @param group Group in which request mutex access. [string]
| @param mutex Identifier of a mutex in the group. [string]
| @param cb Callback to be called when access to mutex is guaranteed. [function]
| @param cb_err Optional callback to be called if access to mutex is denied. [function]
--]]
function _M.enter(group, mutex, cb, cb_err)
	assert(group, "Parameter 'group' must not be nil.")
	assert(mutex, "Parameter 'mutex' must not be nil.")
	assert(cb, "Parameter 'cb' must not be nil.")
	
	local _mutex = getMutex(group, mutex)
	
	if _mutex.status == _M.status.REQUESTING then
		return false, "Mutex already being requested. Awaiting replies."
	elseif _mutex.status == _M.status.BLOCKED then
		return true, "Mutex already owned."
	end


	_mutex.status = _M.status.REQUESTING
	_mutex.replies = {}
	_mutex.necessary.list = {}
	_mutex.necessary.NUMBER = 0
	_mutex.callback = cb
	_mutex.callback_err = cb_err
	
	local msg = "getMembers('" .. group .. "', " ..
	                       "'" .. alua.id .. "', " ..
	                       "'__mutexDaemonGetMembers', "..
	                       "'" .. mutex .. "')"
	alua.send(alua.daemonid, msg)
	return true
end


--[[
| Exit the critical region by freeing the mutex.
--]]
function _M.leave(group, mutex)	
	assert(group, "Parameter 'group' must not be nil.")
	assert(mutex, "Parameter 'mutex' must not be nil.")
	
	local _mutex = getMutex(group, mutex)
	table.copy(DEFAULT_MUTEX, _mutex)
end


--[[
| Callback function that will be called by the daemon when it returns
| the list of group members.
| See t3lua-mutex.lua:_M.enter() and t3daemonscode.lua:getMembers().
--]]
function __mutexDaemonGetMembers(group, table_as_str, mutex)
	local members = loadstring("return " .. table_as_str)()
	local num_members = 0
	for _ in pairs(members) do -- Count number of members.
		num_members = num_members + 1
	end
	
	local _mutex = getMutex(group, mutex)

	_mutex.necessary.list = members
	_mutex.necessary.NUMBER = num_members

--[[ TODO Daemon version
	local msg = "mutexRequest('" .. alua.id .. "', " ..
	                         "'" .. table_as_str .. "', " ..
	                         "'" .. events.mutex_requrest .. "', " ..
	                         "'" .. group .. "', " ..
	                         "'" .. mutex .. "')"
	alua.send(alua.daemonid, msg)
--]]
	
	for dst in pairs(members) do
		print(alua.id .. " requesting " .. group .."." .. mutex .. " for " .. dst) --TODO DEBUG
		alua.send_event(dst, t3lua.events.mutex_enter, { ["group"] = group, ["mutex"] = mutex} )
	end
end


local function __mutexEventHandlerEnter(msg)
	local group = msg.data.group
	local mutex = msg.data.mutex
	
	print(alua.id .. " received request for " .. group .. "." .. mutex .. " by " .. msg.src) --TODO DEBUG
	
	local _mutex = getMutex(group, mutex)

	local reply
	if _mutex.status == _M.status.FREE or msg.src == alua.id then
		reply = "ok" 
	else
		reply = "no"
	end
	
	print(alua.id .. " said " .. reply) --TODO DEBUG
	
	local tab = { ["group"] = group, ["mutex"] = mutex, ["reply"] = reply }
	alua.send_event(msg.src, t3lua.events.mutex_reply, tab)
end


local function __mutexEventHandlerReply(msg)
	local group = msg.data.group
	local mutex = msg.data.mutex
	
	print(alua.id .. " received reply for " .. group .. "." .. mutex .. " from " .. msg.src .. ": " .. msg.data.reply) --TODO DEBUG
	
	local _mutex = getMutex(group, mutex)
	
	if _mutex.status ~= _M.status.REQUESTING then
		-- If already in the critical zone or no longer requiring entrace, do nothing.
		return
	end
	
	if msg.data.reply == "ok" then 
		table.insert(_mutex.replies, msg.src) --TODO Não verifica mensagens (repetidas, se são mesmo as necessárias...)
		if #_mutex.replies >= _mutex.necessary.NUMBER then
			_mutex.status = _M.status.BLOCKED
			_mutex.callback()
		end
	else
		-- Critical zone unavailable. Give up entering.
		_M.leave(group, mutex)
		print(alua.id .. " droped request.", _mutex.status) --TODO DEBUG
		if _mutex.callback_err then
			_mutex.callback_err()
		end
	end
end

alua.reg_event(t3lua.events.mutex_enter, __mutexEventHandlerEnter)
alua.reg_event(t3lua.events.mutex_reply, __mutexEventHandlerReply)
