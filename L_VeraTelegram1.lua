module("L_VeraTelegram1", package.seeall)

local _PLUGIN_NAME = "VeraTelegram"
local _PLUGIN_VERSION = "0.2.0"

local debugMode = false
local openLuup = false

local taskHandle = -1
local TASK_ERROR = 2
local TASK_ERROR_PERM = -2
local TASK_SUCCESS = 4
local TASK_BUSY = 1

local masterID = -1

-- SIDs
local MYSID										= "urn:bochicchio-com:serviceId:VeraTelegram1"
local HASID										= "urn:micasaverde-com:serviceId:HaDevice1"

TASK_HANDLE = nil

--- ***** GENERIC FUNCTIONS *****
local function dump(t, seen)
	if t == nil then return "nil" end
	if seen == nil then seen = {} end
	local sep = ""
	local str = "{ "
	for k, v in pairs(t) do
		local val
		if type(v) == "table" then
			if seen[v] then
				val = "(recursion)"
			else
				seen[v] = true
				val = dump(v, seen)
			end
		elseif type(v) == "string" then
			if #v > 255 then
				val = string.format("%q", v:sub(1, 252) .. "...")
			else
				val = string.format("%q", v)
			end
		elseif type(v) == "number" and (math.abs(v - os.time()) <= 86400) then
			val = tostring(v) .. "(" .. os.date("%x.%X", v) .. ")"
		else
			val = tostring(v)
		end
		str = str .. sep .. k .. "=" .. val
		sep = ", "
	end
	str = str .. " }"
	return str
end

local function L(msg, ...) -- luacheck: ignore 212
	local str
	local level = 50
	if type(msg) == "table" then
		str = tostring(msg.prefix or _PLUGIN_NAME) .. ": " .. tostring(msg.msg)
		level = msg.level or level
	else
		str = _PLUGIN_NAME .. ": " .. tostring(msg)
	end
	str = string.gsub(str, "%%(%d+)", function(n)
		n = tonumber(n, 10)
		if n < 1 or n > #arg then return "nil" end
		local val = arg[n]
		if type(val) == "table" then
			return dump(val)
		elseif type(val) == "string" then
			return string.format("%q", val)
		elseif type(val) == "number" and math.abs(val - os.time()) <= 86400 then
			return tostring(val) .. "(" .. os.date("%x.%X", val) .. ")"
		end
		return tostring(val)
	end)
	luup.log(str, level)
end

local function getVarNumeric(sid, name, dflt, dev)
	local s = luup.variable_get(sid, name, dev) or ""
	if s == "" then return dflt end
	s = tonumber(s)
	return (s == nil) and dflt or s
end

local function D(msg, ...)
	debugMode = getVarNumeric(MYSID, "DebugMode", 0, masterID) == 1

	if debugMode then
		local t = debug.getinfo(2)
		local pfx = _PLUGIN_NAME .. "(" .. tostring(t.name) .. "@" ..
						tostring(t.currentline) .. ")"
		L({msg = msg, prefix = pfx}, ...)
	end
end

local function setVar(sid, name, val, dev)
	val = (val == nil) and "" or tostring(val)
	local s = luup.variable_get(sid, name, dev) or ""
	D("setVar(%1,%2,%3,%4) old value %5", sid, name, val, dev, s)
	if s ~= val then
		luup.variable_set(sid, name, val, dev)
		return true, s
	end
	return false, s
end

local function getVar(sid, name, dflt, dev)
	local s = luup.variable_get(sid, name, dev) or ""
	if s == "" then return dflt end
	return (s == nil) and dflt or s
end

local function split(str, sep)
	if sep == nil then sep = "," end
	local arr = {}
	if #(str or "") == 0 then return arr, 0 end
	local rest = string.gsub(str or "", "([^" .. sep .. "]*)" .. sep,
		function(m)
			table.insert(arr, m)
			return ""
		end)
	table.insert(arr, rest)
	return arr, #arr
end

local function map(arr, f, res)
	res = res or {}
	for ix, x in ipairs(arr) do
		if f then
			local k, v = f(x, ix)
			res[k] = (v == nil) and x or v
		else
			res[x] = x
		end
	end
	return res
end

local function initVar(sid, name, dflt, dev)
	local currVal = luup.variable_get(sid, name, dev)
	if currVal == nil then
		luup.variable_set(sid, name, tostring(dflt), dev)
		return tostring(dflt)
	end
	return currVal
end

function deviceMessage(devID, message, error, timeout)
	local status = error and 2 or 4
	timeout = timeout or 15
	D("deviceMessage(%1,%2,%3,%4)", devID, message, error, timeout)
	luup.device_message(devID, status, message, timeout, _PLUGIN_NAME)
end

function os.capture(cmd, raw)
	local handle = assert(io.popen(cmd, 'r'))
	local output = assert(handle:read('*a'))
	
	handle:close()
	
	if raw then 
		return output 
	end
   
	output = string.gsub(
		string.gsub(
			string.gsub(output, '^%s+', ''), 
			'%s+$', 
			''
		), 
		'[\n\r]+',
		' ')
   
   return output
end

local function safeCall(call)
	local function err(x)
		local s = string.dump(call)
		D('Error: %s - %s', x, s)
	end

	local s, r, e = xpcall(call, err)
	return r
end

-- ** PLUGIN CODE **
local function executeCommand(command)
	return safeCall(function()
		local response = os.capture(command)
		D('executeCommand(%1): %2', command, response)

		return response
	end)
end

local function urlEncode(url)
	local char_to_hex = function(c)
		return string.format("%%%02X", string.byte(c))
	end

	if url == nil then return "" end

	url = url:gsub("\n", "\r\n")
	url = string.gsub(url, "([^%w _%%%-%.~])", char_to_hex)
	url = url:gsub(" ", "+")
	return url
end

function send(device, settings)
	D('send(%1)', settings)

	local defaultChatID = getVar(MYSID, "DefaultChatID", "", masterID)
	local disableNotification = tostring(settings.DisableNotification or "false") == "true"
	local text = (settings.Text or "Test")
	local format = (settings.Format or "MarkdownV2")

	local chatID = settings.ChatID or defaultChatID
	local botToken = getVar(MYSID, "BotToken", "", masterID)
	local telegramUrl = 'https://api.telegram.org/bot' .. botToken .. '/'
	
	-- gif/video or still image
	if settings.VideoUrl ~= nil or settings.ImageUrl ~= nil then
		local ext = settings.ImageUrl ~= nil and '.jpg' or '.gif'
		local endpoint = settings.ImageUrl ~= nil and 'sendPhoto' or 'sendAnimation'
		local param = settings.ImageUrl ~= nil and 'photo' or 'animation'

		local name = tostring(math.random(os.time()))
		local snapFile = "/tmp/camsnapshot" .. name:gsub("%s+", "") .."." .. ext

		-- remove Image
		os.execute('/bin/rm ' .. snapFile)

		-- save locally
		local imageUrl = settings.VideoUrl or settings.ImageUrl
		local cmd = 'curl -H "Accept-Charset: utf-8" -H "Content-Type: application/x-www-form-urlencoded" -o ' .. snapFile .. ' "' .. imageUrl .. '"'
		D('os.execute(%1)', cmd)
		executeCommand(cmd)

		-- send via telegram
		cmd = 'curl "' .. telegramUrl .. endpoint ..'" -F caption="' .. text ..'" -F chat_id=' .. chatID ..' -F disable_notification=' .. tostring(disableNotification) ..' -F ' .. param .. '=@' .. snapFile
		executeCommand(cmd)
	else
		-- text message
		local url = string.format("%ssendMessage?parse_mode=%s&chat_id=%s&text=%s&disable_notification=%s",
								telegramUrl,
								format,
								tostring(chatID),
								urlEncode(text),
								tostring(disableNotification)
					)
		local cmd = string.format("curl -k -H 'Content-type: application/json' '%s'", url)
		--local cmd = 'curl -k -H "Content-type: application/json" -G --data "chat_id=' .. chatID .. '" --data "parse_mode=' .. format .. '" --data-urlencode $\'text=' .. text .. '\' --data "disable_notification=' .. tostring(disableNotification).. '" "' .. telegramUrl .. 'sendMessage"'
		executeCommand(cmd)
	end
end

function startPlugin(devNum)
	masterID = devNum

	L("Plugin starting: %1 - %2", _PLUGIN_NAME, _PLUGIN_VERSION)

	-- detect OpenLuup
	for k,v in pairs(luup.devices) do
		if v.device_type == "openLuup" then
			openLuup = true
		end
	end

	D("OpenLuup: %1", openLuup)

	-- init default vars
	initVar(MYSID, "DebugMode", 0, masterID)
	initVar(MYSID, "BotToken", "YourBotToken", masterID)
	initVar(MYSID, "DefaultChatID", "-1", masterID)

	-- categories
	if luup.attr_get("category_num", masterID) == nil then
		luup.attr_set("category_num", "15", masterID)			-- A/V
	end

	-- generic
	initVar(HASID, "CommFailure", 0, masterID)

	-- currentversion
	local vers = initVar(MYSID, "CurrentVersion", "0", masterID)
	if vers ~= _PLUGIN_VERSION then
		-- new version, let's reload the script again
		L("New version detected: reconfiguration in progress")
		setVar(HASID, "Configured", 0, masterID)
		setVar(MYSID, "CurrentVersion", _PLUGIN_VERSION, masterID)

		-- change config
		local botID = getVar(MYSID, "BotID", nil, masterID)
		local botKey = getVar(MYSID, "BotKey", nil, masterID)

		if botID ~= nil and botKey ~= nil then
			setVar(MYSID, "BotToken", botID .. ':' .. botKey, masterID)
			setVar(MYSID, "BotID", nil, masterID)
			setVar(MYSID, "BotKey", nil, masterID)
			D("Bot configuration upgraded")
		end
	end
	
	-- check for configured flag and for the script
	local configured = getVarNumeric(HASID, "Configured", 0, masterID)
	if configured == 0 then
		setVar(HASID, "Configured", 1, devNum)
	else
		D("Engine correctly configured: skipping config")
	end

	-- randomizer
	math.randomseed(tonumber(tostring(os.time()):reverse():sub(1,6)))

	-- status
	luup.set_failure(0, masterID)
	return true, "Ready", _PLUGIN_NAME
end
