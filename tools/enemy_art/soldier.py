"""Soldier: a possessed marine — torn olive fatigues, dead-white eyes, rifle held across the chest.

Canvas 64x96. Frames: 0 idle, 1-3 walk, 4-5 firing, 6 hurt, 7 recoil, 8 falling, 9 corpse.
"""

from pixelart import Canvas, ramp, rgb

W, H = 64, 96

UNIFORM = ramp(rgb(84, 92, 58), deep=rgb(26, 30, 18), hi=rgb(150, 158, 112))
UNIFORM_DK = ramp(rgb(62, 68, 44), deep=rgb(20, 24, 14), hi=rgb(120, 128, 92))
SKIN = ramp(rgb(176, 168, 140), deep=rgb(58, 54, 46), hi=rgb(230, 224, 200))   # corpse-pale
HELMET = ramp(rgb(66, 74, 54), deep=rgb(18, 22, 14), hi=rgb(128, 138, 106))
BOOT = ramp(rgb(52, 40, 28), deep=rgb(14, 10, 6), hi=rgb(104, 84, 62))
GUN = ramp(rgb(58, 58, 64), deep=rgb(14, 14, 18), hi=rgb(130, 132, 140))
WOOD = ramp(rgb(96, 62, 34), deep=rgb(34, 20, 10), hi=rgb(168, 118, 74))
BELT = ramp(rgb(70, 52, 30), deep=rgb(24, 16, 8), hi=rgb(128, 100, 62))
BUCKLE = rgb(180, 160, 60)
EYE = rgb(232, 236, 220)
EYE_SOCKET = rgb(30, 26, 26)
MOUTH = rgb(50, 20, 20)
TOOTH = rgb(214, 204, 180)
BLOOD = rgb(150, 12, 10)
BLOOD_DARK = rgb(96, 6, 6)
OUTLINE = rgb(14, 16, 10)
FLASH = [rgb(255, 250, 210), rgb(255, 210, 90), rgb(240, 130, 30)]
BACK = ((10, 10, 20), 0.22)


def leg(cv, hx, hipY, ground, foot_dx, back):
    tint = BACK if back else None
    kneeX = hx + foot_dx // 2
    kneeY = hipY + 14 - abs(foot_dx) // 4
    footX = hx + foot_dx
    footY = ground - 4 - (2 if foot_dx > 0 else 0)
    m = cv.mask().tapered(hx, hipY, 6, kneeX, kneeY, 5)
    cv.part(m, UNIFORM, thickness=3, rim=1, tint=tint)
    m = cv.mask().tapered(kneeX, kneeY, 5, footX, footY - 4, 4)
    cv.part(m, UNIFORM, thickness=2, rim=1, tint=tint)
    # knee pad
    m = cv.mask().oval(kneeX, kneeY, 4, 3)
    cv.part(m, UNIFORM_DK, thickness=1, rim=1, shadow=1, tint=tint)
    # boot
    m = cv.mask()
    m.rect(footX - 4, footY - 6, 9, 7)
    m.poly([(footX - 4, footY), (footX + 7, footY), (footX + 7, footY + 4), (footX - 5, footY + 4)])
    cv.part(m, BOOT, thickness=2, rim=1, tint=tint)
    cv.set(footX - 2, footY - 3, BOOT[1])
    cv.set(footX + 2, footY - 3, BOOT[1])


def rifle(cv, x0, y0, x1, y1, muzzle_flash=False):
    """Rifle from the butt of the stock (x0,y0) to the muzzle (x1,y1)."""
    def at(t):
        return x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
    # wooden stock, thick at the shoulder
    m = cv.mask().tapered(*at(0.0), 4.5, *at(0.3), 3.5)
    cv.part(m, WOOD, thickness=2, rim=1)
    # receiver block
    m = cv.mask().tapered(*at(0.28), 4, *at(0.6), 3.5)
    cv.part(m, GUN, thickness=2, rim=1)
    # barrel with a front sight
    m = cv.mask().tapered(*at(0.58), 2.5, *at(1.0), 2)
    cv.part(m, GUN, thickness=1, rim=1)
    sx, sy = at(0.92)
    cv.set(int(sx), int(sy) - 3, GUN[3])
    cv.set(int(sx), int(sy) - 2, GUN[3])
    # curved magazine hanging below the receiver
    mx, my = at(0.45)
    m = cv.mask().poly([(mx - 3, my + 2), (mx + 4, my + 1), (mx + 6, my + 10), (mx - 1, my + 11)])
    cv.part(m, GUN, thickness=1, rim=1, shadow=1)
    # top rail highlight
    for t in (0.35, 0.45, 0.55):
        hx, hy = at(t)
        cv.set(int(hx), int(hy) - 3, GUN[4])
    if muzzle_flash:
        for i, col in enumerate(FLASH[::-1]):
            cv.paint(cv.mask().circle(x1 + 2, y1 - 1, 5 - i * 1.5), col)
        for dx, dy in ((6, -3), (7, 1), (4, -6), (5, 4)):
            cv.set(int(x1 + dx), int(y1 + dy), FLASH[1])


def head(cv, hx, hy, hurt=False, yell=False):
    m = cv.mask().rect(hx - 4, hy + 8, 9, 6)
    cv.part(m, SKIN, thickness=2, rim=0)
    m = cv.mask()
    m.oval(hx, hy + 1, 8, 9)
    m.poly([(hx - 7, hy + 4), (hx + 7, hy + 4), (hx + 5, hy + 11), (hx - 5, hy + 11)])
    cv.part(m, SKIN, thickness=3, rim=2)
    # sunken eyes
    for side in (-1, 1):
        ex = hx + side * 4
        cv.paint(cv.mask().oval(ex, hy, 2.8, 2.2), EYE_SOCKET)
        if not hurt:
            cv.set(ex, hy, EYE)
            cv.set(ex + side, hy, EYE)
    # gaunt cheeks and jaw
    cv.set(hx - 6, hy + 4, SKIN[1])
    cv.set(hx + 6, hy + 4, SKIN[1])
    cv.set(hx - 5, hy + 5, SKIN[1])
    cv.set(hx + 5, hy + 5, SKIN[1])
    cv.set(hx, hy + 3, SKIN[1])  # nose shadow
    cv.set(hx, hy + 4, SKIN[1])
    # mouth
    if yell or hurt:
        cv.paint(cv.mask().rect(hx - 4, hy + 6, 9, 4), MOUTH)
        for mx in (hx - 3, hx - 1, hx + 1, hx + 3):
            cv.set(mx, hy + 6, TOOTH)
            cv.set(mx, hy + 9, TOOTH)
    else:
        cv.paint(cv.mask().rect(hx - 4, hy + 7, 9, 1), MOUTH)
        for mx in (hx - 2, hx, hx + 2):
            cv.set(mx, hy + 7, TOOTH)
    # helmet: dome with a rim, chin strap
    m = cv.mask()
    m.oval(hx, hy - 3, 10, 8)
    m.rect(hx - 10, hy - 3, 21, 3)
    cut = cv.mask().rect(hx - 11, hy, 23, 14)
    m.subtract(cut)
    cv.part(m, HELMET, thickness=3, rim=2, shadow=2)
    cv.paint(cv.mask().rect(hx - 10, hy - 1, 21, 1), HELMET[0])
    for side in (-1, 1):
        cv.set(hx + side * 8, hy + 2, BELT[1])
        cv.set(hx + side * 8, hy + 4, BELT[1])
        cv.set(hx + side * 7, hy + 6, BELT[1])
    # dents and a scrape
    cv.set(hx + 3, hy - 7, HELMET[1])
    cv.set(hx + 4, hy - 7, HELMET[1])
    cv.set(hx - 5, hy - 5, HELMET[0])


def torso(cv, tx, hipY):
    m = cv.mask()
    m.poly([(tx - 15, hipY - 26), (tx + 15, hipY - 26), (tx + 12, hipY - 2), (tx - 12, hipY - 2)])
    cv.part(m, UNIFORM, thickness=3, rim=2)
    # chest rig straps and pouches
    for side in (-1, 1):
        m = cv.mask().poly([(tx + side * 11, hipY - 26), (tx + side * 14, hipY - 26),
                            (tx + side * 3, hipY - 4), (tx + side * 1, hipY - 4)])
        cv.part(m, BELT, thickness=1, rim=0, shadow=1)
    for i in range(2):
        px = tx - 9 + i * 12
        m = cv.mask().rect(px, hipY - 14, 6, 6)
        cv.part(m, UNIFORM_DK, thickness=1, rim=1, shadow=1)
        cv.set(px + 2, hipY - 12, BUCKLE)
    # belt
    m = cv.mask().rect(tx - 12, hipY - 3, 25, 3)
    cv.part(m, BELT, thickness=1, rim=1, shadow=1)
    cv.paint(cv.mask().rect(tx - 1, hipY - 3, 3, 3), BUCKLE)
    # torn cloth / grime
    for (dx, dy) in ((-7, -20), (6, -8), (-3, -6), (9, -18)):
        cv.set(tx + dx, hipY + dy, UNIFORM[0])
        cv.set(tx + dx + 1, hipY + dy + 1, UNIFORM[0])
    # collar
    m = cv.mask().poly([(tx - 6, hipY - 28), (tx + 6, hipY - 28), (tx + 4, hipY - 24), (tx - 4, hipY - 24)])
    cv.part(m, UNIFORM_DK, thickness=1, rim=0)


def arm(cv, shx, shy, elx, ely, hx, hy, back=False):
    tint = BACK if back else None
    m = cv.mask().tapered(shx, shy, 5, elx, ely, 4)
    cv.part(m, UNIFORM, thickness=2, rim=1, tint=tint)
    m = cv.mask().tapered(elx, ely, 4, hx, hy, 3)
    cv.part(m, UNIFORM, thickness=2, rim=1, tint=tint)
    m = cv.mask().circle(hx, hy, 3)
    cv.part(m, SKIN, thickness=2, rim=1, tint=tint)


def draw_standing(frame):
    cv = Canvas(W, H)
    firing = frame in (4, 5)
    hurt = frame == 6
    phase = {1: 0, 2: 1, 3: 2}.get(frame, -1)
    bob, lf, rf = 0, 0, 0
    if phase == 0:
        lf, rf, bob = 6, -6, 1
    elif phase == 1:
        lf, rf, bob = 0, 0, -1
    elif phase == 2:
        lf, rf, bob = -6, 6, 1

    ground = 94
    hipY = 58 + bob + (1 if hurt else 0)
    tx = 32 + (-2 if hurt else 0)

    if lf >= rf:
        leg(cv, tx + 6, hipY, ground, rf, back=True)
        leg(cv, tx - 6, hipY, ground, lf, back=False)
    else:
        leg(cv, tx - 6, hipY, ground, lf, back=True)
        leg(cv, tx + 6, hipY, ground, rf, back=False)

    torso(cv, tx, hipY)
    shY = hipY - 22

    if firing:
        # rifle shouldered, pointing at the viewer's right-front
        arm(cv, tx - 14, shY, tx - 12, shY + 12, tx - 2, shY + 12, back=True)
        arm(cv, tx + 14, shY, tx + 12, shY + 12, tx + 8, shY + 6)
        rifle(cv, tx - 6, shY + 12, tx + 22, shY - 2, muzzle_flash=(frame == 4))
        cv.part(cv.mask().circle(tx - 2, shY + 12, 3), SKIN, thickness=2, rim=1)
        cv.part(cv.mask().circle(tx + 8, shY + 6, 3), SKIN, thickness=2, rim=1)
    else:
        # rifle held across the chest, arms swing slightly while walking
        sw = -lf // 3
        arm(cv, tx - 14, shY, tx - 14 + sw, shY + 12, tx - 6, shY + 16, back=True)
        rifle(cv, tx - 12, shY + 20, tx + 16, shY + 4)
        arm(cv, tx + 14, shY, tx + 14 - sw, shY + 12, tx + 6, shY + 9)
        cv.part(cv.mask().circle(tx - 6, shY + 16, 3), SKIN, thickness=2, rim=1)
        cv.part(cv.mask().circle(tx + 6, shY + 9, 3), SKIN, thickness=2, rim=1)

    head(cv, tx, hipY - 38 + (2 if hurt else 0), hurt=hurt, yell=firing)

    if hurt:
        for (bx, by, r) in ((tx - 5, hipY - 16, 3), (tx + 4, hipY - 10, 2)):
            cv.paint(cv.mask().circle(bx, by, r), BLOOD)
        cv.set(tx - 8, hipY - 20, BLOOD_DARK)
    cv.outline(OUTLINE)
    return cv


def draw_recoil():
    cv = draw_standing(6)
    out = Canvas(W, H)
    for y in range(H):
        shift = -(H - y) // 9
        for x in range(W):
            c = cv.get(x, y)
            if c is not None:
                out.set(x + shift, y, c)
    for (bx, by, r) in ((28, 44, 4), (23, 40, 2), (33, 48, 2)):
        out.paint(out.mask().circle(bx, by, r), BLOOD)
    out.paint(out.mask().circle(27, 46, 2), BLOOD_DARK)
    out.outline(OUTLINE)
    return out


def draw_falling():
    """Frame 8: falling backwards, rifle flying from the hands."""
    cv = Canvas(W, H)
    ground = 94
    hipY = 76
    # legs kicked forward
    m = cv.mask().tapered(30, hipY, 6, 18, hipY + 6, 5)
    cv.part(m, UNIFORM, thickness=3, tint=BACK)
    m = cv.mask().tapered(18, hipY + 6, 5, 8, hipY + 12, 4)
    cv.part(m, UNIFORM, thickness=2, tint=BACK)
    m = cv.mask().rect(2, hipY + 9, 9, 7)
    cv.part(m, BOOT, thickness=2, tint=BACK)
    m = cv.mask().tapered(36, hipY + 2, 6, 24, hipY + 10, 5)
    cv.part(m, UNIFORM, thickness=3)
    m = cv.mask().tapered(24, hipY + 10, 5, 14, hipY + 14, 4)
    cv.part(m, UNIFORM, thickness=2)
    m = cv.mask().rect(7, hipY + 12, 9, 6)
    cv.part(m, BOOT, thickness=2)
    # torso leaning back to the right
    m = cv.mask().tapered(34, hipY - 2, 11, 50, hipY - 22, 12)
    cv.part(m, UNIFORM, thickness=3, rim=2)
    m = cv.mask().poly([(40, hipY - 24), (44, hipY - 26), (38, hipY - 2), (35, hipY - 3)])
    cv.part(m, BELT, thickness=1, rim=0, shadow=1)
    # arms thrown up
    arm(cv, 38, hipY - 20, 30, hipY - 30, 24, hipY - 40, back=True)
    arm(cv, 54, hipY - 24, 60, hipY - 34, 58, hipY - 44)
    # head back
    head(cv, 56, hipY - 34, hurt=True)
    # rifle tumbling away
    rifle(cv, 6, hipY - 40, 26, hipY - 52)
    cv.paint(cv.mask().circle(44, hipY - 12, 4), BLOOD)
    cv.paint(cv.mask().circle(41, hipY - 8, 2), BLOOD_DARK)
    cv.outline(OUTLINE)
    return cv


def draw_corpse():
    """Frame 9: on his back, helmet rolled off, rifle beside him."""
    cv = Canvas(W, H)
    ground = 92
    cv.paint(cv.mask().oval(34, ground, 26, 3), BLOOD_DARK)
    cv.paint(cv.mask().oval(36, ground - 1, 16, 2), BLOOD)
    # legs to the left
    m = cv.mask().tapered(26, ground - 8, 5, 12, ground - 6, 4)
    cv.part(m, UNIFORM, thickness=2, tint=BACK)
    m = cv.mask().rect(4, ground - 10, 9, 6)
    cv.part(m, BOOT, thickness=2, tint=BACK)
    m = cv.mask().tapered(28, ground - 6, 5, 14, ground - 3, 4)
    cv.part(m, UNIFORM, thickness=2)
    m = cv.mask().rect(6, ground - 6, 9, 5)
    cv.part(m, BOOT, thickness=2)
    # torso
    m = cv.mask().oval(36, ground - 8, 14, 7)
    cv.part(m, UNIFORM, thickness=3, rim=1)
    m = cv.mask().poly([(26, ground - 12), (28, ground - 12), (46, ground - 5), (44, ground - 4)])
    cv.part(m, BELT, thickness=1, rim=0, shadow=1)
    cv.paint(cv.mask().rect(29, ground - 10, 3, 3), UNIFORM_DK[2])
    # arm flung out
    m = cv.mask().tapered(44, ground - 10, 3, 56, ground - 14, 2.5)
    cv.part(m, UNIFORM, thickness=2)
    cv.part(cv.mask().circle(58, ground - 15, 2.5), SKIN, thickness=1)
    # head on the right, no helmet
    hx, hy = 52, ground - 8
    m = cv.mask().oval(hx, hy, 7, 6)
    cv.part(m, SKIN, thickness=3, rim=1)
    cv.paint(cv.mask().rect(hx - 4, hy - 1, 3, 1), EYE_SOCKET)
    cv.paint(cv.mask().rect(hx + 1, hy - 1, 3, 1), EYE_SOCKET)
    cv.paint(cv.mask().rect(hx - 2, hy + 2, 5, 1), MOUTH)
    # helmet rolled away, upside down
    m = cv.mask().oval(14, ground - 18, 8, 5)
    m.subtract(cv.mask().rect(0, ground - 24, 30, 6))
    cv.part(m, HELMET, thickness=2, rim=1)
    # rifle on the floor behind
    rifle(cv, 20, ground - 22, 46, ground - 24)
    cv.paint(cv.mask().circle(38, ground - 10, 3), BLOOD)
    cv.paint(cv.mask().circle(40, ground - 8, 2), BLOOD_DARK)
    cv.outline(OUTLINE)
    return cv


def frames():
    out = [draw_standing(f) for f in range(7)]
    out.append(draw_recoil())
    out.append(draw_falling())
    out.append(draw_corpse())
    return out
