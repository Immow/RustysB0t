local M = {
	cooldown = 10,
	removable = false,
	writeable = false
}

function M.get_info()
	return "test" .. os.date(" %M:%S")
end

return M
