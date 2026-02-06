local M = {
	cooldown = 0,
	removable = false,
	writeable = false,
	data_path = "points_db.lua"
}

M.users = {}

-- Load points from the local file
function M.load()
	local f = loadfile(M.data_path)
	if f then
		M.users = f() or {}
	else
		M.users = {}
	end
end

-- Save points to the local file
function M.save()
	local f = io.open(M.data_path, "w")
	if f then
		f:write("return {\n")
		for user, amt in pairs(M.users) do
			f:write(string.format("  [%q] = %d,\n", user, amt))
		end
		f:write("}")
		f:close()
	end
end

function M.add(user, amount)
	M.users[user] = (M.users[user] or 0) + amount
	-- Auto-save occasionally or on every add for safety
	M.save()
end

function M.get_balance(user)
	return M.users[user] or 0
end

-- Initialize on load
M.load()

return M
