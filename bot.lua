local socket = require("socket")
local config = require("config")
local commands = require("commands") -- Import the new module

-- Function to grab live Spotify data via playerctl
-- local function get_spotify_info()
-- 	local handle = io.popen("playerctl -p spotify metadata --format '{{title}} by {{artist}} 🎶 {{url}}' 2>/dev/null")

-- 	if not handle then
-- 		return "Error: Could not open pipe to playerctl."
-- 	end

-- 	local result = handle:read("*a")
-- 	handle:close()

-- 	-- Clean up the result and check if it's empty
-- 	if result == nil or result == "" then
-- 		return "Spotify is currently chilling (not playing)."
-- 	end

-- 	-- Trim whitespace and return
-- 	return "Current Song: " .. result:gsub("^%s*(.-)%s*$", "%1")
-- end

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
		if err == "timeout" then goto continue end
		print("Connection error: " .. err)
		break
	end

	-- Keep PING/PONG here as it's a protocol requirement, not a "command"
	if line:match("^PING") then
		client:send("PONG :tmi.twitch.tv\r\n")
	end

	commands.handle(line, client, config)

	::continue::
end

print("Bot script terminated.")
