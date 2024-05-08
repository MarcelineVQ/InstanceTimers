local DEBUG = false
local wasDead = UnitIsGhost("player")

local function its_print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local function debug_print(msg)
  if DEBUG then DEFAULT_CHAT_FRAME:AddMessage(msg) end
end

-- local _G = getfenv(0)

InstanceTimers = CreateFrame("Frame")

local defaults = {
  enabled = true,
  announce = true,
  db = {},
  in_instance = {},
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
  end
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

-- mechanism to fire just once
local delay = 0
local default_OnUpdate = InstanceTimers:GetScript("OnUpdate")
local function timedAnnounce()
  delay = delay + arg1
  if delay > 5 then

    -- use this delay to update the zone for the last entry
    if IsInInstance() then InstanceTimersDB.db[tsize(InstanceTimersDB.db)][2] = GetZoneText() end

    delay = 0
    clearExpired(time(),3600)
    local limit = 5 - tsize(InstanceTimersDB.db)
    -- if we have none locked why mention it
    if InstanceTimersDB.announce and limit < 5 then
      its_print(limit.." instance lockouts remain, oldest expires in: "
        ..date("%Mm%Ss",3600-(time() - InstanceTimersDB.db[1][3])))
    end
    InstanceTimers:SetScript("OnUpdate", default_OnUpdate)
  end
end

local function EventHandler()
  -- keeping this dumb, events are very unreliable in 1.12, we re-update the zone info using timedAnnounce to be accurate
  if event == "PLAYER_ENTERING_WORLD" then
    if IsInInstance() then
        if not wasDead then
            local zone_name = GetZoneText()
            local player = UnitName("player")
            local now = time()
        
            debug_print("adding new timer")
            tinsert(InstanceTimersDB.db,{player,zone_name,now})
        end
        -- if InstanceTimersDB.announce then InstanceTimers:SetScript("OnUpdate", timedAnnounce) end
        InstanceTimers:SetScript("OnUpdate", timedAnnounce)
    else
        wasDead = UnitIsGhost("player")
    end
  end
end

local function Init()
  if event == "ADDON_LOADED" and arg1 == "InstanceTimers" then
    InstanceTimers:UnregisterEvent("ADDON_LOADED")
    if not InstanceTimersDB then
      its_print("init empty")
      InstanceTimersDB = defaults -- initialize default settings
    else -- or check that we only have the current settings format
      its_print("init settingscheck")
      local s = {}
      for k,v in pairs(defaults) do
        if InstanceTimersDB[k] == nil -- specifically nil
          then s[k] = defaults[k]
          else s[k] = InstanceTimersDB[k] end
      end
      -- is the above just: s[k] = ((AutoManaSettings[k] == nil) and defaults[k]) or AutoManaSettings[k]
      InstanceTimersDB = s
    end
    InstanceTimers:SetScript("OnEvent", EventHandler)
    -- if InstanceTimersDB.announce then InstanceTimers:SetScript("OnUpdate", timedAnnounce) end
  end
end

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
InstanceTimers:RegisterEvent("ZONE_CHANGED_INDOORS")
-- InstanceTimers:RegisterEvent("MEETINGSTONE_CHANGED")
InstanceTimers:RegisterEvent("PLAYER_ENTERING_WORLD")
-- InstanceTimers:RegisterEvent("RAID_TARGET_UPDATE")
-- InstanceTimers:RegisterEvent("UPDATE_INSTANCE_INFO")
-- InstanceTimers:RegisterEvent("PLAYER_LEAVING_WORLD")
-- InstanceTimers:RegisterEvent("PLAYER_LOGIN")
-- InstanceTimers:RegisterEvent("CHAT_MSG_SYSTEM")
InstanceTimers:RegisterEvent("ADDON_LOADED")
InstanceTimers:SetScript("OnEvent", Init)

SLASH_INSTANCETIMERS1 = "/instancetimers";
SLASH_INSTANCETIMERS2 = "/its";
SlashCmdList["INSTANCETIMERS"] = handleCommands
