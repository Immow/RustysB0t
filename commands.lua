local timer = require("timer")

local Commands = {}

-- Pass the client, config, and the specific spotify function into this module
function Commands.handle(line, client, config, get_spotify_info)
	-- Normalize the line to lowercase for easier matching
	local message = line:lower()

	if message:match("!song") then
		local on_cooldown, time_left = timer.is_on_cooldown("spotify", 10)

		if on_cooldown then
			print("[Timer] !song is on cooldown: " .. time_left .. "s left")
		else
			local song_info = get_spotify_info()
			client:send("PRIVMSG " .. config.chan .. " :" .. song_info .. "\r\n")
			print("[Bot] Sent Song Info: " .. song_info)
		end
	end

	-- You can easily add more commands here!
end

return Commands
