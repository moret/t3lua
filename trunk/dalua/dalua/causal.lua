-- DALua Causal Order Module
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
local unpack = unpack

-- End Imports --

module(...)
local dalua = require(string.sub(_PACKAGE, 1, #_PACKAGE - 1))
local alua = dalua.alua
__dalua = dalua

-- Global Properties --

debug = false

forcedelay = false

delaycondition = function (msg)
    if math.random(100) < 20 then
        return true
    else
        return false
    end
end

-- End Global Properties --

local NUM_PROCS = 2
local earliest = {}
local blocked = {}
local delivery_list = {}
local my_vt = {}
local sort_inx = 1
local msgwaiting = {}

function table.copy(t)
    local newt = {}
    for p in pairs(t) do newt[p] = t[p] end
    return newt
end

function __receive(...)
    local timestamp = table.copy(arg[1])
    local id = arg[2]
    -- arg[3] = fc
    -- arg[4] = args
    local p = inx(id)
    delivery_list = {}
    if table.getn(blocked[p]) == 0 then
        earliest[p] = table.copy(timestamp)
    end
    table.insert(blocked[p], {["timestamp"] = timestamp, ["id"] = id, 
	["func"] = arg[3], ["args"] = arg[4]})
    for k = 1, NUM_PROCS do
        if table.getn(blocked[k]) > 0 then
	    local deliver = true
            for i = 1, NUM_PROCS do
	    --  print("i="..i..", k="..k..", inx="..dalua.getindex(dalua.self())..", erlst="..printtable(earliest)..", not_erl="..tostring(not_earlier(earliest[i], earliest[k], i))..", arg="..arg[4][1]..", ts="..printtable(timestamp).." from="..dalua.getindex(id))
                if i ~= k and i ~= inx(dalua.self()) 
		and not not_earlier(earliest[i], earliest[k], i) then
		    --print("deliver false")
		    deliver = false
		    break
                end
            end
	    if deliver then
	        local msg = table.remove(blocked[k], 1)
		table.insert(delivery_list, msg)
                if table.getn(blocked[k]) > 0 then
                    earliest[k] = table.copy(blocked[k][1].timestamp)
                else
                    earliest[k][k] = earliest[k][k] + 1
                end		
            end
        end
    end

    for i = 1, NUM_PROCS do
        --print("i="..i.." ts1: "..timestamp[i].." ts2: "..my_vt[i])
        if timestamp[i] > my_vt[i] then 
            my_vt[i] = timestamp[i]
        end
    end
    if table.getn(delivery_list) > 0 then
        processa(delivery_list, p)
    end
end

function __pre_receive(...)
    --print("pre_receive de "..alua.id)
    if causal.delaycondition(arg) then
	if debug then
		print("[dalua.causal]["..dalua.getindex(dalua.self()).."] delayed message from ["..dalua.getindex(arg[2]).."]")
	end
        table.insert(msgwaiting, arg)
    else
        __receive(unpack(arg))
	if table.getn(msgwaiting) > 0 then
	    for _,v in ipairs(msgwaiting) do
	        __receive(unpack(v))
	    end
            msgwaiting = {}
        end
    end
end

function deliverwaiting()
    if table.getn(msgwaiting) > 0 then
	for _,v in ipairs(msgwaiting) do
	    __receive(unpack(v))
	end
        msgwaiting = {}
    end
end

local function processa(msgs, proc)
    sort_inx = proc
    if table.getn(msgs) > 1 then
        table.sort(msgs, cmp_msgs)
    end
    for i, m in msgs do
        assert(loadstring(m.func..'(unpack('..ad_aux.serialize(m.args)..'))'))()
    end
end

local function inx(id)
    return dalua.getindex(id) + 1
end

local function not_earlier(my_ts, msg_ts, i)
    if msg_ts[i] < my_ts[i] then
        return true
    else
        return false
    end
end
                        
local function cmp_msgs(m1, m2)
    local menor = true
    for i = 1, NUM_PROCS do
      if not_earlier (m1.timestamp, m2.timestamp, i) then 
        menor = false
        break
      end
    end
    return menor
end

function send(procs, fc, ...)
    --print("causal_send "..dalua.self().." "..inx(dalua.self()))
    my_vt[inx(dalua.self())] = my_vt[inx(dalua.self())] + 1
    if forcedelay then
	recvfun = "__dalua.causal.__pre_receive"
    else
        recvfun = "__dalua.causal.__receive"
    end
    for _,p in ipairs(procs) do
        if p ~= dalua.self() then
            dalua.send(p, recvfun, my_vt, dalua.self(), fc, arg)
	end
    end
end

function init(procs)
    NUM_PROCS = table.getn(procs)
    for i = 1, NUM_PROCS do
        table.insert(earliest, {})
        table.insert(blocked, {})
        my_vt[i] = 0
    end
    print("NUM_PROCS="..NUM_PROCS)
    for i = 1, NUM_PROCS do
        for j = 1, NUM_PROCS do
            if i == j then
                earliest[i][j] = 1
            else
                earliest[i][j] = 0
            end
        end
    end
end
