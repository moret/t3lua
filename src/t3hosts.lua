t3hosts = {
	{addr = "127.0.0.1", port = 11111},
	{addr = "127.0.0.1", port = 11112},
	{addr = "127.0.0.1", port = 11113},
	{addr = "127.0.0.1", port = 11114},
	{addr = "127.0.0.1", port = 11115},
	getDaemonString = function(host)
		return host.addr .. ":" .. host.port .. "/0"
	end,
	getDaemonsAsString = function()
		local hosts = {}
		for _, host in ipairs(t3hosts) do
			hosts[#hosts + 1] = t3hosts.getDaemonString(host)
		end
		return hosts
	end
}
