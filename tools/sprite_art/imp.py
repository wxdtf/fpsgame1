"""Imp: a hunched, horned, long-armed hellspawn with glowing yellow eyes that throws fireballs.

Canvas 64x96, feet on the bottom row. Built on the turntable rig: one body
definition projected to the front, 3/4, side, back-3/4 and back views.
Frames per view: 0 idle, 1-3 walk, 4-5 attack, 6 hurt; front only: 7-12 the six death frames (see death_frames).
"""

from pixelart import Canvas, Rig, ramp, rgb, turntable_frames

W, H = 64, 96
CX = 32

SKIN = ramp(rgb(168, 62, 34), deep=rgb(58, 16, 12), hi=rgb(236, 142, 96))
BELLY = ramp(rgb(188, 118, 78), deep=rgb(92, 44, 28), hi=rgb(238, 194, 154))
HORN = ramp(rgb(96, 62, 40), deep=rgb(34, 18, 10), hi=rgb(176, 136, 100))
CLAW = ramp(rgb(56, 32, 22), deep=rgb(18, 8, 6), hi=rgb(124, 92, 72))
SPIKE = ramp(rgb(112, 40, 26), deep=rgb(40, 12, 8), hi=rgb(206, 114, 84))
EYE_GLOW = rgb(255, 214, 40)
EYE_CORE = rgb(255, 255, 200)
EYE_RIM = rgb(150, 90, 0)
MOUTH = rgb(44, 8, 8)
TOOTH = rgb(240, 232, 214)
TOOTH_DARK = rgb(190, 180, 160)
BLOOD = rgb(150, 12, 10)
BLOOD_DARK = rgb(96, 6, 6)
OUTLINE = rgb(24, 8, 8)
FIRE = [rgb(255, 250, 200), rgb(255, 200, 60), rgb(255, 120, 20), rgb(170, 40, 10)]
BACK = ((24, 0, 12), 0.22)


def claws(cv, points, up=False, length=5):
    for tx, ty in points:
        tx, ty = int(round(tx)), int(round(ty))
        if up:
            m = cv.mask().poly([(tx - 1, ty), (tx + 1, ty), (tx, ty - length)])
        else:
            m = cv.mask().poly([(tx - 1, ty), (tx + 1, ty), (tx, ty + length)])
        cv.part(m, CLAW, thickness=1, rim=0, contact=False)


def spike(cv, base_a, base_b, tip):
    m = cv.mask().poly([base_a, base_b, tip])
    cv.part(m, SPIKE, thickness=1, rim=1, shadow=1)


def leg(rig, side, hipY, ground, step):
    """Digitigrade leg. side = +1 (creature's left) / -1. step: forward (+z) offset of the foot."""
    hx = side * 7
    sway = side * step * 0.35          # a little lateral spread so the walk reads head-on
    hip = (hx, hipY + 1, 0)
    knee = (hx + sway * 0.5, hipY + 11 - abs(step) // 4, 3 + step * 0.4)
    hock = (hx - side + sway, hipY + 20 - abs(step) // 5, -5 + step * 0.5)
    toe = (hx + sway, ground - 1 - (2 if step > 0 else 0), 5 + step)
    rig.limb(hip, 6, knee, 4, SKIN, thickness=3)
    rig.limb(knee, 4, hock, 3, SKIN)

    def foot(r):
        cv = r.cv
        ax, ay = r.p(hock)
        tx, ty = r.p(toe)
        m = cv.mask().tapered(ax, ay, 3, tx, ty - 2, 3.5)
        m.oval(tx + (0 if r.side_on else 1), ty - 1, r.width(5, 4), 2.5)
        cv.part(m, SKIN, thickness=2, rim=1, tint=r.tint_for(r.depth(hock[0], hock[2])))
        # three toe claws fan out in front; foreshortened from the side
        spread = r.width(4, 1)
        claws(cv, [(tx - spread, ty), (tx + 1 - r.s * 3, ty + 1), (tx + spread, ty)], length=4)
        claws(cv, [(ax - 2 * r.c, ay + 1)], length=3)  # heel spur
    rig.custom(rig.depth(hock[0], hock[2]) + 0.5, foot)


def arm(rig, side, shY, swing=0, raised=False):
    """Long arm with forearm spikes and clawed hand. swing: forward offset of the hand."""
    sx = side * 15
    shoulder = (sx, shY, 0)
    if raised:
        elbow = (sx + side * 7, shY - 3, 4)
        hand = (sx + side * 6, shY - 16, 6)
    else:
        elbow = (sx + side * 5, shY + 14, swing)
        hand = (sx + side * 3, shY + 30, swing * 2)
    rig.limb(shoulder, 5, elbow, 3.5, SKIN)

    def forearm_spikes(r):
        for k in (0.35, 0.65):
            px = elbow[0] + (hand[0] - elbow[0]) * k
            py = elbow[1] + (hand[1] - elbow[1]) * k
            pz = elbow[2] + (hand[2] - elbow[2]) * k
            bx, by = r.p((px, py, pz))
            tx, ty = r.p((px + side * 6, py - 2, pz))
            spike(r.cv, (bx, by - 1), (bx, by + 1), (tx, ty))
    rig.limb(elbow, 3.5, hand, 3, SKIN, after=forearm_spikes)

    def hand_part(r):
        hx, hy = r.p(hand)
        r.cv.part(r.cv.mask().circle(hx, hy, 3.5), SKIN, thickness=2, rim=1,
                  tint=r.tint_for(r.depth(hand[0], hand[2])))
        spread = max(1.5, r.width(3, 1))
        if raised:
            claws(r.cv, [(hx - spread, hy - 2), (hx, hy - 3), (hx + spread, hy - 2)], up=True, length=6)
        else:
            claws(r.cv, [(hx - spread, hy + 2), (hx, hy + 3), (hx + spread, hy + 2)], length=6)
    rig.custom(rig.depth(hand[0], hand[2]) + 0.3, hand_part)
    return hand


def torso(rig, hipY, hunch=0):
    def shoulders(m, r):
        pts = [(-17, hipY - 24 + hunch, 0), (17, hipY - 24 + hunch, 0), (13, hipY - 6, 0), (-13, hipY - 6, 0)]
        wide = r.width(17, 10)
        sx0, _ = r.p((0, 0, 0))
        m.poly([(sx0 - wide, hipY - 24 + hunch), (sx0 + wide, hipY - 24 + hunch),
                (sx0 + r.width(13, 10), hipY - 6), (sx0 - r.width(13, 10), hipY - 6)])
        px, py = r.p((0, hipY + 1, 0))
        m.oval(px, py, r.width(8, 6), 6)

    def details(r):
        cv = r.cv
        if r.facing_away:
            # spine and shoulder blades
            sx, _ = r.p((0, 0, 0))
            for y in range(hipY - 22, hipY - 2, 3):
                cv.set(int(sx), y, SKIN[1])
            for side in (-1, 1):
                bx, by = r.p((side * 6, hipY - 17, -6))
                cv.part(cv.mask().oval(bx, by, r.width(5, 3), 4), SKIN, thickness=2, rim=1, shadow=1)
            return
        # belly plate on the front surface
        bx, by = r.p((0, hipY - 5, 7))
        cv.part(cv.mask().oval(bx, by, max(1.5, r.width(6, 2)), 8), BELLY, thickness=2, rim=1, shadow=1)
        if r.c > 0.6:
            for y in range(hipY - 10, hipY + 1, 4):
                cv.set(int(bx), y, BELLY[1])
                cv.set(int(bx) - 3, y + 1, BELLY[1])
                cv.set(int(bx) + 3, y + 1, BELLY[1])
        # pectorals
        for side in (-1, 1):
            px, py = r.p((side * 6, hipY - 17, 6))
            cv.part(cv.mask().oval(px, py, max(1.5, r.width(6, 3)), 4), SKIN, thickness=2, rim=1, shadow=1)
        if r.c > 0.6:
            sx, _ = r.p((0, 0, 8))
            for y in range(hipY - 21, hipY - 11):
                cv.set(int(sx), y, SKIN[1])
        # ribs
        for i in range(3):
            y = hipY - 12 + i * 3
            for side in (-1, 1):
                rx, _ = r.p((side * 11, y, 3))
                cv.set(int(rx), y, SKIN[1])
                cv.set(int(rx) + (1 if side > 0 else -1) * int(round(r.c)), y + 1, SKIN[1])

    rig.blob((0, hipY - 20, -6), 12, 8, 7, SKIN, thickness=3, rim=2)   # hunched upper back
    rig.blob((0, hipY - 12, 0), 13, 14, 11, SKIN, thickness=3, rim=2, extra=shoulders, after=details)

    # shoulder spikes, pointing outward
    for side in (-1, 1):
        for k in range(3):
            base_y = hipY - 23 + hunch + k * 4
            b = (side * 15, base_y + 3, 0)
            t = (side * 22, base_y - 3, 0)
            d = rig.depth(b[0], b[2]) + 1

            def draw(r, b=b, t=t):
                bx, by = r.p(b)
                tx, ty = r.p(t)
                if abs(tx - bx) < 2:
                    tx = bx + (2 if t[0] > 0 else -2) * r.c
                spike(r.cv, (bx - 2, by), (bx + 2, by), (tx, ty))
            rig.custom(d, draw)


def head(rig, hy, open_mouth=False, hurt=False):
    rig.limb((0, hy + 6, 0), 4, (0, hy + 12, 0), 4, SKIN, thickness=2, rim=0)

    def jaw(m, r):
        pts = [r.p((-9, hy + 2, 2)), r.p((9, hy + 2, 2)), r.p((6, hy + 11, 3)), r.p((-6, hy + 11, 3))]
        m.poly(pts)

    def face(r):
        cv = r.cv
        if r.facing_away:
            return
        # brow ridge
        bl = r.p((-10, hy - 4, 5))
        br = r.p((10, hy - 4, 5))
        m = cv.mask().poly([bl, br, (br[0], hy - 1), (bl[0], hy - 1)])
        cv.part(m, SKIN, thickness=1, rim=1, shadow=2)
        # eyes
        for side in (-1, 1):
            ex, ey = r.p((side * 4, hy + 1, 9))
            ex = int(round(ex))
            w = max(1.5, r.width(3, 1))
            cv.paint(cv.mask().oval(ex, ey, w, 2), SKIN[0])
            cv.paint(cv.mask().oval(ex, ey, max(1, w - 1), 1.5), EYE_RIM)
            cv.paint(cv.mask().oval(ex, ey, max(1, w - 1.5), 1), EYE_GLOW)
            cv.set(ex + side * int(round(r.c)), int(ey), EYE_CORE)
            if hurt:
                cv.set(ex, int(ey) - 1, SKIN[0])
        # nostrils, cheekbones
        for side in (-1, 1):
            nx, ny = r.p((side * 1, hy + 4, 10))
            cv.set(int(round(nx)), int(ny), SKIN[0])
            kx, ky = r.p((side * 7, hy + 4, 5))
            cv.set(int(round(kx)), int(ky), SKIN[3])
        # mouth
        mh = 4 if open_mouth else 1
        mx, my = r.p((0, hy + 6, 9))
        mw = max(2, int(round(r.width(5, 1))))
        cv.paint(cv.mask().rect(int(round(mx)) - mw, my, 2 * mw + 1, mh + 1), MOUTH)
        for i, tx in enumerate(range(int(round(mx)) - mw + 1, int(round(mx)) + mw, 2)):
            tall = 3 if i % 4 == 0 else 2
            col = TOOTH if tall == 3 else TOOTH_DARK
            cv.paint(cv.mask().poly([(tx - 1, my), (tx + 1, my), (tx, my + tall)]), col)
        if open_mouth:
            for tx in range(int(round(mx)) - mw + 2, int(round(mx)) + mw, 3):
                cv.paint(cv.mask().poly([(tx - 1, my + mh + 1), (tx + 1, my + mh + 1), (tx, my + mh - 1)]), TOOTH_DARK)

    rig.blob((0, hy, 0), 10, 9, 9, SKIN, thickness=3, rim=2, extra=jaw, after=face)

    # horns: sweep up and out, slightly back
    for side in (-1, 1):
        pts = [(side * 3, hy - 4, 1), (side * 9, hy - 4, 1), (side * 15, hy - 14, -5), (side * 19, hy - 25, -11),
               (side * 17, hy - 25, -11), (side * 12, hy - 14, -5)]
        d = rig.depth(side * 9, 0) + 0.5

        def draw(r, pts=pts, side=side):
            proj = [r.p(pt) for pt in pts]
            m = r.cv.mask().poly(proj)
            r.cv.part(m, HORN, thickness=2, rim=1, shadow=1)
            for k in range(4):
                rx, ry = r.p((side * (10 + k * 2), hy - 7 - k * 3, 0))
                r.cv.set(int(round(rx)), int(ry), HORN[1])
        rig.custom(d, draw)


def draw_standing(frame, turn):
    cv = Canvas(W, H)
    rig = Rig(cv, turn, CX)
    attacking = frame in (4, 5)
    hurt = frame == 6
    phase = {1: 0, 2: 1, 3: 2}.get(frame, -1)
    bob, lstep, rstep = 0, 0, 0
    if phase == 0:
        lstep, rstep, bob = 6, -6, 1
    elif phase == 1:
        lstep, rstep, bob = 0, 0, -1
    elif phase == 2:
        lstep, rstep, bob = -6, 6, 1

    ground = 94
    hipY = 60 + bob + (1 if hurt else 0)

    leg(rig, +1, hipY, ground, lstep)
    leg(rig, -1, hipY, ground, rstep)
    torso(rig, hipY, hunch=1 if hurt else 0)

    shY = hipY - 20
    if attacking:
        arm(rig, +1, shY, swing=4)
        hand = arm(rig, -1, shY, raised=True)
        fx, fy = rig.p((hand[0], hand[1] - (11 if frame == 5 else 7), hand[2] + 2))
        r = 7 if frame == 5 else 5

        def fireball(rg, fx=fx, fy=fy, r=r):
            for i, col in enumerate(FIRE[::-1]):
                rg.cv.paint(rg.cv.mask().circle(fx, fy, r - i * 1.6), col)
            for dx, dy in ((-r, -2), (r - 1, -3), (0, -r - 2), (-2, -r - 1)):
                rg.cv.set(int(fx + dx), int(fy + dy), FIRE[1])
        rig.custom(rig.depth(hand[0], hand[2]) + 5, fireball)
    else:
        arm(rig, +1, shY, swing=-lstep // 2)
        arm(rig, -1, shY, swing=-rstep // 2)

    head(rig, hipY - 31 + (2 if hurt else 0), open_mouth=attacking or hurt, hurt=hurt)
    rig.render()

    if hurt:
        for (bx, by, r) in ((CX - 4, hipY - 14, 3), (CX + 3, hipY - 9, 2), (CX - 8, hipY - 20, 1)):
            cv.paint(cv.mask().circle(bx, by, r), BLOOD)
        cv.set(CX - 6, hipY - 24, BLOOD_DARK)
        cv.set(CX + 5, hipY - 15, BLOOD_DARK)

    cv.outline(OUTLINE)
    return cv


def draw_recoil():
    """Death 0: the killing shot lands — knocked back, chest torn open."""
    cv = draw_standing(6, 0)
    out = Canvas(W, H)
    for y in range(H):
        shift = -(H - y) // 10
        for x in range(W):
            c = cv.get(x, y)
            if c is not None:
                out.set(x + shift, y, c)
    for (bx, by, r) in ((28, 48, 5), (22, 44, 3), (33, 42, 2)):
        out.paint(out.mask().circle(bx, by, r), BLOOD)
    out.paint(out.mask().circle(27, 49, 2), BLOOD_DARK)
    # spray leaving the wound toward the shooter
    for k in range(6):
        out.set(20 - k * 2, 46 - (k % 3) * 2, BLOOD if k % 2 else BLOOD_DARK)
    out.outline(OUTLINE)
    return out


def draw_twist():
    """Death 1: spun sideways by the impact, arms flung up, knees starting to go."""
    cv = Canvas(W, H)
    rig = Rig(cv, 90, CX)
    ground = 94
    hipY = 64
    leg(rig, +1, hipY, ground, 5)
    leg(rig, -1, hipY, ground, -5)
    torso(rig, hipY, hunch=2)
    shY = hipY - 20
    arm(rig, +1, shY, raised=True)
    arm(rig, -1, shY, raised=True)
    head(rig, hipY - 28, open_mouth=True, hurt=True)
    rig.render()
    # the chest wound now faces screen-left (the creature's front)
    for (bx, by, r) in ((CX - 9, hipY - 14, 4), (CX - 12, hipY - 9, 2)):
        cv.paint(cv.mask().circle(bx, by, r), BLOOD)
    cv.paint(cv.mask().circle(CX - 8, hipY - 12, 2), BLOOD_DARK)
    for k in range(4):
        cv.set(CX - 14 - k * 2, hipY - 16 + k, BLOOD)
    cv.outline(OUTLINE)
    return cv


def draw_crumple():
    """Death 2: turned almost away, legs folding, arms dropping."""
    cv = Canvas(W, H)
    rig = Rig(cv, 135, CX)
    ground = 94
    hipY = 72
    leg(rig, +1, hipY, ground, 2)
    leg(rig, -1, hipY, ground, -6)
    torso(rig, hipY, hunch=3)
    shY = hipY - 19
    arm(rig, +1, shY, swing=3)
    arm(rig, -1, shY, swing=-2)
    head(rig, hipY - 27, open_mouth=True, hurt=True)
    rig.render()
    cv.paint(cv.mask().circle(CX + 3, hipY - 12, 3), BLOOD)
    cv.paint(cv.mask().circle(CX + 6, hipY - 8, 2), BLOOD_DARK)
    cv.outline(OUTLINE)
    return cv


def draw_falling():
    """Death 3: knees buckled, torso pitching forward-right, one arm reaching for the floor."""
    cv = Canvas(W, H)
    ground = 94
    hipY = 74
    m = cv.mask().tapered(22, hipY, 6, 14, hipY + 10, 4)
    cv.part(m, SKIN, thickness=3, tint=BACK)
    m = cv.mask().tapered(14, hipY + 10, 4, 24, hipY + 17, 3)
    cv.part(m, SKIN, thickness=2, tint=BACK)
    m = cv.mask().tapered(34, hipY + 2, 6, 40, hipY + 12, 4)
    cv.part(m, SKIN, thickness=3)
    m = cv.mask().tapered(40, hipY + 12, 4, 30, hipY + 18, 3)
    cv.part(m, SKIN, thickness=2)
    claws(cv, [(24, ground - 2), (28, ground - 1), (32, ground - 2)], length=3)
    m = cv.mask()
    m.oval(30, hipY - 6, 9, 7)
    m.tapered(28, hipY - 4, 9, 44, hipY - 22, 11)
    cv.part(m, SKIN, thickness=3, rim=2)
    m = cv.mask().tapered(30, hipY - 6, 4, 38, hipY - 14, 5)
    cv.part(m, BELLY, thickness=2, rim=0, shadow=1)
    for k in range(3):
        spike(cv, (50 + k * 2, hipY - 30 + k * 3), (52 + k * 2, hipY - 28 + k * 3), (57 + k * 3, hipY - 34 + k * 3))
    # arms: one braced toward the floor, one trailing
    m = cv.mask().tapered(40, hipY - 26, 5, 46, hipY - 12, 3.5)
    cv.part(m, SKIN, thickness=2)
    m = cv.mask().tapered(46, hipY - 12, 3.5, 50, hipY + 2, 3)
    cv.part(m, SKIN, thickness=2)
    claws(cv, [(47, hipY + 4), (50, hipY + 5), (53, hipY + 4)], length=5)
    m = cv.mask().tapered(30, hipY - 20, 5, 18, hipY - 16, 3.5)
    cv.part(m, SKIN, thickness=2, tint=BACK)
    m = cv.mask().tapered(18, hipY - 16, 3.5, 10, hipY - 4, 3)
    cv.part(m, SKIN, thickness=2, tint=BACK)
    claws(cv, [(7, hipY - 2), (10, hipY - 1), (13, hipY - 2)], length=5)
    # head hanging forward-right (front-view head via the rig)
    r = Rig(cv, 0, 50)
    head(r, hipY - 36, open_mouth=True)
    r.render()
    cv.paint(cv.mask().circle(38, hipY - 16, 4), BLOOD)
    cv.paint(cv.mask().circle(35, hipY - 12, 2), BLOOD_DARK)
    cv.set(41, hipY - 8, BLOOD)
    cv.set(42, hipY - 4, BLOOD_DARK)
    cv.outline(OUTLINE)
    return cv


def draw_impact():
    """Death 4: hits the floor face first — the body bounces, dust and blood kick up."""
    body = draw_corpse(pool=False)
    cv = Canvas(W, H)
    cv.blit(body, 0, -4)
    ground = 92
    cv.paint(cv.mask().oval(32, ground, 20, 2), BLOOD_DARK)
    dust = (rgb(96, 80, 70), rgb(128, 108, 96))
    for k, (dx, dy, r) in enumerate(((8, ground - 5, 3), (14, ground - 9, 2), (54, ground - 6, 3), (60, ground - 10, 2), (4, ground - 10, 1.5))):
        cv.paint(cv.mask().circle(dx, dy, r), dust[k % 2])
    for k in range(7):
        cv.set(24 + k * 3, ground - 18 - (k % 3) * 3, BLOOD if k % 2 else BLOOD_DARK)
    cv.outline(OUTLINE)
    return cv


def draw_corpse(pool=True):
    """Death 5: face down on the floor, horns and spikes still recognisable."""
    cv = Canvas(W, H)
    ground = 92
    if pool:
        cv.paint(cv.mask().oval(32, ground, 26, 3), BLOOD_DARK)
        cv.paint(cv.mask().oval(30, ground - 1, 18, 2), BLOOD)
    m = cv.mask().tapered(16, ground - 10, 5, 6, ground - 4, 4)
    cv.part(m, SKIN, thickness=2, tint=BACK)
    m = cv.mask().tapered(22, ground - 8, 5, 12, ground - 3, 4)
    cv.part(m, SKIN, thickness=2)
    claws(cv, [(3, ground - 2), (7, ground - 1)], length=3)
    m = cv.mask().oval(33, ground - 9, 16, 8)
    cv.part(m, SKIN, thickness=3, rim=1)
    for k in range(3):
        bx = 24 + k * 5
        spike(cv, (bx - 2, ground - 15), (bx + 2, ground - 15), (bx, ground - 21))
    m = cv.mask().oval(30, ground - 5, 8, 4)
    cv.part(m, BELLY, thickness=2, rim=0, shadow=1)
    m = cv.mask().tapered(40, ground - 7, 3, 48, ground - 3, 2.5)
    cv.part(m, SKIN, thickness=2)
    claws(cv, [(48, ground - 3), (51, ground - 4), (54, ground - 3)], length=3)
    hx, hy = 50, ground - 11
    m = cv.mask().oval(hx, hy, 8, 7)
    cv.part(m, SKIN, thickness=3, rim=1)
    cv.paint(cv.mask().rect(hx - 2, hy + 1, 5, 1), SKIN[0])
    cv.paint(cv.mask().rect(hx - 4, hy + 4, 8, 2), MOUTH)
    for mx in (hx - 3, hx, hx + 3):
        cv.paint(cv.mask().poly([(mx - 1, hy + 4), (mx + 1, hy + 4), (mx, hy + 7)]), TOOTH_DARK)
    m = cv.mask().poly([(hx + 2, hy - 5), (hx + 6, hy - 4), (hx + 10, hy - 19), (hx + 8, hy - 19)])
    cv.part(m, HORN, thickness=2, rim=1)
    m = cv.mask().poly([(hx - 6, hy - 4), (hx - 4, hy - 2), (hx - 18, hy - 1), (hx - 18, hy - 3)])
    cv.part(m, HORN, thickness=1, rim=0)
    cv.paint(cv.mask().circle(28, ground - 10, 3), BLOOD)
    cv.paint(cv.mask().circle(26, ground - 8, 2), BLOOD_DARK)
    cv.outline(OUTLINE)
    return cv


def death_frames():
    """Shot in the chest, spun round by the hit, and dropped face first."""
    return [draw_recoil(), draw_twist(), draw_crumple(), draw_falling(), draw_impact(), draw_corpse()]


def frames():
    return turntable_frames(draw_standing, death_frames)
