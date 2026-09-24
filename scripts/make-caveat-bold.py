#!/usr/bin/env python3
"""Make a static Caveat Bold (wght 700) instance from the Google Fonts variable file.

Usage: python3 scripts/make-caveat-bold.py <Caveat[wght].ttf> <out Caveat-Bold.ttf>
Needs fontTools (pip install fonttools).
"""
import sys
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

src, dst = sys.argv[1], sys.argv[2]
font = instantiateVariableFont(TTFont(src), {"wght": 700}, updateFontNames=False)
name = font["name"]
for rec in list(name.names):
    if rec.nameID in (1, 2, 3, 4, 6, 16, 17, 25):
        name.removeNames(nameID=rec.nameID)
for nid, value in {1: "Caveat", 2: "Bold", 3: "Caveat-Bold-Foundry", 4: "Caveat Bold", 6: "Caveat-Bold"}.items():
    name.setName(value, nid, 3, 1, 0x409)
    name.setName(value, nid, 1, 0, 0)
font["OS/2"].usWeightClass = 700
font["OS/2"].fsSelection = (font["OS/2"].fsSelection | 0x20) & ~0x40  # bold, not regular
font["head"].macStyle |= 0x1
font.save(dst)
print("wrote", dst)
