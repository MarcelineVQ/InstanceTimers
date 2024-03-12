local function its_print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

-- local _G = getfenv(0)

InstanceTimers = CreateFrame("Frame")

local defaults = {
  enabled = true,
  announce = true,
  db = {},
}

local function tsize(table)
  local i = 0
  for _ in pairs(table) do i = i + 1 end
  return i
end

local function compStamp(a,b)
  local x = a[2]
  local y = b[2]
  return x[3] < y[3]
end

local function lookup(table,value)
  for k,v in pairs(table) do
    if v == value then return true end
  end
  return false
end

-- Clear expired entries over a certain duration and make new array keys
local function clearExpired(time,duration)
  local a = {}
  for k,v in pairs(InstanceTimersDB.db) do
    local started = v[3]
    local rem = time - started
    if rem < duration then tinsert(a,v) end
    -- if rem > duration then InstanceTimersDB.db[k] = nil else tinsert(a,v) end
  end -- ^ lockout isnt doing anything here
  InstanceTimersDB.db = a
end

local function showTimers(duration)
  local now = time()
  clearExpired(now,duration)
  if tsize(InstanceTimersDB.db) > 0 then
    its_print("Instance lockout timers:")
    for k,v in pairs(InstanceTimersDB.db) do
      local character,instance,started = v[1],v[2],v[3]
      local rem = now - started
      its_print(k .. ": " .. character .. "'s " .. instance .. " @ " .. date("%H:%M:%S",started) .. ", wait: " .. date("%Mm%Ss",duration-rem))
    end
  else
    its_print("You have no instance lockout timers.")
  end
end


-- fire once per screen load
local delay = 0
local default_OnUpdate = InstanceTimers:GetScript("OnUpdate")
local function timedAnnounce()
  delay = delay + arg1
  if delay > 5 then
    delay = 0
    clearExpired(time(),3600)
    local limit = 5 - tsize(InstanceTimersDB.db)
    if limit < 5 then -- if we have none locked why mention it
      its_print(limit.." instance lockouts currently remain.")
    end
    InstanceTimers:SetScript("OnUpdate", default_OnUpdate)
  end
end

-- add an event to announce lockouts remaining when entering zone
local function EventHandler()
  if event == "ZONE_CHANGED_NEW_AREA" then
    local zonename = GetZoneText()
    if IsInInstance() then
      tinsert(InstanceTimersDB.db,{UnitName("player"),zonename,time()})
    end
  elseif event == "PLAYER_ENTERING_WORLD" and InstanceTimersDB.announce then
    InstanceTimers:SetScript("OnUpdate", timedAnnounce)
  elseif event == "ADDON_LOADED" then
    InstanceTimers:UnregisterEvent("ADDON_LOADED")
    if not InstanceTimersDB then
      InstanceTimersDB = defaults -- initialize default settings
    else -- or check that we only have the current settings format
      local s = {}
      for k,v in pairs(defaults) do
        if InstanceTimersDB[k] == nil -- specifically nil
          then s[k] = defaults[k]
          else s[k] = InstanceTimersDB[k] end
      end
      -- is the above just: s[k] = ((AutoManaSettings[k] == nil) and defaults[k]) or AutoManaSettings[k]
      InstanceTimersDB = s
    end
  end
end

-- add a command to show raid lockouts easily too
-- I need to account to logging into a raid instance too
-- some kind of 'from world' variable that if set precludes adding more
-- also if it's a saved it it shouln't count towards the limit
local function handleCommands(msg,editbox)

  local args = {};
  for word in string.gfind(msg,'%S+') do table.insert(args,word) end

  if args[1] == "enabled" then
    InstanceTimersDB.enabled = not AutoRFDB.enabled
    its_print("InstanceTimers toggled.")
  elseif args[1] == "announce" then
    InstanceTimersDB.announce = not AutoRFDB.announce
    its_print("Toggled announcing remaining lockouts.")
  elseif args[1] == "del" or args[1] == "delete" or args[1] == "rem" or args[1] == "remove" then
    tremove(InstanceTimersDB.db)
  elseif args[1] == "help" or args[1] ~= nil then
    its_print("Type /its followed by:")
    its_print("[enable] to toggle addon.")
    its_print("[rem] to remove the last lockout timer.")
    its_print("[announce] to toggle announcing remaining lockouts.")
  else
    showTimers(3600)
  end
end

InstanceTimers:RegisterEvent("ZONE_CHANGED_NEW_AREA")
InstanceTimers:RegisterEvent("PLAYER_ENTERING_WORLD")
InstanceTimers:RegisterEvent("ADDON_LOADED")
InstanceTimers:SetScript("OnEvent", EventHandler)

SLASH_INSTANCETIMERS1 = "/instancetimers";
SLASH_INSTANCETIMERS2 = "/its";
SlashCmdList["INSTANCETIMERS"] = handleCommands
