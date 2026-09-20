"""Baron of Hell: a towering goat-legged demon — pink-tan torso, bone horns, green eyes, green plasma.

Canvas 96x120 (4:5 like the old 64x80 sheet). Frames: 0 idle, 1-3 stride, 4-5 hurl plasma,
6 hurt, 7 recoil, 8 falling to one knee, 9 corpse.
"""

from pixelart import Canvas, ramp, rgb

W, H = 96, 120

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


def leg(cv, hx, hipY, ground, foot_dx, back):
    """Goat leg: furred thigh, backward hock, thin cannon, cloven hoof."""
    tint = BACK if back else None
    kneeX = hx + 2 + foot_dx // 3
    kneeY = hipY + 14 - abs(foot_dx) // 4
    hockX = hx - 4 + foot_dx // 2
    hockY = hipY + 28 - abs(foot_dx) // 4
    hoofX = hx + 1 + foot_dx
    hoofY = ground - 3 - (3 if foot_dx > 0 else 0)
    m = cv.mask().tapered(hx, hipY + 2, 9, kneeX, kneeY, 6)
    cv.part(m, FUR, thickness=3, rim=2, tint=tint)
    m = cv.mask().tapered(kneeX, kneeY, 6, hockX, hockY, 4)
    cv.part(m, FUR, thickness=3, rim=1, tint=tint)
    m = cv.mask().tapered(hockX, hockY, 4, hoofX, hoofY - 4, 3.5)
    cv.part(m, FUR, thickness=2, rim=1, tint=tint)
    # fur tufts
    for k in range(3):
        px, py = hx - 8 + k, hipY + 6 + k * 5
        cv.set(int(px), int(py), FUR[3])
        cv.set(int(px) + 1, int(py) + 1, FUR[3])
    # hoof
    m = cv.mask().poly([(hoofX - 5, hoofY - 3), (hoofX + 5, hoofY - 3), (hoofX + 6, hoofY + 3), (hoofX - 6, hoofY + 3)])
    cv.part(m, HOOF, thickness=2, rim=1, tint=tint)
    cv.set(hoofX, hoofY, HOOF[0])
    cv.set(hoofX, hoofY + 1, HOOF[0])
    cv.set(hoofX, hoofY + 2, HOOF[0])


def arm(cv, shx, shy, elx, ely, hx, hy, back=False, fingers_up=False, holding=False):
    tint = BACK if back else None
    m = cv.mask().tapered(shx, shy, 8, elx, ely, 6)
    cv.part(m, SKIN, thickness=3, rim=2, tint=tint)
    # bicep bulge
    m = cv.mask().oval((shx + elx) / 2, (shy + ely) / 2, 6, 5)
    cv.part(m, SKIN, thickness=2, rim=1, shadow=1, tint=tint)
    m = cv.mask().tapered(elx, ely, 6, hx, hy, 4.5)
    cv.part(m, SKIN, thickness=3, rim=1, tint=tint)
    m = cv.mask().circle(hx, hy, 5)
    cv.part(m, SKIN, thickness=2, rim=1, tint=tint)
    for dx in (-4, 0, 4):
        if fingers_up:
            m = cv.mask().poly([(hx + dx - 1, hy - 3), (hx + dx + 1, hy - 3), (hx + dx, hy - 10)])
        elif holding:
            m = cv.mask().poly([(hx + dx - 1, hy - 3), (hx + dx + 2, hy - 3), (hx + dx + 3, hy - 9)])
        else:
            m = cv.mask().poly([(hx + dx - 1, hy + 3), (hx + dx + 1, hy + 3), (hx + dx, hy + 10)])
        cv.part(m, CLAW, thickness=1, rim=0, contact=False)


def head(cv, hx, hy, roar=False, hurt=False):
    m = cv.mask().rect(hx - 6, hy + 10, 12, 8)
    cv.part(m, SKIN, thickness=2, rim=0)
    m = cv.mask()
    m.oval(hx, hy, 13, 12)
    m.poly([(hx - 11, hy + 4), (hx + 11, hy + 4), (hx + 7, hy + 15), (hx - 7, hy + 15)])
    cv.part(m, SKIN, thickness=4, rim=2)
    # brow
    m = cv.mask().poly([(hx - 13, hy - 5), (hx + 13, hy - 5), (hx + 12, hy - 1), (hx - 12, hy - 1)])
    cv.part(m, SKIN, thickness=1, rim=1, shadow=2)
    for side in (-1, 1):
        ex = hx + side * 6
        cv.paint(cv.mask().oval(ex, hy + 1, 3.5, 2.2), SKIN[0])
        if not hurt:
            cv.paint(cv.mask().oval(ex, hy + 1, 2.2, 1.4), EYE)
            cv.set(ex + side, hy + 1, EYE_CORE)
        else:
            cv.set(ex, hy + 1, EYE)
    # cheekbones, nose
    cv.set(hx - 9, hy + 5, SKIN[3])
    cv.set(hx + 9, hy + 5, SKIN[3])
    cv.set(hx - 2, hy + 5, SKIN[0])
    cv.set(hx + 2, hy + 5, SKIN[0])
    # mouth
    mh = 5 if roar else 1
    cv.paint(cv.mask().rect(hx - 7, hy + 8, 15, mh + 1), MOUTH)
    for mx in range(hx - 6, hx + 7, 3):
        tall = 4 if mx in (hx - 6, hx + 6) else 2
        cv.paint(cv.mask().poly([(mx - 1, hy + 8), (mx + 1, hy + 8), (mx, hy + 8 + tall)]), TOOTH)
    if roar:
        for mx in (hx - 4, hx, hx + 4):
            cv.paint(cv.mask().poly([(mx - 1, hy + 9 + mh), (mx + 1, hy + 9 + mh), (mx, hy + 6 + mh)]), TOOTH)
    # big curled horns
    for side in (-1, 1):
        bx = hx + side * 9
        m = cv.mask()
        m.poly([(bx - 3, hy - 6), (bx + 3, hy - 6), (bx + side * 10, hy - 12), (bx + side * 15, hy - 24),
                (bx + side * 11, hy - 32), (bx + side * 8, hy - 30), (bx + side * 11, hy - 23), (bx + side * 6, hy - 13)])
        cv.part(m, HORN, thickness=2, rim=2, shadow=1)
        for k in range(4):
            cv.set(bx + side * (4 + k * 2), hy - 8 - k * 4, HORN[1])
            cv.set(bx + side * (5 + k * 2), hy - 8 - k * 4, HORN[1])


def torso(cv, tx, hipY):
    m = cv.mask()
    m.poly([(tx - 26, hipY - 40), (tx + 26, hipY - 40), (tx + 14, hipY - 4), (tx - 14, hipY - 4)])
    m.oval(tx, hipY - 2, 13, 8)
    cv.part(m, SKIN, thickness=4, rim=3)
    # pecs
    for side in (-1, 1):
        m = cv.mask().oval(tx + side * 10, hipY - 30, 10, 6)
        cv.part(m, SKIN, thickness=2, rim=2, shadow=2)
    for y in range(hipY - 36, hipY - 4):
        cv.set(tx, y, SKIN[1])
    # abs
    for row in range(3):
        y = hipY - 20 + row * 5
        for side in (-1, 1):
            m = cv.mask().oval(tx + side * 5, y, 4, 2)
            cv.part(m, SKIN, thickness=1, rim=1, shadow=1)
    # obliques / rib shadows
    for i in range(4):
        y = hipY - 24 + i * 4
        for side in (-1, 1):
            cv.set(tx + side * (16 - i), y, SKIN[1])
            cv.set(tx + side * (15 - i), y + 1, SKIN[1])
    # fur loincloth at the hips
    m = cv.mask().poly([(tx - 14, hipY - 4), (tx + 14, hipY - 4), (tx + 12, hipY + 8), (tx - 12, hipY + 8)])
    cv.part(m, FUR, thickness=2, rim=1, shadow=1)
    for k in range(-10, 11, 4):
        cv.set(tx + k, hipY + 6, FUR[0])
        cv.set(tx + k, hipY + 7, FUR[0])


def draw_standing(frame):
    cv = Canvas(W, H)
    hurling = frame in (4, 5)
    hurt = frame == 6
    phase = {1: 0, 2: 1, 3: 2}.get(frame, -1)
    bob, lf, rf = 0, 0, 0
    if phase == 0:
        lf, rf, bob = 8, -8, 2
    elif phase == 1:
        lf, rf, bob = 0, 0, -2
    elif phase == 2:
        lf, rf, bob = -8, 8, 2

    ground = 118
    hipY = 72 + bob + (2 if hurt else 0)
    tx = 48 + (3 if hurling else (-3 if hurt else 0))

    if lf >= rf:
        leg(cv, tx + 10, hipY, ground, rf, back=True)
        leg(cv, tx - 10, hipY, ground, lf, back=False)
    else:
        leg(cv, tx - 10, hipY, ground, lf, back=True)
        leg(cv, tx + 10, hipY, ground, rf, back=False)

    torso(cv, tx, hipY)
    shY = hipY - 36
    if hurling:
        arm(cv, tx - 22, shY, tx - 32, shY + 16, tx - 30, shY + 34, back=True)
        arm(cv, tx + 22, shY, tx + 34, shY - 6, tx + 32, shY - 24, holding=True)
        px, py = tx + 34, shY - 34 if frame == 5 else shY - 30
        r = 10 if frame == 5 else 7
        for i, col in enumerate(PLASMA[::-1]):
            cv.paint(cv.mask().circle(px, py, r - i * 2.2), col)
        for dx, dy in ((-r, -3), (r - 1, -4), (0, -r - 3), (-3, -r - 1), (r - 3, 4)):
            cv.set(px + dx, py + dy, PLASMA[1])
    else:
        sw = -lf // 2
        arm(cv, tx - 22, shY, tx - 32 + sw, shY + 18, tx - 30 + sw * 2, shY + 40, back=(lf < rf))
        arm(cv, tx + 22, shY, tx + 32 - sw, shY + 18, tx + 30 - sw * 2, shY + 40, back=(rf < lf))

    head(cv, tx + (2 if hurling else 0), hipY - 54 + (3 if hurt else 0), roar=hurling or hurt, hurt=hurt)

    if hurt:
        for (bx, by, r) in ((tx - 6, hipY - 24, 4), (tx + 6, hipY - 16, 3), (tx - 12, hipY - 32, 2)):
            cv.paint(cv.mask().circle(bx, by, r), BLOOD)
        cv.paint(cv.mask().circle(tx - 4, hipY - 20, 2), BLOOD_DARK)
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
    # kneeling leg (left) and planted leg (right)
    m = cv.mask().tapered(38, hipY, 9, 22, hipY + 18, 6)
    cv.part(m, FUR, thickness=3, tint=BACK)
    m = cv.mask().tapered(22, hipY + 18, 6, 40, hipY + 28, 4)
    cv.part(m, FUR, thickness=2, tint=BACK)
    m = cv.mask().poly([(38, ground - 6), (50, ground - 6), (52, ground), (37, ground)])
    cv.part(m, HOOF, thickness=2, tint=BACK)
    leg(cv, 58, hipY - 2, ground, 4, back=False)
    torso(cv, 48, hipY)
    arm(cv, 26, hipY - 36, 14, hipY - 20, 12, hipY - 2, back=True)
    arm(cv, 70, hipY - 36, 84, hipY - 26, 90, hipY - 10)
    head(cv, 52, hipY - 46, roar=True, hurt=True)
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
    # legs to the left
    m = cv.mask().tapered(30, ground - 16, 8, 14, ground - 10, 5)
    cv.part(m, FUR, thickness=3, tint=BACK)
    m = cv.mask().poly([(4, ground - 14), (14, ground - 14), (14, ground - 7), (3, ground - 7)])
    cv.part(m, HOOF, thickness=2, tint=BACK)
    m = cv.mask().tapered(34, ground - 10, 8, 16, ground - 4, 5)
    cv.part(m, FUR, thickness=3)
    m = cv.mask().poly([(6, ground - 8), (16, ground - 8), (17, ground - 1), (5, ground - 1)])
    cv.part(m, HOOF, thickness=2)
    # torso
    m = cv.mask().oval(50, ground - 12, 22, 9)
    cv.part(m, SKIN, thickness=4, rim=2)
    for side in (-1, 1):
        m = cv.mask().oval(50 + side * 8, ground - 15, 6, 3)
        cv.part(m, SKIN, thickness=1, rim=1, shadow=1)
    m = cv.mask().poly([(30, ground - 16), (34, ground - 16), (36, ground - 6), (30, ground - 6)])
    cv.part(m, FUR, thickness=2, rim=0, shadow=1)
    # arm out to the right, claws up
    m = cv.mask().tapered(66, ground - 14, 5, 82, ground - 18, 4)
    cv.part(m, SKIN, thickness=2)
    cv.part(cv.mask().circle(84, ground - 19, 4), SKIN, thickness=2)
    for dx in (82, 86, 90):
        m = cv.mask().poly([(dx - 1, ground - 21), (dx + 1, ground - 21), (dx, ground - 27)])
        cv.part(m, CLAW, thickness=1, rim=0, contact=False)
    # head on the right
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
    out = [draw_standing(f) for f in range(7)]
    out.append(draw_recoil())
    out.append(draw_falling())
    out.append(draw_corpse())
    return out
