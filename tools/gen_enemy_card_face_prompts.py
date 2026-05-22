# -*- coding: utf-8 -*-
"""从 docs/enemy_card_face_ids_zh.tsv 生成英文生图提示词（白底 1024²、无文字），输出含中文名列。"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "docs/enemy_card_face_ids_zh.tsv"
OUT = ROOT / "docs/enemy_card_face_ids_zh_prompts.tsv"

NO_TEXT = (
    "no text, no letters, no numbers, no watermark, no logos, no typography, "
    "no captions, no speech bubbles, no readable insignia or labels on image"
)

BASE = (
    "game trading card illustration, single centered subject, clean studio lighting, "
    "slightly low three-quarter view, sharp focus, rich material detail, "
    "1024x1024 square composition, seamless pure white background #FFFFFF, "
    f"{NO_TEXT}, "
)

# 36 固定原型：按 id 定制（英文描述，避免提示词里出现中文以免模型画字）
FIXED: dict[str, str] = {
    "boss_cold_mig": "Soviet MiG-29 fighter jet in flight gray camouflage, cold war era, dynamic banking pose, missile pylons, no roundels with readable text",
    "boss_future_nexus": "massive futuristic storm command core, floating armored sphere with lightning conduits and dark metal plates, sci-fi energy glow violet and cyan",
    "boss_modern_command": "modern military command bunker entrance with reinforced blast doors and radar dome, concrete and steel, subtle desert tan",
    "boss_ww1_av7": "French Saint-Chamond WW1 rhomboid tank, long hull with field gun in casemate, muddy olive drab metal, trench mud splashes",
    "boss_ww2_kingtiger": "German King Tiger heavy tank WW2, angular hull and wide tracks, dunkelgelb yellow-ochre paint, commander cupola closed",
    "elite_cold_spetsnaz": "Cold War Soviet Spetsnaz squad in berets and load bearing gear, AK rifles, winter forest palette, tactical stance",
    "elite_cold_t72": "Soviet T-72 main battle tank cold war, low turret rounded cheeks, green khaki camouflage, hull front angle",
    "elite_future_colossus": "colossal bipedal mech walker futuristic, heavy armor plates, glowing reactor vents, urban ruins implied only as silhouette blur",
    "elite_future_spectre": "sleek stealth operative in futuristic nano-armor suit, visor glow, suppressed rifle, dark blue and graphite tones",
    "elite_modern_abrams": "US M1 Abrams main battle tank modern, desert tan composite armor, long 120mm gun, desert heat haze minimal",
    "elite_modern_apache": "AH-64 Apache attack helicopter modern, tandem cockpit, rocket pods, olive drab and gray, hovering pose",
    "elite_modern_delta": "US special forces operators modern, plate carriers and helmets, carbines, multicam pattern, tight squad wedge",
    "elite_ww1_armored": "WW1 armored car with spoked wheels and riveted hull, machine gun turret, khaki paint, dirt road dust",
    "elite_ww1_storm": "WW1 German Sturmtruppen squad with steel helmets, MP18 style submachine guns, trench coats, storming pose",
    "elite_ww2_panther": "German Panther medium tank WW2, sloped glacis, dark yellow and red oxide primer edges, forest edge lighting",
    "elite_ww2_paratrooper": "WW2 US paratroopers with M1 helmets and jump jackets, Thompson and Garand, scattered gear, heroic upward angle",
    "enemy_cold_ak": "Soviet motorized rifle squad cold war, AK-74 style rifles, green uniforms, BMP in soft background blur very subtle",
    "enemy_cold_btr": "BTR-80 wheeled APC cold war, eight wheels, turret with autocannon, green camouflage, mud splatter on hull",
    "enemy_cold_m113": "M113 tracked APC aluminum hull, US olive drab, simple box shape, commander hatch open with figure silhouette only",
    "enemy_cold_m60": "US infantry fireteam cold war, M16 rifles, woodland BDUs, sandbag firing position minimal",
    "enemy_future_cyborg": "cyborg heavy infantry futuristic, chrome limbs and armored torso, red sensor eyes, storm rifle integrated",
    "enemy_future_drone": "swarm of compact combat drones futuristic, quad-rotor gunships, gray polymer shells, blue LED accents",
    "enemy_future_hovertank": "hovering tank without tracks futuristic, anti-gravity glow under hull, twin plasma cannons, matte gunmetal",
    "enemy_future_mech": "medium battle mech futuristic, humanoid piloted frame, shoulder missile racks, worn battle paint",
    "enemy_modern_marine": "US Marines fireteam modern, desert MARPAT, rifles and SAW, kneeling behind low concrete barrier",
    "enemy_modern_mlrs": "HIMARS style rocket launcher truck modern, launcher elevated, desert tan, heat shimmer subtle",
    "enemy_modern_stryker": "Stryker ICV eight wheels modern, slat armor cage, urban gray-green, turret remote weapon station",
    "enemy_modern_technical": "Toyota pickup technical truck with heavy machine gun on pintle mount, desert dust, improvised armor plates",
    "enemy_ww1_infantry_basic": "WW1 German stormtrooper squad with MP18 drum submachine guns, steel Stahlhelm, trench mud, dynamic charge",
    "enemy_ww1_infantry_rifle": "WW1 British infantry section with Lee-Enfield rifles, Brodie helmets, khaki wool, bayonets fixed",
    "enemy_ww1_mg_nest": "WW1 heavy machine gun nest sandbags and wooden beams, Maxim style gun, spent brass belt, brown earth tones",
    "enemy_ww1_mortar": "WW1 mortar crew with trench mortar tube, wooden base plate, crew in helmets loading shell, smoke wisps",
    "enemy_ww2_infantry": "WW2 US infantry squad Thompson submachine gun and rifles, M1 helmets, olive drab, Pacific or European generic",
    "enemy_ww2_mg42": "WW2 German MG42 machine gun on tripod with belt ammunition, assistant gunner, splinter camouflage smock",
    "enemy_ww2_panzerschreck": "WW2 German anti-tank team with shoulder-fired rocket launcher tube, sandbags, winter or summer neutral gear",
    "enemy_ww2_rifleman": "WW2 US rifleman with M1 Garand, cartridge belt, helmet net, crouched aiming",
}


def _era_from_id(unit_id: str) -> str:
    if "_ww1_" in unit_id or unit_id.endswith("_ww1") or "ww1" in unit_id.split("_"):
        return "World War 1 European theater, mud and khaki, early steel helmets"
    if "_ww2_" in unit_id:
        return "World War 2, olive drab and field gray mix, steel helmets, weathered equipment"
    if "_cold_" in unit_id:
        return "Cold War era, Warsaw Pact or NATO generic, green khaki and steel"
    if "_modern_" in unit_id:
        return "modern military circa 2010s, multicam or desert tan, optics and polymer gear"
    if "_near_" in unit_id:
        return "near-future sci-fi military, advanced alloys, subtle cyan energy accents"
    return "generic military"


def _prompt_procedural(unit_id: str, zh: str) -> str:
    era = _era_from_id(unit_id)
    tail = zh.split("·", 1)[-1] if "·" in zh else zh
    # 将中文角色类型粗略映射为英文视觉词（不含字面中文进 prompt 主体）
    subject = "military unit or vehicle matching the Chinese label theme"
    if "步兵" in tail or "志愿" in tail or "堑壕" in tail or "民兵" in tail or "征召" in tail or "陆战" in tail or "特种" in tail or "侦察" in tail or "支援" in tail or "伞兵" in tail or "狙击" in tail or "医疗" in tail or "后勤" in tail or "通讯" in tail or "工兵" in tail or "炊事" in tail or "维修" in tail or "雷达" in tail or "空降" in tail or "三角洲" in tail:
        subject = "infantry squad or fireteam in era-appropriate uniforms and rifles, dynamic combat pose"
    if "坦克" in tail or "装甲" in tail or "战车" in tail or "履带" in tail or "自行" in tail or "半履带" in tail:
        subject = "armored fighting vehicle, tank or APC, era-appropriate silhouette and camouflage"
    if "机枪" in tail or "迫击" in tail or "炮" in tail or "阵地" in tail or "碉堡" in tail or "防空" in tail or "反坦克" in tail or "火箭" in tail or "导弹" in tail or "岸防" in tail or "高射" in tail or "近防" in tail:
        subject = "crew-served weapons emplacement or artillery piece with sandbags and metal, firing stance implied"
    if "直升" in tail or "阿帕奇" in tail:
        subject = "attack helicopter with weapons pods, hovering three-quarter view"
    if "无人" in tail or "机群" in tail:
        subject = "cluster of small combat drones, mechanical detail"
    if "机甲" in tail or "机械" in tail or "悬浮" in tail or "巨神" in tail:
        subject = "sci-fi mech or hover tank, heavy armor plates"
    if "能量" in tail or "激光" in tail or "矩阵" in tail or "核心" in tail or "相位" in tail or "纳米" in tail or "赛博" in tail or "幽灵" in tail or "猎杀" in tail:
        subject = "futuristic energy weapon platform or powered armor, glowing tech details restrained"
    if "米格" in tail or "MiG" in unit_id:
        subject = "MiG fighter jet, cold war metal"
    return f"{BASE}{era}. {subject}. Heroic collectible card key art, one clear silhouette, high detail."


def _prompt_fixed(unit_id: str, zh: str) -> str:
    core = FIXED.get(unit_id)
    if core:
        return f"{BASE}{core}"
    # 不应发生
    return f"{BASE}{zh}, military subject, detailed illustration."


def _tsv_cell(s: str) -> str:
    return s.replace("\t", " ").replace("\n", " ").replace("\r", "")


def main() -> None:
    lines_out = ["id\t中文名\tprompt_en"]
    text = SRC.read_text(encoding="utf-8")
    for raw in text.splitlines():
        raw = raw.strip()
        if not raw or raw.startswith("id\t"):
            continue
        parts = raw.split("\t", 1)
        if len(parts) != 2:
            continue
        uid, zh = parts[0].strip(), parts[1].strip()
        if uid == "id":
            continue
        if re.match(r"^enemy_(ww1|ww2|cold|modern|near)_\d{2}$", uid):
            prompt = _prompt_procedural(uid, zh)
        else:
            prompt = _prompt_fixed(uid, zh)
        prompt_one = _tsv_cell(prompt)
        zh_cell = _tsv_cell(zh)
        lines_out.append(f"{uid}\t{zh_cell}\t{prompt_one}")
    OUT.write_text("\n".join(lines_out) + "\n", encoding="utf-8")
    print("Wrote", OUT, "rows", len(lines_out) - 1)


if __name__ == "__main__":
    main()
