# ADHDFocus

A WoW addon for sensory-overload reduction in PvP. Bulk-mutes ambient game
audio (footsteps, mount foley, gear jingle, world ambience, etc.) while
leaving tactical PvP cues audible (CC casts, interrupts, stuns, roots,
stealth openers, major cooldowns, flag capture audio).

Built for the TBC Classic Anniversary client (2026) but the API surface
should work on any Classic flavor that exposes `MuteSoundFile`.

## Install

Clone or download into your AddOns folder so the path is
`Interface/AddOns/wow-adhd-focus/`.

```
cd /path/to/Interface/AddOns
git clone https://github.com/plejon/wow-adhd-focus.git
```

Enable **ADHDFocus** at character select.

## Commands

```
/adhd                              status
/adhd on | off                     master toggle
/adhd profile                      show active + list available
/adhd profile <name>               apply a profile
/adhd profile save <name>          save current state as a profile
/adhd profile delete <name>        delete a saved profile
/adhd mute <id>                    add a custom muted fileDataId
/adhd unmute <id>                  remove a custom muted fileDataId
/adhd list                         list session custom mutes
```

## Profiles

| Profile  | Effect                                                                 |
|----------|------------------------------------------------------------------------|
| `pvp`    | Default. Everything muted. PvP-tactical spells stay audible.           |
| `arena`  | Same as `pvp` at category level (room to differentiate later).         |
| `light`  | Light muting: only footsteps, doodads, mount foley, emotes. Spells / weapons / gear / vocals / creature noise all audible. |

### Saving custom profiles

```
/adhd profile pvp
/adhd mute 569720
/adhd mute 569721
/adhd profile save mypvp
```

`/adhd profile save` snapshots the active profile's category state plus
any custom mutes you've added in this session. Switching profiles
afterward clears the session-level customs (your saved profile keeps them
baked in). Saved profiles persist across sessions in `ADHDFocusDB.savedProfiles`.

Reserved names (cannot be used for saved profiles): `list`, `save`,
`delete`. Built-in names (`pvp`, `arena`, `light`) are also blocked.

## What each profile mutes

Each profile is a category-state map. The categories themselves live in
`Categories.lua` (auto-generated from the wow-listfile). Total bucketed
sound IDs: ~95K out of ~277K under `sound/` in the listfile.

| Category          | What it covers                                                                 | IDs    |
|-------------------|--------------------------------------------------------------------------------|--------|
| CreatureAmbience  | Non-tactical creature noise: idle/loop/breath/fidget/walk/run/wing-flap/takeoff/landing, plus attack/wound/crit/preaggro/chuff (druid form attacks, mechastrider engine, NPC melee swings). | ~44K   |
| SpellCasts        | All `sound/spell[s]/*` except the tactical whitelist (see below).             | ~16.5K |
| CharacterVocals   | Race/gender vocalizations (jumps, falls, hits, breathing).                    | ~16K   |
| Doodads           | Environmental objects (anvils, doors, fires, banners).                        | ~9K    |
| Weapons           | `sound/item/weapons/*` **except** bow + gun (positional ranged cue kept).     | ~3K    |
| MountFoley        | All `sound/creature/<mount>/*` **except** mount summon cast/precast.          | ~2.7K  |
| Footsteps         | `sound/character/*footstep*` + `sound/foley/*`.                               | ~1.9K  |
| Interface         | `sound/interface/*` **except** raid alerts + PvP cues (see whitelist).        | ~615   |
| Gear              | `sound/item/foleysounds/*` (armor jingle) + `sound/item/usesounds/*`.         | 78     |
| UtilitySpells     | Hearthstone, refreshment, conjure, teleport, mark of the wild, thorns, inner fire, arcane intellect, etc. | 67     |
| Emotes            | `sound/character/*emote*`.                                                    | 40     |

### Not muted by this addon (use WoW UI)

The following audio is intentionally left alone — WoW already exposes a
dedicated volume slider, so duplicating the mute would just take control
away from the slider.

- **Music** (`sound/music/*`) — Sound options → Music slider.
- **World ambience** (`sound/ambience/*` + `sound/emitters/*`) — Ambience slider.
- **NPC dialog & quest VO** (gossip greets, click responses, `vo_*`) — Dialog slider.

## Sounds kept audible (whitelist)

These are excluded from category muting at the build step. They stay
audible regardless of profile.

### Tactical PvP spell cues (~216 files)

Filename match on any of these tokens inside `sound/spell[s]/*`:

- **Stealth / openers** — stealth, prowl, vanish, shadowdance, invisibility,
  cheapshot, ambush, garrote, pounce, ravage.
- **Crowd control** — polymorph, fear, psychic scream, howl of fear,
  seduce, intimidating shout, scare animal, cyclone, hibernate, banish,
  repent, sap, gouge, blind, freezing trap, scatter shot.
- **Roots** — entangling roots, nature's grasp, frost nova.
- **Stuns** — kidney shot, hammer of justice, mace stun, concussion blow,
  intercept stun, maim, intimidate, war stomp, bash.
- **Interrupts / silences** — counterspell, pummel, kick (rogue),
  earth shock, spell lock, spell silence, shadow word: silence.
- **Major cooldowns** — bestial wrath, recklessness, berserker rage,
  death wish, inner focus, presence of mind, icy veins, arcane power,
  blade flurry, adrenaline rush, sprint, fade, divine favor,
  avenging wrath, blood fury, berserking, stoneform, escape artist.

### PvP objective audio (`sound/interface/`)

- Flag captured / taken (both factions) — WSG, EotS.
- BG countdown start + timer ticks.
- Capture nodes (mine carts in SotA, etc.).
- `pvpwarning` family.
- Victory / defeat stingers.

### Mount summon

Any file in a `sound/creature/<mount>/*` folder whose name contains
`_cast_` or `_precast_`. The "mounting up" sound stays audible across
all mounts — incoming-enemy cue in world PvP.

### Other

- `sound/item/trinkets/*` — on-use PvP trinket audio.
- `sound/item/weapons/{bow,gun}/*` + top-level `gunfire*` — ranged shots.
- `sound/cinematicvoices/*` — cinematic dialog.
- Raid alerts: `raidwarning`, `readycheck`, alarm clock, generic warning.

## Forced CVars

On every `PLAYER_LOGIN` the addon sets:

```
Sound_EnableErrorSpeech = 0
Sound_EnableEmoteSounds = 0
```

These silence the "Not enough mana!" voice lines and `/laugh /cheer` NPC
emote audio respectively. Override per session via `/console` if needed.

## Adding sounds you want kept

To restore a specific sound:

```
/adhd unmute <fileDataId>
```

To find a FileDataID, browse the [wago.tools](https://wago.tools/files?product=wow_anniversary)
file index filtered by path. Sound ID Finder addon doesn't exist for TBC
Anniversary, and Lua `PlaySound` hooks only see UI audio — engine-internal
sounds (creature animations, mount foley, takeoff flaps) bypass Lua
entirely, so there's no runtime discovery path.

If you want a sound permanently retained, add the filename pattern to
`SPELL_KEEP` in `build_categories.py` and regenerate.

## Regenerating Categories.lua

```
python3 build_categories.py [--refresh]
```

`--refresh` re-downloads the wow-listfile community CSV (~146 MB; cached
at `/tmp/wow-community-listfile.csv`).
