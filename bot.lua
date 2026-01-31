local socket = require("socket")
local config = require("config")
local commands = require("commands")

local client = socket.tcp()
client:settimeout(0.5)
local ok, err = client:connect(config.server, config.port)

if not ok then
	print("Failed to connect: " .. err)
	os.exit()
end

-- Login
client:send("PASS " .. config.pass .. "\r\n")
client:send("NICK " .. config.nick .. "\r\n")
client:send("CAP REQ :twitch.tv/tags\r\n")
client:send("JOIN " .. config.chan .. "\r\n")

print("Bot is live on CachyOS! Dynamic modules loaded.")

while true do
	local line, err = client:receive()

	-- 1. Pulse the timer check every loop (roughly every 0.5s)
	commands.check_timers(client, config)

	if not line then
		if err == "timeout" then goto continue end
		break
	end

	-- 2. Process chat messages normally
	if line:match("^PING") then client:send("PONG :tmi.twitch.tv\r\n") end
	commands.handle(line, client, config)

	::continue::
end
