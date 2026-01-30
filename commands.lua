local timer = require("timer")
local Commands = {}
local command_map = {}

-- DYNAMIC LOADER: Scan modules folder on startup
local handle = io.popen('ls modules/*.lua 2>/dev/null')
if handle then
	for file in handle:lines() do
		local name = file:match("modules/(%w+)%.lua")
		if name then
			-- Use pcall to prevent the bot from crashing if a module has a syntax error
			local ok, mod = pcall(require, "modules." .. name)
			if ok then
				command_map[name] = mod
				print("[System] Loaded: !" .. name)
			else
				print("[Error] Failed to load " .. name .. ": " .. mod)
			end
		end
	end
	handle:close()
end

function Commands.handle(line, client, config)
	-- Parse Tagged IRC Line
	-- Tags contain mod=1 or badges=broadcaster/1
	local is_mod = line:match("mod=1") ~= nil
	local is_broadcaster = line:match("badges=[^;]*broadcaster/1") ~= nil
	local has_permission = is_mod or is_broadcaster

	-- Extract User and Message
	local user, chat_message = line:match("display%-name=(%w+).+PRIVMSG #%w+ :(.*)$")
	if not user or not chat_message then return end

	-- HANDLE !ADD COMMAND
	local new_cmd, new_text = chat_message:match("^!add (%w+) (.+)$")
	if new_cmd and has_permission then
		local target = new_cmd:lower()
		local existing = command_map[target]

		if existing and existing.writeable == false then
			client:send("PRIVMSG " .. config.chan .. " :Error: !" .. target .. " is protected. 🛡️\r\n")
			return
		end

		local path = "modules/" .. target .. ".lua"
		local f = io.open(path, "w")
		if f then
			f:write(string.format([[
local M = {
    cooldown = 10,
    removable = true,
    writeable = true
}

function M.get_info()
    return "%s"
end

return M
]], new_text))
			f:close()
			package.loaded["modules." .. target] = nil
			command_map[target] = require("modules." .. target)
			client:send("PRIVMSG " .. config.chan .. " :Command !" .. target .. " saved! ✅\r\n")
		end
		return
	end

	-- HANDLE !REMOVE COMMAND
	local del_cmd = chat_message:match("^!remove (%w+)$")
	if del_cmd and has_permission then
		local target = del_cmd:lower()
		if command_map[target] and command_map[target].removable then
			os.remove("modules/" .. target .. ".lua")
			command_map[target] = nil
			client:send("PRIVMSG " .. config.chan .. " :Command !" .. target .. " deleted. 🗑️\r\n")
		else
			client:send("PRIVMSG " .. config.chan .. " :Cannot delete protected command. ❌\r\n")
		end
		return
	end

	-- RUN STANDARD COMMANDS
	local cmd_name = chat_message:lower():match("^!(%a+)")
	local cmd_data = command_map[cmd_name]

	if cmd_data then
		local on_cooldown, time_left = timer.is_on_cooldown(cmd_name, cmd_data.cooldown or 5)
		if not on_cooldown then
			local output = cmd_data.get_info()
			client:send("PRIVMSG " .. config.chan .. " :" .. output .. "\r\n")
		else
			print(string.format("[Timer] %s busy (%.1fs)", cmd_name, time_left))
		end
	end
end

return Commands
