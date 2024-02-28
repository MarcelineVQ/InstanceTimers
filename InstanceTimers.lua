local function print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

-- local _G = getfenv(0)

InstanceTimers = CreateFrame("Frame")

local function tsize(table)
  local i = 0
  for _ in pairs(table) do i = i + 1 end
  return i
end

-- local function sortDB()
--   local a = {}
--   for n in pairs(lockoutDB) do table.insert(a, n) end
--   table.sort(a,function (x,y)
--     print(x[3])
--     print(y[3])
--     return x[3] < y[3] end)
--   lockoutDB = a
-- end

-- function pairsByKeys (t, f)
--   local a = {}
--   for n in pairs(t) do table.insert(a, n) end
--   table.sort(a, f)
--   local i = 0      -- iterator variable
--   local iter = function ()   -- iterator function
--     i = i + 1
--     if a[i] == nil then return nil
--     else return a[i], t[a[i]]
--     end
--   end
--   return iter
-- end

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

local function EventHandler()
  if event == "ZONE_CHANGED_NEW_AREA" then
    local zonename = GetZoneText()
    if IsInInstance() then
      tinsert(lockoutDB,{UnitName("player"),zonename,time()})
    end
  elseif event == "ADDON_LOADED" then
    if not lockoutDB then lockoutDB = {} end
    InstanceTimers:UnregisterEvent("ADDON_LOADED")
  end
end

-- Clear expired entries over a certain duration and make new array keys
local function clearExpired(time,duration)
  local a = {}
  for k,v in pairs(lockoutDB) do
    local started = v[3]
    local rem = time - started
    if rem > duration then lockoutDB[k] = nil else tinsert(a,v) end
  end -- ^ lockout isnt doing anything here
  lockoutDB = a
end

local function showTimers(duration)
  local now = time()
  clearExpired(now,duration)
  if tsize(lockoutDB) > 0 then
    print("Instance lockout timers:")
    for k,v in pairs(lockoutDB) do
      local character,instance,started = v[1],v[2],v[3]
      local rem = now - started
      print(k .. ": " .. character .. "'s " .. instance .. " @ " .. date("%H:%M:%S",started) .. ", wait: " .. date("%Mm%Ss",duration-rem))
    end
  else
    print("You have no instance lockout timers.")
  end
end

-- add a command to show raid lockouts easily too
-- I need to account to logging into a raid instance too
-- some kind of 'from world' variable that if set precludes adding more
-- also if it's a saved it it shouln't count towards the limit
local function handleCommands(msg,editbox)
  if msg == "del" or msg == "delete" or msg == "rem" or msg == "remove" then
    tremove(lockoutDB)
  elseif msg ~= "" then
    print("Type /its del to remove the latest timestamp.")
  else
    showTimers(3600)
  end
end

InstanceTimers:RegisterEvent("ZONE_CHANGED_NEW_AREA")
InstanceTimers:RegisterEvent("ADDON_LOADED")
InstanceTimers:SetScript("OnEvent", EventHandler)

SLASH_INSTANCETIMERS1 = "/instancetimers";
SLASH_INSTANCETIMERS2 = "/its";
SlashCmdList["INSTANCETIMERS"] = handleCommands
