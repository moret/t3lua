require("socket")

math.randomseed(os.time())

function sleep(sec)
	--print("going to sleep for a while...")
	socket.select(nil, nil, sec)
end

function getRandom(num)
	return math.random(num)
end

function log(msg)
	if __debug then print(msg) end
end

function testFunction(...)
	print("Teste")
end

function table.val_to_str ( v )
	if "string" == type( v ) then
		v = string.gsub( v, "\n", "\\n" )
		if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
			return "'" .. v .. "'"
		end
		return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
	else
		return "table" == type( v ) and table.tostring( v ) or
			tostring( v )
	end
end


function table.key_to_str ( k )
	if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
		return k
	else
		return "[" .. table.val_to_str( k ) .. "]"
	end
end


--[[
| @brief Converts a table to a string.
| Produces a compact, uncluttered representation of a table.
| Mutual recursion is employed. 
| Taken from lua-users wiki (http://lua-users.org/wiki/TableUtils).
--]]
function table.tostring( tbl )
	if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
		return k
	else
		local result, done = {}, {}
		for k, v in ipairs( tbl ) do
			table.insert( result, table.val_to_str( v ) )
			done[ k ] = true
		end
		for k, v in pairs( tbl ) do
			if not done[ k ] then
				table.insert( result,
					table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
			end
		end
		return "{" .. table.concat( result, "," ) .. "}"
	end
end


function table.copy(orig_table, dest_table, recursive, copy_metatable)
	assert(orig_table, "Parameter 'orig_table' must not be nil.")
	dest_table = dest_table or {}
	
	for key, value in pairs(orig_table) do
		if recursive and type(value) == "table" then
			dest_table[key] = {}
			table.copy(value, dest_table[key], recursive, copy_metatable)
		else
			dest_table[key] = value
		end
	end
	
	if copy_metatable then
		setmetatable(dest_table, getmetatable(orig_table))
	end
	
	return dest_table
end