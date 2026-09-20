"""Soldier: a possessed marine — torn olive fatigues, dead-white eyes, rifle held across the chest.

Canvas 64x96, turntable rig. Frames per view: 0 idle, 1-3 walk, 4-5 firing, 6 hurt;
front only: 7 recoil, 8 falling, 9 corpse.
"""

from pixelart import Canvas, Rig, ramp, rgb, turntable_frames

W, H = 64, 96
CX = 32

UNIFORM = ramp(rgb(84, 92, 58), deep=rgb(26, 30, 18), hi=rgb(150, 158, 112))
UNIFORM_DK = ramp(rgb(62, 68, 44), deep=rgb(20, 24, 14), hi=rgb(120, 128, 92))
SKIN = ramp(rgb(176, 168, 140), deep=rgb(58, 54, 46), hi=rgb(230, 224, 200))   # corpse-pale
HELMET = ramp(rgb(66, 74, 54), deep=rgb(18, 22, 14), hi=rgb(128, 138, 106))
BOOT = ramp(rgb(52, 40, 28), deep=rgb(14, 10, 6), hi=rgb(104, 84, 62))
GUN = ramp(rgb(58, 58, 64), deep=rgb(14, 14, 18), hi=rgb(130, 132, 140))
WOOD = ramp(rgb(96, 62, 34), deep=rgb(34, 20, 10), hi=rgb(168, 118, 74))
BELT = ramp(rgb(70, 52, 30), deep=rgb(24, 16, 8), hi=rgb(128, 100, 62))
PACK = ramp(rgb(74, 66, 44), deep=rgb(24, 20, 12), hi=rgb(130, 120, 84))
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


def rifle2d(cv, x0, y0, x1, y1, muzzle_flash=False, tint=None):
    """Rifle from the butt of the stock (x0,y0) to the muzzle (x1,y1), in screen space."""
    def at(t):
        return x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
    length = max(abs(x1 - x0), abs(y1 - y0))
    m = cv.mask().tapered(*at(0.0), 4.5, *at(0.3), 3.5)
    cv.part(m, WOOD, thickness=2, rim=1, tint=tint)
    m = cv.mask().tapered(*at(0.28), 4, *at(0.6), 3.5)
    cv.part(m, GUN, thickness=2, rim=1, tint=tint)
    m = cv.mask().tapered(*at(0.58), 2.5, *at(1.0), 2)
    cv.part(m, GUN, thickness=1, rim=1, tint=tint)
    if length > 14:
        sx, sy = at(0.92)
        cv.set(int(sx), int(sy) - 3, GUN[3])
        cv.set(int(sx), int(sy) - 2, GUN[3])
        mx, my = at(0.45)
        m = cv.mask().poly([(mx - 3, my + 2), (mx + 4, my + 1), (mx + 6, my + 10), (mx - 1, my + 11)])
        cv.part(m, GUN, thickness=1, rim=1, shadow=1, tint=tint)
        for t in (0.35, 0.45, 0.55):
            hx, hy = at(t)
            cv.set(int(hx), int(hy) - 3, GUN[4])
    if muzzle_flash:
        for i, col in enumerate(FLASH[::-1]):
            cv.paint(cv.mask().circle(x1 + 2, y1 - 1, 5 - i * 1.5), col)
        for dx, dy in ((6, -3), (7, 1), (4, -6), (5, 4)):
            cv.set(int(x1 + dx), int(y1 + dy), FLASH[1])


def leg(rig, side, hipY, ground, step):
    hx = side * 6
    sway = side * step * 0.3
    hip = (hx, hipY, 0)
    knee = (hx + sway * 0.5, hipY + 14 - abs(step) // 4, 1 + step * 0.5)
    ankle = (hx + sway, ground - 8 - (2 if step > 0 else 0), step)
    rig.limb(hip, 6, knee, 5, UNIFORM, thickness=3)
    rig.limb(knee, 5, ankle, 4, UNIFORM)
    rig.blob(knee, 4, 3, 4, UNIFORM_DK, thickness=1, rim=1, shadow=1)
    # boot: short and wide from the front, long from the side
    rig.blob((ankle[0], ankle[1] + 5, ankle[2] + 3), 4.5, 3.5, 6.5, BOOT, thickness=2, rim=1)
    rig.blob((ankle[0], ankle[1] + 1, ankle[2]), 4, 3, 4, BOOT, thickness=2, rim=1, shadow=1)


def arm(rig, side, shoulder, elbow, hand):
    rig.limb(shoulder, 5, elbow, 4, UNIFORM)
    rig.limb(elbow, 4, hand, 3, UNIFORM)
    rig.blob(hand, 3, 3, 3, SKIN, thickness=2, rim=1)


def torso(rig, hipY):
    def shoulders(m, r):
        sx0, _ = r.p((0, 0, 0))
        m.poly([(sx0 - r.width(15, 7), hipY - 26), (sx0 + r.width(15, 7), hipY - 26),
                (sx0 + r.width(12, 7), hipY - 2), (sx0 - r.width(12, 7), hipY - 2)])

    def details(r):
        cv = r.cv
        # belt all the way round
        bx, by = r.p((0, hipY - 2, 0))
        m = cv.mask().rect(bx - r.width(12, 7), hipY - 3, 2 * r.width(12, 7) + 1, 3)
        cv.part(m, BELT, thickness=1, rim=1, shadow=1)
        if r.facing_away:
            # back: pack straps
            for side in (-1, 1):
                ax, _ = r.p((side * 8, 0, -6))
                for y in range(hipY - 26, hipY - 6):
                    cv.set(int(round(ax)), y, BELT[1])
            return
        kx, _ = r.p((0, 0, 7))
        cv.paint(cv.mask().rect(int(round(kx)) - 1, hipY - 3, 3, 3), BUCKLE)
        # chest rig straps + pouches on the front surface
        for side in (-1, 1):
            tx, _ = r.p((side * 12, 0, 6))
            bx2, _ = r.p((side * 2, 0, 7))
            m = cv.mask().poly([(tx, hipY - 26), (tx + side * 2 * r.c, hipY - 26), (bx2 + side * 2 * r.c, hipY - 4), (bx2, hipY - 4)])
            cv.part(m, BELT, thickness=1, rim=0, shadow=1)
        for side in (-1, 1):
            px, _ = r.p((side * 6, 0, 8))
            w = max(1, int(round(r.width(3, 1))))
            m = cv.mask().rect(int(round(px)) - w, hipY - 14, 2 * w + 1, 6)
            cv.part(m, UNIFORM_DK, thickness=1, rim=1, shadow=1)
            cv.set(int(round(px)), hipY - 12, BUCKLE)
        for (dx, dy) in ((-7, -20), (6, -8), (-3, -6), (9, -18)):
            gx, _ = r.p((dx, 0, 7))
            cv.set(int(round(gx)), hipY + dy, UNIFORM[0])
        # collar
        cx0, _ = r.p((0, 0, 6))
        m = cv.mask().poly([(cx0 - r.width(6, 2), hipY - 28), (cx0 + r.width(6, 2), hipY - 28),
                            (cx0 + r.width(4, 2), hipY - 24), (cx0 - r.width(4, 2), hipY - 24)])
        cv.part(m, UNIFORM_DK, thickness=1, rim=0)

    rig.blob((0, hipY - 18, -7), 9, 8, 4, PACK, thickness=2, rim=1)   # small pack on the back
    rig.blob((0, hipY - 14, 0), 14, 13, 8, UNIFORM, thickness=3, rim=2, extra=shoulders, after=details)


def head(rig, hy, hurt=False, yell=False):
    rig.limb((0, hy + 8, 0), 4, (0, hy + 13, 0), 4, SKIN, thickness=2, rim=0)

    def jaw(m, r):
        m.poly([r.p((-7, hy + 4, 2)), r.p((7, hy + 4, 2)), r.p((5, hy + 11, 3)), r.p((-5, hy + 11, 3))])

    def face(r):
        cv = r.cv
        if r.facing_away:
            return
        for side in (-1, 1):
            ex, ey = r.p((side * 4, hy, 8))
            ex, ey = int(round(ex)), int(ey)
            cv.paint(cv.mask().oval(ex, ey, max(1.5, r.width(2.8, 1)), 2.2), EYE_SOCKET)
            if not hurt:
                cv.set(ex, ey, EYE)
                cv.set(ex + side * int(round(r.c)), ey, EYE)
        for side in (-1, 1):
            kx, _ = r.p((side * 6, 0, 5))
            cv.set(int(round(kx)), hy + 4, SKIN[1])
            kx, _ = r.p((side * 5, 0, 6))
            cv.set(int(round(kx)), hy + 5, SKIN[1])
        nx, _ = r.p((0, 0, 9))
        cv.set(int(round(nx)), hy + 3, SKIN[1])
        cv.set(int(round(nx)), hy + 4, SKIN[1])
        mx, _ = r.p((0, 0, 8))
        mx = int(round(mx))
        mw = max(1, int(round(r.width(4, 1))))
        if yell or hurt:
            cv.paint(cv.mask().rect(mx - mw, hy + 6, 2 * mw + 1, 4), MOUTH)
            for tx in range(mx - mw + 1, mx + mw, 2):
                cv.set(tx, hy + 6, TOOTH)
                cv.set(tx, hy + 9, TOOTH)
        else:
            cv.paint(cv.mask().rect(mx - mw, hy + 7, 2 * mw + 1, 1), MOUTH)
            for tx in range(mx - mw + 2, mx + mw, 2):
                cv.set(tx, hy + 7, TOOTH)

    rig.blob((0, hy + 1, 0), 8, 9, 8, SKIN, thickness=3, rim=2, extra=jaw, after=face)

    def helmet(r):
        cv = r.cv
        hx, _ = r.p((0, 0, 0))
        w = r.width(10, 10)
        m = cv.mask()
        m.oval(hx, hy - 3, w, 8)
        m.rect(hx - w, hy - 3, 2 * w + 1, 3)
        m.subtract(cv.mask().rect(hx - w - 1, hy, 2 * w + 3, 14))
        cv.part(m, HELMET, thickness=3, rim=2, shadow=2)
        cv.paint(cv.mask().rect(hx - w, hy - 1, 2 * w + 1, 1), HELMET[0])
        if not r.facing_away:
            for side in (-1, 1):
                sx, _ = r.p((side * 8, 0, 3))
                cv.set(int(round(sx)), hy + 2, BELT[1])
                cv.set(int(round(sx)), hy + 4, BELT[1])
                sx, _ = r.p((side * 7, 0, 4))
                cv.set(int(round(sx)), hy + 6, BELT[1])
        dx, _ = r.p((3, 0, 4))
        cv.set(int(round(dx)), hy - 7, HELMET[1])
        cv.set(int(round(dx)) + 1, hy - 7, HELMET[1])
    rig.custom(rig.depth(0, 0) + 0.5, helmet)


def draw_standing(frame, turn):
    cv = Canvas(W, H)
    rig = Rig(cv, turn, CX)
    firing = frame in (4, 5)
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
    hipY = 58 + bob + (1 if hurt else 0)

    leg(rig, +1, hipY, ground, lstep)
    leg(rig, -1, hipY, ground, rstep)
    torso(rig, hipY)
    shY = hipY - 22

    if firing:
        # rifle shouldered, pointing straight ahead (+z)
        stock = (-3, shY + 10, 5)
        muzzle = (-5, shY + 2, 30)
        arm(rig, +1, (14, shY, 0), (12, shY + 12, 4), (2, shY + 12, 8))
        arm(rig, -1, (-14, shY, 0), (-12, shY + 10, 6), (-4, shY + 6, 14))
    else:
        # held across the chest, muzzle up-left
        sw = -lstep // 3
        stock = (10, shY + 20, 7)
        muzzle = (-16, shY + 4, 9)
        arm(rig, +1, (14, shY, 0), (14, shY + 12, sw), (6, shY + 9, 7))
        arm(rig, -1, (-14, shY, 0), (-14, shY + 12, sw), (-6, shY + 16, 7))

    def gun(r, stock=stock, muzzle=muzzle):
        x0, y0 = r.p(stock)
        x1, y1 = r.p(muzzle)
        flash = firing and frame == 4
        if r.facing_away and not firing:
            # from behind only the barrel tip and stock show past the body
            rifle2d(r.cv, x0, y0, x1, y1, tint=BACK)
        else:
            rifle2d(r.cv, x0, y0, x1, y1, muzzle_flash=flash)
    rig.custom(rig.depth(0, 8), gun)

    head(rig, hipY - 38 + (2 if hurt else 0), hurt=hurt, yell=firing)
    rig.render()

    if hurt:
        for (bx, by, r) in ((CX - 5, hipY - 16, 3), (CX + 4, hipY - 10, 2)):
            cv.paint(cv.mask().circle(bx, by, r), BLOOD)
        cv.set(CX - 8, hipY - 20, BLOOD_DARK)
    cv.outline(OUTLINE)
    return cv


def draw_recoil():
    cv = draw_standing(6, 0)
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
    hipY = 76
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
    m = cv.mask().tapered(34, hipY - 2, 11, 50, hipY - 22, 12)
    cv.part(m, UNIFORM, thickness=3, rim=2)
    m = cv.mask().poly([(40, hipY - 24), (44, hipY - 26), (38, hipY - 2), (35, hipY - 3)])
    cv.part(m, BELT, thickness=1, rim=0, shadow=1)
    for (a, b, c) in (((38, hipY - 20), (30, hipY - 30), (24, hipY - 40)), ((54, hipY - 24), (60, hipY - 34), (58, hipY - 44))):
        m = cv.mask().tapered(a[0], a[1], 5, b[0], b[1], 4)
        cv.part(m, UNIFORM, thickness=2)
        m = cv.mask().tapered(b[0], b[1], 4, c[0], c[1], 3)
        cv.part(m, UNIFORM, thickness=2)
        cv.part(cv.mask().circle(c[0], c[1], 3), SKIN, thickness=2)
    r = Rig(cv, 0, 56)
    head(r, hipY - 34, hurt=True)
    r.render()
    rifle2d(cv, 6, hipY - 40, 26, hipY - 52)
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
    m = cv.mask().tapered(26, ground - 8, 5, 12, ground - 6, 4)
    cv.part(m, UNIFORM, thickness=2, tint=BACK)
    m = cv.mask().rect(4, ground - 10, 9, 6)
    cv.part(m, BOOT, thickness=2, tint=BACK)
    m = cv.mask().tapered(28, ground - 6, 5, 14, ground - 3, 4)
    cv.part(m, UNIFORM, thickness=2)
    m = cv.mask().rect(6, ground - 6, 9, 5)
    cv.part(m, BOOT, thickness=2)
    m = cv.mask().oval(36, ground - 8, 14, 7)
    cv.part(m, UNIFORM, thickness=3, rim=1)
    m = cv.mask().poly([(26, ground - 12), (28, ground - 12), (46, ground - 5), (44, ground - 4)])
    cv.part(m, BELT, thickness=1, rim=0, shadow=1)
    cv.paint(cv.mask().rect(29, ground - 10, 3, 3), UNIFORM_DK[2])
    m = cv.mask().tapered(44, ground - 10, 3, 56, ground - 14, 2.5)
    cv.part(m, UNIFORM, thickness=2)
    cv.part(cv.mask().circle(58, ground - 15, 2.5), SKIN, thickness=1)
    hx, hy = 52, ground - 8
    m = cv.mask().oval(hx, hy, 7, 6)
    cv.part(m, SKIN, thickness=3, rim=1)
    cv.paint(cv.mask().rect(hx - 4, hy - 1, 3, 1), EYE_SOCKET)
    cv.paint(cv.mask().rect(hx + 1, hy - 1, 3, 1), EYE_SOCKET)
    cv.paint(cv.mask().rect(hx - 2, hy + 2, 5, 1), MOUTH)
    m = cv.mask().oval(14, ground - 18, 8, 5)
    m.subtract(cv.mask().rect(0, ground - 24, 30, 6))
    cv.part(m, HELMET, thickness=2, rim=1)
    rifle2d(cv, 20, ground - 22, 46, ground - 24)
    cv.paint(cv.mask().circle(38, ground - 10, 3), BLOOD)
    cv.paint(cv.mask().circle(40, ground - 8, 2), BLOOD_DARK)
    cv.outline(OUTLINE)
    return cv


def frames():
    return turntable_frames(draw_standing, lambda: [draw_recoil(), draw_falling(), draw_corpse()])
