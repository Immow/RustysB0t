local timer = require("timer")
local Commands = {}
local command_map = {}

-- ==========================================================
-- INTERNAL HELPERS & DYNAMIC LOADER
-- ==========================================================

local function load_modules()
	local handle = io.popen('ls modules/*.lua 2>/dev/null')
	if not handle then return end

	for file in handle:lines() do
		local name = file:match("modules/(%w+)%.lua")
		if name then
			package.loaded["modules." .. name] = nil -- Clear cache for fresh load
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

load_modules()

-- ==========================================================
-- COMMAND HANDLERS (Logic Organized by Type)
-- ==========================================================

local Handlers = {}

-- !commands
function Handlers.list_commands(client, config)
	local list = {}
	for name, _ in pairs(command_map) do
		-- Only add to list if it is NOT in the hidden_commands config
		if not config.hidden_commands[name] then
			table.insert(list, "!" .. name)
		end
	end

	table.sort(list)

	local output = #list > 0 and table.concat(list, ", ") or "No public commands available."
	client:send("PRIVMSG " .. config.chan .. " :Available commands: " .. output .. "\r\n")
end

-- !poll, !vote, !pollend
function Handlers.handle_poll(action, input, user, client, config, has_perm)
	local poll_mod = command_map["poll"]
	local points_mod = command_map["points"]       -- Retrieve the points module here

	if not poll_mod or not points_mod then return end -- Ensure both exist

	if action == "start" and has_perm then
		local response = poll_mod.start(input, user)
		client:send("PRIVMSG " .. config.chan .. " :" .. response .. "\r\n")
	elseif action == "vote" then
		-- Pass points_mod so poll.lua can check balances
		local err = poll_mod.vote(input, user, points_mod)
		if err then
			client:send("PRIVMSG " .. config.chan .. " :" .. user .. ": " .. err .. "\r\n")
		end
	elseif action == "end" and has_perm then
		-- Pass points_mod so poll.lua can pay out winners
		local results = poll_mod.get_results(points_mod)
		client:send("PRIVMSG " .. config.chan .. " :" .. results .. "\r\n")
	end
end

-- !ban <user> [reason]
function Handlers.handle_ban(target, reason, client, config)
	if not target then return end

	local ban_cmd = "/ban " .. target
	if reason and reason ~= "" then
		ban_cmd = ban_cmd .. " " .. reason
	end

	client:send("PRIVMSG " .. config.chan .. " :" .. ban_cmd .. "\r\n")
	print("[Mod] Banned user: " .. target .. (reason and (" for: " .. reason) or ""))
end

-- !add
function Handlers.add_command(name, text, client, config)
	local target = name:lower()
	local existing = command_map[target]

	if existing and existing.writeable == false then
		client:send("PRIVMSG " .. config.chan .. " :Error: !" .. target .. " is protected. 🛡️\r\n")
		return
	end

	local path = "modules/" .. target .. ".lua"
	local f = io.open(path, "w")
	if f then
		f:write(string.format([[
local M = { cooldown = 30, removable = true, writeable = true }
function M.get_info() return %q end
return M
]], text))
		f:close()
		package.loaded["modules." .. target] = nil
		command_map[target] = require("modules." .. target)
		client:send("PRIVMSG " .. config.chan .. " :Command !" .. target .. " saved! ✅\r\n")
	end
end

-- !remove
function Handlers.remove_command(name, client, config)
	local target = name:lower()
	if command_map[target] and command_map[target].removable then
		os.remove("modules/" .. target .. ".lua")
		command_map[target] = nil
		client:send("PRIVMSG " .. config.chan .. " :Command !" .. target .. " deleted. 🗑️\r\n")
	else
		client:send("PRIVMSG " .. config.chan .. " :Cannot delete protected command. ❌\r\n")
	end
end

-- ==========================================================
-- MAIN INTERFACE
-- ==========================================================

function Commands.check_timers(client, config)
	local poll = command_map["poll"]
	local points = command_map["points"] -- Add this
	if poll and poll.current_poll and poll.current_poll.active then
		if os.time() >= poll.current_poll.ends_at then
			-- Pass points to get_results for auto-payouts
			client:send("PRIVMSG " .. config.chan .. " :[Timer] " .. poll.get_results(points) .. "\r\n")
		end
	end
end

function Commands.handle(line, client, config)
	-- 1. Parse Permissions and User Data
	local is_mod = line:match("mod=1") ~= nil
	local is_broadcaster = line:match("badges=[^;]*broadcaster/1") ~= nil
	local has_perm = is_mod or is_broadcaster

	local user, msg = line:match("display%-name=(%w+).+PRIVMSG #%w+ :(.*)$")
	if not user or not msg then return end
	local msg_lower = msg:lower()
	local ban_user, ban_reason = msg:match("^!ban (%w+)%s*(.*)")

	-- 2. Grant points for every message sent in chat
	local points_mod = command_map["points"]
	if points_mod then
		points_mod.add(user, config.points)
	end

	-- 3. Capture Inputs for Routing
	local poll_start_input = msg:match("^!poll (.+)")
	local vote_input = msg:match("^!vote (.+)") -- Capture full string for betting logic
	local add_cmd, add_text = msg:match("^!add (%w+) (.+)")
	local remove_name = msg:match("^!remove (%w+)")

	-- 4. Route Internal/Management Commands
	if msg_lower:match("^!commands") then
		local ok, time_left = timer.is_on_cooldown("list_commands", 10)
		if not ok then
			Handlers.list_commands(client, config)
		else
			local cooldown_msg = string.format("!commands is on cooldown (%.1fs left).", time_left)
			client:send("PRIVMSG " .. config.chan .. " :" .. cooldown_msg .. "\r\n")
		end
		return

		-- NEW: Route for checking user points balance
	elseif msg_lower:match("^!points") then
		if points_mod then
			local balance = points_mod.get_balance(user)
			client:send("PRIVMSG " .. config.chan .. " :" .. user .. ", you have " .. balance .. " points! 💰\r\n")
		end
		return
	elseif msg_lower:match("^!pollend") then
		Handlers.handle_poll("end", nil, user, client, config, has_perm)
		return
	elseif poll_start_input then
		Handlers.handle_poll("start", poll_start_input, user, client, config, has_perm)
		return
	elseif vote_input then
		Handlers.handle_poll("vote", vote_input, user, client, config, has_perm)
		return
	elseif ban_user and has_perm then
		Handlers.handle_ban(ban_user, ban_reason, client, config)
		return
	elseif add_cmd and add_text and has_perm then
		Handlers.add_command(add_cmd, add_text, client, config)
		return
	elseif remove_name and has_perm then
		Handlers.remove_command(remove_name, client, config)
		return

		-- 5. Route Standard Dynamic Commands
	else
		local cmd_name = msg_lower:match("^!(%a+)")
		local cmd_data = command_map[cmd_name]

		if cmd_data then
			local ok, time_left = timer.is_on_cooldown(cmd_name, cmd_data.cooldown or 5)
			if not ok then
				-- Check if the module actually has a get_info function
				if cmd_data.get_info then
					client:send("PRIVMSG " .. config.chan .. " :" .. cmd_data.get_info() .. "\r\n")
				end
			else
				local cooldown_msg = string.format("Command !%s is on cooldown (%.1fs left).", cmd_name, time_left)
				client:send("PRIVMSG " .. config.chan .. " :" .. cooldown_msg .. "\r\n")
			end
		end
	end
end

return Commands
