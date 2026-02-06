local M = {
	cooldown = 2,
	removable = false,
	writeable = false,
	current_poll = nil
}

function M.start(input, user)
	local parts = {}
	for part in input:gmatch("([^|]+)") do
		local cleaned = part:match("^%s*(.-)%s*$")
		if cleaned and cleaned ~= "" then table.insert(parts, tostring(cleaned)) end
	end

	local duration = 120
	local first_val = tonumber(parts[1])
	if first_val then duration = table.remove(parts, 1) end

	if #parts < 3 then return "Usage: !poll [seconds] | Question | Opt1 | Opt2" end

	local question = table.remove(parts, 1)
	M.current_poll = {
		question = question,
		options = parts,
		votes = {}, -- stores: user = {choice = index, bet = amount}
		active = true,
		ends_at = os.time() + duration
	}

	return string.format("POLL: %s — !vote <num> [bet]", question)
end

function M.vote(input, user, points_mod)
	if not M.current_poll or not M.current_poll.active then return nil end
	if M.current_poll.votes[user] then return "You already voted!" end

	-- Pattern captures the choice and an optional bet
	local choice_str, bet_str = input:match("(%d+)%s*(%d*)")
	local choice = tonumber(choice_str)
	local bet = tonumber(bet_str) or 0

	if not (choice and M.current_poll.options[choice]) then return "Invalid option." end

	if bet > 0 then
		local balance = points_mod.get_balance(user)
		if balance < bet then return "Not enough points to bet " .. bet end
		points_mod.add(user, -bet) -- Deduct bet immediately
	end

	M.current_poll.votes[user] = { choice = choice, bet = bet }
	print(string.format("[Poll] %s voted for %d (Bet: %d)", user, choice, bet))
	return nil
end

function M.get_results(points_mod)
	if not M.current_poll then return "No poll active." end

	local counts = {}
	for i = 1, #M.current_poll.options do counts[i] = 0 end

	for _, data in pairs(M.current_poll.votes) do
		counts[data.choice] = counts[data.choice] + 1
	end

	local winner_idx = 1
	for i = 2, #counts do
		if counts[i] > counts[winner_idx] then winner_idx = i end
	end

	-- Reward winners: return original bet + 100% (2x total)
	if points_mod then
		for voter, data in pairs(M.current_poll.votes) do
			if data.choice == winner_idx and data.bet > 0 then
				points_mod.add(voter, data.bet * 2)
			end
		end
	end

	local result = "WINNER: " .. M.current_poll.options[winner_idx] .. "!"
	M.current_poll.active = false
	return result
end

function M.get_info()
	if M.current_poll and M.current_poll.active then
		return "Poll active: " .. M.current_poll.question
	end
	return "No active poll."
end

return M
