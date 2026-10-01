# -*- coding: utf-8 -*-
"""Full-cell 2x zoom probes for batch-2 codeanim sheets (cells 512)."""
from PIL import Image
import os

BASE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                     "..", ".godot", "unit_review", "codeanim"))

# (prefix, [(col,row)...]) -> one output per cell, 2x
PROBES = [
    ("cold_rpg", [(1, 0), (2, 0), (3, 0)]),
    ("cold_mig21", [(2, 0)]),
    ("mod_air_bomber", [(3, 0), (0, 1)]),
    ("fut_sup_ps9", [(2, 0)]),
    ("fut_stealth_bomber", [(3, 0)]),
]

def main():
    sheets = {}
    for prefix, cells in PROBES:
        if prefix not in sheets:
            sheets[prefix] = Image.open(os.path.join(
                BASE, "%s_codeanim_sheet.png" % prefix)).convert("RGBA")
        sheet = sheets[prefix]
        for i, (col, row) in enumerate(cells):
            c = sheet.crop((col * 512, row * 512, col * 512 + 512, row * 512 + 512))
            c = c.resize((1024, 1024), 3)
            out = os.path.join(BASE, "_probe3_%s_cell%d.png" % (prefix, col + row * 5))
            c.convert("RGB").save(out)
            print("saved", os.path.basename(out))

if __name__ == "__main__":
    main()
