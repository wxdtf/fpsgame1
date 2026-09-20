"""Pickup sprites, 32x32, in the order Item.spriteIndex expects:

 0 medkit   1 armor vest   2 bullet box   3 shell box   4 shotgun   5 chaingun
 6 red key  7 blue key     8 yellow key   9 berserk    10 intel    11 artifact
12 rocket launcher  13 rocket box
"""

from pixelart import Canvas, ramp, rgb

W, H = 32, 32

WHITE = ramp(rgb(222, 222, 216), deep=rgb(90, 90, 94), hi=rgb(255, 255, 255))
RED = ramp(rgb(190, 36, 30), deep=rgb(70, 8, 6), hi=rgb(255, 120, 100))
GREEN = ramp(rgb(60, 140, 70), deep=rgb(14, 48, 20), hi=rgb(150, 230, 150))
OLIVE = ramp(rgb(110, 104, 60), deep=rgb(36, 34, 16), hi=rgb(190, 184, 120))
BROWN = ramp(rgb(120, 82, 44), deep=rgb(40, 24, 10), hi=rgb(200, 150, 96))
BRASS = ramp(rgb(200, 158, 62), deep=rgb(80, 58, 16), hi=rgb(250, 232, 160))
STEEL = ramp(rgb(96, 100, 110), deep=rgb(22, 24, 30), hi=rgb(184, 190, 202))
GUNMETAL = ramp(rgb(46, 48, 56), deep=rgb(8, 8, 12), hi=rgb(112, 116, 128))
WOOD = ramp(rgb(126, 78, 40), deep=rgb(44, 24, 10), hi=rgb(200, 142, 88))
BLACK = ramp(rgb(40, 38, 44), deep=rgb(6, 6, 8), hi=rgb(100, 98, 108))
BLUE = ramp(rgb(50, 90, 200), deep=rgb(10, 24, 80), hi=rgb(150, 190, 255))
YELLOW = ramp(rgb(220, 190, 40), deep=rgb(90, 70, 8), hi=rgb(255, 250, 170))
PURPLE = ramp(rgb(120, 40, 140), deep=rgb(40, 8, 50), hi=rgb(220, 140, 240))
BONE = ramp(rgb(214, 204, 176), deep=rgb(90, 84, 66), hi=rgb(250, 246, 230))
OUTLINE = rgb(8, 8, 12)
GLOW = rgb(255, 250, 200)


def box(cv, x, y, w, h, mat, lid=True):
    cv.part(cv.mask().rect(x, y, w, h), mat, thickness=3, rim=2)
    if lid:
        cv.paint(cv.mask().rect(x, y + 3, w, 1), mat[1])


def medkit():
    cv = Canvas(W, H)
    box(cv, 5, 9, 22, 16, WHITE)
    cv.part(cv.mask().rect(13, 6, 6, 4), STEEL, thickness=1, rim=1)      # handle
    cv.paint(cv.mask().rect(14, 12, 4, 10), RED[2])
    cv.paint(cv.mask().rect(11, 15, 10, 4), RED[2])
    cv.set(14, 12, RED[3]); cv.set(11, 15, RED[3])
    cv.outline(OUTLINE)
    return cv


def armor():
    cv = Canvas(W, H)
    m = cv.mask().poly([(7, 6), (12, 6), (16, 10), (20, 6), (25, 6), (27, 14), (24, 16), (24, 26), (8, 26), (8, 16), (5, 14)])
    cv.part(m, GREEN, thickness=3, rim=2)
    cv.paint(cv.mask().rect(12, 8, 8, 4), GREEN[0])                       # neck opening
    for y in (12, 16, 20):
        cv.paint(cv.mask().rect(9, y, 14, 1), GREEN[1])                    # plates
    cv.paint(cv.mask().rect(15, 9, 2, 16), GREEN[3])                       # centre seam highlight
    cv.outline(OUTLINE)
    return cv


def bullet_box():
    cv = Canvas(W, H)
    box(cv, 5, 12, 22, 14, OLIVE)
    cv.paint(cv.mask().rect(6, 17, 20, 1), OLIVE[0])
    for k in range(5):
        cv.part(cv.mask().rect(7 + k * 4, 6, 2, 8), BRASS, thickness=1, rim=1)
        cv.set(7 + k * 4, 6, BRASS[4])
    cv.outline(OUTLINE)
    return cv


def shell_box():
    cv = Canvas(W, H)
    box(cv, 5, 13, 22, 13, BROWN)
    for k in range(4):
        x = 7 + k * 5
        cv.part(cv.mask().rect(x, 5, 3, 9), RED, thickness=1, rim=1)
        cv.paint(cv.mask().rect(x, 12, 3, 2), BRASS[2])
    cv.outline(OUTLINE)
    return cv


def shotgun_pickup():
    cv = Canvas(W, H)
    cv.part(cv.mask().poly([(2, 20), (10, 18), (12, 24), (4, 26)]), WOOD, thickness=2, rim=1)   # stock
    cv.part(cv.mask().tapered(10, 20, 3, 30, 12, 2), STEEL, thickness=1, rim=1)                    # barrel
    cv.part(cv.mask().tapered(12, 23, 2.5, 22, 18, 2), WOOD, thickness=1, rim=1)                   # pump
    cv.part(cv.mask().rect(11, 17, 6, 6), GUNMETAL, thickness=1, rim=1)                            # receiver
    cv.outline(OUTLINE)
    return cv


def chaingun_pickup():
    cv = Canvas(W, H)
    cv.part(cv.mask().rect(4, 15, 12, 10), GUNMETAL, thickness=2, rim=1)                           # body
    for k, y in enumerate((14, 18, 22)):
        cv.part(cv.mask().rect(15, y, 14, 2), STEEL, thickness=1, rim=1)                          # barrels
    cv.part(cv.mask().oval(9, 12, 4, 3), STEEL, thickness=1, rim=1)                                # drum
    cv.outline(OUTLINE)
    return cv


def keycard(mat):
    cv = Canvas(W, H)
    cv.part(cv.mask().poly([(9, 4), (23, 4), (23, 28), (9, 28)]), mat, thickness=3, rim=2)
    cv.part(cv.mask().rect(12, 8, 8, 6), BRASS, thickness=1, rim=1)                                # chip
    cv.paint(cv.mask().rect(13, 10, 6, 1), BRASS[1])
    cv.paint(cv.mask().rect(11, 18, 10, 2), mat[4])                                                 # stripe
    cv.paint(cv.mask().rect(11, 22, 6, 2), mat[1])
    cv.outline(OUTLINE)
    return cv


def berserk():
    cv = Canvas(W, H)
    box(cv, 5, 8, 22, 18, BLACK)
    cv.paint(cv.mask().rect(6, 12, 20, 1), RED[2])
    cv.paint(cv.mask().rect(6, 22, 20, 1), RED[2])
    # a red fist emblem
    m = cv.mask()
    m.oval(16, 17, 5, 4)
    m.rect(11, 17, 10, 4)
    cv.part(m, RED, thickness=1, rim=1, contact=False)
    for k in range(3):
        cv.set(13 + k * 3, 14, RED[4])
    cv.outline(OUTLINE)
    return cv


def intel():
    cv = Canvas(W, H)
    cv.part(cv.mask().rect(6, 6, 20, 20), GUNMETAL, thickness=3, rim=2)                            # datapad
    cv.paint(cv.mask().rect(9, 9, 14, 12), BLUE[0])                                                 # screen
    for k, w in enumerate((10, 7, 12, 5)):
        cv.paint(cv.mask().rect(10, 10 + k * 3, w, 1), BLUE[3])
    cv.set(21, 19, GLOW)
    cv.paint(cv.mask().rect(12, 23, 8, 2), STEEL[2])
    cv.outline(OUTLINE)
    return cv


def artifact():
    cv = Canvas(W, H)
    # a horned skull idol on a pedestal, eyes glowing purple
    cv.part(cv.mask().poly([(9, 24), (23, 24), (25, 28), (7, 28)]), BLACK, thickness=2, rim=1)
    m = cv.mask()
    m.oval(16, 13, 7, 7)
    m.poly([(11, 15), (21, 15), (19, 23), (13, 23)])
    cv.part(m, BONE, thickness=3, rim=2)
    for side in (-1, 1):
        cv.part(cv.mask().poly([(16 + side * 5, 8), (16 + side * 8, 8), (16 + side * 11, 1)]), BONE, thickness=1, rim=1)
        cv.paint(cv.mask().oval(16 + side * 3, 13, 2, 1.5), BLACK[0])
        cv.set(16 + side * 3, 13, PURPLE[4])
    cv.paint(cv.mask().rect(14, 18, 5, 1), BLACK[0])
    for x in (14, 16, 18):
        cv.set(x, 19, BONE[2])
    cv.set(16, 17, BLACK[0])
    cv.outline(OUTLINE)
    return cv


def launcher_pickup():
    cv = Canvas(W, H)
    cv.part(cv.mask().tapered(4, 20, 4, 27, 13, 4), GUNMETAL, thickness=2, rim=1)                   # tube
    cv.part(cv.mask().oval(27, 13, 4, 4), STEEL, thickness=1, rim=1)
    cv.paint(cv.mask().oval(27, 13, 2, 2), OUTLINE)
    cv.part(cv.mask().rect(12, 21, 4, 6), GUNMETAL, thickness=1, rim=1)                            # grip
    for k in range(2):
        cv.paint(cv.mask().rect(15 + k * 5, 15, 2, 6), BRASS[2])                                    # stripes
    cv.outline(OUTLINE)
    return cv


def rocket_box():
    cv = Canvas(W, H)
    box(cv, 4, 14, 24, 12, OLIVE)
    for k in range(3):
        x = 7 + k * 7
        cv.part(cv.mask().rect(x, 6, 4, 9), STEEL, thickness=1, rim=1)
        cv.part(cv.mask().poly([(x, 6), (x + 4, 6), (x + 2, 2)]), RED, thickness=1, rim=0, contact=False)
        cv.paint(cv.mask().rect(x + 1, 13, 2, 2), OUTLINE)
    cv.outline(OUTLINE)
    return cv


def frames():
    return [medkit(), armor(), bullet_box(), shell_box(), shotgun_pickup(), chaingun_pickup(),
            keycard(RED), keycard(BLUE), keycard(YELLOW), berserk(), intel(), artifact(),
            launcher_pickup(), rocket_box()]
