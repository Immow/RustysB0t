local M = {}

function M.get_info()
	return "test" .. os.date(" %M:%S")
end

return M
