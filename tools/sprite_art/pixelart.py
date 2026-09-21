"""
Tiny pure-Python pixel-art toolkit used to author the enemy sprite sheets.

Everything is drawn as *parts*: a part is a silhouette mask filled with one
material (a 5-tone colour ramp). When a part is composited onto the canvas it
gets automatic cel shading from a top-left light (highlight on the lit edge,
shadow on the far edge) and casts a small contact shadow on whatever was
already drawn beneath it. Details (eyes, teeth, seams) are painted directly.

Frames are exported as run-length strings that Sprites.swift decodes at
runtime, so the game still ships no image files.
"""

import struct
import zlib

TRANSPARENT = None


def rgb(r, g, b):
    return (max(0, min(255, int(r))), max(0, min(255, int(g))), max(0, min(255, int(b))))


def mix(a, b, t):
    return rgb(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def ramp(base, deep=None, hi=None):
    """5-tone ramp [deep, dark, base, light, hi] around a base colour."""
    deep = deep or mix(base, (10, 0, 10), 0.55)
    hi = hi or mix(base, (255, 240, 220), 0.45)
    return [deep, mix(deep, base, 0.5), base, mix(base, hi, 0.5), hi]


class Mask:
    """A silhouette to fill with one material."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = bytearray(w * h)

    def _set(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y * self.w + x] = 1

    def get(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h and self.px[y * self.w + x] == 1

    def oval(self, cx, cy, rx, ry):
        rx, ry = max(rx, 0.5), max(ry, 0.5)
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if nx * nx + ny * ny <= 1.0:
                    self._set(x, y)
        return self

    def circle(self, cx, cy, r):
        return self.oval(cx, cy, r, r)

    def rect(self, x, y, w, h):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self._set(xx, yy)
        return self

    def poly(self, points):
        ys = [p[1] for p in points]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            xs = []
            n = len(points)
            for i in range(n):
                (ax, ay), (bx, by) = points[i], points[(i + 1) % n]
                if ay == by:
                    continue
                if (ay <= y < by) or (by <= y < ay):
                    xs.append(ax + (y - ay) * (bx - ax) / (by - ay))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for x in range(int(round(xs[i])), int(round(xs[i + 1])) + 1):
                    self._set(x, y)
        return self

    def line(self, x0, y0, x1, y1, thick=1):
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(int(steps) + 1):
            t = i / steps
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            if thick <= 1:
                self._set(int(round(x)), int(round(y)))
            else:
                self.circle(x, y, thick / 2.0)
        return self

    def capsule(self, x0, y0, x1, y1, r):
        """A limb: a thick line with round ends."""
        return self.line(x0, y0, x1, y1, thick=r * 2)

    def tapered(self, x0, y0, r0, x1, y1, r1):
        """A limb that changes thickness along its length."""
        steps = max(abs(x1 - x0), abs(y1 - y0), 1) * 2
        for i in range(int(steps) + 1):
            t = i / steps
            self.circle(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, r0 + (r1 - r0) * t)
        return self

    def subtract(self, other):
        for i in range(len(self.px)):
            if other.px[i]:
                self.px[i] = 0
        return self

    def union(self, other):
        for i in range(len(self.px)):
            if other.px[i]:
                self.px[i] = 1
        return self

    def mirror_x(self, axis):
        """Mirror the mask around a vertical axis (x = axis) into itself."""
        out = Mask(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y * self.w + x]:
                    out._set(x, y)
                    out._set(int(round(2 * axis - x)), y)
        self.px = out.px
        return self

    def offset(self, dx, dy):
        out = Mask(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y * self.w + x]:
                    out._set(x + dx, y + dy)
        return out


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [TRANSPARENT] * (w * h)

    def mask(self):
        return Mask(self.w, self.h)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y * self.w + x]
        return TRANSPARENT

    def set(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y * self.w + x] = color

    # -- shading -----------------------------------------------------------

    def part(self, mask, material, light=(-1, -1), thickness=2, rim=1, shadow=2, dither=True,
             contact=True, tint=None):
        """Composite a part with cel shading.

        material: 5-tone ramp [deep, dark, base, light, hi]
        thickness: how many pixels from the shadow edge get the dark tone
        rim: pixels from the lit edge that get the highlight tone
        shadow: contact-shadow depth cast onto pixels already on the canvas
        tint: optional (colour, amount) to shift the whole material
        """
        deep, dark, base, light_c, hi = material
        if tint:
            deep, dark, base, light_c, hi = [mix(c, tint[0], tint[1]) for c in material]
        lx, ly = light
        sx, sy = -lx, -ly

        # contact shadow on what is underneath, just past the part's far edge
        if contact and shadow > 0:
            for y in range(self.h):
                for x in range(self.w):
                    if not mask.get(x, y):
                        continue
                    for d in range(1, shadow + 1):
                        px, py = x + sx * d, y + sy * d
                        if mask.get(px, py):
                            continue
                        c = self.get(px, py)
                        if c is not TRANSPARENT:
                            self.set(px, py, mix(c, (0, 0, 0), 0.28))

        for y in range(self.h):
            for x in range(self.w):
                if not mask.get(x, y):
                    continue
                # distance to the far (shadow) edge and to the lit edge
                ds = 0
                while ds < 8 and mask.get(x + sx * (ds + 1), y + sy * (ds + 1)):
                    ds += 1
                dl = 0
                while dl < 8 and mask.get(x + lx * (dl + 1), y + ly * (dl + 1)):
                    dl += 1
                # also the vertical extent, so tops of round parts read as lit
                du = 0
                while du < 8 and mask.get(x, y - (du + 1)):
                    du += 1
                dd = 0
                while dd < 8 and mask.get(x, y + (dd + 1)):
                    dd += 1

                if ds < 1 or dd < 1:
                    c = deep if (ds < 1 and dd < 1) else dark
                elif ds < thickness or dd < thickness:
                    c = dark
                    if dither and (ds == thickness - 1 or dd == thickness - 1) and (x + y) % 2 == 0:
                        c = base
                elif dl < rim or du < rim:
                    c = hi
                elif dl < rim + 1 or du < rim + 1:
                    c = light_c
                    if dither and (x + y) % 2 == 0:
                        c = base
                else:
                    c = base
                self.set(x, y, c)
        return self

    def paint(self, mask, color):
        """Flat fill (details)."""
        for y in range(self.h):
            for x in range(self.w):
                if mask.get(x, y):
                    self.set(x, y, color)
        return self

    def outline(self, color):
        """1px outline around the whole silhouette."""
        src = list(self.px)
        for y in range(self.h):
            for x in range(self.w):
                if src[y * self.w + x] is not TRANSPARENT:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and src[ny * self.w + nx] is not TRANSPARENT:
                        self.px[y * self.w + x] = color
                        break
        return self

    def darken_silhouette_edge(self, color, amount=0.35):
        """Darken the outermost opaque pixels (used by corpses to sink them)."""
        src = list(self.px)
        for y in range(self.h):
            for x in range(self.w):
                c = src[y * self.w + x]
                if c is TRANSPARENT:
                    continue
                edge = any(self.get(x + dx, y + dy) is TRANSPARENT for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if edge:
                    self.px[y * self.w + x] = mix(c, color, amount)
        return self

    def tint_all(self, color, amount):
        for i, c in enumerate(self.px):
            if c is not TRANSPARENT:
                self.px[i] = mix(c, color, amount)
        return self

    def blit(self, other, dx, dy):
        for y in range(other.h):
            for x in range(other.w):
                c = other.px[y * other.w + x]
                if c is not TRANSPARENT:
                    self.set(x + dx, y + dy, c)
        return self

    def flipped(self):
        out = Canvas(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                out.px[y * self.w + (self.w - 1 - x)] = self.px[y * self.w + x]
        return out

    def rotated(self, degrees, cx=None, cy=None):
        """Nearest-neighbour rotation around (cx, cy), for falling poses."""
        import math
        cx = self.w / 2 if cx is None else cx
        cy = self.h / 2 if cy is None else cy
        a = math.radians(degrees)
        ca, sa = math.cos(a), math.sin(a)
        out = Canvas(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                # inverse map
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                sx = cx + dx * ca + dy * sa
                sy = cy - dx * sa + dy * ca
                c = self.get(int(sx), int(sy))
                if c is not TRANSPARENT:
                    out.px[y * self.w + x] = c
        return out


# -- export ----------------------------------------------------------------

def write_png(path, canvases, scale=3, cols=None, gap=2, bg=(34, 30, 40)):
    """Write a preview sheet of several canvases (all the same size)."""
    if not canvases:
        return
    w, h = canvases[0].w, canvases[0].h
    cols = cols or len(canvases)
    rows = (len(canvases) + cols - 1) // cols
    W = cols * (w * scale + gap) + gap
    H = rows * (h * scale + gap) + gap
    img = bytearray()
    rowsdata = []
    for Y in range(H):
        row = bytearray([0])
        for X in range(W):
            col = (X - gap) // (w * scale + gap)
            rw = (Y - gap) // (h * scale + gap)
            c = bg
            idx = rw * cols + col
            if 0 <= col < cols and 0 <= rw < rows and idx < len(canvases):
                lx = (X - gap) - col * (w * scale + gap)
                ly = (Y - gap) - rw * (h * scale + gap)
                if 0 <= lx < w * scale and 0 <= ly < h * scale:
                    p = canvases[idx].get(lx // scale, ly // scale)
                    if p is not TRANSPARENT:
                        c = p
                    else:
                        c = (44, 40, 52) if ((lx // scale + ly // scale) % 2 == 0) else (38, 34, 46)
            row += bytes(c)
        rowsdata.append(bytes(row))
    raw = b"".join(rowsdata)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"


def colour_code(i):
    """Two-letter palette index (52 x 52 colours)."""
    return ALPHABET[i // len(ALPHABET)] + ALPHABET[i % len(ALPHABET)]


def encode_sheet(canvases):
    """Return (palette, [frame strings]) with a shared palette per sheet.

    Frame string: runs of `<count><code>` where code is two letters indexing the
    palette, or `.` for transparent. Counts are decimal.
    """
    palette = []
    index = {}
    for cv in canvases:
        for c in cv.px:
            if c is not TRANSPARENT and c not in index:
                index[c] = len(palette)
                palette.append(c)
    if len(palette) > len(ALPHABET) ** 2:
        raise ValueError(f"palette has {len(palette)} colours, max {len(ALPHABET) ** 2}")
    frames = []
    for cv in canvases:
        out = []
        run_char, run_len = None, 0
        for c in cv.px:
            ch = "." if c is TRANSPARENT else colour_code(index[c])
            if ch == run_char:
                run_len += 1
            else:
                if run_char is not None:
                    out.append(f"{run_len}{run_char}")
                run_char, run_len = ch, 1
        out.append(f"{run_len}{run_char}")
        frames.append("".join(out))
    return palette, frames


def swift_sheet(name, w, h, canvases):
    palette, frames = encode_sheet(canvases)
    pal = ", ".join(f"0xFF{r:02X}{g:02X}{b:02X}" for r, g, b in palette)
    lines = [f"    static let {name} = BakedSpriteSheet(", f"        width: {w}, height: {h},",
             f"        palette: [{pal}],", "        frames: ["]
    for fr in frames:
        lines.append(f'            "{fr}",')
    lines.append("        ]")
    lines.append("    )")
    return "\n".join(lines)


# -- turntable rig ----------------------------------------------------------
#
# Bodies are described in a simple 3D "rig space" and projected onto the
# canvas for one of five turn angles, so a single definition yields the front,
# 3/4, side, back-3/4 and back views. Axes: x lateral (viewer's right in the
# front view = the creature's left), y down the screen, z forward toward the
# viewer in the front view. Views are drawn with the creature facing
# screen-left; the engine mirrors them for the other side.

import math


class Rig:
    def __init__(self, cv, turn_deg, cx):
        self.cv = cv
        self.cx = cx
        self.turn = turn_deg
        phi = math.radians(turn_deg)
        self.c, self.s = math.cos(phi), math.sin(phi)
        self.parts = []

    # projection
    def sx(self, x, z):
        return self.cx + x * self.c - z * self.s

    def depth(self, x, z):
        """Larger = nearer the viewer."""
        return z * self.c + x * self.s

    def p(self, pt):
        x, y, z = pt
        return (self.sx(x, z), y)

    def width(self, rx, rz):
        """Screen half-width of an ellipsoid with lateral radius rx and depth radius rz."""
        return abs(rx * self.c) + abs(rz * self.s)

    @property
    def facing_away(self):
        return self.c < -0.2

    @property
    def side_on(self):
        return abs(self.s) > 0.9

    # parts: (depth, draw closure); rendered far to near
    def add(self, depth, fn):
        self.parts.append((depth, fn))

    def tint_for(self, depth, threshold=-4.0):
        return ((20, 0, 14), 0.22) if depth < threshold else None

    def limb(self, a, ra, b, rb, material, thickness=2, rim=1, after=None, tint="auto", shadow=2):
        d = (self.depth(a[0], a[2]) + self.depth(b[0], b[2])) / 2

        def draw():
            m = self.cv.mask().tapered(*self.p(a), ra, *self.p(b), rb)
            t = self.tint_for(d) if tint == "auto" else tint
            self.cv.part(m, material, thickness=thickness, rim=rim, tint=t, shadow=shadow)
            if after:
                after(self)
        self.add(d, draw)

    def blob(self, center, rx, ry, rz, material, thickness=3, rim=2, after=None, tint="auto", shadow=2,
             extra=None):
        """An ellipsoid. `extra(mask, rig)` may add to the silhouette before shading."""
        d = self.depth(center[0], center[2])

        def draw():
            sx, sy = self.p(center)
            m = self.cv.mask().oval(sx, sy, self.width(rx, rz), ry)
            if extra:
                extra(m, self)
            t = self.tint_for(d) if tint == "auto" else tint
            self.cv.part(m, material, thickness=thickness, rim=rim, tint=t, shadow=shadow)
            if after:
                after(self)
        self.add(d, draw)

    def custom(self, depth, fn):
        """A hand-drawn part; fn(rig) is called when its turn comes in the depth order."""
        self.add(depth, lambda: fn(self))

    def render(self):
        for _, fn in sorted(self.parts, key=lambda t: t[0]):
            fn()
        self.parts = []


TURNS = [0, 45, 90, 135, 180]


def turntable_frames(draw_standing, draw_death, standing_count=7):
    """Sheet layout: front 0..6, the death frames (6), then for each of the four other turns frames 0..6."""
    out = [draw_standing(f, 0) for f in range(standing_count)] + draw_death()
    for turn in TURNS[1:]:
        out += [draw_standing(f, turn) for f in range(standing_count)]
    return out
