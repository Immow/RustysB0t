local socket = require("socket")
local Timers = {}
local last_used_times = {}

function Timers.is_on_cooldown(command_name, seconds)
	local now = socket.gettime()
	local last_used = last_used_times[command_name] or 0
	local elapsed = now - last_used

	if elapsed < seconds then
		return true, seconds - elapsed
	end

	last_used_times[command_name] = now
	return false, 0
end

return Timers
