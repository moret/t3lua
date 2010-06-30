require("t3lua")

function tf()
	print("tf has been called!")
end

t3lua.join("testGroup", tf)

