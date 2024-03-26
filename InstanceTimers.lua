local DEBUG = false

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

-- mechanism to fire just once
local delay = 0
local default_OnUpdate = InstanceTimers:GetScript("OnUpdate")
local function timedAnnounce()
  delay = delay + arg1
  if delay > 5 then
    delay = 0
    clearExpired(time(),3600)
    local limit = 5 - tsize(InstanceTimersDB.db)
    -- if we have none locked or we just zonechanged from death why mention it
    if limit < 5 and not UnitIsGhost("player") then
      its_print(limit.." instance lockouts remain, oldest expires in: "
        ..date("%Mm%Ss",3600-(time() - InstanceTimersDB.db[1][3])))
    end
    InstanceTimers:SetScript("OnUpdate", default_OnUpdate)
  end
end


local function invalidTable()
  -- table of when a new timer should not be made
  -- playered entered as ghost
  -- player logged in and their own last lockout still had a timer and they either still have a group or still don't

  -- table of when a new timer should be made
  -- 
end

-- I need to account to logging into a raid instance too
-- this uses a lockout but only once, even if it's a saved it
-- I need to account for running back in from ghost state, this shouldn't make a new timer
-- some kind of 'from world' variable that if set precludes adding more
-- also if it's a saved it it shouln't count towards the limit
-- How should I handle "The Upper Necropolis"? Are there any other similar cases? Should I just keep note of the last 'zone name'?

-- bascially I wanna keep the name of the last zone I was in, if it's the same zone I log into and there's already
-- a timer for that zone then it doens't use a new timer

-- what about the case that player makes new group and runs in as ghost?
-- does Reset Instanced fire an event or do you have to scan chat? It does not, sad.
-- CHAT_MSG_SYSTEM
local last_zone = GetZoneText()
local was_ghost = false
local in_group = false
local group_dropped = false
-- local just_logged_in = false

-- potential zone-in
local entering_world = false

-- zone changed new area or and entering_world 
-- meeting stone changed

local function EventHandler()
  -- if event == "ZONE_CHANGED_NEW_AREA" and UnitIsGhost("player") then
    -- was_ghost = true
  -- This DOES NOT work, unghosting happens before you enter the instance
  -- elseif event == "PLAYER_UNGHOST" and not IsInInstance() then
    -- was_ghost = false
  -- elseif event == "CHAT_MSG_SYSTEM" and arg1 == "You have entered too many instances recently." then
  --   debug_print("Over instance limit.")

  -- elseif event == "PLAYER_LOGIN" then
    -- just_logged_in = true
  -- elseif event == "ZONE_CHANGED_NEW_AREA" and not IsInInstance() then
  --   just_logged_in = false
  -- this is a bust, it queries too early zone is wrong
  -- if event == "UPDATE_INSTANCE_INFO" then
  --   local zone_name = GetZoneText()
  --   if IsInInstance() then
  --     its_print("info updated inside instance")
  --     print(zone_name)
  --   end
  --   if not IsInInstance() then
  --     its_print("info updated outside instance")
  --     print(zone_name)
  --   end
  -- if event == "ZONE_CHANGED_NEW_AREA" and not IsInInstance() then
  --   if not UnitIsGhost("player") then
  --     debug_print("not a ghost and not in an instance")
  --     InstanceTimersDB.in_instance[UnitName("player")] = nil
  --   end
  --   if max(GetNumPartyMembers(),GetNumRaidMembers()) == 0 then
  --     debug_print("zc group dropped")
  --     group_dropped = true -- this might be an issue for single-member raid entries like flask making?
  --   end
  -- elseif event == "RAID_TARGET_UPDATE" then
  --   debug_print("rt party changed")
  --   if max(GetNumPartyMembers(),GetNumRaidMembers()) == 0 then
  --     debug_print("rt group dropped")
  --     group_dropped = true -- this might be an issue for single-member raid entries like flask making?
  --   else
  --     debug_print("not dropped")
  --     group_dropped = false
  --   end
    if event == "PLAYER_ENTERING_WORLD" and IsInInstance() then
    -- if entering_world and event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED_INDOORS" and IsInInstance() then
    local zone_name = GetZoneText()
    local player = UnitName("player")
    -- local had_instance = InstanceTimersDB.in_instance[player]
    entering_world = false

    -- if not group_dropped and had_instance and had_instance == zone_name then
    --   debug_print("doing previous save check")
    --   -- find out if player was saved here already
    --   local tz = tsize(InstanceTimersDB.db)
    --   for i=1,tz do
    --     local v = InstanceTimersDB.db[tz + 1 - i]
    --     if v[1] == player then
    --       if v[2] == zone_name then
    --         return nil -- last instance was this one
    --       else
    --         break -- last instance wasn't this one
    --       end
    --     end
    --   end
    -- end
    debug_print("adding new timer")
    -- InstanceTimersDB.in_instance[player] = zone_name
    tinsert(InstanceTimersDB.db,{player,zone_name,time()})
    if InstanceTimersDB.announce then InstanceTimers:SetScript("OnUpdate", timedAnnounce) end
  -- elseif event == "PLAYER_ENTERING_WORLD" and IsInInstance() then
    -- entering_world = true
    -- its_print("enterworld_wasinside")
  -- elseif event == "PLAYER_ENTERING_WORLD" then
  --   entering_world = true
  --   its_print("enterworld")
  end
  -- elseif event == "PLAYER_LEAVING_WORLD" then
  --   local zone_name = GetZoneText()
  --   -- save if the player is inside an instance, and which one if so
  --   if IsInInstance() then
  --     debug_print(zone_name)
  --     InstanceTimersDB.in_instance[UnitName("player")] = zone_name
  --   -- else
  --   --   InstanceTimersDB.in_instance[UnitName("player")] = nil
  --   end
  -- end
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
