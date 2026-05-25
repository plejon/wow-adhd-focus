local ADDON, A = ...

-- Built-in profiles. Each maps which Categories (from Categories.lua) get
-- muted. Categories are an implementation detail — the user sees only
-- profiles. Saved profiles may additionally carry per-id custom mutes.
local BUILTIN_PROFILES = {
  ["pvp"] = {
    desc = "PvP-strict: everything muted, tactical cues kept audible",
    categories = {
      SpellCasts = true, Weapons = true, Gear = true,
      CharacterVocals = true, Footsteps = true, Doodads = true,
      CreatureAmbience = true, WorldAmbience = true, Emotes = true,
      Interface = true, Music = true, MountFoley = true,
      UtilitySpells = true,
    },
  },
  ["arena"] = {
    desc = "Arena: identical to pvp at category granularity",
    categories = {
      SpellCasts = true, Weapons = true, Gear = true,
      CharacterVocals = true, Footsteps = true, Doodads = true,
      CreatureAmbience = true, WorldAmbience = true, Emotes = true,
      Interface = true, Music = true, MountFoley = true,
      UtilitySpells = true,
    },
  },
  ["light"] = {
    desc = "Light muting: only obvious ambient noise",
    categories = {
      SpellCasts = false, Weapons = false, Gear = false,
      CharacterVocals = false, Footsteps = true, Doodads = true,
      CreatureAmbience = false, WorldAmbience = true, Emotes = true,
      Interface = false, Music = false, MountFoley = true,
      UtilitySpells = false,
    },
  },
}

local DEFAULT_PROFILE = "pvp"
local RESERVED_PROFILE_NAMES = { list = true, save = true, delete = true }

local CVAR_OVERRIDES = {
  Sound_EnableErrorSpeech = "0",
  Sound_EnableEmoteSounds = "0",
}

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffADHDFocus|r " .. msg)
end

local function GetProfile(name)
  if not name then return nil end
  if BUILTIN_PROFILES[name] then return BUILTIN_PROFILES[name], "builtin" end
  local saved = ADHDFocusDB.savedProfiles and ADHDFocusDB.savedProfiles[name]
  if saved then return saved, "saved" end
  return nil
end

local function ApplyCategory(category, enable)
  local ids = A.Categories[category]
  if not ids then return 0 end
  for _, id in ipairs(ids) do
    if enable then MuteSoundFile(id) else UnmuteSoundFile(id) end
  end
  return #ids
end

local function UnmuteEverything()
  for category in pairs(A.Categories) do
    ApplyCategory(category, false)
  end
  for id in pairs(ADHDFocusDB.customMutes or {}) do
    UnmuteSoundFile(id)
  end
end

local function ApplyCurrentState()
  if not ADHDFocusDB.enabled then
    UnmuteEverything()
    return 0
  end
  local profile = GetProfile(ADHDFocusDB.activeProfile)
                  or BUILTIN_PROFILES[DEFAULT_PROFILE]
  local muted = 0
  for category in pairs(A.Categories) do
    local on = profile.categories and profile.categories[category]
    if on then
      muted = muted + ApplyCategory(category, true)
    else
      ApplyCategory(category, false)
    end
  end
  -- profile-baked customs (saved profiles)
  if profile.customMutes then
    for id in pairs(profile.customMutes) do
      MuteSoundFile(id)
      muted = muted + 1
    end
  end
  -- session-level customs (on top of whatever profile is active)
  for id in pairs(ADHDFocusDB.customMutes or {}) do
    MuteSoundFile(id)
    muted = muted + 1
  end
  return muted
end

local function CopyCategories(src)
  local out = {}
  for k, v in pairs(src or {}) do out[k] = v end
  return out
end

local function CopyCustomMutes(src)
  local out = {}
  for id in pairs(src or {}) do out[id] = true end
  return out
end

local function EnforceCVars()
  if type(SetCVar) ~= "function" then return end
  for cvar, value in pairs(CVAR_OVERRIDES) do
    if GetCVar and GetCVar(cvar) ~= value then
      SetCVar(cvar, value)
    end
  end
end

local function HandleSlash(input)
  input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, rest = input:match("^(%S+)%s*(.*)$")
  cmd = (cmd or ""):lower()
  rest = rest or ""

  if cmd == "" or cmd == "status" then
    local state = ADHDFocusDB.enabled and "|cff88ff88on|r" or "|cffff8888off|r"
    local active = ADHDFocusDB.activeProfile or DEFAULT_PROFILE
    local profile, kind = GetProfile(active)
    local n = 0
    if profile then
      for c, on in pairs(profile.categories or {}) do
        if on and A.Categories[c] then n = n + #A.Categories[c] end
      end
      if profile.customMutes then
        for _ in pairs(profile.customMutes) do n = n + 1 end
      end
    end
    local custom = 0
    for _ in pairs(ADHDFocusDB.customMutes or {}) do custom = custom + 1 end
    Print("addon: " .. state)
    Print(("active profile: %s (%s, %d ids)"):format(active, kind or "missing", n))
    Print("session-level custom mutes: " .. custom)

  elseif cmd == "on" then
    ADHDFocusDB.enabled = true
    local n = ApplyCurrentState()
    Print(("on — %d sounds muted (profile: %s)"):format(n, ADHDFocusDB.activeProfile or DEFAULT_PROFILE))

  elseif cmd == "off" then
    ADHDFocusDB.enabled = false
    UnmuteEverything()
    Print("off — reload UI to fully hear sounds that already played")

  elseif cmd == "profile" then
    local sub, arg = rest:match("^(%S*)%s*(.*)$")
    sub = (sub or ""):lower()
    arg = arg or ""

    if sub == "" or sub == "list" then
      Print("active: " .. (ADHDFocusDB.activeProfile or DEFAULT_PROFILE))
      Print("available:")
      for name, p in pairs(BUILTIN_PROFILES) do
        Print(("  %s  |cffaaaaaa(builtin) %s|r"):format(name, p.desc or ""))
      end
      if ADHDFocusDB.savedProfiles then
        for name, p in pairs(ADHDFocusDB.savedProfiles) do
          Print(("  %s  |cffaaaaaa(saved) %s|r"):format(name, p.desc or ""))
        end
      end

    elseif sub == "save" then
      local name = arg:gsub("^%s*(.-)%s*$", "%1")
      if name == "" or RESERVED_PROFILE_NAMES[name] or BUILTIN_PROFILES[name] then
        Print("invalid name: " .. (name ~= "" and name or "<empty>")
              .. " (reserved or conflicts with builtin)")
        return
      end
      local active = GetProfile(ADHDFocusDB.activeProfile)
                     or BUILTIN_PROFILES[DEFAULT_PROFILE]
      ADHDFocusDB.savedProfiles = ADHDFocusDB.savedProfiles or {}
      ADHDFocusDB.savedProfiles[name] = {
        desc = "saved from " .. (ADHDFocusDB.activeProfile or DEFAULT_PROFILE),
        categories = CopyCategories(active.categories),
        customMutes = CopyCustomMutes(ADHDFocusDB.customMutes),
      }
      -- saved customs are now baked in; clear session-level
      ADHDFocusDB.customMutes = {}
      ADHDFocusDB.activeProfile = name
      Print("saved profile: " .. name .. " (and switched to it)")

    elseif sub == "delete" or sub == "remove" then
      local name = arg:gsub("^%s*(.-)%s*$", "%1")
      if BUILTIN_PROFILES[name] then
        Print("can't delete builtin profile: " .. name)
        return
      end
      if not (ADHDFocusDB.savedProfiles and ADHDFocusDB.savedProfiles[name]) then
        Print("no saved profile named: " .. name)
        return
      end
      ADHDFocusDB.savedProfiles[name] = nil
      if ADHDFocusDB.activeProfile == name then
        ADHDFocusDB.activeProfile = DEFAULT_PROFILE
        ApplyCurrentState()
        Print("deleted; switched to " .. DEFAULT_PROFILE)
      else
        Print("deleted: " .. name)
      end

    else
      -- treat sub as a profile name to apply
      local name = sub
      local p = GetProfile(name)
      if not p then
        Print("unknown profile: " .. name .. " — try /adhd profile list")
        return
      end
      ADHDFocusDB.activeProfile = name
      ADHDFocusDB.customMutes = {} -- profile switch clears session customs
      local n = ApplyCurrentState()
      Print(("applied profile: %s (%d sounds muted)"):format(name, n))
    end

  elseif cmd == "mute" then
    local id = tonumber(rest)
    if not id then Print("usage: /adhd mute <fileDataId>") return end
    ADHDFocusDB.customMutes = ADHDFocusDB.customMutes or {}
    ADHDFocusDB.customMutes[id] = true
    if ADHDFocusDB.enabled then MuteSoundFile(id) end
    Print("muted id " .. id)

  elseif cmd == "unmute" then
    local id = tonumber(rest)
    if not id then Print("usage: /adhd unmute <fileDataId>") return end
    if ADHDFocusDB.customMutes then ADHDFocusDB.customMutes[id] = nil end
    UnmuteSoundFile(id)
    Print("unmuted id " .. id)

  elseif cmd == "list" then
    local ids = {}
    for id in pairs(ADHDFocusDB.customMutes or {}) do table.insert(ids, id) end
    table.sort(ids)
    Print("session-level custom mutes: "
          .. (#ids == 0 and "(none)" or table.concat(ids, ", ")))

  else
    Print("commands:")
    Print("  /adhd                          status")
    Print("  /adhd on | off                 master toggle")
    Print("  /adhd profile                  show active + list available")
    Print("  /adhd profile <name>           apply a profile")
    Print("  /adhd profile save <name>      save current state as a profile")
    Print("  /adhd profile delete <name>    delete a saved profile")
    Print("  /adhd mute <id>                add a custom muted fileDataId")
    Print("  /adhd unmute <id>              remove a custom muted fileDataId")
    Print("  /adhd list                     list session custom mutes")
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == ADDON then
    ADHDFocusDB = ADHDFocusDB or {}
    if ADHDFocusDB.enabled == nil then ADHDFocusDB.enabled = true end
    ADHDFocusDB.activeProfile = ADHDFocusDB.activeProfile or DEFAULT_PROFILE
    ADHDFocusDB.customMutes  = ADHDFocusDB.customMutes  or {}
    ADHDFocusDB.savedProfiles = ADHDFocusDB.savedProfiles or {}
  elseif event == "PLAYER_LOGIN" then
    EnforceCVars()
    local n = ApplyCurrentState()
    local state = ADHDFocusDB.enabled and "on" or "off"
    Print(("loaded (%s), profile: %s, %d sounds muted. /adhd for commands."):format(
      state, ADHDFocusDB.activeProfile, n))
  end
end)

SLASH_ADHDFOCUS1 = "/adhd"
SLASH_ADHDFOCUS2 = "/adhdfocus"
SlashCmdList["ADHDFOCUS"] = HandleSlash
