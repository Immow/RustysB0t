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

function Commands.check_timers(client, config)
	local poll = command_map["poll"]
	if poll and poll.current_poll and poll.current_poll.active then
		-- Check if current time has passed the end time
		if os.time() >= poll.current_poll.ends_at then
			local results = poll.get_results() -- This also sets active = false
			client:send("PRIVMSG " .. config.chan .. " :[Timer] " .. results .. "\r\n")
		end
	end
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

	-- HANDLE !COMMANDS LIST
	if chat_message:lower():match("^!commands") then
		local list = {}
		for name, _ in pairs(command_map) do
			table.insert(list, "!" .. name)
		end

		-- Sort them alphabetically so the list is clean
		table.sort(list)

		local output = "Available commands: " .. table.concat(list, ", ")
		client:send("PRIVMSG " .. config.chan .. " :" .. output .. "\r\n")
		return
	end

	-- Inside Commands.handle(line, client, config)

	-- 1. START POLL (Broadcaster/Mod only)
	local poll_input = chat_message:match("^!poll (.+)")
	if poll_input and has_permission then
		local poll_mod = command_map["poll"]
		if poll_mod then
			local response = poll_mod.start(poll_input, user)
			client:send("PRIVMSG " .. config.chan .. " :" .. response .. "\r\n")
			return
		end
	end

	-- 2. VOTE (Any user)
	local vote_input = chat_message:match("^!vote (%d+)")
	if vote_input then
		local poll_mod = command_map["poll"]
		if poll_mod then
			poll_mod.vote(vote_input, user)
			-- We don't send a message back to avoid spam,
			-- but you can print to your CachyOS terminal:
			-- print("[Poll] " .. user .. " voted for " .. vote_input)
			return
		end
	end

	-- 3. END POLL & SHOW RESULTS (Broadcaster/Mod only)
	if chat_message:match("^!pollend") and has_permission then
		local poll_mod = command_map["poll"]
		if poll_mod then
			local results = poll_mod.get_results()
			client:send("PRIVMSG " .. config.chan .. " :" .. results .. "\r\n")
			return
		end
	end

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
    cooldown = 30,
    removable = true,
    writeable = true
}

function M.get_info()
    return %q
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

			local chat_msg = string.format("Command !%s is on cooldown. Try again in %.1f seconds.", cmd_name, time_left)
			client:send("PRIVMSG " .. config.chan .. " :" .. chat_msg .. "\r\n")
		end
	end
end

return Commands
