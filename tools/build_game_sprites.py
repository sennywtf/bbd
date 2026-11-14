"""Generate the small pixel sprites used by the game.

Requires Pillow. Run from the project root with: python3 tools/build_game_sprites.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / 'assets/sprites'
HOUSES = ROOT / 'assets/houses'
SPRITES.mkdir(parents=True, exist_ok=True)


def canvas(name, size, paint):
    im = Image.new('RGBA', size, (0, 0, 0, 0))
    paint(ImageDraw.Draw(im))
    im.save(SPRITES / name)


def rect(draw, box, color):
    x, y, w, h = box
    draw.rectangle((x, y, x + w - 1, y + h - 1), fill=color)


def van(draw):
    def r(x, y, w, h, color): rect(draw, (x+105, y+93, w, h), color)
    ink='#1d1b23'
    r(-105,-93,151,113,ink);r(-101,-89,143,104,'#f4dfb8');r(-97,-85,135,85,'#9d8299')
    r(-94,-82,129,5,'#b49bb0')
    for x in range(-89,30,23): r(x,-75,10,3,'#b49bb0')
    r(43,-44,44,64,ink);r(83,-33,10,53,ink);r(91,-23,11,43,ink)
    r(47,-40,38,56,'#d66b43');r(85,-29,6,45,'#d66b43');r(91,-19,7,35,'#d66b43')
    r(54,-36,29,28,ink);r(58,-32,22,20,'#5ca8c9');r(58,-32,18,4,'#92d5e5')
    r(88,-3,5,5,'#f0b457');r(-105,14,208,13,ink);r(-98,15,130,5,'#bd5e3c')
    r(-47,22,81,3,'#f0a062')
canvas('van.png',(210,140),van)

# The exact stepped tire used before the wheel animation was introduced.
def wheel(draw):
    def r(x, y, w, h, color): rect(draw, (x + 20, y - 8, w, h), color)
    ink = '#1d1b23'
    r(-13, 10, 26, 4, ink); r(-17, 14, 34, 4, ink)
    r(-20, 18, 40, 20, ink); r(-17, 38, 34, 4, ink); r(-13, 42, 26, 4, ink)
    r(-9, 19, 18, 18, '#b9bec1')
    r(-5, 23, 10, 10, '#695967')
    r(-2, 26, 4, 4, '#d6d9cc')
canvas('wheel.png', (40, 40), wheel)

for damaged in (False,True):
    def box(draw):
        rect(draw,(0,0,22,22),'#1d1b23')
        rect(draw,(2,2,18,18),'#e78a75' if damaged else '#f6d8a6')
        rect(draw,(9,2,5,18),'#b96e49')
        rect(draw,(2,10,18,2),'#b96e49')
    canvas('box-damaged.png' if damaged else 'box.png',(22,22),box)

for done in (False,True):
    def sign(draw):
        rect(draw,(34,29,5,76),'#5b465d')
        rect(draw,(0,0,76,31),'#4a344e')
        rect(draw,(4,4,68,23),'#a9dec4' if done else '#fff0d1')
    canvas('stop-sign-done.png' if done else 'stop-sign.png',(76,105),sign)
    def yard(draw):
        rect(draw,(0,1,220,6),'#91c9a4' if done else '#ead9bd')
        rect(draw,(94,0,32,7),'#c1a5a5')
    canvas('yard-done.png' if done else 'yard.png',(220,7),yard)


def road_tile(draw):
    rect(draw,(0,0,48,48),'#798ca8')
    for x,y,w,c in ((5,7,9,'#889ab1'),(31,19,12,'#647a99'),(14,33,7,'#889ab1'),(38,42,5,'#647a99')):
        rect(draw,(x,y,w,3),c)
canvas('road-tile.png',(48,48),road_tile)
canvas('sky-tile.png',(16,16),lambda d: rect(d,(0,0,16,16),'#8dddf4'))

# House PNGs are edited assets. The original sheet is intentionally not bundled.
# This builder regenerates the other gameplay sprites without touching the houses.
print('Built van body, original stepped wheel, boxes, signs, yard, road, and sky sprites.')
