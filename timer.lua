local Timers = {}

-- local function is_on_cooldown(command_name, seconds)
-- 	local now = os.time()
-- 	local last_used = timers[command_name] or 0

-- 	if now - last_used < seconds then
-- 		-- Still on cooldown
-- 		return true, seconds - (now - last_used)
-- 	end

-- 	-- Not on cooldown, update the timestamp
-- 	timers[command_name] = now
-- 	return false, 0
-- end

function Timers:is_on_cooldown(command_name, seconds)
	local now = os.time()
	local last_used = Timers[command_name] or 0

	if now - last_used < seconds then
		-- Still on cooldown
		return true, seconds - (now - last_used)
	end

	-- Not on cooldown, update the timestamp
	Timers[command_name] = now
	return false, 0
end

return Timers
