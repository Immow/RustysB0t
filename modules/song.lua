local M = {}

function M.get_info()
	local handle = io.popen("playerctl -p spotify metadata --format '{{title}} by {{artist}} 🎶 {{url}}' 2>/dev/null")

	if not handle then
		return "Error: Could not open pipe to playerctl."
	end

	local result = handle:read("*a")
	handle:close()

	if result == nil or result == "" then
		return "Spotify is currently chilling (not playing)."
	end

	return "Current Song: " .. result:gsub("^%s*(.-)%s*$", "%1")
end

return M
