# -*- coding: utf-8 -*-
"""P2-2A：30 位相位师 master 立绘批量生成（agnes，512×512 卡面）

风格锚点：写实军事卡牌插画风、暗色调、系别色点缀（钢=钢灰蓝/焰=绯橙/雷=紫电/
虚空=暗青）。性别按名pha排（虚构人物，单条不满意可用 --only <id> 重掷）。
输出：assets/enemies/phase_masters/<master_id>.png
"""
import importlib.util
import os
import sys

_spec = importlib.util.spec_from_file_location("g", os.path.join(os.path.dirname(os.path.abspath(__file__)), "_tmp_gen_weapons_realistic.py"))
_g = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_g)

OUT_DIR = os.path.join(_g.ROOT, "assets", "enemies", "phase_masters")

ERA_ATTIRE = {
    "ww1": "WWI-era Chinese warlord army greatcoat with high collar and peaked cap",
    "ww2": "WWII-era Chinese field officer uniform with leather straps",
    "cold": "Cold-War-era Chinese PLA-style olive greatcoat with soft cap",
    "modern": "modern Chinese digital-camouflage combat uniform with tactical vest",
    "future": "near-future high-collared black techno greatcoat with subtle glowing circuit lines",
}
FACTION_ACCENT = {
    "steel": "steel-grey and gunmetal color accent",
    "flame": "crimson and ember-orange color accent",
    "thunder": "violet lightning-glow color accent",
    "void": "dark teal and shadow-black color accent",
    "steel_flame": "steel-grey with ember-red trim accent",
    "thunder_steel": "gunmetal with violet arc accents",
    "void_flame": "dark teal with ember-orange trim accent",
    "steel_thunder": "steel-grey with violet arc accents",
    "flame_void": "ember-red with dark-teal shadow accents",
    "all": "subtle gold trim accent",
}

# id: (名, 称号意象英文, era, gender, motif)
MASTERS = {
    "enemy_master_001": ("沈铸城", "unbreakable fortress wall defender", "ww1", "m", "stone-wall bastion motif on the coat"),
    "enemy_master_002": ("祝晚棠", "overload flame artillery caller", "ww1", "f", "ember sparks drifting around the shoulders"),
    "enemy_master_003": ("陆惊鸿", "seven-fold lightning striker", "ww1", "m", "thin lightning arcs crackling at the collar"),
    "enemy_master_004": ("裴溯", "forty-one-second rift walker", "ww1", "m", "faint teal rift glow behind the shoulder"),
    "enemy_master_005": ("霍北望", "unbreakable shield bearer", "ww1", "m", "riveted shield emblem on the chest"),
    "enemy_master_006": ("姜拾烬", "flame of destruction bearer", "ww1", "m", "smoldering embers on the glove"),
    "enemy_master_007": ("秦引路", "thunder that points the way", "ww1", "m", "lightning-rod staff resting on the shoulder"),
    "enemy_master_008": ("池晏", "dimension tear duelist", "ww2", "m", "thin floating teal rift blades"),
    "enemy_master_009": ("靳承岗", "iron legion grand commander", "ww2", "m", "row of polished medal bars"),
    "enemy_master_010": ("闻人烬", "eternal flame keeper", "ww2", "m", "ever-burning ember in the palm"),
    "enemy_master_011": ("程默雷", "silent thunder listener", "ww2", "m", "soundless violet glow in the eyes"),
    "enemy_master_012": ("温折野", "forty-day pocket dimension survivor", "ww2", "m", "frayed cloak with teal rift stitches"),
    "enemy_master_013": ("韩铸犁", "sword reforged into plow idealist", "cold", "m", "half-sword half-plow emblem pin"),
    "enemy_master_014": ("方镇流", "armor that swallowed thunder", "cold", "m", "caged violet arcs along the shoulder plate"),
    "enemy_master_015": ("郁向暖", "entropy-reversing warm flame", "cold", "f", "warm ember glow against cold teal shadow"),
    "enemy_master_016": ("石顶安", "the one who held the collapsing tunnel", "cold", "m", "cracked stone-slab pauldron"),
    "enemy_master_017": ("江焚渡", "bridge burner at the river crossing", "cold", "m", "burning bridge ember reflection in the eyes"),
    "enemy_master_018": ("纪回春", "thunder outside the encirclement", "cold", "m", "violet thunder mark on the temple"),
    "enemy_master_019": ("晏怀空", "world devourer calm gaze", "modern", "m", "faint galaxy shimmer in the coat lining"),
    "enemy_master_020": ("盛传书", "antenna of seven islands", "modern", "m", "slim radio antenna pinned to the collar"),
    "enemy_master_021": ("明未晞", "chaos flame before dawn", "modern", "f", "twin-tone ember and teal flame wisps"),
    "enemy_master_022": ("宋卸甲", "the one who captures but never kills", "modern", "m", "removal-style loose armor strap"),
    "enemy_master_023": ("楚再春", "returnee from the ashes", "modern", "f", "ash-grey to spring-green gradient hem"),
    "enemy_master_024": ("岑风眠", "thunderstorm that yields the way", "modern", "m", "parted violet storm clouds motif"),
    "enemy_master_025": ("宿怀夜", "eight-hour shadow operative", "future", "m", "shadow-woven cloak with teal seams"),
    "enemy_master_026": ("鲁满仓", "two hundred hoes quartermaster", "future", "m", "row of small tool tags on the chest strap"),
    "enemy_master_027": ("涂知温", "thirty-seven-degree gentle flame", "future", "f", "soft warm glow at the fingertips"),
    "enemy_master_028": ("端木近雨", "thunderstorm that lands close", "future", "m", "rain-streak violet arcs overhead"),
    "enemy_master_029": ("叶掌灯", "the one who folded the starry sky", "future", "m", "folded paper-star lantern in hand"),
    "enemy_master_030": ("贺同舟", "the thirty-first in the same boat", "future", "m", "gold-trim coat with thirty small name tags"),
}

PROMPT = (
    "2D game character portrait card art, {gender} Chinese {era_attire}, bearer of \"{motif}\", "
    "{accent}, stern weathered face befitting a fallen hero, bust portrait, muted military painterly "
    "realistic style matching tactical card game art, dramatic side lighting, dark textured background "
    "with subtle {accent_short} glow, centered composition, entire figure fully inside frame"
)
ACCENT_SHORT = {"steel": "steel-grey", "flame": "ember-orange", "thunder": "violet", "void": "teal",
                "steel_flame": "steel-grey", "thunder_steel": "violet", "void_flame": "teal",
                "steel_thunder": "violet", "flame_void": "ember-orange", "all": "gold"}
GENDER_WORD = {"m": "male", "f": "female"}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    keys = _g.load_keys()
    only = None
    if "--only" in sys.argv:
        only = sys.argv[sys.argv.index("--only") + 1]
    todo = []
    for mid, (name, motif, era, gender, motif_full) in MASTERS.items():
        if only and mid != only and name != only:
            continue
        out = os.path.join(OUT_DIR, mid + ".png")
        if os.path.exists(out) and os.path.getsize(out) > 10000:
            continue
        todo.append((mid, name, motif, era, gender, motif_full))
    print("todo:", len(todo))
    fails = 0
    for i, (mid, name, motif, era, gender, motif_full) in enumerate(todo):
        accent = FACTION_ACCENT[_faction_of(mid)]
        prompt = PROMPT.format(gender=GENDER_WORD[gender], era_attire=ERA_ATTIRE[era],
                               motif=motif_full, accent=accent,
                               accent_short=ACCENT_SHORT[_faction_of(mid)])
        raw = os.path.join(OUT_DIR, mid + ".raw.png")
        ok = False
        for attempt in range(4):
            key = keys[(i + attempt) % len(keys)]
            if _g.call_api(prompt, key, "1024x1024", raw):
                try:
                    from PIL import Image
                    im = Image.open(raw).convert("RGB")
                    w, h = im.size
                    side = min(w, h)
                    im = im.crop(((w - side) // 2, (h - side) // 2,
                                  (w + side) // 2, (h + side) // 2)).resize((512, 512), Image.LANCZOS)
                    im.save(os.path.join(OUT_DIR, mid + ".png"))
                    ok = True
                    break
                except Exception as e:
                    print("  postprocess fail:", type(e).__name__)
        try:
            os.unlink(raw)
        except OSError:
            pass
        if not ok:
            fails += 1
        print("[%d/%d] %s %s -> %s" % (i + 1, len(todo), name, mid[-3:], "OK" if ok else "FAIL"), flush=True)
    print("done. fails=%d" % fails)


def _faction_of(mid: str) -> str:
    txt = _load_factions()
    return txt.get(mid, "steel")


_FAC_CACHE = None


def _load_factions() -> dict:
    global _FAC_CACHE
    if _FAC_CACHE is None:
        import re
        _FAC_CACHE = {}
        for fn in ["enemy_phase_masters_ww1.gd", "enemy_phase_masters_ww2.gd",
                   "enemy_phase_masters_cold.gd", "enemy_phase_masters_modern.gd",
                   "enemy_phase_masters_future.gd"]:
            txt = open(os.path.join(_g.ROOT, "data", fn), encoding="utf-8").read()
            for m in re.finditer(r'"id":\s*"(enemy_master_\d+)"[\s\S]{0,500}?"faction":\s*"([^"]+)"', txt):
                _FAC_CACHE[m.group(1)] = m.group(2)
    return _FAC_CACHE


if __name__ == "__main__":
    main()
