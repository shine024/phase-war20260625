"""
master.json platforms 迁移：平台卡 id → archetype id（删除平台卡层）
落实用户决策"删除平台卡层，直引 archetype"。

策略：
- 每个相位师根据 faction（势力偏好）+ era（时代）预选 archetype
- 过滤掉 boss（避免产兵出 boss 单位过强），保留普通 + 少量 elite
- 保留旧 platforms 字段作为 _legacy_platforms（向后兼容/回退）

产兵代码侧：_produce_unit_with_equipment 增加 archetype-id 优先分支。
"""
import os, json

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MASTER_PATH = os.path.join(PROJECT_ROOT, "data", "json", "enemy_phase_masters.json")
ARCH_PATH = os.path.join(PROJECT_ROOT, "data", "json", "enemy_archetypes.json")

# faction → 偏好 archetype tags（基于原平台卡 type 语义）
FAC_TAGS = {
    "steel": ["tank", "armored", "turret", "vehicle"],          # titan/fortress
    "flame": ["vehicle", "fast", "artillery"],                  # raider/siege
    "thunder": ["infantry", "frontline", "elite"],              # striker/sniper
    "void": ["infantry", "fast", "elite", "stealth", "aircraft"],  # stealth/mage
}

def level_to_era(level):
    if level <= 20: return 0
    if level <= 40: return 1
    if level <= 60: return 2
    if level <= 80: return 3
    return 4

def main():
    dry = "--dry-run" in __import__("sys").argv
    with open(ARCH_PATH, "r", encoding="utf-8") as f:
        arch_data = json.load(f).get("data", {})
    by_era = {}
    for k, v in arch_data.items():
        if not (isinstance(v, dict) and "display_name" in v):
            continue
        era = v.get("era", 0)
        tags = v.get("tags", [])
        by_era.setdefault(era, []).append((k, tags))

    with open(MASTER_PATH, "r", encoding="utf-8") as f:
        masters_raw = f.read()
    masters_obj = json.loads(masters_raw)
    # 保留顶层结构，取 data/masters/list
    if isinstance(masters_obj, list):
        masters = masters_obj
        wrap = None
    else:
        wrap = masters_obj
        masters = masters_obj.get("data", masters_obj.get("masters", []))
        if isinstance(masters, dict):
            masters = list(masters.values())

    changed = 0
    for m in masters:
        if not isinstance(m, dict):
            continue
        eq = m.get("equipment", {})
        if not isinstance(eq, dict):
            continue
        old_plats = eq.get("platforms", [])
        if not isinstance(old_plats, list):
            continue
        # 旧平台卡 id 形态（steel_*/flame_*/thunter_*/void_*）才迁移
        is_legacy = any(str(p).split("_")[0] in ("steel", "flame", "thunter", "void") for p in old_plats)
        if not is_legacy:
            continue

        fam = m.get("faction", "steel")
        level = m.get("era", m.get("level", 5))
        era = level_to_era(level) if level > 4 else level

        prefs = set()
        for f in fam.split("_"):
            prefs.update(FAC_TAGS.get(f, []))
        if fam == "all":
            for v in FAC_TAGS.values():
                prefs.update(v)

        # 候选：匹配任一偏好 tag，过滤 boss，保留普通+elite
        candidates = []
        for aid, tags in by_era.get(era, []):
            if "boss" in tags or "ultimate" in tags:
                continue
            if any(t in prefs for t in tags):
                # elite 排序靠后（普通单位优先）
                is_elite = "elite" in tags
                candidates.append((is_elite, aid))
        candidates.sort(key=lambda x: x[0])  # 普通在前，elite 在后
        new_plats = [aid for _, aid in candidates[:4]]
        if not new_plats:
            new_plats = [aid for aid, _ in by_era.get(era, [])[:2]]

        # 保留旧字段为 _legacy_platforms，新字段覆盖 platforms
        eq["_legacy_platforms"] = old_plats
        eq["platforms"] = new_plats
        changed += 1

    print("迁移相位师: %d / %d" % (changed, len(masters)))
    if dry:
        print("(DRY-RUN：未写入)")
        return

    # 写回（保持原结构）
    if wrap is None:
        out = masters
    else:
        if "data" in wrap:
            wrap["data"] = masters
        elif "masters" in wrap:
            wrap["masters"] = masters
        out = wrap
    with open(MASTER_PATH, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print("已写入: data/json/enemy_phase_masters.json")


if __name__ == "__main__":
    main()
