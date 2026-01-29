local socket = require("socket")
local config = require("config")
local commands = require("commands")

-- Connect to Twitch
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
client:send("JOIN " .. config.chan .. "\r\n")

print("Bot is live on CachyOS! Listening for !song...")

while true do
	local line, err = client:receive()

	if not line then
		if err == "timeout" then
			goto continue
		else
			print("Connection error: " .. err)
			break
		end
	end

	if line:match("^PING") then
		client:send("PONG :tmi.twitch.tv\r\n")
	end

	commands.handle(line, client, config)

	::continue::
end

print("Bot script terminated.")
