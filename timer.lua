local Timers = {}
local last_used_times = {}

function Timers.is_on_cooldown(command_name, seconds)
	local now = os.time()
	local last_used = last_used_times[command_name] or 0

	if now - last_used < seconds then
		return true, seconds - (now - last_used)
	end

	last_used_times[command_name] = now
	return false, 0
end

return Timers
