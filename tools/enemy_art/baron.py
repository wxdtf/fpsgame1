"""Baron of Hell: a towering goat-legged demon — pink-tan torso, bone horns, green eyes, green plasma.

Canvas 96x120, turntable rig. Frames per view: 0 idle, 1-3 stride, 4-5 hurl plasma, 6 hurt;
front only: 7 recoil, 8 falling to one knee, 9 corpse.
"""

from pixelart import Canvas, Rig, ramp, rgb, turntable_frames

W, H = 96, 120
CX = 48

SKIN = ramp(rgb(196, 142, 122), deep=rgb(66, 34, 30), hi=rgb(244, 208, 190))
FUR = ramp(rgb(88, 54, 34), deep=rgb(22, 12, 6), hi=rgb(150, 104, 72))
HORN = ramp(rgb(222, 212, 186), deep=rgb(96, 88, 70), hi=rgb(250, 246, 232))
HOOF = ramp(rgb(44, 28, 18), deep=rgb(10, 6, 4), hi=rgb(96, 70, 50))
CLAW = ramp(rgb(226, 220, 200), deep=rgb(110, 100, 84), hi=rgb(250, 248, 236))
EYE = rgb(80, 255, 110)
EYE_CORE = rgb(220, 255, 230)
MOUTH = rgb(70, 16, 24)
TOOTH = rgb(240, 236, 220)
PLASMA = [rgb(230, 255, 236), rgb(120, 255, 150), rgb(40, 210, 90), rgb(10, 120, 50)]
BLOOD = rgb(50, 170, 40)     # Barons bleed green
BLOOD_DARK = rgb(22, 96, 20)
OUTLINE = rgb(30, 14, 16)
BACK = ((20, 0, 16), 0.22)


def claws(cv, points, up=False, length=8):
    for tx, ty in points:
        tx, ty = int(round(tx)), int(round(ty))
        if up:
            m = cv.mask().poly([(tx - 1, ty), (tx + 1, ty), (tx, ty - length)])
        else:
            m = cv.mask().poly([(tx - 1, ty), (tx + 1, ty), (tx, ty + length)])
        cv.part(m, CLAW, thickness=1, rim=0, contact=False)


def leg(rig, side, hipY, ground, step):
    """Goat leg: furred thigh, backward hock, thin cannon, cloven hoof."""
    hx = side * 10
    sway = side * step * 0.3
    hip = (hx, hipY + 2, 0)
    knee = (hx + 1 + sway * 0.5, hipY + 14 - abs(step) // 4, 4 + step * 0.4)
    hock = (hx - side + sway, hipY + 28 - abs(step) // 4, -6 + step * 0.5)
    hoof = (hx + sway, ground - 3 - (3 if step > 0 else 0), 4 + step)
    rig.limb(hip, 9, knee, 6, FUR, thickness=3, rim=2)
    rig.limb(knee, 6, hock, 4, FUR, thickness=3)
    rig.limb(hock, 4, (hoof[0], hoof[1] - 4, hoof[2]), 3.5, FUR)

    def tufts(r):
        for k in range(3):
            px, py = r.p((hx - side * 8, hipY + 6 + k * 5, -2 + k))
            r.cv.set(int(round(px)), int(py), FUR[3])
            r.cv.set(int(round(px)) + 1, int(py) + 1, FUR[3])
    rig.custom(rig.depth(hip[0], hip[2]) + 0.4, tufts)

    def hoof_part(r):
        fx, fy = r.p(hoof)
        w = r.width(5.5, 5)
        m = r.cv.mask().poly([(fx - w, fy - 3), (fx + w, fy - 3), (fx + w + 1, fy + 3), (fx - w - 1, fy + 3)])
        r.cv.part(m, HOOF, thickness=2, rim=1, tint=r.tint_for(r.depth(hoof[0], hoof[2])))
        if not r.side_on:
            for k in range(3):
                r.cv.set(int(round(fx)), int(fy) + k, HOOF[0])
    rig.custom(rig.depth(hoof[0], hoof[2]) + 0.3, hoof_part)


def arm(rig, side, shoulder, elbow, hand, fingers_up=False, holding=False):
    rig.limb(shoulder, 8, elbow, 6, SKIN, thickness=3, rim=2)
    mid = ((shoulder[0] + elbow[0]) / 2, (shoulder[1] + elbow[1]) / 2, (shoulder[2] + elbow[2]) / 2)
    rig.blob(mid, 6, 5, 5, SKIN, thickness=2, rim=1, shadow=1)
    rig.limb(elbow, 6, hand, 4.5, SKIN, thickness=3)

    def hand_part(r):
        hx, hy = r.p(hand)
        r.cv.part(r.cv.mask().circle(hx, hy, 5), SKIN, thickness=2, rim=1,
                  tint=r.tint_for(r.depth(hand[0], hand[2])))
        spread = max(1.5, r.width(4, 1.5))
        pts = [(hx - spread, hy), (hx, hy), (hx + spread, hy)]
        if fingers_up or holding:
            claws(r.cv, [(x, y - 3) for x, y in pts], up=True, length=7)
        else:
            claws(r.cv, [(x, y + 3) for x, y in pts], length=8)
    rig.custom(rig.depth(hand[0], hand[2]) + 0.3, hand_part)


def head(rig, hy, roar=False, hurt=False):
    rig.limb((0, hy + 10, 0), 6, (0, hy + 18, 0), 6, SKIN, thickness=2, rim=0)

    def jaw(m, r):
        m.poly([r.p((-11, hy + 4, 3)), r.p((11, hy + 4, 3)), r.p((7, hy + 15, 4)), r.p((-7, hy + 15, 4))])

    def face(r):
        cv = r.cv
        if r.facing_away:
            return
        bl = r.p((-13, hy - 5, 6))
        br = r.p((13, hy - 5, 6))
        cv.part(cv.mask().poly([bl, br, (br[0], hy - 1), (bl[0], hy - 1)]), SKIN, thickness=1, rim=1, shadow=2)
        for side in (-1, 1):
            ex, ey = r.p((side * 6, hy + 1, 12))
            ex, ey = int(round(ex)), int(ey)
            cv.paint(cv.mask().oval(ex, ey, max(2, r.width(3.5, 1.2)), 2.2), SKIN[0])
            if not hurt:
                cv.paint(cv.mask().oval(ex, ey, max(1.2, r.width(2.2, 0.8)), 1.4), EYE)
                cv.set(ex + side * int(round(r.c)), ey, EYE_CORE)
            else:
                cv.set(ex, ey, EYE)
        for side in (-1, 1):
            kx, _ = r.p((side * 9, 0, 7))
            cv.set(int(round(kx)), hy + 5, SKIN[3])
            nx, _ = r.p((side * 2, 0, 13))
            cv.set(int(round(nx)), hy + 5, SKIN[0])
        mh = 5 if roar else 1
        mx, _ = r.p((0, 0, 12))
        mx = int(round(mx))
        mw = max(2, int(round(r.width(7, 1.5))))
        cv.paint(cv.mask().rect(mx - mw, hy + 8, 2 * mw + 1, mh + 1), MOUTH)
        for i, tx in enumerate(range(mx - mw + 1, mx + mw, 3)):
            tall = 4 if i % 4 == 0 else 2
            cv.paint(cv.mask().poly([(tx - 1, hy + 8), (tx + 1, hy + 8), (tx, hy + 8 + tall)]), TOOTH)
        if roar:
            for tx in range(mx - mw + 3, mx + mw, 4):
                cv.paint(cv.mask().poly([(tx - 1, hy + 9 + mh), (tx + 1, hy + 9 + mh), (tx, hy + 6 + mh)]), TOOTH)

    rig.blob((0, hy, 0), 13, 12, 12, SKIN, thickness=4, rim=2, extra=jaw, after=face)

    # big horns curling up, out and back
    for side in (-1, 1):
        # curl up, out and back; the tips stay inside the canvas (hy is 18 at rest)
        pts = [(side * 6, hy - 6, 2), (side * 12, hy - 6, 2), (side * 19, hy - 10, -6), (side * 25, hy - 15, -14),
               (side * 23, hy - 18, -22), (side * 19, hy - 17, -22), (side * 20, hy - 13, -14), (side * 15, hy - 10, -6)]
        d = rig.depth(side * 12, 0) + 0.5

        def draw(r, pts=pts, side=side):
            proj = [r.p(pt) for pt in pts]
            m = r.cv.mask().poly(proj)
            # thicken: union with copies nudged down and sideways so foreshortened views keep some body
            m.union(r.cv.mask().poly([(x, y + 2) for x, y in proj]))
            m.union(r.cv.mask().poly([(x + side, y + 1) for x, y in proj]))
            r.cv.part(m, HORN, thickness=2, rim=2, shadow=1)
            for k in range(3):
                rx, ry = r.p((side * (14 + k * 3), hy - 8 - k * 3, 0 - k * 5))
                r.cv.set(int(round(rx)), int(ry), HORN[1])
                r.cv.set(int(round(rx)) + side, int(ry), HORN[1])
        rig.custom(d, draw)


def torso(rig, hipY):
    def shoulders(m, r):
        sx0, _ = r.p((0, 0, 0))
        m.poly([(sx0 - r.width(26, 12), hipY - 40), (sx0 + r.width(26, 12), hipY - 40),
                (sx0 + r.width(14, 10), hipY - 4), (sx0 - r.width(14, 10), hipY - 4)])

    def details(r):
        cv = r.cv
        if r.facing_away:
            sx, _ = r.p((0, 0, 0))
            for y in range(hipY - 36, hipY - 6):
                cv.set(int(sx), y, SKIN[1])
            for side in (-1, 1):
                bx, by = r.p((side * 9, hipY - 28, -9))
                cv.part(cv.mask().oval(bx, by, r.width(8, 4), 6), SKIN, thickness=2, rim=1, shadow=1)
            return
        for side in (-1, 1):
            px, py = r.p((side * 10, hipY - 30, 9))
            cv.part(cv.mask().oval(px, py, max(2, r.width(10, 4)), 6), SKIN, thickness=2, rim=2, shadow=2)
        if r.c > 0.6:
            sx, _ = r.p((0, 0, 11))
            for y in range(hipY - 36, hipY - 4):
                cv.set(int(sx), y, SKIN[1])
        for row in range(3):
            y = hipY - 20 + row * 5
            for side in (-1, 1):
                ax, _ = r.p((side * 5, 0, 10))
                cv.part(cv.mask().oval(ax, y, max(1.5, r.width(4, 1.5)), 2), SKIN, thickness=1, rim=1, shadow=1)
        for i in range(4):
            y = hipY - 24 + i * 4
            for side in (-1, 1):
                ox, _ = r.p((side * (16 - i), 0, 4))
                cv.set(int(round(ox)), y, SKIN[1])
                cv.set(int(round(ox)) + side * int(round(r.c)), y + 1, SKIN[1])

    rig.blob((0, hipY - 22, 0), 20, 20, 14, SKIN, thickness=4, rim=3, extra=shoulders, after=details)

    def loincloth(r):
        cv = r.cv
        lx, _ = r.p((0, 0, 0))
        w = r.width(14, 9)
        m = cv.mask().poly([(lx - w, hipY - 4), (lx + w, hipY - 4), (lx + w - 2, hipY + 8), (lx - w + 2, hipY + 8)])
        cv.part(m, FUR, thickness=2, rim=1, shadow=1)
        for k in range(int(-w) + 2, int(w) - 1, 4):
            cv.set(int(lx) + k, hipY + 6, FUR[0])
            cv.set(int(lx) + k, hipY + 7, FUR[0])
    rig.custom(rig.depth(0, 0) + 0.6, loincloth)


def draw_standing(frame, turn):
    cv = Canvas(W, H)
    rig = Rig(cv, turn, CX)
    hurling = frame in (4, 5)
    hurt = frame == 6
    phase = {1: 0, 2: 1, 3: 2}.get(frame, -1)
    bob, lstep, rstep = 0, 0, 0
    if phase == 0:
        lstep, rstep, bob = 8, -8, 2
    elif phase == 1:
        lstep, rstep, bob = 0, 0, -2
    elif phase == 2:
        lstep, rstep, bob = -8, 8, 2

    ground = 118
    hipY = 72 + bob + (2 if hurt else 0)

    leg(rig, +1, hipY, ground, lstep)
    leg(rig, -1, hipY, ground, rstep)
    torso(rig, hipY)
    shY = hipY - 36

    if hurling:
        arm(rig, +1, (22, shY, 0), (32, shY + 16, 6), (30, shY + 34, 10))
        hand = (-32, shY - 24, 10)
        arm(rig, -1, (-22, shY, 0), (-34, shY - 6, 6), hand, holding=True)
        px, py = rig.p((hand[0], hand[1] - (10 if frame == 5 else 6), hand[2] + 4))
        r = 10 if frame == 5 else 7

        def plasma(rg, px=px, py=py, r=r):
            for i, col in enumerate(PLASMA[::-1]):
                rg.cv.paint(rg.cv.mask().circle(px, py, r - i * 2.2), col)
            for dx, dy in ((-r, -3), (r - 1, -4), (0, -r - 3), (-3, -r - 1), (r - 3, 4)):
                rg.cv.set(int(px + dx), int(py + dy), PLASMA[1])
        rig.custom(rig.depth(hand[0], hand[2]) + 6, plasma)
    else:
        arm(rig, +1, (22, shY, 0), (32, shY + 18, -lstep * 0.5), (30, shY + 40, -lstep))
        arm(rig, -1, (-22, shY, 0), (-32, shY + 18, -rstep * 0.5), (-30, shY + 40, -rstep))

    head(rig, hipY - 54 + (3 if hurt else 0), roar=hurling or hurt, hurt=hurt)
    rig.render()

    if hurt:
        for (bx, by, r) in ((CX - 6, hipY - 24, 4), (CX + 6, hipY - 16, 3), (CX - 12, hipY - 32, 2)):
            cv.paint(cv.mask().circle(bx, by, r), BLOOD)
        cv.paint(cv.mask().circle(CX - 4, hipY - 20, 2), BLOOD_DARK)
    cv.outline(OUTLINE)
    return cv


def draw_recoil():
    cv = draw_standing(6, 0)
    out = Canvas(W, H)
    for y in range(H):
        shift = -(H - y) // 12
        for x in range(W):
            c = cv.get(x, y)
            if c is not None:
                out.set(x + shift, y, c)
    for (bx, by, r) in ((42, 50, 6), (34, 44, 3), (50, 40, 3)):
        out.paint(out.mask().circle(bx, by, r), BLOOD)
    out.paint(out.mask().circle(40, 52, 3), BLOOD_DARK)
    out.outline(OUTLINE)
    return out


def draw_falling():
    """Frame 8: down on one knee, torso sagging, head dropping."""
    cv = Canvas(W, H)
    ground = 118
    hipY = 86
    m = cv.mask().tapered(38, hipY, 9, 22, hipY + 18, 6)
    cv.part(m, FUR, thickness=3, tint=BACK)
    m = cv.mask().tapered(22, hipY + 18, 6, 40, hipY + 28, 4)
    cv.part(m, FUR, thickness=2, tint=BACK)
    m = cv.mask().poly([(38, ground - 6), (50, ground - 6), (52, ground), (37, ground)])
    cv.part(m, HOOF, thickness=2, tint=BACK)
    rig = Rig(cv, 0, CX)
    leg(rig, +1, hipY - 2, ground, 4)
    torso(rig, hipY)
    arm(rig, -1, (-22, hipY - 36, 0), (-34, hipY - 20, 2), (-36, hipY - 2, 4))
    arm(rig, +1, (22, hipY - 36, 0), (36, hipY - 26, 4), (42, hipY - 10, 6))
    rig.render()
    rig = Rig(cv, 0, 52)
    head(rig, hipY - 46, roar=True, hurt=True)
    rig.render()
    cv.paint(cv.mask().circle(44, hipY - 22, 6), BLOOD)
    cv.paint(cv.mask().circle(52, hipY - 14, 4), BLOOD_DARK)
    for k in range(6):
        cv.set(46 + k // 2, hipY - 16 + k * 3, BLOOD)
    cv.outline(OUTLINE)
    return cv


def draw_corpse():
    """Frame 9: sprawled on its back, horns propping the head up."""
    cv = Canvas(W, H)
    ground = 116
    cv.paint(cv.mask().oval(48, ground, 40, 4), BLOOD_DARK)
    cv.paint(cv.mask().oval(46, ground - 1, 28, 2), BLOOD)
    m = cv.mask().tapered(30, ground - 16, 8, 14, ground - 10, 5)
    cv.part(m, FUR, thickness=3, tint=BACK)
    m = cv.mask().poly([(4, ground - 14), (14, ground - 14), (14, ground - 7), (3, ground - 7)])
    cv.part(m, HOOF, thickness=2, tint=BACK)
    m = cv.mask().tapered(34, ground - 10, 8, 16, ground - 4, 5)
    cv.part(m, FUR, thickness=3)
    m = cv.mask().poly([(6, ground - 8), (16, ground - 8), (17, ground - 1), (5, ground - 1)])
    cv.part(m, HOOF, thickness=2)
    m = cv.mask().oval(50, ground - 12, 22, 9)
    cv.part(m, SKIN, thickness=4, rim=2)
    for side in (-1, 1):
        m = cv.mask().oval(50 + side * 8, ground - 15, 6, 3)
        cv.part(m, SKIN, thickness=1, rim=1, shadow=1)
    m = cv.mask().poly([(30, ground - 16), (34, ground - 16), (36, ground - 6), (30, ground - 6)])
    cv.part(m, FUR, thickness=2, rim=0, shadow=1)
    m = cv.mask().tapered(66, ground - 14, 5, 82, ground - 18, 4)
    cv.part(m, SKIN, thickness=2)
    cv.part(cv.mask().circle(84, ground - 19, 4), SKIN, thickness=2)
    claws(cv, [(82, ground - 21), (86, ground - 21), (90, ground - 21)], up=True, length=6)
    hx, hy = 76, ground - 12
    m = cv.mask().oval(hx, hy, 11, 8)
    cv.part(m, SKIN, thickness=3, rim=1)
    cv.paint(cv.mask().rect(hx - 3, hy - 1, 3, 1), SKIN[0])
    cv.paint(cv.mask().rect(hx + 3, hy - 1, 3, 1), SKIN[0])
    cv.paint(cv.mask().rect(hx - 5, hy + 3, 11, 2), MOUTH)
    for mx in range(hx - 4, hx + 5, 3):
        cv.paint(cv.mask().poly([(mx - 1, hy + 3), (mx + 1, hy + 3), (mx, hy + 6)]), TOOTH)
    m = cv.mask().poly([(hx + 4, hy - 7), (hx + 8, hy - 6), (hx + 16, hy - 20), (hx + 14, hy - 24), (hx + 11, hy - 22), (hx + 12, hy - 16)])
    cv.part(m, HORN, thickness=2, rim=1)
    m = cv.mask().poly([(hx - 8, hy - 6), (hx - 5, hy - 4), (hx - 20, hy - 2), (hx - 22, hy - 5)])
    cv.part(m, HORN, thickness=1, rim=0)
    cv.paint(cv.mask().circle(48, ground - 14, 5), BLOOD)
    cv.paint(cv.mask().circle(54, ground - 10, 3), BLOOD_DARK)
    cv.outline(OUTLINE)
    return cv


def frames():
    return turntable_frames(draw_standing, lambda: [draw_recoil(), draw_falling(), draw_corpse()])
