#!/usr/bin/env python3
"""Build Categories.lua from wow-listfile community CSV.

Run: python3 build_categories.py [--refresh]
"""
import csv
import os
import re
import sys
import subprocess
from collections import defaultdict
from pathlib import Path

LISTFILE_URL = "https://github.com/wowdev/wow-listfile/releases/latest/download/community-listfile.csv"
CACHE = Path("/tmp/wow-community-listfile.csv")
OUT = Path(__file__).parent / "Categories.lua"

# Path-prefix matchers, evaluated top-to-bottom; first match wins.
# Each entry is (category, predicate). Returning None from a predicate skips
# that file entirely (keep-audible list).
KEEP_AUDIBLE_PATTERNS = [
    # NOTE: sound/spell[s]/ is NOT in keep-audible. PvP-strict strategy:
    # everything in sound/spells/ goes into the SpellCasts category (muted
    # by default). User listens during play and reports which spell sounds
    # they want kept; we whitelist by adding patterns to SPELL_KEEP below.
    re.compile(r"^sound/item/trinkets/"),
    # Ranged weapons = positional / threat cue in PvP
    re.compile(r"^sound/item/weapons/(bow|gun)/"),
    re.compile(r"^sound/item/weapons/gunfire"),
    re.compile(r"^sound/interface/(raidwarning|readycheck|alarm|alert|warning)"),
    re.compile(r"^sound/cinematicvoices/"),
    # Combat / alert cues from creatures: aggro, death, cast, summon
    re.compile(r"^sound/creature/[^/]+/.*(aggro|death|cast|summon)"),
]

# Spell sound filename patterns the user has confirmed they want kept
# audible during play. Add to this list as they identify each tactical
# cue they need back. Matched against the full sound/spell[s]/ path,
# case-insensitively (paths are already lowered).
SPELL_KEEP = re.compile(
    r"^sound/spells?/[^/]*("
    # placeholder — empty whitelist, add patterns here as user requests
    r"$^"  # impossible match while empty so nothing matches yet
    r")"
)

# Folders whose name contains "mount" but not "mountain" (Highmountain tauren
# NPCs etc.). Negative lookahead skips the false positive.
MOUNT_FOLDER = re.compile(r"^sound/creature/[^/]*mount(?!ain)[^/]*/")

# Utility / buff spells we want OUT of keep-audible. These are sound/spell[s]/
# filenames that match non-combat patterns — applied buffs, hearthstone,
# portal/teleport, conjure food/water, etc. Conservative list to avoid
# muting boss-ability sounds that happen to share prefixes (e.g.
# blessingofhalazzi which is a ZA boss cast).
UTILITY_SPELL_FILENAME = re.compile(
    r"^sound/spells?/[^/]*("
    r"hearth|refreshment|conjure|"
    r"^teleport|_teleport|demonicsummonteleport|"
    r"markofthewild|markofwild|giftofthewild|giftofwild|"
    r"thorns|innerfire|arcaneint|amplifymagic|dampenmagic|"
    r"divinespirit|prayerofspirit|prayer_of_spirit|"
    r"fortitude_buff|powerwordfortitude|prayeroffortitude"
    r")"
)

# Mount-specific creatures whose foley loops we want to mute (idle/breath/loop
# audio only; the KEEP_AUDIBLE block above already protects summon/cast).
CATEGORY_RULES = [
    # (category, regex) — first match wins.
    ("Footsteps",        re.compile(r"^sound/character/.*(footstep|foley)")),
    ("Footsteps",        re.compile(r"^sound/foley/")),
    ("Emotes",           re.compile(r"^sound/character/.*emote")),
    ("CharacterVocals",  re.compile(r"^sound/character/")),
    ("Weapons",          re.compile(r"^sound/item/weapons/")),
    ("Gear",             re.compile(r"^sound/item/(foleysounds|usesounds)/")),
    ("Doodads",          re.compile(r"^sound/doodad/")),
    ("Interface",        re.compile(r"^sound/interface/")),
    ("Music",            re.compile(r"^sound/music/")),
    ("WorldAmbience",    re.compile(r"^sound/(ambience|emitters)/")),
    # Non-combat creature noise. Combat cues (aggro/death/cast/etc) are in the
    # keep-audible list above so they get excluded before reaching here.
    # "moving" + "mountspecial" + "jumpstart" cover flying-mount wing flaps
    # on non-mount-named flyers (dragons, drakes, gryphons used as NPCs).
    ("CreatureAmbience", re.compile(r"^sound/creature/[^/]+/.*(ambient|ambience|idle|loop|breath|fidget|stand|walk|run|moving|mountspecial|jumpstart|flap|flutter|wingbeat|takeoff|land|flyup|fly_up|fly_start|flightstart|liftoff|lift_off)")),
]


def fetch_listfile(refresh: bool) -> Path:
    if CACHE.exists() and not refresh:
        return CACHE
    print(f"downloading {LISTFILE_URL} -> {CACHE}", file=sys.stderr)
    subprocess.run(["curl", "-fsSL", "-o", str(CACHE), LISTFILE_URL], check=True)
    return CACHE


def categorize(path: str) -> str | None:
    if not path.startswith("sound/"):
        return None
    # Mount folders: keep ONLY the mount-up cast/precast sound, mute the rest
    # (foley, wing flap loops, fidget, walk, run, moving, mountspecial).
    # This overrides the global keep-audible list so mount wound/attack/etc.
    # still get muted.
    if MOUNT_FOLDER.match(path):
        if "_cast_" in path or "_precast_" in path:
            return None
        return "MountFoley"
    # Spell sound handling. Everything in sound/spell[s]/ defaults to muted
    # (SpellCasts category). The user whitelists specific tactical sounds
    # via SPELL_KEEP as they identify them during play.
    if re.match(r"^sound/spells?/", path):
        if SPELL_KEEP.search(path):
            return None  # explicitly kept audible
        if UTILITY_SPELL_FILENAME.search(path):
            return "UtilitySpells"
        return "SpellCasts"
    for pat in KEEP_AUDIBLE_PATTERNS:
        if pat.search(path):
            return None
    for category, pat in CATEGORY_RULES:
        if pat.search(path):
            return category
    return None


def render_lua(buckets: dict[str, list[tuple[int, str]]]) -> str:
    head = '''-- AUTO-GENERATED by build_categories.py from wow-listfile community CSV.
-- Edit the script's CATEGORY_RULES + KEEP_AUDIBLE_PATTERNS, not this file
-- (your edits here will be overwritten on next regenerate).
--
-- KEEP AUDIBLE (excluded from all categories below):
--   * sound/item/trinkets/*              on-use trinket audio
--   * sound/item/weapons/{bow,gun}/*     ranged weapons = positional cue
--   * sound/item/weapons/gunfire*        top-level gun shots
--   * sound/interface/raidwarning|readycheck|alarm|alert|warning
--   * sound/cinematicvoices/*            cinematic dialog
--   * sound/creature/*/aggro|death|cast|summon
--                                        combat cues only (takeoff/land
--                                        moved to CreatureAmbience)
--   * sound/creature/<mount>/*_cast_*    mount summon ("mounting up")
--   * sound/creature/<mount>/*_precast_* mount summon channel
--   * sound/spells?/* matching SPELL_KEEP
--                                        explicit per-spell whitelist
--                                        (empty until user identifies)
--
-- All other sound/spell[s]/ files go into the new SpellCasts category
-- (default muted). User identifies what to keep via /adhd unmute <id>
-- or by reporting back so SPELL_KEEP is updated.
--
-- MountFoley mutes EVERYTHING else in mount-named creature folders
-- (fidget, moving, walk, run, wing-flap loop, mountspecial, attack,
-- battleshout, wound — sensory reduction wins over mounted combat cues).
--
-- To remove an individual mute at runtime: /adhd unmute <fileDataId>

local _, A = ...
A.Categories = {}
'''
    order = [
        "SpellCasts", "Weapons", "Gear", "CharacterVocals", "Footsteps",
        "Doodads", "CreatureAmbience", "WorldAmbience", "Emotes",
        "Interface", "Music", "MountFoley", "UtilitySpells",
    ]
    out = [head]
    for cat in order:
        rows = sorted(buckets.get(cat, []))
        out.append("")
        out.append("-- " + "-" * 74)
        out.append(f"-- {cat}: {len(rows)} ids")
        out.append(f"A.Categories.{cat} = {{")
        for fdid, path in rows:
            out.append(f"  {fdid}, -- {path}")
        out.append("}")
    return "\n".join(out) + "\n"


def main() -> int:
    refresh = "--refresh" in sys.argv
    src = fetch_listfile(refresh)
    buckets: dict[str, list[tuple[int, str]]] = defaultdict(list)
    total = 0
    sound_total = 0
    with src.open(newline="") as f:
        reader = csv.reader(f, delimiter=";")
        for row in reader:
            total += 1
            if len(row) < 2:
                continue
            try:
                fdid = int(row[0])
            except ValueError:
                continue
            path = row[1].lower().strip()
            if path.startswith("sound/"):
                sound_total += 1
            cat = categorize(path)
            if cat:
                buckets[cat].append((fdid, path))
    OUT.write_text(render_lua(buckets))
    print(f"scanned {total} files, {sound_total} under sound/", file=sys.stderr)
    bucketed = sum(len(v) for v in buckets.values())
    print(f"bucketed {bucketed}:", file=sys.stderr)
    for cat in sorted(buckets.keys()):
        print(f"  {cat}: {len(buckets[cat])}", file=sys.stderr)
    print(f"wrote {OUT}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
