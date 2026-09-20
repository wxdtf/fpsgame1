"""Demon: a hulking pink beast that is mostly jaws — hunched, spined back, tiny burning eyes, charges to bite.

Canvas 96x96. Frames: 0 idle, 1-3 lumber, 4-5 bite, 6 hurt, 7 recoil, 8 collapsing, 9 corpse.
"""

from pixelart import Canvas, ramp, rgb

W, H = 96, 96

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


def leg(cv, hx, hipY, ground, foot_dx, back, thick=1.0):
    tint = BACK if back else None
    kneeX = hx + foot_dx // 3
    kneeY = hipY + 10
    footX = hx + foot_dx
    footY = ground - 5 - (2 if foot_dx > 0 else 0)
    m = cv.mask().tapered(hx, hipY, 8 * thick, kneeX, kneeY, 6 * thick)
    cv.part(m, HIDE, thickness=3, rim=1, tint=tint)
    m = cv.mask().tapered(kneeX, kneeY, 6 * thick, footX, footY - 3, 5 * thick)
    cv.part(m, HIDE, thickness=3, rim=1, tint=tint)
    # cloven hoof
    m = cv.mask().poly([(footX - 6, footY - 2), (footX + 6, footY - 2), (footX + 7, footY + 5), (footX - 7, footY + 5)])
    cv.part(m, HOOF, thickness=2, rim=1, tint=tint)
    cv.set(footX, footY + 2, HOOF[0])
    cv.set(footX, footY + 3, HOOF[0])
    cv.set(footX, footY + 4, HOOF[0])


def jaws(cv, hx, hy, open_amount, hurt=False):
    """Head that is mostly mouth. open_amount 0..1."""
    gap = int(open_amount * 12)
    # skull (upper head)
    m = cv.mask()
    m.oval(hx, hy - 2, 20, 12)
    m.poly([(hx - 20, hy), (hx + 20, hy), (hx + 18, hy + 6), (hx - 18, hy + 6)])
    cv.part(m, HIDE, thickness=3, rim=2)
    # brow ridges
    for side in (-1, 1):
        m = cv.mask().oval(hx + side * 9, hy - 8, 6, 3)
        cv.part(m, HIDE, thickness=1, rim=1, shadow=2)
    # small burning eyes deep in the sockets
    for side in (-1, 1):
        ex = hx + side * 9
        cv.paint(cv.mask().oval(ex, hy - 5, 3.2, 2.2), HIDE[0])
        if not hurt:
            cv.paint(cv.mask().oval(ex, hy - 5, 2, 1.3), EYE)
            cv.set(ex + side, hy - 5, EYE_CORE)
        else:
            cv.set(ex, hy - 5, EYE_CORE)
            cv.set(ex + side, hy - 5, EYE_CORE)
    # nostrils
    for side in (-1, 1):
        cv.set(hx + side * 2, hy + 1, HIDE[0])
        cv.set(hx + side * 3, hy + 2, HIDE[0])
    # upper gum + teeth
    cv.paint(cv.mask().rect(hx - 17, hy + 6, 35, 2), GUM)
    for i, mx in enumerate(range(hx - 15, hx + 16, 4)):
        tall = 5 if i in (0, 7) or mx in (hx - 3, hx + 1) else 3
        col = TOOTH if tall == 5 else TOOTH_DARK
        cv.paint(cv.mask().poly([(mx - 1, hy + 7), (mx + 2, hy + 7), (mx, hy + 7 + tall)]), col)
    # mouth cavity
    if gap > 0:
        cv.paint(cv.mask().rect(hx - 16, hy + 8, 33, gap), GUM_DARK)
        cv.paint(cv.mask().oval(hx, hy + 8 + gap // 2, 8, max(1, gap // 3)), GUM)
        # drool strands
        for dx in (-8, 5):
            for k in range(gap // 2):
                cv.set(hx + dx, hy + 9 + k, DROOL)
    # lower jaw
    jy = hy + 8 + gap
    m = cv.mask()
    m.poly([(hx - 17, jy), (hx + 17, jy), (hx + 14, jy + 8), (hx - 14, jy + 8)])
    cv.part(m, HIDE, thickness=3, rim=0, shadow=1)
    cv.paint(cv.mask().rect(hx - 16, jy, 33, 2), GUM)
    for i, mx in enumerate(range(hx - 13, hx + 14, 4)):
        tall = 5 if i in (0, 6) else 3
        col = TOOTH if tall == 5 else TOOTH_DARK
        cv.paint(cv.mask().poly([(mx - 1, jy + 1), (mx + 2, jy + 1), (mx, jy + 1 - tall)]), col)


def body(cv, tx, hipY, bob=0):
    # massive hunched torso
    m = cv.mask()
    m.oval(tx, hipY - 14, 30, 22)
    m.oval(tx, hipY - 26, 22, 14)   # hump
    cv.part(m, HIDE, thickness=4, rim=3)
    # lighter chest/belly
    m = cv.mask().oval(tx, hipY - 6, 16, 12)
    cv.part(m, UNDER, thickness=3, rim=1, shadow=1)
    for y in range(hipY - 14, hipY + 3, 4):
        cv.set(tx, y, UNDER[1])
        cv.set(tx - 4, y + 2, UNDER[1])
        cv.set(tx + 4, y + 2, UNDER[1])
    # skin folds on the shoulders
    for side in (-1, 1):
        for k in range(3):
            y = hipY - 30 + k * 5
            for d in range(6):
                cv.set(tx + side * (18 + d), y + d // 2, HIDE[1])
    # spines along the top of the hump, tallest in the middle
    for k in range(7):
        sx = tx - 21 + k * 7
        height = 6 + (3 if 2 <= k <= 4 else 0)
        sy = hipY - 37 - abs(k - 3)
        m = cv.mask().poly([(sx - 2, sy + 4), (sx + 2, sy + 4), (sx, sy - height)])
        cv.part(m, SPINE, thickness=1, rim=1, shadow=1)


def arm(cv, shx, shy, elx, ely, hx, hy, back=False):
    tint = BACK if back else None
    m = cv.mask().tapered(shx, shy, 7, elx, ely, 5)
    cv.part(m, HIDE, thickness=3, rim=1, tint=tint)
    m = cv.mask().tapered(elx, ely, 5, hx, hy, 4)
    cv.part(m, HIDE, thickness=2, rim=1, tint=tint)
    m = cv.mask().circle(hx, hy, 4.5)
    cv.part(m, HIDE, thickness=2, rim=1, tint=tint)
    for dx in (-3, 0, 3):
        m = cv.mask().poly([(hx + dx - 1, hy + 3), (hx + dx + 1, hy + 3), (hx + dx, hy + 8)])
        cv.part(m, HOOF, thickness=1, rim=0, contact=False)


def draw_standing(frame):
    cv = Canvas(W, H)
    biting = frame in (4, 5)
    hurt = frame == 6
    phase = {1: 0, 2: 1, 3: 2}.get(frame, -1)
    bob, lf, rf = 0, 0, 0
    if phase == 0:
        lf, rf, bob = 7, -7, 2
    elif phase == 1:
        lf, rf, bob = 0, 0, -2
    elif phase == 2:
        lf, rf, bob = -7, 7, 2

    ground = 94
    hipY = 66 + bob + (2 if hurt else 0)
    tx = 48 + (-3 if hurt else 0)

    if lf >= rf:
        leg(cv, tx + 14, hipY, ground, rf, back=True)
        leg(cv, tx - 14, hipY, ground, lf, back=False)
    else:
        leg(cv, tx - 14, hipY, ground, lf, back=True)
        leg(cv, tx + 14, hipY, ground, rf, back=False)

    body(cv, tx, hipY, bob)

    shY = hipY - 24
    if biting:
        # arms reaching forward and out
        arm(cv, tx - 26, shY, tx - 36, shY + 6, tx - 40, shY + 20)
        arm(cv, tx + 26, shY, tx + 36, shY + 6, tx + 40, shY + 20)
    else:
        sw = lf // 3
        arm(cv, tx - 26, shY, tx - 34 + sw, shY + 14, tx - 32 + sw * 2, shY + 30, back=(lf < rf))
        arm(cv, tx + 26, shY, tx + 34 - sw, shY + 14, tx + 32 - sw * 2, shY + 30, back=(rf < lf))

    open_amount = 0.15 if not biting else (1.0 if frame == 4 else 0.45)
    if hurt:
        open_amount = 0.6
    jaws(cv, tx, hipY - 22 + (3 if biting else 0), open_amount, hurt=hurt)

    if hurt:
        for (bx, by, r) in ((tx - 8, hipY - 12, 4), (tx + 6, hipY - 6, 3), (tx - 14, hipY - 20, 2)):
            cv.paint(cv.mask().circle(bx, by, r), BLOOD)
        cv.paint(cv.mask().circle(tx - 6, hipY - 9, 2), BLOOD_DARK)
    cv.outline(OUTLINE)
    return cv


def draw_recoil():
    cv = draw_standing(6)
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
    leg(cv, 30, hipY - 2, ground, -2, back=True)
    leg(cv, 66, hipY, ground, 2, back=False)
    # body pitched forward
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
    arm(cv, 26, hipY - 12, 14, hipY - 2, 10, hipY + 12, back=True)
    arm(cv, 74, hipY - 12, 84, hipY - 2, 86, hipY + 12)
    jaws(cv, 48, hipY - 2, 0.8, hurt=True)
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
    # legs sprawled left
    m = cv.mask().tapered(30, ground - 12, 7, 12, ground - 8, 5)
    cv.part(m, HIDE, thickness=3, tint=BACK)
    m = cv.mask().poly([(4, ground - 12), (14, ground - 12), (15, ground - 5), (3, ground - 5)])
    cv.part(m, HOOF, thickness=2, tint=BACK)
    m = cv.mask().tapered(34, ground - 8, 7, 16, ground - 3, 5)
    cv.part(m, HIDE, thickness=3)
    m = cv.mask().poly([(8, ground - 6), (18, ground - 6), (19, ground), (7, ground)])
    cv.part(m, HOOF, thickness=2)
    # body mound
    m = cv.mask().oval(52, ground - 12, 28, 11)
    cv.part(m, HIDE, thickness=4, rim=2)
    m = cv.mask().oval(46, ground - 6, 14, 5)
    cv.part(m, UNDER, thickness=2, rim=0, shadow=1)
    for k in range(5):
        sx = 40 + k * 6
        m = cv.mask().poly([(sx - 2, ground - 22), (sx + 2, ground - 22), (sx, ground - 30 + (k % 2) * 2)])
        cv.part(m, SPINE, thickness=1, rim=1, shadow=1)
    # arm out to the right
    m = cv.mask().tapered(70, ground - 10, 5, 84, ground - 5, 4)
    cv.part(m, HIDE, thickness=2)
    for dx in (86, 89, 92):
        m = cv.mask().poly([(dx - 1, ground - 5), (dx + 1, ground - 5), (dx + 1, ground - 1)])
        cv.part(m, HOOF, thickness=1, rim=0, contact=False)
    # head on the right, jaw slack on the floor
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
    out = [draw_standing(f) for f in range(7)]
    out.append(draw_recoil())
    out.append(draw_falling())
    out.append(draw_corpse())
    return out
