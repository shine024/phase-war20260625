# -*- coding: utf-8 -*-
import os
import re

REPO = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))

CN: dict[str, str] = {
    "res://assets/backgrounds/bg_04.png": "世界地图背景04",
    "res://assets/backgrounds/bg_05.png": "世界地图背景05",
    "res://assets/backgrounds/bg_06.png": "世界地图背景06",
    "res://assets/backgrounds/bg_07.png": "世界地图背景07",
    "res://assets/backgrounds/bg_08.png": "世界地图背景08",
    "res://assets/backgrounds/bg_09.png": "世界地图背景09",
    "res://assets/backgrounds/bg_10.png": "世界地图背景10",
    "res://assets/backgrounds/bg_11.png": "世界地图背景11",
    "res://assets/backgrounds/bg_12.png": "世界地图背景12",
    "res://assets/phase_field/player_phase_field.png": "我方相位场",
    "res://assets/phase_field/enemy_phase_field.png": "敌方相位场",
    "res://assets/icons/drops/blueprint.png": "蓝图掉落",
    "res://assets/icons/drops/boost.png": "增益掉落",
    "res://assets/icons/drops/card.png": "卡牌掉落",
    "res://assets/icons/drops/default.png": "默认掉落",
    "res://assets/icons/drops/energy.png": "能量掉落",
    "res://assets/icons/drops/energy_blueprint.png": "能量蓝图掉落",
    "res://assets/icons/drops/law_blueprint.png": "法则蓝图掉落",
    "res://assets/icons/drops/law_card.png": "法则卡掉落",
    "res://assets/icons/drops/lore.png": "档案掉落",
    "res://assets/icons/drops/material.png": "材料掉落",
    "res://assets/resources/basic_nano.png": "纳米材料",
    "res://assets/resources/alloy.png": "合金",
    "res://assets/resources/crystal.png": "晶体",
    "res://assets/resources/energy_block.png": "能量块",
    "res://assets/cards/frames/common.png": "普通边框",
    "res://assets/cards/frames/uncommon.png": "优秀边框",
    "res://assets/cards/frames/rare.png": "稀有边框",
    "res://assets/cards/frames/epic.png": "史诗边框",
    "res://assets/cards/frames/legendary.png": "传说边框",
    "res://assets/ui/factions/neutral_128.png": "中立势力Logo128",
    "res://assets/ui/factions/neutral_32.png": "中立势力Logo32",
    "res://assets/ui/factions/iron_wall_corp_128.png": "钢壁防务公司Logo128",
    "res://assets/ui/factions/iron_wall_corp_32.png": "钢壁防务公司Logo32",
    "res://assets/ui/factions/nova_arms_128.png": "新星兵工制造Logo128",
    "res://assets/ui/factions/nova_arms_32.png": "新星兵工制造Logo32",
    "res://assets/ui/factions/aether_dynamics_128.png": "以太动力重工Logo128",
    "res://assets/ui/factions/aether_dynamics_32.png": "以太动力重工Logo32",
    "res://assets/ui/factions/quantum_logistics_128.png": "量子后勤集团Logo128",
    "res://assets/ui/factions/quantum_logistics_32.png": "量子后勤集团Logo32",
    "res://assets/ui/factions/helix_recon_128.png": "螺旋侦察系统Logo128",
    "res://assets/ui/factions/helix_recon_32.png": "螺旋侦察系统Logo32",
    "res://assets/ui/factions/void_research_128.png": "虚空相位研究所Logo128",
    "res://assets/ui/factions/void_research_32.png": "虚空相位研究所Logo32",
    "res://assets/ui/factions/frontier_union_128.png": "边境联合公司Logo128",
    "res://assets/ui/factions/frontier_union_32.png": "边境联合公司Logo32",
    "res://assets/ui/stars/star_1.png": "1星",
    "res://assets/ui/stars/star_2.png": "2星",
    "res://assets/ui/stars/star_3.png": "3星",
    "res://assets/ui/stars/star_4.png": "4星",
    "res://assets/ui/stars/star_5.png": "5星",
    "res://assets/ui/stars/star_6.png": "6星",
    "res://assets/ui/stars/star_7.png": "7星",
    "res://assets/ui/stars/star_8.png": "8星",
    "res://assets/ui/instruments/pi_generic_01.png": "巡航I型",
    "res://assets/ui/instruments/pi_generic_02.png": "巡航II型",
    "res://assets/ui/instruments/pi_generic_03.png": "巡航III型",
    "res://assets/ui/instruments/pi_generic_04.png": "锋线III型",
    "res://assets/ui/instruments/pi_generic_05.png": "锋线IV型",
    "res://assets/ui/instruments/pi_generic_06.png": "壁垒IV型",
    "res://assets/ui/instruments/pi_generic_07.png": "壁垒V型",
    "res://assets/ui/instruments/pi_generic_08.png": "脉冲V型",
    "res://assets/ui/instruments/pi_generic_09.png": "脉冲VI型",
    "res://assets/ui/instruments/pi_generic_10.png": "星链VI型",
    "res://assets/ui/instruments/pi_generic_11.png": "星链VII型",
    "res://assets/ui/instruments/pi_generic_12.png": "天穹VII型",
    "res://assets/ui/instruments/pi_aegis_01.png": "神盾-前哨",
    "res://assets/ui/instruments/pi_aegis_02.png": "神盾-方阵",
    "res://assets/ui/instruments/pi_aegis_03.png": "神盾-穹顶",
    "res://assets/ui/instruments/pi_aegis_04.png": "神盾-壁垒核",
    "res://assets/ui/instruments/pi_helix_01.png": "螺旋-猎线",
    "res://assets/ui/instruments/pi_helix_02.png": "螺旋-织网",
    "res://assets/ui/instruments/pi_helix_03.png": "螺旋-神经束",
    "res://assets/ui/instruments/pi_nova_01.png": "新星-回路",
    "res://assets/ui/instruments/pi_nova_02.png": "新星-灼流",
    "res://assets/ui/instruments/pi_nova_03.png": "新星-超弦",
    "res://assets/ui/instruments/pi_nova_04.png": "新星-裂变庭",
    "res://assets/ui/instruments/pi_iron_01.png": "铁幕-重锚",
    "res://assets/ui/instruments/pi_iron_02.png": "铁幕-铸链",
    "res://assets/ui/instruments/pi_iron_03.png": "铁幕-王座",
    "res://assets/ui/instruments/pi_umbra_01.png": "影幕-薄刃",
    "res://assets/ui/instruments/pi_umbra_02.png": "影幕-折光",
    "res://assets/ui/instruments/pi_umbra_03.png": "影幕-寂静域",
    "res://assets/ui/instruments/pi_atlas_01.png": "擎天-工蜂",
    "res://assets/ui/instruments/pi_atlas_02.png": "擎天-梁柱",
    "res://assets/ui/instruments/pi_atlas_03.png": "擎天-桥核",
    "res://assets/ui/instruments/pi_eon_01.png": "永纪-秒针",
    "res://assets/ui/instruments/pi_eon_02.png": "永纪-时阶",
    "res://assets/ui/instruments/pi_eon_03.png": "永纪-终式",
    "res://assets/ui/instruments/pi_atk.png": "卡牌伤害+%",
    "res://assets/ui/instruments/pi_def.png": "防御+%",
    "res://assets/ui/instruments/pi_hp.png": "生命+%",
    "res://assets/ui/instruments/pi_xp.png": "经验+%",
    "res://assets/ui/instruments/pi_drop.png": "掉落+%",
    "res://assets/ui/instruments/pi_energy_out.png": "能量输出+%",
    "res://assets/ui/instruments/pi_energy_rec.png": "能量恢复+%",
    "res://assets/ui/instruments/pi_energy_cost.png": "能量消耗-X",
    "res://assets/ui/instruments/pi_deploy_range.png": "部署范围+%",
    "res://assets/ui/instruments/pi_crit.png": "暴击率+%",
    "res://assets/ui/instruments/pi_crit_dmg.png": "暴击伤害+%",
    "res://assets/ui/instruments/pi_move_speed.png": "移速+%",
    "res://assets/ui/instruments/pi_attack_speed.png": "攻速+%",
    "res://assets/ui/instruments/pi_r_first_deploy.png": "初次部署",
    "res://assets/ui/instruments/pi_r_kill_energy.png": "战斗续能",
    "res://assets/ui/instruments/pi_r_law_boost.png": "法则共鸣",
    "res://assets/ui/instruments/pi_r_energy_fountain.png": "能量涌泉",
    "res://assets/ui/instruments/pi_r_dmg_reflect.png": "伤害反射",
    "res://assets/ui/instruments/pi_r_respawn.png": "相位重生",
    "res://assets/ui/instruments/pi_r_shield.png": "初始护盾",
    "res://assets/ui/instruments/pi_r_cascade.png": "连锁反应",
    "res://assets/ui/instruments/pi_r_overload.png": "过载强化",
    "res://assets/ui/instruments/pi_r_last_stand.png": "最后意志",
    "res://assets/ui/instruments/pi_r_energy_burst.png": "能量爆发",
    "res://assets/ui/instruments/pi_r_scale.png": "越战越强",
    "res://assets/ui/instruments/pi_r_free_deploy.png": "零成本部署",
}


def disk(res_path: str) -> str:
    return os.path.join(REPO, res_path.replace("res://", "").replace("/", os.sep))


def all_expected() -> list[str]:
    paths: list[str] = []
    for i in range(4, 13):
        paths.append(f"res://assets/backgrounds/bg_{i:02d}.png")
    for name in (
        "player_phase_field.png", "enemy_phase_field.png",
    ):
        paths.append(f"res://assets/phase_field/{name}")
    for name in (
        "blueprint.png", "boost.png", "card.png", "default.png", "energy.png",
        "energy_blueprint.png", "law_blueprint.png", "law_card.png", "lore.png", "material.png",
    ):
        paths.append(f"res://assets/icons/drops/{name}")
    for name in ("basic_nano.png", "alloy.png", "crystal.png", "energy_block.png"):
        paths.append(f"res://assets/resources/{name}")
    for name in ("common.png", "uncommon.png", "rare.png", "epic.png", "legendary.png"):
        paths.append(f"res://assets/cards/frames/{name}")
    for fid in (
        "neutral", "iron_wall_corp", "nova_arms", "aether_dynamics",
        "quantum_logistics", "helix_recon", "void_research", "frontier_union",
    ):
        paths.append(f"res://assets/ui/factions/{fid}_128.png")
        paths.append(f"res://assets/ui/factions/{fid}_32.png")
    for i in range(1, 9):
        paths.append(f"res://assets/ui/stars/star_{i}.png")
    pi_gd = open(os.path.join(REPO, "data", "phase_instruments.gd"), encoding="utf-8").read()
    pi_ids = set(re.findall(r'_make_def\("(pi_[^"]+)"', pi_gd))
    pi_ids |= set(re.findall(r'\{"id":"(pi_[^"]+)"', pi_gd))
    for pid in sorted(pi_ids):
        paths.append(f"res://assets/ui/instruments/{pid}.png")
    return paths


def main() -> None:
    expected = all_expected()
    missing = [p for p in expected if not os.path.isfile(disk(p))]
    found = [p for p in expected if os.path.isfile(disk(p))]

    out = os.path.join(REPO, "docs", "missing_image_paths.txt")
    lines = [
        "# 缺失图片路径清单（一行一个）",
        f"# 扫描：2026-05-22 | 仍缺 {len(missing)} 项 | 已有 {len(found)} 项",
        "# 单位卡图 assets/card_icons/units/ 100 张齐全，不在此列",
        "# 格式：res://路径  # 中文名",
        "",
    ]
    for p in missing:
        cn = CN.get(p, "")
        lines.append(f"{p}  # {cn}" if cn else p)
    lines.extend(["", f"# ── 已有 {len(found)} 项（供对照）──"])
    for p in found:
        cn = CN.get(p, "")
        lines.append(f"# {p}  # {cn}" if cn else f"# {p}")

    open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print(f"missing={len(missing)} found={len(found)}")
    for p in missing:
        print(p)


if __name__ == "__main__":
    main()
