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

	local cmd_data = command_map[cmd_name]

	if cmd_data then
		local on_cooldown, time_left = timer.is_on_cooldown(cmd_name, cmd_data.cooldown)
		if on_cooldown then
			-- Log the precise float to your CachyOS terminal for debugging
			print(string.format("[Timer] %s is on cooldown: %.1fs left", cmd_name, time_left))

			-- Send a cleaner, rounded version to Twitch chat
			local chat_msg = string.format("Slow down! !%s is on cooldown (wait %.0fs).", cmd_name, time_left)
			client:send("PRIVMSG " .. config.chan .. " :" .. chat_msg .. "\r\n")
		else
			local output = cmd_data.module.get_info()
			client:send("PRIVMSG " .. config.chan .. " :" .. output .. "\r\n")
			print("[Bot] Sent: " .. output)
		end
	end
end

return Commands
