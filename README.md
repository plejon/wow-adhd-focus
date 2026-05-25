# ADHDFocus

A WoW addon for sensory-overload reduction in PvP. Bulk-mutes ambient game
audio (footsteps, mount foley, gear jingle, world ambience, etc.) while
leaving tactical PvP cues audible (CC casts, interrupts, stuns, roots,
stealth openers, major cooldowns, flag capture audio).

Built for the TBC Classic Anniversary client (2026) but the API surface
should work on any Classic flavor that exposes `MuteSoundFile`.

## Install

Clone or download the repo into your AddOns folder so the path is
`Interface/AddOns/wow-adhd-focus/`.

```
cd /path/to/Interface/AddOns
git clone https://github.com/plejon/wow-adhd-focus.git
```

In WoW, enable **ADHDFocus** at character select. On login the addon
prints `loaded, N sounds muted. /adhd for commands.`

## Commands

```
/adhd status                  show category states + id counts
/adhd mute all                mute every category
/adhd unmute all              unmute every category
/adhd mute   <category>       mute one category
/adhd unmute <category>       unmute one category
/adhd mute   <id>             mute one fileDataId
/adhd unmute <id>             unmute one fileDataId
/adhd list                    list custom muted ids
/adhd apply                   re-apply all enabled mutes
/adhd reset                   reset categories to in-code defaults
/adhd profile <name>          apply default | pvp | arena
/adhd profile list            show active + available profiles
```

## Profiles

| Profile   | Use case             | Effect                                                 |
|-----------|----------------------|--------------------------------------------------------|
| `pvp`     | BG / world PvP       | Everything muted. PvP-tactical spells stay audible.    |
| `arena`   | Arena                | Same as `pvp` at category level (room to differentiate via per-spell whitelist later). |
| `default` | Light sensory reduction | Only Footsteps / Doodads / WorldAmbience / Music / MountFoley / Emotes muted. |

Active profile persists across sessions in `ADHDFocusDB.profile`.

## Categories

| Category          | What it covers                                                                 | IDs    |
|-------------------|--------------------------------------------------------------------------------|--------|
| SpellCasts        | All `sound/spell[s]/*` except the tactical whitelist (see below).             | ~16.5K |
| CreatureAmbience  | Idle/loop/breath/fidget/walk/run/wing-flap/takeoff/landing for non-mount creatures. | ~20K   |
| CharacterVocals   | Race/gender vocalizations (jumps, falls, hits, breathing).                    | ~16K   |
| Doodads           | Environmental objects (anvils, doors, fires, banners).                        | ~9K    |
| WorldAmbience     | `sound/ambience/*` + `sound/emitters/*` (placed world ambient).               | ~8K    |
| Music             | `sound/music/*`.                                                              | ~6K    |
| MountFoley        | All `sound/creature/<mount>/*` **except** mount summon cast/precast.          | ~2.7K  |
| Weapons           | `sound/item/weapons/*` **except** bow + gun (positional ranged cue kept).     | ~3K    |
| Footsteps         | `sound/character/*footstep*` + `sound/foley/*`.                               | ~1.9K  |
| Interface         | `sound/interface/*` **except** raid/PvP alerts (see whitelist).               | ~625   |
| Gear              | `sound/item/foleysounds/*` (armor jingle) + `sound/item/usesounds/*` (bandage, lockpick, eating). | 78     |
| UtilitySpells     | Hearthstone, refreshment, conjure, teleport, mark of the wild, thorns, inner fire, arcane intellect, etc. | 67     |
| Emotes            | `sound/character/*emote*` (most also killed via `Sound_EnableEmoteSounds=0`). | 40     |

## Sounds kept audible by default

Everything below is **excluded** from category muting so it stays audible
regardless of profile.

### Tactical PvP spell cues (216 sound files)

Filename match on any of these tokens inside `sound/spell[s]/*`:

- **Stealth / openers** — stealth, prowl, vanish, shadowdance, invisibility,
  cheapshot, ambush, garrote, pounce, ravage.
- **Crowd control** — polymorph, fear, psychic scream, howl of fear, seduce,
  intimidating shout, scare animal, cyclone, hibernate, banish, repent,
  sap, gouge, blind, freezing trap, scatter shot.
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

- Flag captured / taken (both factions) — Warsong Gulch, Eye of the Storm.
- BG countdown start / timer ticks.
- Capture node (mine cart in Strand of the Ancients, etc.).
- `pvpwarning` family (general PvP alert).
- Victory / defeat stingers.

### Mount summon

Any file in a `sound/creature/<mount>/*` folder whose name contains
`_cast_` or `_precast_`. The "mounting up" sound stays audible across
all mounts — useful for catching incoming enemies mounting in world PvP.

### Other keep-audible

- `sound/item/trinkets/*` — on-use PvP trinket audio.
- `sound/item/weapons/{bow,gun}/*` + top-level `gunfire*` — ranged shots
  retained as positional cues.
- `sound/cinematicvoices/*` — cinematic dialog.
- Raid alerts: `raidwarning`, `readycheck`, alarm clock, generic warning.

## Forced CVars

On every `PLAYER_LOGIN`, the addon sets:

```
Sound_EnableErrorSpeech = 0
Sound_EnableEmoteSounds = 0
```

These silence the "Not enough mana!" voice lines and `/laugh /cheer` NPC
emote audio respectively. Override per session via `/console` if needed.

## Identifying sounds you want kept

If something tactical is still being muted, name the file (path or
FileDataID) and add it via:

```
/adhd unmute <fileDataId>
```

Persisted as a custom unmute across sessions. Reload UI to take effect
for sounds already loaded.

To find FileDataIDs, browse the [wago.tools](https://wago.tools/files?product=wow_anniversary)
file index filtered by path. Sound ID Finder addon is not available for
TBC Anniversary; Lua hooks on `PlaySound` only see UI sounds, not engine
audio, so there's no in-game discovery path.

## Regenerating Categories.lua

The `Categories.lua` file is generated by `build_categories.py` from the
[wow-listfile community CSV](https://github.com/wowdev/wow-listfile). Run
when the listfile updates or you change rules in the script:

```
python3 build_categories.py [--refresh]
```

`--refresh` re-downloads the listfile (~146 MB; cached at
`/tmp/wow-community-listfile.csv`).
