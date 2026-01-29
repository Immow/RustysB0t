local timer = require("timer")
local Commands = {}

-- A table to map !command to its module file
local command_map = {
	song = { module = require("modules.song"), cooldown = 10 },
	test = { module = require("modules.test"), cooldown = 2 },
}

function Commands.handle(line, client, config)
	local chat_message = line:match("^:%w+!%w+@%w+%.tmi%.twitch%.tv PRIVMSG #%w+ :(.*)$")
	if not chat_message then return end

	local cmd_name = chat_message:lower():match("^!(%a+)")

	-- 1. Get the command data from your map first
	local cmd_data = command_map[cmd_name]

	if cmd_data then
		-- 2. Use cmd_data to get the module and specific cooldown
		local on_cooldown, time_left = timer.is_on_cooldown(cmd_name, cmd_data.cooldown)
		-- print(on_cooldown, time_left)

		if on_cooldown then
			-- Note: string.format helps keep these prints clean
			print(string.format("[Timer] %s is on cooldown: %.1fs left", cmd_name, time_left))
		else
			print("cow")
			-- 3. Access the module stored inside cmd_data
			local output = cmd_data.module.get_info()
			client:send("PRIVMSG " .. config.chan .. " :" .. output .. "\r\n")
			print("[Bot] Sent: " .. output)
		end
	end
end

return Commands
