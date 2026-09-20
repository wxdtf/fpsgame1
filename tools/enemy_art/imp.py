"""Imp: a hunched, horned, long-armed hellspawn with glowing yellow eyes that throws fireballs.

Canvas 64x96, feet on the bottom row. Frames: 0 idle, 1-3 walk, 4-5 attack,
6 hurt, 7 recoil, 8 falling, 9 corpse.
"""

from pixelart import Canvas, ramp, rgb

W, H = 64, 96

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
BACK = ((24, 0, 12), 0.22)   # tint for limbs on the far side


def claws(cv, points, up=False, length=5):
    for tx, ty in points:
        if up:
            m = cv.mask().poly([(tx - 1, ty), (tx + 1, ty), (tx, ty - length)])
        else:
            m = cv.mask().poly([(tx - 1, ty), (tx + 1, ty), (tx, ty + length)])
        cv.part(m, CLAW, thickness=1, rim=0, contact=False)


def leg(cv, hx, hipY, ground, foot_dx, back):
    """Digitigrade leg: thigh forward-down, hock bent back, long foot with claws."""
    tint = BACK if back else None
    kneeX = hx + 1 + foot_dx // 3
    kneeY = hipY + 11 - abs(foot_dx) // 4
    hockX = hx - 4 + foot_dx // 2
    hockY = hipY + 20 - abs(foot_dx) // 5
    toeX = hx + 2 + foot_dx
    toeY = ground - 1 - (2 if foot_dx > 0 else 0)
    m = cv.mask().tapered(hx, hipY + 1, 6, kneeX, kneeY, 4)
    cv.part(m, SKIN, thickness=3, rim=1, tint=tint)
    m = cv.mask().tapered(kneeX, kneeY, 4, hockX, hockY, 3)
    cv.part(m, SKIN, thickness=2, rim=1, tint=tint)
    # foot from the hock forward to the toes
    m = cv.mask().tapered(hockX, hockY, 3, toeX, toeY - 2, 3.5)
    cv.part(m, SKIN, thickness=2, rim=1, tint=tint)
    m = cv.mask().oval(toeX + 1, toeY - 1, 5, 2.5)
    cv.part(m, SKIN, thickness=2, rim=0, tint=tint)
    claws(cv, [(toeX - 3, toeY), (toeX + 1, toeY + 1), (toeX + 5, toeY)], length=4)
    # heel spur
    claws(cv, [(hockX - 2, hockY + 1)], length=3)


def arm(cv, shx, shy, elx, ely, hx, hy, back=False, fingers_up=False, spikes=True):
    tint = BACK if back else None
    m = cv.mask().tapered(shx, shy, 5, elx, ely, 3.5)
    cv.part(m, SKIN, thickness=2, rim=1, tint=tint)
    m = cv.mask().tapered(elx, ely, 3.5, hx, hy, 3)
    cv.part(m, SKIN, thickness=2, rim=1, tint=tint)
    if spikes:
        # two small spikes on the forearm, pointing away from the hand
        for k in (0.35, 0.65):
            px, py = elx + (hx - elx) * k, ely + (hy - ely) * k
            side = -1 if hx < 32 else 1
            m = cv.mask().poly([(px + side * 2, py - 1), (px + side * 2, py + 1), (px + side * 6, py - 2)])
            cv.part(m, SPIKE, thickness=1, rim=0, contact=False)
    m = cv.mask().circle(hx, hy, 3.5)
    cv.part(m, SKIN, thickness=2, rim=1, tint=tint)
    if fingers_up:
        claws(cv, [(hx - 3, hy - 2), (hx, hy - 3), (hx + 3, hy - 2)], up=True, length=6)
    else:
        claws(cv, [(hx - 3, hy + 2), (hx, hy + 3), (hx + 3, hy + 2)], length=6)


def head(cv, hx, hy, open_mouth=False, hurt=False):
    # neck
    m = cv.mask().rect(hx - 4, hy + 6, 8, 7)
    cv.part(m, SKIN, thickness=2, rim=0)
    # skull + jaw
    m = cv.mask()
    m.oval(hx, hy, 10, 9)
    m.poly([(hx - 9, hy + 2), (hx + 9, hy + 2), (hx + 6, hy + 11), (hx - 6, hy + 11)])
    cv.part(m, SKIN, thickness=3, rim=2)
    # heavy brow ridge casting shadow on the eyes
    m = cv.mask().poly([(hx - 10, hy - 4), (hx + 10, hy - 4), (hx + 9, hy - 1), (hx - 9, hy - 1)])
    cv.part(m, SKIN, thickness=1, rim=1, shadow=2)
    # eye sockets + glow
    for side in (-1, 1):
        ex = hx + side * 4
        cv.paint(cv.mask().oval(ex, hy + 1, 3, 2), SKIN[0])
        cv.paint(cv.mask().oval(ex, hy + 1, 2, 1.5), EYE_RIM)
        cv.paint(cv.mask().oval(ex, hy + 1, 1.5, 1), EYE_GLOW)
        cv.set(ex + side, hy + 1, EYE_CORE)
        if hurt:
            cv.set(ex, hy, SKIN[0])
            cv.set(ex + side, hy, SKIN[0])
    # cheekbones
    cv.set(hx - 7, hy + 4, SKIN[3])
    cv.set(hx + 7, hy + 4, SKIN[3])
    # nostrils
    cv.set(hx - 1, hy + 4, SKIN[0])
    cv.set(hx + 1, hy + 4, SKIN[0])
    # mouth
    mh = 4 if open_mouth else 1
    cv.paint(cv.mask().rect(hx - 5, hy + 6, 11, mh + 1), MOUTH)
    for mx in range(hx - 4, hx + 5, 2):
        tall = 3 if mx in (hx - 4, hx + 4) else 2
        col = TOOTH if tall == 3 else TOOTH_DARK
        cv.paint(cv.mask().poly([(mx - 1, hy + 6), (mx + 1, hy + 6), (mx, hy + 6 + tall)]), col)
    if open_mouth:
        for mx in (hx - 3, hx, hx + 3):
            cv.paint(cv.mask().poly([(mx - 1, hy + 7 + mh), (mx + 1, hy + 7 + mh), (mx, hy + 5 + mh)]), TOOTH_DARK)
    # horns: sweep up and out with ridges
    for side in (-1, 1):
        bx = hx + side * 6
        m = cv.mask().poly([(bx - 3, hy - 4), (bx + 3, hy - 4), (bx + side * 9, hy - 14),
                            (bx + side * 13, hy - 25), (bx + side * 11, hy - 25), (bx + side * 6, hy - 14)])
        cv.part(m, HORN, thickness=2, rim=1, shadow=1)
        for k in range(4):
            cv.set(bx + side * (4 + k * 2), hy - 7 - k * 3, HORN[1])
            cv.set(bx + side * (5 + k * 2), hy - 7 - k * 3, HORN[1])


def torso(cv, tx, hipY, hunch=0):
    m = cv.mask()
    m.oval(tx, hipY - 12, 13, 14)                      # ribcage
    m.oval(tx, hipY + 1, 8, 6)                         # pelvis
    m.poly([(tx - 17, hipY - 24 + hunch), (tx + 17, hipY - 24 + hunch),
            (tx + 13, hipY - 6), (tx - 13, hipY - 6)])  # shoulders
    cv.part(m, SKIN, thickness=3, rim=2)
    # belly plate
    m = cv.mask().oval(tx, hipY - 5, 6, 8)
    cv.part(m, BELLY, thickness=2, rim=1, shadow=1)
    for y in range(hipY - 10, hipY + 1, 4):
        cv.set(tx, y, BELLY[1])
        cv.set(tx - 3, y + 1, BELLY[1])
        cv.set(tx + 3, y + 1, BELLY[1])
    # pectorals
    for side in (-1, 1):
        m = cv.mask().oval(tx + side * 6, hipY - 17, 6, 4)
        cv.part(m, SKIN, thickness=2, rim=1, shadow=1)
    for y in range(hipY - 21, hipY - 11):
        cv.set(tx, y, SKIN[1])
    # ribs
    for i in range(3):
        y = hipY - 12 + i * 3
        for side in (-1, 1):
            cv.set(tx + side * 11, y, SKIN[1])
            cv.set(tx + side * 10, y + 1, SKIN[1])
    # shoulder spikes (three per side, growing outward)
    for side in (-1, 1):
        sx = tx + side * 15
        for k in range(3):
            base_y = hipY - 23 + hunch + k * 4
            m = cv.mask().poly([(sx - 2, base_y + 3), (sx + 2, base_y + 3), (sx + side * 7, base_y - 3)])
            cv.part(m, SPIKE, thickness=1, rim=1, shadow=1)


def draw_standing(frame):
    """Frames 0-6."""
    cv = Canvas(W, H)
    attacking = frame in (4, 5)
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
    hipY = 60 + bob + (1 if hurt else 0)
    tx = 32 + (2 if attacking else (-2 if hurt else 0))
    hipL, hipR = tx - 7, tx + 7

    if lf >= rf:
        leg(cv, hipR, hipY, ground, rf, back=True)
        leg(cv, hipL, hipY, ground, lf, back=False)
    else:
        leg(cv, hipL, hipY, ground, lf, back=True)
        leg(cv, hipR, hipY, ground, rf, back=False)

    torso(cv, tx, hipY, hunch=1 if hurt else 0)

    shY = hipY - 20
    if attacking:
        arm(cv, tx - 14, shY, tx - 21, shY + 13, tx - 18, shY + 27, back=True)
        arm(cv, tx + 14, shY, tx + 22, shY - 3, tx + 21, shY - 16, fingers_up=True)
        fx, fy = tx + 21, shY - 27 if frame == 5 else shY - 23
        r = 7 if frame == 5 else 5
        for i, col in enumerate(FIRE[::-1]):
            cv.paint(cv.mask().circle(fx, fy, r - i * 1.6), col)
        for dx, dy in ((-r, -2), (r - 1, -3), (0, -r - 2), (-2, -r - 1)):
            cv.set(fx + dx, fy + dy, FIRE[1])
    else:
        swingL, swingR = -lf // 2, -rf // 2
        arm(cv, tx - 14, shY, tx - 20 + swingL, shY + 14, tx - 18 + swingL * 2, shY + 30, back=(lf < rf))
        arm(cv, tx + 14, shY, tx + 20 + swingR, shY + 14, tx + 18 + swingR * 2, shY + 30, back=(rf < lf))

    hx = tx + (2 if attacking else (-2 if hurt else 0))
    head(cv, hx, hipY - 31 + (2 if hurt else 0), open_mouth=attacking or hurt, hurt=hurt)

    if hurt:
        for (bx, by, r) in ((tx - 4, hipY - 14, 3), (tx + 3, hipY - 9, 2), (tx - 8, hipY - 20, 1)):
            cv.paint(cv.mask().circle(bx, by, r), BLOOD)
        cv.set(tx - 6, hipY - 24, BLOOD_DARK)
        cv.set(tx + 5, hipY - 15, BLOOD_DARK)

    cv.outline(OUTLINE)
    return cv


def draw_recoil():
    """Frame 7: knocked back, chest wound, arms flung out."""
    cv = draw_standing(6)
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
    out.outline(OUTLINE)
    return out


def draw_falling():
    """Frame 8: knees buckled, torso pitching forward-right, one arm reaching for the floor."""
    cv = Canvas(W, H)
    ground = 94
    hipY = 74
    # legs folded under
    m = cv.mask().tapered(22, hipY, 6, 14, hipY + 10, 4)
    cv.part(m, SKIN, thickness=3, tint=BACK)
    m = cv.mask().tapered(14, hipY + 10, 4, 24, hipY + 17, 3)
    cv.part(m, SKIN, thickness=2, tint=BACK)
    m = cv.mask().tapered(34, hipY + 2, 6, 40, hipY + 12, 4)
    cv.part(m, SKIN, thickness=3)
    m = cv.mask().tapered(40, hipY + 12, 4, 30, hipY + 18, 3)
    cv.part(m, SKIN, thickness=2)
    claws(cv, [(24, ground - 2), (28, ground - 1), (32, ground - 2)], length=3)
    # torso tilted ~40 degrees to the right
    m = cv.mask()
    m.oval(30, hipY - 6, 9, 7)
    m.tapered(28, hipY - 4, 9, 44, hipY - 22, 11)
    cv.part(m, SKIN, thickness=3, rim=2)
    m = cv.mask().tapered(30, hipY - 6, 4, 38, hipY - 14, 5)
    cv.part(m, BELLY, thickness=2, rim=0, shadow=1)
    for k in range(3):
        m = cv.mask().poly([(50 + k * 2, hipY - 30 + k * 3), (52 + k * 2, hipY - 28 + k * 3), (57 + k * 3, hipY - 34 + k * 3)])
        cv.part(m, SPIKE, thickness=1, rim=0, shadow=1)
    # arms: one braced toward the floor, one trailing
    arm(cv, 40, hipY - 26, 46, hipY - 12, 50, hipY + 2, spikes=False)
    arm(cv, 30, hipY - 20, 18, hipY - 16, 10, hipY - 4, back=True, spikes=False)
    # head hanging forward-right
    head(cv, 50, hipY - 36, open_mouth=True)
    # wound
    cv.paint(cv.mask().circle(38, hipY - 16, 4), BLOOD)
    cv.paint(cv.mask().circle(35, hipY - 12, 2), BLOOD_DARK)
    cv.set(41, hipY - 8, BLOOD)
    cv.set(42, hipY - 4, BLOOD_DARK)
    cv.outline(OUTLINE)
    return cv


def draw_corpse():
    """Frame 9: face down on the floor, horns and spikes still recognisable."""
    cv = Canvas(W, H)
    ground = 92
    cv.paint(cv.mask().oval(32, ground, 26, 3), BLOOD_DARK)
    cv.paint(cv.mask().oval(30, ground - 1, 18, 2), BLOOD)
    # legs (left), folded
    m = cv.mask().tapered(16, ground - 10, 5, 6, ground - 4, 4)
    cv.part(m, SKIN, thickness=2, tint=BACK)
    m = cv.mask().tapered(22, ground - 8, 5, 12, ground - 3, 4)
    cv.part(m, SKIN, thickness=2)
    claws(cv, [(3, ground - 2), (7, ground - 1)], length=3)
    # torso lying, back spikes up
    m = cv.mask().oval(33, ground - 9, 16, 8)
    cv.part(m, SKIN, thickness=3, rim=1)
    for k in range(3):
        bx = 24 + k * 5
        m = cv.mask().poly([(bx - 2, ground - 15), (bx + 2, ground - 15), (bx, ground - 21)])
        cv.part(m, SPIKE, thickness=1, rim=1, shadow=1)
    m = cv.mask().oval(30, ground - 5, 8, 4)
    cv.part(m, BELLY, thickness=2, rim=0, shadow=1)
    # arm draped forward
    m = cv.mask().tapered(40, ground - 7, 3, 48, ground - 3, 2.5)
    cv.part(m, SKIN, thickness=2)
    claws(cv, [(48, ground - 3), (51, ground - 4), (54, ground - 3)], length=3)
    # head on the right, cheek on the floor
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


def frames():
    out = [draw_standing(f) for f in range(7)]
    out.append(draw_recoil())
    out.append(draw_falling())
    out.append(draw_corpse())
    return out
