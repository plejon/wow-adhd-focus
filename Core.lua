local ADDON, A = ...

local DEFAULT_ENABLED = {
  SpellCasts = true,
  Weapons = true,
  Gear = true,
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

local CVAR_OVERRIDES = {
  Sound_EnableErrorSpeech = "0", -- silences "Not enough mana!" voice lines
  Sound_EnableEmoteSounds = "0", -- silences /laugh /cheer NPC emote audio
}

-- Category-level preset bundles. Apply with /adhd profile <name>.
-- Each profile is a complete category-state map; categories absent
-- here fall back to true (muted).
local PROFILES = {
  -- "default": light sensory reduction, most game audio retained.
  -- Closest to a vanilla WoW experience with the obvious noise removed.
  ["default"] = {
    SpellCasts       = false,
    Weapons          = false,
    Gear             = false,
    CharacterVocals  = false,
    Footsteps        = true,
    Doodads          = true,
    CreatureAmbience = false,
    WorldAmbience    = true,
    Emotes           = true,
    Interface        = false,
    Music            = true,
    MountFoley       = true,
    UtilitySpells    = false,
  },
  -- "pvp": current PvP-strict setup. Everything muted. The SPELL_KEEP
  -- whitelist baked into Categories.lua surfaces the tactical cues
  -- (CC, interrupts, roots, stuns, stealth openers, major CDs).
  ["pvp"] = {
    SpellCasts       = true,
    Weapons          = true,
    Gear             = true,
    CharacterVocals  = true,
    Footsteps        = true,
    Doodads          = true,
    CreatureAmbience = true,
    WorldAmbience    = true,
    Emotes           = true,
    Interface        = true,
    Music            = true,
    MountFoley       = true,
    UtilitySpells    = true,
  },
  -- "arena": same category set as pvp; intent is to ship a stricter
  -- per-spell whitelist later. Profile granularity is category-only
  -- right now, so pvp and arena are functionally identical until then.
  ["arena"] = {
    SpellCasts       = true,
    Weapons          = true,
    Gear             = true,
    CharacterVocals  = true,
    Footsteps        = true,
    Doodads          = true,
    CreatureAmbience = true,
    WorldAmbience    = true,
    Emotes           = true,
    Interface        = true,
    Music            = true,
    MountFoley       = true,
    UtilitySpells    = true,
  },
}
local DEFAULT_PROFILE = "pvp"

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

  elseif cmd == "reset" then
    for category in pairs(A.Categories) do
      local desired = DEFAULT_ENABLED[category]
      if desired == nil then desired = true end
      ADHDFocusDB.enabled[category] = desired
      ApplyCategory(category, desired)
    end
    Print("reset all categories to defaults")

  elseif cmd == "profile" then
    local name = arg:lower():gsub("^%s*(.-)%s*$", "%1")
    if name == "" or name == "list" then
      Print("active profile: " .. (ADHDFocusDB.profile or DEFAULT_PROFILE))
      Print("available:")
      for k in pairs(PROFILES) do Print("  " .. k) end
      return
    end
    local p = PROFILES[name]
    if not p then
      Print("unknown profile: " .. name .. " — try /adhd profile list")
      return
    end
    for category in pairs(A.Categories) do
      local desired = p[category]
      if desired == nil then desired = true end
      ADHDFocusDB.enabled[category] = desired
      ApplyCategory(category, desired)
    end
    ADHDFocusDB.profile = name
    Print("applied profile: " .. name)

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
    Print("  /adhd reset               - reset categories to defaults")
    Print("  /adhd profile <name>      - apply a profile (default|pvp|arena)")
    Print("  /adhd profile list        - show active + available profiles")
  end
end

local function EnforceCVars()
  if type(SetCVar) ~= "function" then return end
  for cvar, value in pairs(CVAR_OVERRIDES) do
    if GetCVar and GetCVar(cvar) ~= value then
      SetCVar(cvar, value)
    end
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
    EnforceCVars()
    local n = ApplyAll()
    Print(("loaded, %d sounds muted. /adhd for commands."):format(n))
  end
end)

SLASH_ADHDFOCUS1 = "/adhd"
SLASH_ADHDFOCUS2 = "/adhdfocus"
SlashCmdList["ADHDFOCUS"] = HandleSlash
