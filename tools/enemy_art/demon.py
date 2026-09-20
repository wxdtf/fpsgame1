"""Demon: a hulking pink beast that is mostly jaws — hunched, spined back, small burning eyes, charges to bite.

Canvas 96x96, turntable rig. Frames per view: 0 idle, 1-3 lumber, 4-5 bite, 6 hurt;
front only: 7 recoil, 8 collapsing, 9 corpse.
"""

from pixelart import Canvas, Rig, ramp, rgb, turntable_frames

W, H = 96, 96
CX = 48

HIDE = ramp(rgb(178, 92, 112), deep=rgb(58, 22, 34), hi=rgb(236, 160, 176))
UNDER = ramp(rgb(206, 150, 150), deep=rgb(96, 52, 60), hi=rgb(244, 214, 206))
SPINE = ramp(rgb(120, 56, 70), deep=rgb(40, 14, 22), hi=rgb(200, 120, 136))
HOOF = ramp(rgb(60, 34, 24), deep=rgb(18, 8, 6), hi=rgb(120, 82, 62))
GUM = rgb(104, 22, 34)
GUM_DARK = rgb(60, 10, 20)
TOOTH = rgb(242, 236, 220)
TOOTH_DARK = rgb(196, 188, 170)
EYE = rgb(255, 60, 20)
EYE_CORE = rgb(255, 200, 120)
DROOL = rgb(200, 190, 170)
BLOOD = rgb(150, 12, 10)
BLOOD_DARK = rgb(96, 6, 6)
OUTLINE = rgb(28, 8, 14)
BACK = ((20, 0, 16), 0.22)


def leg(rig, side, hipY, ground, step):
    hx = side * 14
    sway = side * step * 0.3
    hip = (hx, hipY, 0)
    knee = (hx + sway * 0.5, hipY + 10, 2 + step * 0.4)
    foot = (hx + sway, ground - 8 - (2 if step > 0 else 0), 3 + step)
    rig.limb(hip, 8, knee, 6, HIDE, thickness=3)
    rig.limb(knee, 6, foot, 5, HIDE, thickness=3)

    def hoof(r):
        fx, fy = r.p(foot)
        w = r.width(6.5, 6)
        m = r.cv.mask().poly([(fx - w, fy + 1), (fx + w, fy + 1), (fx + w + 1, fy + 8), (fx - w - 1, fy + 8)])
        r.cv.part(m, HOOF, thickness=2, rim=1, tint=r.tint_for(r.depth(foot[0], foot[2])))
        if not r.side_on:
            for k in range(3):
                r.cv.set(int(round(fx)), int(fy) + 5 + k, HOOF[0])
    rig.custom(rig.depth(foot[0], foot[2]) + 0.3, hoof)


def arm(rig, side, shoulder, elbow, hand):
    rig.limb(shoulder, 7, elbow, 5, HIDE, thickness=3)
    rig.limb(elbow, 5, hand, 4, HIDE)

    def paw(r):
        hx, hy = r.p(hand)
        r.cv.part(r.cv.mask().circle(hx, hy, 4.5), HIDE, thickness=2, rim=1,
                  tint=r.tint_for(r.depth(hand[0], hand[2])))
        spread = max(1.5, r.width(3, 1))
        for dx in (-spread, 0, spread):
            m = r.cv.mask().poly([(hx + dx - 1, hy + 3), (hx + dx + 1, hy + 3), (hx + dx, hy + 8)])
            r.cv.part(m, HOOF, thickness=1, rim=0, contact=False)
    rig.custom(rig.depth(hand[0], hand[2]) + 0.3, paw)


def body(rig, hipY):
    # hump behind/above, then the massive torso
    rig.blob((0, hipY - 26, -6), 22, 14, 16, HIDE, thickness=4, rim=3)

    def details(r):
        cv = r.cv
        if r.facing_away:
            return
        bx, by = r.p((0, hipY - 6, 16))
        cv.part(cv.mask().oval(bx, by, max(2, r.width(16, 6)), 12), UNDER, thickness=3, rim=1, shadow=1)
        if r.c > 0.6:
            for y in range(hipY - 14, hipY + 3, 4):
                cv.set(int(round(bx)), y, UNDER[1])
                cv.set(int(round(bx)) - 4, y + 2, UNDER[1])
                cv.set(int(round(bx)) + 4, y + 2, UNDER[1])
    rig.blob((0, hipY - 14, 0), 30, 22, 22, HIDE, thickness=4, rim=3, after=details)

    # skin folds on the shoulders
    def folds(r):
        for side in (-1, 1):
            for k in range(3):
                y = hipY - 30 + k * 5
                for d in range(6):
                    fx, _ = r.p((side * (18 + d), 0, 8 - d))
                    r.cv.set(int(round(fx)), y + d // 2, HIDE[1])
    rig.custom(rig.depth(0, 12), folds)

    # row of spines across the top of the hump
    for k in range(7):
        x = -21 + k * 7
        height = 6 + (3 if 2 <= k <= 4 else 0)
        base = (x, hipY - 33 - abs(k - 3), -6)

        def draw(r, base=base, height=height):
            bx, by = r.p(base)
            m = r.cv.mask().poly([(bx - 2, by + 4), (bx + 2, by + 4), (bx, by - height)])
            r.cv.part(m, SPINE, thickness=1, rim=1, shadow=1)
        rig.custom(rig.depth(base[0], base[2]) + 0.2, draw)


def jaws(rig, hy, open_amount, hurt=False):
    gap = int(open_amount * 12)
    z = 12  # the head sits forward of the body

    def skull_extra(m, r):
        m.poly([r.p((-20, hy, z)), r.p((20, hy, z)), r.p((18, hy + 6, z + 2)), r.p((-18, hy + 6, z + 2))])

    def face(r):
        cv = r.cv
        if r.facing_away:
            return
        for side in (-1, 1):
            bx, by = r.p((side * 9, hy - 8, z + 8))
            cv.part(cv.mask().oval(bx, by, max(2, r.width(6, 2)), 3), HIDE, thickness=1, rim=1, shadow=2)
        for side in (-1, 1):
            ex, ey = r.p((side * 9, hy - 5, z + 11))
            ex, ey = int(round(ex)), int(ey)
            cv.paint(cv.mask().oval(ex, ey, max(2, r.width(3.2, 1.2)), 2.2), HIDE[0])
            if not hurt:
                cv.paint(cv.mask().oval(ex, ey, max(1.2, r.width(2, 0.8)), 1.3), EYE)
                cv.set(ex + side * int(round(r.c)), ey, EYE_CORE)
            else:
                cv.set(ex, ey, EYE_CORE)
        for side in (-1, 1):
            nx, _ = r.p((side * 2, 0, z + 13))
            cv.set(int(round(nx)), hy + 1, HIDE[0])
            cv.set(int(round(nx)) + side, hy + 2, HIDE[0])
        # upper gum + teeth along the front
        gx, _ = r.p((0, 0, z + 12))
        gw = max(2, int(round(r.width(17, 5))))
        cv.paint(cv.mask().rect(int(round(gx)) - gw, hy + 6, 2 * gw + 1, 2), GUM)
        for i, mx in enumerate(range(int(round(gx)) - gw + 2, int(round(gx)) + gw, 4)):
            tall = 5 if i % 3 == 0 else 3
            col = TOOTH if tall == 5 else TOOTH_DARK
            cv.paint(cv.mask().poly([(mx - 1, hy + 7), (mx + 2, hy + 7), (mx, hy + 7 + tall)]), col)
        if gap > 0:
            cv.paint(cv.mask().rect(int(round(gx)) - gw + 1, hy + 8, 2 * gw - 1, gap), GUM_DARK)
            cv.paint(cv.mask().oval(gx, hy + 8 + gap // 2, max(2, r.width(8, 3)), max(1, gap // 3)), GUM)
            for dx in (-8, 5):
                for k in range(gap // 2):
                    cv.set(int(round(gx)) + int(dx * r.c), hy + 9 + k, DROOL)

    rig.blob((0, hy - 2, z), 20, 12, 14, HIDE, thickness=3, rim=2, extra=skull_extra, after=face)

    jy = hy + 8 + gap

    def lower_jaw(r):
        cv = r.cv
        pts = [r.p((-17, jy, z)), r.p((17, jy, z)), r.p((14, jy + 8, z + 1)), r.p((-14, jy + 8, z + 1))]
        cv.part(cv.mask().poly(pts), HIDE, thickness=3, rim=0, shadow=1)
        if r.facing_away:
            return
        gx, _ = r.p((0, 0, z + 12))
        gw = max(2, int(round(r.width(16, 4))))
        cv.paint(cv.mask().rect(int(round(gx)) - gw, jy, 2 * gw + 1, 2), GUM)
        for i, mx in enumerate(range(int(round(gx)) - gw + 3, int(round(gx)) + gw, 4)):
            tall = 5 if i % 3 == 0 else 3
            col = TOOTH if tall == 5 else TOOTH_DARK
            cv.paint(cv.mask().poly([(mx - 1, jy + 1), (mx + 2, jy + 1), (mx, jy + 1 - tall)]), col)
    rig.custom(rig.depth(0, z) + 0.5, lower_jaw)


def draw_standing(frame, turn):
    cv = Canvas(W, H)
    rig = Rig(cv, turn, CX)
    biting = frame in (4, 5)
    hurt = frame == 6
    phase = {1: 0, 2: 1, 3: 2}.get(frame, -1)
    bob, lstep, rstep = 0, 0, 0
    if phase == 0:
        lstep, rstep, bob = 7, -7, 2
    elif phase == 1:
        lstep, rstep, bob = 0, 0, -2
    elif phase == 2:
        lstep, rstep, bob = -7, 7, 2

    ground = 94
    hipY = 66 + bob + (2 if hurt else 0)

    leg(rig, +1, hipY, ground, lstep)
    leg(rig, -1, hipY, ground, rstep)
    body(rig, hipY)

    shY = hipY - 24
    if biting:
        arm(rig, +1, (26, shY, 4), (36, shY + 6, 10), (36, shY + 20, 18))
        arm(rig, -1, (-26, shY, 4), (-36, shY + 6, 10), (-36, shY + 20, 18))
    else:
        arm(rig, +1, (26, shY, 4), (34, shY + 14, lstep * 0.5), (32, shY + 30, lstep))
        arm(rig, -1, (-26, shY, 4), (-34, shY + 14, rstep * 0.5), (-32, shY + 30, rstep))

    open_amount = 0.15 if not biting else (1.0 if frame == 4 else 0.45)
    if hurt:
        open_amount = 0.6
    jaws(rig, hipY - 22 + (3 if biting else 0), open_amount, hurt=hurt)
    rig.render()

    if hurt:
        for (bx, by, r) in ((CX - 8, hipY - 12, 4), (CX + 6, hipY - 6, 3), (CX - 14, hipY - 20, 2)):
            cv.paint(cv.mask().circle(bx, by, r), BLOOD)
        cv.paint(cv.mask().circle(CX - 6, hipY - 9, 2), BLOOD_DARK)
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
    for (bx, by, r) in ((40, 54, 6), (32, 48, 3), (50, 46, 3)):
        out.paint(out.mask().circle(bx, by, r), BLOOD)
    out.paint(out.mask().circle(38, 56, 3), BLOOD_DARK)
    out.outline(OUTLINE)
    return out


def draw_falling():
    """Frame 8: front legs give way, the head crashes down toward the floor."""
    cv = Canvas(W, H)
    ground = 94
    hipY = 74
    rig = Rig(cv, 0, CX)
    leg(rig, -1, hipY - 2, ground, -2)
    leg(rig, +1, hipY, ground, 2)
    rig.render()
    m = cv.mask()
    m.oval(50, hipY - 10, 30, 18)
    m.oval(44, hipY - 20, 20, 12)
    cv.part(m, HIDE, thickness=4, rim=3)
    m = cv.mask().oval(48, hipY, 14, 8)
    cv.part(m, UNDER, thickness=3, rim=0, shadow=1)
    for k in range(6):
        sx = 34 + k * 6
        sy = hipY - 30 + k * 2
        m = cv.mask().poly([(sx - 2, sy + 6), (sx + 2, sy + 6), (sx - 1, sy - 3)])
        cv.part(m, SPINE, thickness=1, rim=1, shadow=1)
    rig = Rig(cv, 0, CX)
    arm(rig, -1, (-22, hipY - 12, 0), (-34, hipY - 2, 4), (-38, hipY + 12, 8))
    arm(rig, +1, (26, hipY - 12, 0), (36, hipY - 2, 4), (38, hipY + 12, 8))
    jaws(rig, hipY - 2, 0.8, hurt=True)
    rig.render()
    cv.paint(cv.mask().circle(52, hipY - 14, 5), BLOOD)
    cv.paint(cv.mask().circle(58, hipY - 10, 3), BLOOD_DARK)
    cv.outline(OUTLINE)
    return cv


def draw_corpse():
    """Frame 9: a heap on the floor, jaws slack, spines up."""
    cv = Canvas(W, H)
    ground = 92
    cv.paint(cv.mask().oval(48, ground, 38, 3), BLOOD_DARK)
    cv.paint(cv.mask().oval(46, ground - 1, 26, 2), BLOOD)
    m = cv.mask().tapered(30, ground - 12, 7, 12, ground - 8, 5)
    cv.part(m, HIDE, thickness=3, tint=BACK)
    m = cv.mask().poly([(4, ground - 12), (14, ground - 12), (15, ground - 5), (3, ground - 5)])
    cv.part(m, HOOF, thickness=2, tint=BACK)
    m = cv.mask().tapered(34, ground - 8, 7, 16, ground - 3, 5)
    cv.part(m, HIDE, thickness=3)
    m = cv.mask().poly([(8, ground - 6), (18, ground - 6), (19, ground), (7, ground)])
    cv.part(m, HOOF, thickness=2)
    m = cv.mask().oval(52, ground - 12, 28, 11)
    cv.part(m, HIDE, thickness=4, rim=2)
    m = cv.mask().oval(46, ground - 6, 14, 5)
    cv.part(m, UNDER, thickness=2, rim=0, shadow=1)
    for k in range(5):
        sx = 40 + k * 6
        m = cv.mask().poly([(sx - 2, ground - 22), (sx + 2, ground - 22), (sx, ground - 30 + (k % 2) * 2)])
        cv.part(m, SPINE, thickness=1, rim=1, shadow=1)
    m = cv.mask().tapered(70, ground - 10, 5, 84, ground - 5, 4)
    cv.part(m, HIDE, thickness=2)
    for dx in (86, 89, 92):
        m = cv.mask().poly([(dx - 1, ground - 5), (dx + 1, ground - 5), (dx + 1, ground - 1)])
        cv.part(m, HOOF, thickness=1, rim=0, contact=False)
    hx, hy = 78, ground - 16
    m = cv.mask().oval(hx, hy, 14, 8)
    cv.part(m, HIDE, thickness=3, rim=1)
    cv.paint(cv.mask().oval(hx + 6, hy - 3, 2, 1), HIDE[0])
    cv.paint(cv.mask().rect(hx - 10, hy + 4, 22, 2), GUM)
    for mx in range(hx - 9, hx + 12, 4):
        cv.paint(cv.mask().poly([(mx - 1, hy + 5), (mx + 2, hy + 5), (mx, hy + 9)]), TOOTH_DARK)
    cv.paint(cv.mask().circle(52, ground - 14, 4), BLOOD)
    cv.paint(cv.mask().circle(56, ground - 11, 3), BLOOD_DARK)
    cv.outline(OUTLINE)
    return cv


def frames():
    return turntable_frames(draw_standing, lambda: [draw_recoil(), draw_falling(), draw_corpse()])
