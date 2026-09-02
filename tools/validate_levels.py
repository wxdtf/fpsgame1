#!/usr/bin/env python3
"""
Static validator for the hand-authored levels in fpsgame1/GameWorld.swift.

The game has no automated tests, and level data is a large hand-typed grid, so
this script parses every `levelNData()` function straight out of the Swift
source and checks that each map is actually playable:

  * grid is rectangular and fully enclosed by walls
  * player start, enemies and items sit on walkable tiles (not inside walls/doors)
  * the exit portal, the mission objective, every key and (by default) every
    enemy/item can be reached from the start, honouring locked doors: a colour
    only unlocks once its key card is reachable
  * doors sit in a corridor (walls on two opposite sides)
  * damage-floor tiles are used only where a wall would not be expected

Usage:
    python3 tools/validate_levels.py            # validate all levels
    python3 tools/validate_levels.py --verbose  # also print maps and stats

Exit status is non-zero when any level has an error, so the script can run in CI.
"""

import argparse
import re
import sys
from collections import deque
from pathlib import Path

# Tile ids — must match TileType in GameWorld.swift
EMPTY, BRICK, METAL, TECH, DOOR, BRICK_TORCH, EXIT = 0, 1, 2, 3, 4, 5, 6
LOCKED_RED, LOCKED_BLUE, LOCKED_YELLOW, DAMAGE_FLOOR = 7, 8, 9, 10

LOCKED_DOORS = {LOCKED_RED: "red", LOCKED_BLUE: "blue", LOCKED_YELLOW: "yellow"}
WALKABLE = {EMPTY, DOOR, DAMAGE_FLOOR}
WALLS = {BRICK, METAL, TECH, BRICK_TORCH, EXIT}
ALL_KEYS = {"red", "blue", "yellow"}

TILE_GLYPH = {
    EMPTY: ".", BRICK: "#", METAL: "#", TECH: "#", DOOR: "+", BRICK_TORCH: "T",
    EXIT: "X", LOCKED_RED: "R", LOCKED_BLUE: "B", LOCKED_YELLOW: "Y", DAMAGE_FLOOR: "~",
}


class Level:
    def __init__(self, number):
        self.number = number
        self.layout = []
        self.start = None          # (x, y) floats
        self.enemies = []          # (type, x, y)
        self.items = []            # (kind, args, x, y)
        self.objective = None      # e.g. "retrieveIntel", "exterminate(.demon)"
        self.errors = []
        self.warnings = []

    @property
    def width(self):
        return len(self.layout[0]) if self.layout else 0

    @property
    def height(self):
        return len(self.layout)

    def tile(self, x, y):
        if 0 <= y < self.height and 0 <= x < self.width:
            return self.layout[y][x]
        return BRICK

    def error(self, msg):
        self.errors.append(msg)

    def warn(self, msg):
        self.warnings.append(msg)


# --------------------------------------------------------------------------- parsing

LEVEL_FUNC_RE = re.compile(r"private static func level(\d+)Data\(\)")
ROW_RE = re.compile(r"^\s*\[\s*([0-9]+(?:\s*,\s*[0-9]+)*)\s*,?\s*\]")
START_RE = re.compile(
    r"playerStartX:\s*([-\d.]+)\s*,\s*playerStartY:\s*([-\d.]+)")
ENTITY_RE = re.compile(r"\(\s*\.(\w+)(\([^()]*\))?\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)")
OBJECTIVE_RE = re.compile(r"objective:\s*\.(\w+(?:\([^)]*\))?)")


def strip_comment(line):
    idx = line.find("//")
    return line if idx < 0 else line[:idx]


def parse_levels(source):
    """Return a list of Level objects parsed from GameWorld.swift."""
    matches = list(LEVEL_FUNC_RE.finditer(source))
    levels = []
    for i, m in enumerate(matches):
        chunk_end = matches[i + 1].start() if i + 1 < len(matches) else len(source)
        chunk = source[m.start():chunk_end]
        level = Level(int(m.group(1)))

        # Layout rows
        layout_start = chunk.find("let layout")
        layout_body = chunk[layout_start:]
        for raw in layout_body.splitlines():
            line = strip_comment(raw)
            rm = ROW_RE.match(line)
            if rm:
                level.layout.append([int(v) for v in rm.group(1).split(",")])
            elif level.layout and line.strip().startswith("]"):
                break

        sm = START_RE.search(chunk)
        if sm:
            level.start = (float(sm.group(1)), float(sm.group(2)))

        # Enemies / items sections: text between "enemies: [" ... "items: [" ... end
        def section(name, nxt):
            s = chunk.find(name + ": [")
            if s < 0:
                return ""
            e = chunk.find(nxt, s) if nxt else len(chunk)
            if e < 0:
                e = len(chunk)
            return chunk[s:e]

        enemies_text = section("enemies", "items: [")
        items_text = section("items", "objective:")
        if not items_text:
            items_text = section("items", None)

        for raw in enemies_text.splitlines():
            line = strip_comment(raw)
            for em in ENTITY_RE.finditer(line):
                level.enemies.append((em.group(1), float(em.group(3)), float(em.group(4))))
        for raw in items_text.splitlines():
            line = strip_comment(raw)
            for im in ENTITY_RE.finditer(line):
                level.items.append((im.group(1), im.group(2) or "", float(im.group(3)), float(im.group(4))))

        om = OBJECTIVE_RE.search(chunk)
        if om:
            level.objective = om.group(1)

        levels.append(level)
    return levels


# --------------------------------------------------------------------------- analysis

def passable(tile, keys):
    if tile in WALKABLE:
        return True
    colour = LOCKED_DOORS.get(tile)
    return colour is not None and colour in keys


def flood(level, start_tile, keys):
    """BFS over walkable tiles given the currently held keys."""
    seen = {start_tile}
    q = deque([start_tile])
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if (nx, ny) in seen:
                continue
            if not (0 <= nx < level.width and 0 <= ny < level.height):
                continue
            if passable(level.tile(nx, ny), keys):
                seen.add((nx, ny))
                q.append((nx, ny))
    return seen


def reachable_with_keys(level):
    """Iteratively expand reachability as key cards become reachable."""
    start_tile = (int(level.start[0]), int(level.start[1]))
    keys = set()
    passes = []
    while True:
        reach = flood(level, start_tile, keys)
        new_keys = set()
        for kind, args, x, y in level.items:
            if kind == "keyCard" and (int(x), int(y)) in reach:
                colour = re.search(r"\.(\w+)", args)
                if colour and colour.group(1) not in keys:
                    new_keys.add(colour.group(1))
        if not new_keys:
            return reach, keys, passes
        keys |= new_keys
        passes.append(sorted(new_keys))


def adjacent_walkable(level, x, y, reach):
    return any((nx, ny) in reach for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))


def validate(level, require_all_reachable=True):
    if not level.layout:
        level.error("no layout rows parsed")
        return
    if level.start is None:
        level.error("player start not parsed")
        return

    w, h = level.width, level.height
    for y, row in enumerate(level.layout):
        if len(row) != w:
            level.error(f"row {y} has {len(row)} columns, expected {w}")
    if level.errors:
        return

    # Border must be solid
    for x in range(w):
        for y in (0, h - 1):
            if level.tile(x, y) not in WALLS:
                level.error(f"border tile ({x},{y}) is not a wall")
    for y in range(h):
        for x in (0, w - 1):
            if level.tile(x, y) not in WALLS:
                level.error(f"border tile ({x},{y}) is not a wall")

    # Unknown tile ids
    for y in range(h):
        for x in range(w):
            if level.tile(x, y) not in TILE_GLYPH:
                level.error(f"unknown tile id {level.tile(x, y)} at ({x},{y})")

    # Player start clearance (player radius 0.25 must not touch a solid tile)
    sx, sy = level.start
    for cx, cy in ((sx - 0.25, sy - 0.25), (sx + 0.25, sy - 0.25), (sx - 0.25, sy + 0.25), (sx + 0.25, sy + 0.25)):
        t = level.tile(int(cx), int(cy))
        if t not in WALKABLE or t == DOOR:
            level.error(f"player start ({sx},{sy}) overlaps non-walkable tile ({int(cx)},{int(cy)})")

    # Entities must be on walkable, non-door tiles
    for kind, x, y in level.enemies:
        t = level.tile(int(x), int(y))
        if t not in WALKABLE:
            level.error(f"enemy {kind} at ({x},{y}) is inside a wall tile")
        elif t == DOOR:
            level.error(f"enemy {kind} at ({x},{y}) is inside a door tile")
    for kind, args, x, y in level.items:
        t = level.tile(int(x), int(y))
        if t not in WALKABLE and t not in LOCKED_DOORS:
            level.error(f"item {kind}{args} at ({x},{y}) is inside a wall tile")
        elif t == DOOR or t in LOCKED_DOORS:
            level.error(f"item {kind}{args} at ({x},{y}) is inside a door tile")

    # Duplicate positions (two entities stacked on the same spot)
    positions = {}
    for kind, x, y in level.enemies:
        positions.setdefault((x, y), []).append(f"enemy {kind}")
    for kind, args, x, y in level.items:
        positions.setdefault((x, y), []).append(f"item {kind}")
    for pos, names in positions.items():
        if len(names) > 1:
            level.warn(f"{' and '.join(names)} share the same position {pos}")

    # Doors should be embedded in a corridor: walls on two opposite sides
    for y in range(h):
        for x in range(w):
            t = level.tile(x, y)
            if t == DOOR or t in LOCKED_DOORS:
                horiz_walls = level.tile(x - 1, y) in WALLS and level.tile(x + 1, y) in WALLS
                vert_walls = level.tile(x, y - 1) in WALLS and level.tile(x, y + 1) in WALLS
                if not (horiz_walls or vert_walls):
                    level.warn(f"door at ({x},{y}) is not flanked by walls on opposite sides")
                if horiz_walls and vert_walls:
                    level.warn(f"door at ({x},{y}) is walled in on all four sides")

    # Reachability honouring keys
    reach, keys, key_passes = reachable_with_keys(level)
    level.reach = reach
    level.keys_found = keys
    level.key_passes = key_passes
    level.info = []

    exits = [(x, y) for y in range(h) for x in range(w) if level.tile(x, y) == EXIT]
    if not exits:
        level.error("level has no exit portal")
    for ex, ey in exits:
        if not adjacent_walkable(level, ex, ey, reach):
            level.error(f"exit portal at ({ex},{ey}) is not reachable from the start")

    # Every locked-door colour present needs a reachable key
    colours_needed = {LOCKED_DOORS[t] for row in level.layout for t in row if t in LOCKED_DOORS}
    for colour in sorted(colours_needed - keys):
        level.error(f"{colour} locked door exists but no reachable {colour} key card")
    for kind, args, x, y in level.items:
        if kind == "keyCard":
            colour = re.search(r"\.(\w+)", args).group(1)
            if colour not in colours_needed:
                level.warn(f"{colour} key card at ({x},{y}) has no matching locked door")

    # Mission objective
    obj = level.objective
    if obj:
        if obj.startswith("retrieve"):
            wanted = "intelData" if obj == "retrieveIntel" else "demonicArtifact"
            found = [(x, y) for kind, args, x, y in level.items if kind == wanted]
            if not found:
                level.error(f"objective {obj} but level has no {wanted} item")
            for x, y in found:
                if (int(x), int(y)) not in reach:
                    level.error(f"objective item {wanted} at ({x},{y}) is unreachable")
        elif obj.startswith("exterminate"):
            m = re.match(r"exterminate\(\.(\w+)\)", obj)
            target = m.group(1) if m else None
            targets = [(k, x, y) for k, x, y in level.enemies if target is None or k == target]
            if not targets:
                level.error(f"objective {obj} but level has no matching enemies")
            for k, x, y in targets:
                if (int(x), int(y)) not in reach:
                    level.error(f"objective target {k} at ({x},{y}) is unreachable — level cannot be completed")

    # Everything else reachable?
    for kind, x, y in level.enemies:
        if (int(x), int(y)) not in reach:
            msg = f"enemy {kind} at ({x},{y}) is unreachable from the start"
            (level.error if require_all_reachable else level.warn)(msg)
    for kind, args, x, y in level.items:
        if (int(x), int(y)) not in reach:
            msg = f"item {kind}{args} at ({x},{y}) is unreachable from the start"
            (level.error if require_all_reachable else level.warn)(msg)

    # Gating analysis: seal every door of one colour and see what is still reachable.
    # A colour whose doors can all be walked around is decoration, not a gate.
    def objective_targets():
        if not obj:
            return []
        if obj.startswith("retrieve"):
            wanted = "intelData" if obj == "retrieveIntel" else "demonicArtifact"
            return [(int(x), int(y)) for kind, args, x, y in level.items if kind == wanted]
        if obj.startswith("exterminate"):
            m = re.match(r"exterminate\(\.(\w+)\)", obj)
            target = m.group(1) if m else None
            return [(int(x), int(y)) for k, x, y in level.enemies if target is None or k == target]
        return []

    for colour in sorted(colours_needed):
        sealed = flood(level, (int(sx), int(sy)), ALL_KEYS - {colour})
        exit_ok = all(adjacent_walkable(level, ex, ey, sealed) for ex, ey in exits)
        if exit_ok:
            level.warn(f"{colour} key is never required: the exit is reachable with every {colour} door sealed")
        else:
            level.info.append(f"{colour} key gates the exit")
        blocked_targets = [t for t in objective_targets() if t not in sealed]
        if blocked_targets:
            level.info.append(f"{colour} key gates the objective ({len(blocked_targets)} target(s) behind it)")

    # Dead floor: walkable tiles never reachable even with every key
    all_keys_reach = flood(level, (int(sx), int(sy)), ALL_KEYS)
    dead = [(x, y) for y in range(h) for x in range(w)
            if level.tile(x, y) in WALKABLE and (x, y) not in all_keys_reach]
    if dead:
        level.warn(f"{len(dead)} walkable tiles are sealed off (e.g. {dead[:4]})")

    # Damage floor sanity: should not be the only route to the exit (warn if exit
    # is unreachable when nukage is treated as solid)
    if any(DAMAGE_FLOOR in row for row in level.layout):
        def flood_no_nukage(start_tile):
            seen = {start_tile}
            q = deque([start_tile])
            while q:
                x, y = q.popleft()
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if (nx, ny) in seen or not (0 <= nx < w and 0 <= ny < h):
                        continue
                    t = level.tile(nx, ny)
                    if t != DAMAGE_FLOOR and passable(t, ALL_KEYS):
                        seen.add((nx, ny))
                        q.append((nx, ny))
            return seen
        dry = flood_no_nukage((int(sx), int(sy)))
        for ex, ey in exits:
            if not adjacent_walkable(level, ex, ey, dry):
                level.warn("the exit can only be reached by crossing damage floor")


def stats(level):
    enemy_counts = {}
    for kind, _, _ in level.enemies:
        enemy_counts[kind] = enemy_counts.get(kind, 0) + 1
    totals = {"health": 0, "armor": 0, "bullets": 0, "shells": 0}
    kinds = {}
    for kind, args, _, _ in level.items:
        kinds[kind] = kinds.get(kind, 0) + 1
        amount = re.search(r"amount:\s*(\d+)", args)
        amt = int(amount.group(1)) if amount else 0
        if kind == "healthPack":
            totals["health"] += amt
        elif kind == "armorVest":
            totals["armor"] += amt
        elif kind == "ammoBullets":
            totals["bullets"] += amt
        elif kind == "ammoShells":
            totals["shells"] += amt
    walkable = sum(1 for row in level.layout for t in row if t in WALKABLE)
    nukage = sum(1 for row in level.layout for t in row if t == DAMAGE_FLOOR)
    doors = sum(1 for row in level.layout for t in row if t == DOOR or t in LOCKED_DOORS)
    return enemy_counts, kinds, totals, walkable, nukage, doors


def render_map(level):
    lines = []
    overlay = {}
    for kind, x, y in level.enemies:
        overlay[(int(x), int(y))] = kind[0].upper()
    for kind, args, x, y in level.items:
        glyph = {"keyCard": "k", "intelData": "i", "demonicArtifact": "a",
                 "shotgunPickup": "s", "chaingunPickup": "c", "berserkPack": "b"}.get(kind, "*")
        overlay[(int(x), int(y))] = glyph
    if level.start:
        overlay[(int(level.start[0]), int(level.start[1]))] = "@"
    for y, row in enumerate(level.layout):
        lines.append("".join(overlay.get((x, y), TILE_GLYPH.get(t, "?")) for x, t in enumerate(row)))
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", default=str(Path(__file__).resolve().parent.parent / "fpsgame1" / "GameWorld.swift"))
    parser.add_argument("--verbose", "-v", action="store_true", help="print maps and item statistics")
    parser.add_argument("--allow-unreachable", action="store_true",
                        help="downgrade unreachable non-objective entities from errors to warnings")
    args = parser.parse_args()

    source = Path(args.source).read_text()
    levels = parse_levels(source)
    if not levels:
        print("no levels found in", args.source)
        return 2

    failed = False
    for level in levels:
        validate(level, require_all_reachable=not args.allow_unreachable)
        enemy_counts, kinds, totals, walkable, nukage, doors = stats(level)
        status = "FAIL" if level.errors else "OK"
        print(f"Level {level.number}: {status}  ({level.width}x{level.height}, "
              f"{len(level.enemies)} enemies, {len(level.items)} items, {doors} doors, "
              f"{walkable} walkable tiles, {nukage} damage-floor tiles)")
        if level.objective:
            print(f"  objective: {level.objective}")
        if getattr(level, "key_passes", None):
            print("  key progression: " + " -> ".join("+".join(p) for p in level.key_passes))
        for msg in getattr(level, "info", []):
            print(f"  info:  {msg}")
        for e in level.errors:
            print(f"  ERROR: {e}")
        for wmsg in level.warnings:
            print(f"  warn:  {wmsg}")
        if args.verbose:
            print(f"  enemies: {enemy_counts}")
            print(f"  items:   {kinds}")
            print(f"  supplies: {totals}")
            print(render_map(level))
        if level.errors:
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
