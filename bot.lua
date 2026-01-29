local socket = require("socket")
local config = require("config")
local is_on_cooldown = require("timer")

-- Function to grab live Spotify data via playerctl
local function get_spotify_info()
	local handle = io.popen("playerctl -p spotify metadata --format '{{title}} by {{artist}} 🎶 {{url}}' 2>/dev/null")

	if not handle then
		return "Error: Could not open pipe to playerctl."
	end

	local result = handle:read("*a")
	handle:close()

	-- Clean up the result and check if it's empty
	if result == nil or result == "" then
		return "Spotify is currently chilling (not playing)."
	end

	-- Trim whitespace and return
	return "Current Song: " .. result:gsub("^%s*(.-)%s*$", "%1")
end

-- Connect to Twitch
local client = socket.tcp()
client:settimeout(10) -- Keep the timeout
local ok, err = client:connect(config.server, config.port)

if not ok then
	print("Failed to connect: " .. err)
	os.exit()
end

-- Login
client:send("PASS " .. config.pass .. "\r\n")
client:send("NICK " .. config.nick .. "\r\n")
client:send("JOIN " .. config.chan .. "\r\n")

print("Bot is live on CachyOS! Listening for !song...")

while true do
	local line, err = client:receive()

	if not line then
		-- If we get a timeout error, just continue the loop instead of breaking
		if err == "timeout" then
			-- Optional: print something here if you want to know it timed out
			-- print("Timeout reached, waiting for next message...")
			goto continue
		else
			-- If it's another error (like connection loss), then break the loop
			print("Connection error: " .. err)
			break
		end
	end

	-- Respond to PINGs so Twitch doesn't kick the bot
	if line:match("^PING") then
		client:send("PONG :tmi.twitch.tv\r\n")
	end


	-- Example usage for your Spotify command
	if line:match("!song") then
		local on_cooldown, time_left = is_on_cooldown:is_on_cooldown("spotify", 10)

		if on_cooldown then
			print("Command !song is on cooldown. Wait " .. time_left .. "s")
			-- Optional: client:send("PRIVMSG #chan :Slow down! Wait " .. time_left .. "s\r\n")
		else
			local song_info = get_spotify_info()
			client:send("PRIVMSG " .. config.chan .. " :" .. song_info .. "\r\n")
			print("Replied with: " .. song_info)
		end
	end

	-- Listen for !song command
	-- if line:match("!song") then
	-- 	local song_info = get_spotify_info()
	-- 	client:send("PRIVMSG " .. config.chan .. " :" .. song_info .. "\r\n")
	-- 	print("Replied with: " .. song_info)
	-- end

	::continue::
end

print("Bot script terminated.")
