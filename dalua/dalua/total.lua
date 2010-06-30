-- DALua Total Order Module
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
local tonumber = tonumber

-- End Imports --

module(...)
local dalua = require(string.sub(_PACKAGE, 1, #_PACKAGE - 1))
local alua = dalua.alua
__dalua = dalua

NUM_PROCS = 0
lastid = 0
Fmax = 0
Pmax = 0
holdlist = {}
proplist = {}
msgnum = 0

function rec_request(from, msg)
    print("["..ad.getindex(ad.self()).."] recebe request: "..msg.value.." id="..msg.id)
    Fmax = math.floor(Fmax)
    Pmax = math.floor(Pmax)
    local propid = math.max(Fmax,Pmax) + 1 + ad.getindex(ad.self())/NUM_PROCS
    Pmax = propid
    msg.id = propid
    ad.send(from, "rec_proposed", msg)    
    msg.agreed = false
    table.insert(holdlist, msg)
    table.sort(holdlist, sort_holdlist)
end

function rec_proposed(msg)
    print("["..ad.getindex(ad.self()).."] propoe id para "..msg.value..": "..msg.id)
    if proplist[msg.handle] == nil then
        proplist[msg.handle] = {}
    end
    table.insert(proplist[msg.handle], msg)
    if table.getn(proplist[msg.handle]) == NUM_PROCS then
        table.sort(proplist[msg.handle], sort_proplist)
        local agreed = proplist[msg.handle][1].id
        lastid = agreed
        print("agreed id: "..agreed)
        ad.send(ad.processes("app"), "rec_agreed", proplist[msg.handle][1])
    end
end

function rec_agreed(msg)
    Fmax = msg.id
    for _, m in ipairs(holdlist) do
        if m.handle == msg.handle then
            m.id = msg.id
	    m.agreed = true
            table.sort(holdlist, sort_holdlist)
            break
        end
    end
    
    local removed
    repeat
        removed = false
        for i, m in ipairs(holdlist) do
            if m.agreed then
	        processa(msg)
	        table.remove(holdlist, i)
		removed = true
	        break
            end
        end
    until removed == false
end

function processa(msg)
    print("["..ad.getindex(ad.self()).."] processou a mensagem: "..msg.value)
end

function sort_holdlist(m1, m2)
    if m1.id < m2.id then
        return true
    else
        return false
    end
end

function sort_proplist(m1, m2)
    if m1.id > m2.id then
        return true
    else
        return false
    end
end

function pedir(primeiro, val)
    if msgnum == 0 then
        msgnum = val
    else
        msgnum = msgnum + 1
    end
    print("["..ad.getindex(ad.self()).."] efetuando pedido, começando em "..primeiro)
    local msg = { value = "Msg Nº "..msgnum, id = lastid + msgnum, handle = ad.self()..":"..msgnum }
    for i = 0, NUM_PROCS - 1 do
      n = math.mod((i + primeiro) , NUM_PROCS)
      print("pedindo para "..n)
      ad.addtimer("app", ad.getid("app", n), 1*(n+1), 1, "rec_request", ad.self(), msg)
    end
end

function inicio(procs)
   --ad.debug=true
    NUM_PROCS = table.getn(procs)
    print("NUM_PROCS="..NUM_PROCS)
end

