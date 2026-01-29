local timer = require("timer")
local Commands = {}

-- A table to map !command to its module file
local command_map = {
	song = require("modules.song")
}

function Commands.handle(line, client, config)
	-- 1. Find the message part of the IRC line (after the second colon)
	local chat_message = line:match("^:%w+!%w+@%w+%.tmi%.twitch%.tv PRIVMSG #%w+ :(.*)$")

	if not chat_message then return end -- Not a chat message, ignore it

	-- 2. Extract the command from the isolated chat message
	local cmd_name = chat_message:lower():match("^!(%a+)")

	if cmd_name and command_map[cmd_name] then
		local on_cooldown, time_left = timer.is_on_cooldown(cmd_name, 10)

		if on_cooldown then
			print("[Timer] " .. cmd_name .. " is on cooldown.")
		else
			local output = command_map[cmd_name].get_info()
			client:send("PRIVMSG " .. config.chan .. " :" .. output .. "\r\n")
			print("[Bot] Sent: " .. output)
		end
	end
end

return Commands
