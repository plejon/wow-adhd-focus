local ADDON, A = ...

local DEFAULT_ENABLED = {
  Weapons = false,
  CharacterVocals = false,
  Footsteps = false,
  Doodads = false,
  CreatureAmbience = false,
  Emotes = false,
  Interface = false,
  Music = false,
  MountFoley = false,
}

local function ApplyMutes()
  local muted = 0
  for category, ids in pairs(A.Categories) do
    if ADHDFocusDB.enabled[category] then
      for _, id in ipairs(ids) do
        MuteSoundFile(id)
        muted = muted + 1
      end
    end
  end
  for id in pairs(ADHDFocusDB.custom) do
    MuteSoundFile(id)
    muted = muted + 1
  end
  return muted
end

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffADHDFocus|r " .. msg)
end

local function HandleSlash(input)
  input = (input or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, arg = input:match("^(%S+)%s*(.*)$")
  cmd = cmd or ""

  if cmd == "" or cmd == "status" then
    Print("categories:")
    for category in pairs(A.Categories) do
      local state = ADHDFocusDB.enabled[category] and "|cff88ff88on|r" or "|cffff8888off|r"
      local count = #A.Categories[category]
      Print(("  %s [%s] (%d ids)"):format(category, state, count))
    end
    local custom = 0
    for _ in pairs(ADHDFocusDB.custom) do custom = custom + 1 end
    Print(("custom muted ids: %d"):format(custom))

  elseif cmd == "on" or cmd == "off" then
    local target = arg:gsub("^%s*(.-)%s*$", "%1")
    local matched
    for category in pairs(A.Categories) do
      if category:lower() == target then matched = category end
    end
    if not matched then
      Print("unknown category: " .. (arg ~= "" and arg or "<empty>"))
      return
    end
    ADHDFocusDB.enabled[matched] = (cmd == "on")
    Print(matched .. " -> " .. cmd .. " (reload UI to apply unmutes)")
    if cmd == "on" then ApplyMutes() end

  elseif cmd == "mute" then
    local id = tonumber(arg)
    if not id then Print("usage: /adhd mute <fileDataId>") return end
    ADHDFocusDB.custom[id] = true
    MuteSoundFile(id)
    Print("muted custom id " .. id)

  elseif cmd == "unmute" then
    local id = tonumber(arg)
    if not id then Print("usage: /adhd unmute <fileDataId>") return end
    ADHDFocusDB.custom[id] = nil
    UnmuteSoundFile(id)
    Print("unmuted custom id " .. id .. " (reload UI if it was from a category)")

  elseif cmd == "list" then
    local ids = {}
    for id in pairs(ADHDFocusDB.custom) do table.insert(ids, id) end
    table.sort(ids)
    Print("custom muted ids: " .. (#ids == 0 and "(none)" or table.concat(ids, ", ")))

  elseif cmd == "apply" then
    local n = ApplyMutes()
    Print("applied " .. n .. " mutes")

  else
    Print("commands:")
    Print("  /adhd status              - list categories and counts")
    Print("  /adhd on  <category>      - enable a category")
    Print("  /adhd off <category>      - disable (requires /reload to hear again)")
    Print("  /adhd mute   <id>         - add a custom fileDataId")
    Print("  /adhd unmute <id>         - remove a custom fileDataId")
    Print("  /adhd list                - list custom ids")
    Print("  /adhd apply               - re-run mutes (after editing Categories.lua)")
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == ADDON then
    ADHDFocusDB = ADHDFocusDB or {}
    ADHDFocusDB.enabled = ADHDFocusDB.enabled or {}
    ADHDFocusDB.custom  = ADHDFocusDB.custom  or {}
    for k, v in pairs(DEFAULT_ENABLED) do
      if ADHDFocusDB.enabled[k] == nil then ADHDFocusDB.enabled[k] = v end
    end
  elseif event == "PLAYER_LOGIN" then
    local n = ApplyMutes()
    Print(("loaded, %d sounds muted. /adhd for commands."):format(n))
  end
end)

SLASH_ADHDFOCUS1 = "/adhd"
SLASH_ADHDFOCUS2 = "/adhdfocus"
SlashCmdList["ADHDFOCUS"] = HandleSlash
