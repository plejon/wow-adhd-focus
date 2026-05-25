local ADDON, A = ...

local DEFAULT_ENABLED = {
  Weapons = true,
  CharacterVocals = true,
  Footsteps = true,
  Doodads = true,
  CreatureAmbience = true,
  WorldAmbience = true,
  Emotes = true,
  Interface = true,
  Music = true,
  MountFoley = true,
  UtilitySpells = true,
}

local function ApplyCategory(category, enable)
  local ids = A.Categories[category]
  if not ids then return 0 end
  for _, id in ipairs(ids) do
    if enable then MuteSoundFile(id) else UnmuteSoundFile(id) end
  end
  return #ids
end

local function ApplyAll()
  local muted = 0
  for category in pairs(A.Categories) do
    if ADHDFocusDB.enabled[category] then
      muted = muted + ApplyCategory(category, true)
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

local function MatchCategory(name)
  name = name:lower()
  for category in pairs(A.Categories) do
    if category:lower() == name then return category end
  end
  return nil
end

local function HandleSlash(input)
  input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, arg = input:match("^(%S+)%s*(.*)$")
  cmd = (cmd or ""):lower()

  if cmd == "" or cmd == "status" then
    Print("categories:")
    for category in pairs(A.Categories) do
      local on = ADHDFocusDB.enabled[category]
      local state = on and "|cff88ff88MuteOn|r" or "|cffffaa44MuteOff|r"
      Print(("  %s [%s] (%d ids)"):format(category, state, #A.Categories[category]))
    end
    local custom = 0
    for _ in pairs(ADHDFocusDB.custom) do custom = custom + 1 end
    Print(("custom muted ids: %d"):format(custom))

  elseif cmd == "mute" or cmd == "unmute" then
    local enable = (cmd == "mute")
    local id = tonumber(arg)
    if id then
      if enable then
        ADHDFocusDB.custom[id] = true
        MuteSoundFile(id)
        Print("muted custom id " .. id)
      else
        ADHDFocusDB.custom[id] = nil
        UnmuteSoundFile(id)
        Print("unmuted custom id " .. id .. " (reload UI if it was from a category)")
      end
      return
    end
    if arg:lower() == "all" then
      local n = 0
      for category in pairs(A.Categories) do
        ADHDFocusDB.enabled[category] = enable
        n = n + ApplyCategory(category, enable)
      end
      Print(("%s all categories (%d ids)%s"):format(
        enable and "muted" or "unmuted", n,
        enable and "" or " — reload UI to hear sounds that already played"))
      return
    end
    local matched = MatchCategory(arg)
    if not matched then
      Print("unknown target: " .. (arg ~= "" and arg or "<empty>")
            .. " — use a category name, sound id, or 'all'")
      return
    end
    ADHDFocusDB.enabled[matched] = enable
    local n = ApplyCategory(matched, enable)
    Print(("%s %s (%d ids)%s"):format(
      enable and "muted" or "unmuted", matched, n,
      enable and "" or " — reload UI to hear sounds that already played"))

  elseif cmd == "list" then
    local ids = {}
    for id in pairs(ADHDFocusDB.custom) do table.insert(ids, id) end
    table.sort(ids)
    Print("custom muted ids: " .. (#ids == 0 and "(none)" or table.concat(ids, ", ")))

  elseif cmd == "apply" then
    local n = ApplyAll()
    Print("applied " .. n .. " mutes")

  else
    Print("commands:")
    Print("  /adhd status              - show category states + id counts")
    Print("  /adhd mute all            - mute every category")
    Print("  /adhd unmute all          - unmute every category")
    Print("  /adhd mute   <category>   - mute a single category")
    Print("  /adhd unmute <category>   - unmute a single category")
    Print("  /adhd mute   <id>         - mute a custom fileDataId")
    Print("  /adhd unmute <id>         - unmute a custom fileDataId")
    Print("  /adhd list                - list custom muted ids")
    Print("  /adhd apply               - re-apply all enabled mutes")
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
    local n = ApplyAll()
    Print(("loaded, %d sounds muted. /adhd for commands."):format(n))
  end
end)

SLASH_ADHDFOCUS1 = "/adhd"
SLASH_ADHDFOCUS2 = "/adhdfocus"
SlashCmdList["ADHDFOCUS"] = HandleSlash
