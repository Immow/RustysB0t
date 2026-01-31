local M = {
	cooldown = 2,
	removable = false,
	writeable = false,
	current_poll = nil -- This will store the question, options, and votes
}

-- Usage: !poll question | option1 | option2 | option3
-- modules/poll.lua

function M.start(input, user)
	local parts = {}
	for part in input:gmatch("([^|]+)") do
		local cleaned = part:match("^%s*(.-)%s*$")
		if cleaned and cleaned ~= "" then table.insert(parts, tostring(cleaned)) end
	end

	-- Default to 2 minutes (120s) if no number is found at the start
	local duration = 120
	local first_val = tonumber(parts[1])
	if first_val then
		duration = table.remove(parts, 1)
	end

	if #parts < 3 then
		return "Usage: !poll [seconds] | Question | Opt1 | Opt2"
	end

	local question = table.remove(parts, 1)
	M.current_poll = {
		question = question,
		options = parts,
		votes = {},
		active = true,
		ends_at = os.time() + duration -- The "Alarm Clock"
	}

	return string.format("POLL (Ends in %ds): %s — Vote with !vote <num>", duration, question)
end

-- (The rest of M.vote and M.get_results remains the same as before)

function M.vote(input, user)
	if not M.current_poll or not M.current_poll.active then
		return nil
	end

	-- 1. Check if the user has already voted
	if M.current_poll.votes[user] then
		-- Optional: print to your CachyOS terminal for debugging
		print(string.format("[Poll] Ignored repeat vote from: %s", user))
		return nil
	end

	-- 2. Validate the choice
	local choice = tonumber(input:match("%d+"))
	if choice and M.current_poll.options[choice] then
		M.current_poll.votes[user] = choice
		print(string.format("[Poll] %s voted for %d", user, choice))
		return nil
	end
end

function M.get_results()
	if not M.current_poll then return "No poll has been run." end

	local counts = {}
	for i = 1, #M.current_poll.options do counts[i] = 0 end

	local total = 0
	for _, choice in pairs(M.current_poll.votes) do
		counts[choice] = counts[choice] + 1
		total = total + 1
	end

	local result = "POLL RESULTS: " .. M.current_poll.question .. " — "
	for i, opt in ipairs(M.current_poll.options) do
		local percent = total > 0 and (counts[i] / total * 100) or 0
		result = result .. string.format("%s: %d (%.0f%%) | ", opt, counts[i], percent)
	end

	M.current_poll.active = false -- Close the poll
	return result .. "Total votes: " .. total
end

-- This is required by your existing bot logic, but we will use the functions above
function M.get_info()
	if M.current_poll and M.current_poll.active then
		return "Current Poll: " .. M.current_poll.question .. " (Use !vote to participate!)"
	end
	return "No active poll. Broadcaster can start one with !poll question | opt1 | opt2"
end

return M
