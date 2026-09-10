# 批次③ Task 4：残留甲清除（术语按 Task 0 裁决 B/C：法则→条令/能量卡→充能槽/
# 蓝图→图纸/进化→谱系/星级→等级；仅描述层生效，条目名不动走白名单）。
# 每条 old 必须在目标文件中唯一匹配，否则报错不写——宁漏改不误改。
import io
import sys
from pathlib import Path

REPO = Path(r"F:\godot fair duet\create\phase-war")

E = []  # (file, old, new)

def add(f, old, new):
    E.append((f, old, new))

# ── A. default_cards.gd（法则卡 type_line/描述——裁决 B 描述层）──
add("data/default_cards.gd", 'c.type_line = "法则 — 主动"', 'c.type_line = "条令 — 主动"')
add("data/default_cards.gd", 'c.type_line = "法则 — 被动"', 'c.type_line = "条令 — 被动"')
add("data/default_cards.gd", '"自蓝图印制；装配至相位仪红/蓝槽后,在战前环境满足时可激活。"',
    '"自图纸印制；装配至相位仪红/蓝槽后,在战前环境满足时可激活。"')

# ── B/C. 敌平台/装备 蓝图→图纸 ──
add("data/enemy_blueprints.gd", '"由%s时代敌军装备逆向解析而来的平台蓝图。"',
    '"由%s时代敌军装备逆向解析而来的平台图纸。"')
add("data/enemy_phase_equipment.gd", '"由敌方相位师装备数据生成的平台蓝图（展示用）。"',
    '"由敌方相位师装备数据生成的平台图纸（展示用）。"')
add("data/enemy_phase_equipment.gd", '"由敌方相位师装备数据生成的武器蓝图（展示用）。"',
    '"由敌方相位师装备数据生成的武器图纸（展示用）。"')
add("data/enemy_phase_equipment.gd", '"由敌方相位师装备数据生成的能量卡蓝图（展示用）。"',
    '"由敌方相位师装备数据生成的充能槽图纸（展示用）。"')
add("data/enemy_phase_equipment.gd", '"由统一相位仪池生成的相位仪蓝图（展示用）。"',
    '"由统一相位仪池生成的相位仪图纸（展示用）。"')

# ── E. intel_evolution_branches.gd 进化→谱系 ──
add("data/intel_evolution_branches.gd", "结合步兵战术与隐匿技术的混合进化", "结合步兵战术与隐匿技术的混合谱系")
add("data/intel_evolution_branches.gd", "研究重装甲弱点后开发的反坦克专家进化", "研究重装甲弱点后开发的反坦克专家谱系")
add("data/intel_evolution_branches.gd", "融合纳米技术与热能防护的主战坦克进化", "融合纳米技术与热能防护的主战坦克谱系")
add("data/intel_evolution_branches.gd", "将火炮装载到飞行平台的跨类型疯狂进化", "将火炮装载到飞行平台的跨类型谱系")

add("data/intel_manual_items.gd", '"（进化已退役）此图纸不再有用途，仅作纪念收藏"',
    '"（谱系已退役）此图纸不再有用途，仅作纪念收藏"')

# ── G. task_objective_types.json ──
add("data/json/task_objective_types.json", '"name": "解锁蓝图"', '"name": "解锁图纸"')
add("data/json/task_objective_types.json", '"description_template": "解锁{target}张蓝图"',
    '"description_template": "解锁{target}张图纸"')
add("data/json/task_objective_types.json", '"name": "合成物品"', '"name": "制造物品"')
add("data/json/task_objective_types.json", '"description_template": "合成{target}个物品"',
    '"description_template": "制造{target}个物品"')
add("data/json/task_objective_types.json", '"name": "星级通关"', '"name": "等级通关"')

# ── H. leaderboard_definitions.gd ──
add("data/leaderboard_definitions.gd", '"description": "已解锁的蓝图总数"',
    '"description": "已解锁的图纸总数"')

# ── J. phase_instruments.gd（名域 :26/:94 走白名单；此处修描述层）──
add("data/phase_instruments.gd", '"能量爆发：施放法则时所有单位 5 秒内伤害 +25%"',
    '"能量爆发：施放条令时所有单位 5 秒内伤害 +25%"')
add("data/phase_instruments.gd", '"yellow": return "能量卡"', '"yellow": return "充能槽"')

# ── K. bottom_instrument_bar.gd（活 UI：红蓝槽类型标签）──
add("scenes/ui/bottom_instrument_bar.gd", 'var display_name: String = "能量卡" if card.card_type == GC.CardType.ENERGY else',
    'var display_name: String = "充能槽" if card.card_type == GC.CardType.ENERGY else')
add("scenes/ui/bottom_instrument_bar.gd", '"主动法则" if law_kind == "active" else "被动法则"',
    '"主动条令" if law_kind == "active" else "被动条令"')
add("scenes/ui/bottom_instrument_bar.gd", '"red": return "主动法则"', '"red": return "主动条令"')
add("scenes/ui/bottom_instrument_bar.gd", '"blue": return "被动法则"', '"blue": return "被动条令"')

# ── L. store_panel.gd ──
add("scenes/ui/store_panel.gd", 'GC.CardType.ENERGY:      m_parts.append("能量卡")',
    'GC.CardType.ENERGY:      m_parts.append("充能槽")')
add("scenes/ui/store_panel.gd", 'GC.CardType.ENERGY:      info_parts.append("能量卡")',
    'GC.CardType.ENERGY:      info_parts.append("充能槽")')
add("scenes/ui/store_panel.gd", '"相位仪：星级决定槽位数量与能量上限；能量恢复加快战斗中能量回复"',
    '"相位仪：等级决定槽位数量与能量上限；能量恢复加快战斗中能量回复"')
add("scenes/ui/store_panel.gd", 'attr_parts.append("星级 %d" % star)', 'attr_parts.append("等级 %d" % star)')

# ── M. card_info_panel.gd（数值 3/1/30/10 全保留）──
add("scenes/ui/card_info_panel.gd", '"光环/能力星级：由卡牌等级折算（每 3 级 = 1 星，Lv30 满星 10★）"',
    '"光环/能力等级：由卡牌等级折算（每 3 级 = 1★，Lv30 满级 10★）"')
add("scenes/ui/card_info_panel.gd", 'type_label.text = "能量卡 · 提供 %d 能量"',
    'type_label.text = "充能槽 · 提供 %d 能量"')
add("scenes/ui/card_info_panel.gd", '[base + "StarSection/StarVBox/StarTitle", "星级"]',
    '[base + "StarSection/StarVBox/StarTitle", "等级"]')

# ── N. help_panel.gd（用户 v27.13 在途文件——工作区改，commit 外科暂存）──
add("scenes/ui/help_panel.gd", "等级同时决定光环/能力星级：每 3 级折合 1 星（Lv30 即满星 10★）",
    "等级同时决定光环/能力等级：每 3 级折合 1★（Lv30 即满级 10★）")
add("scenes/ui/help_panel.gd", "槽位数量随相位仪星级提升（最多 9 格）",
    "槽位数量随相位仪等级提升（最多 9 格）")
add("scenes/ui/help_panel.gd", "提升相位仪星级可增加槽位数量与能量上限",
    "提升相位仪等级可增加槽位数量与能量上限")
add("scenes/ui/help_panel.gd", "星级还决定战斗中可部署的[color=#88ccff]前沿范围[/color]（星级越高部署区越靠前）",
    "等级还决定战斗中可部署的[color=#88ccff]前沿范围[/color]（等级越高部署区越靠前）")
add("scenes/ui/help_panel.gd", "也可在势力商店获取", "也可在势力联络台的商店获取")
add("scenes/ui/help_panel.gd", "符文在背包的符文标签页装备与管理（移动基地卡牌墙 / 战斗屏背包同源）",
    "符文在背包的符文标签页装备与管理（移动基地卡仓 / 战斗屏背包同源）")

# ── O. growth_panel.gd（数值 5/10/15/20/25/30/3/1 保留）──
add("scenes/ui/growth_panel.gd", "等级进度：Lv5/10/15/20/25/30 各解锁一个词条节点；每 3 级折合 1 星光环/能力星级",
    "等级进度：Lv5/10/15/20/25/30 各解锁一个词条节点；每 3 级折合 1★ 光环/能力等级")

# ── P/Q. 排行/符文折叠卡 ──
add("scenes/ui/leaderboard/leaderboard_panel.gd", '_make_header_label("星级", 50,',
    '_make_header_label("等级", 50,')
add("scenes/ui/buff_fold_card.gd", '_make_kv_row("最高星级",', '_make_kv_row("最高等级",')

# ── R/S. 情报中心/单位详情 ──
add("scenes/ui/intelligence_hub_panel.gd", '"安装改造需要图纸（蓝图战后掉落，永久持有）；研究进度不替代图纸"',
    '"安装改造需要图纸（战后掉落的消耗品）；研究进度不替代图纸"')
add("scenes/ui/unit_progression_detail_view.gd", '_add_line("蓝图系统未就绪",',
    '_add_line("图纸系统未就绪",')

# ── T. evolution_graph_builder.gd ──
add("scripts/progression/evolution_graph_builder.gd", 'return "初始单位（无前置进化）"',
    'return "初始单位（无前置谱系）"')
add("scripts/progression/evolution_graph_builder.gd", 'return "基础进化"', 'return "基础谱系"')

# ── V/W. 情报谱系域 ──
add("scripts/systems/intel_discovery_manager.gd", '"低进化可用",', '"低谱系可用",')
add("scripts/systems/intel_discovery_manager.gd", '情报过半——该敌方形态的缴获卡可在「成长」面板进化为对应我方卡。',
    '情报过半——该敌方形态的缴获卡可在「成长」面板沿谱系进阶为对应我方卡。')
add("scripts/systems/intel_manual.gd", 'TIER_EVOLUTION:    return "进化资格已解锁 + 掉落率+50%"',
    'TIER_EVOLUTION:    return "谱系资格已解锁 + 掉落率+50%"')

# ── X. unit_lineage_config.gd 判定串（数值 5/10/2/5/3 保留）──
add("data/unit_lineage_config.gd", '"ok": "可进化",', '"ok": "可进阶",')
add("data/unit_lineage_config.gd", '"card_locked": "蓝图未解锁",', '"card_locked": "图纸未解锁",')
add("data/unit_lineage_config.gd", '"invalid_target": "进化目标不存在",', '"invalid_target": "谱系目标不存在",')
add("data/unit_lineage_config.gd", '"target_not_in_path": "目标不在该卡进化路线中",',
    '"target_not_in_path": "目标不在该卡谱系路线中",')
add("data/unit_lineage_config.gd", "基础进化需Lv5，势力分支需Lv10", "基础进阶需Lv5，势力分支需Lv10")
add("data/unit_lineage_config.gd", "改造模块不足（基础进化需2个，势力分支需5个）",
    "改造模块不足（基础进阶需2个，势力分支需5个）")
add("data/unit_lineage_config.gd", '"cross_class": "不能跨类型进化",', '"cross_class": "不能跨类型进阶",')
add("data/unit_lineage_config.gd", '"evo_blueprint_missing": "缺少进化蓝图（需从战斗中获得目标卡的进化蓝图）"',
    '"evo_blueprint_missing": "缺少谱系图纸（需从战斗中获得目标卡的谱系图纸）"')
add("data/unit_lineage_config.gd", "势力贡献度不足（势力分支进化需目标势力达到Lv3）",
    "势力贡献度不足（势力分支进阶需目标势力达到Lv3）")
add("data/unit_lineage_config.gd", '"evolution_not_unlocked_in_skill_tree": "进化能力未在相位师技能树解锁（需解锁概念武器分支的进化节点）"',
    '"evolution_not_unlocked_in_skill_tree": "谱系能力未在相位师技能树解锁（需解锁概念武器分支的谱系节点）"')

# ── Y. card_evolution_manager.gd（活显示层）──
add("managers/evolution/card_evolution_manager.gd", '"detail": "击败精英/Boss 敌人，战后结算几率掉落进化图纸"',
    '"detail": "击败精英/Boss 敌人，战后结算几率掉落谱系图纸"')
add("managers/evolution/card_evolution_manager.gd", 'return "需在相位师技能树解锁该时代的进化能力"',
    'return "需在相位师技能树解锁该时代的谱系能力"')

add("managers/manager_lazy_loader.gd", '"description": "情报进化分支"', '"description": "情报谱系分支"')

# ── AA. 相位仪能量卡补偿 toast（活路径）──
add("managers/phase_instrument_manager.gd", '"能量卡系统已移除，%s 补偿 %d 纳米材料"',
    '"充能槽系统已移除，%s 补偿 %d 纳米材料"')

# ── 扩充①：余烬要塞→移动基地（附录 B#2 活文案三处）──
add("scenes/bunker/bunker_main.gd", 'title.text = "余烬要塞 · 指南"', 'title.text = "移动基地 · 指南"')
add("scenes/world_map.gd", 'lh.tooltip_text = "余烬要塞（家）——点击回基地"',
    'lh.tooltip_text = "移动基地（家）——点击回基地"')
add("scenes/world_map.gd", 'home_lbl2.text = "余烬要塞"', 'home_lbl2.text = "移动基地"')

# ── 扩充②：英雄档案/遗物→同伴档案/同伴遗物（宪法 hero_archive 行已批）──
add("managers/bunker_manager.gd", '"需要 %d 份英雄遗物（当前 %d）——去击败驻守的相位师"',
    '"需要 %d 份同伴遗物（当前 %d）——去击败驻守的相位师"')
add("managers/bunker_manager.gd", 'reasons.append("英雄档案 %d/30" % _hero_fragments.size())',
    'reasons.append("同伴档案 %d/30" % _hero_fragments.size())')
add("scenes/bunker/bunker_main.gd", '"英雄档案解锁 ×%d：%s（%d/30）"',
    '"同伴档案解锁 ×%d：%s（%d/30）"')
add("data/bunker_room_defs.gd", '"function_note": "逝者的名字安放于此。随英雄档案解锁逐一点亮（P3）。"',
    '"function_note": "逝者的名字安放于此。随同伴档案解锁逐一点亮。"')
add("data/bunker_room_defs.gd", '"function_note": "情报中心与英雄档案。升级解锁分析仪（烧缴获卡得情报）。"',
    '"function_note": "情报中心与同伴档案。升级解锁分析仪（烧缴获卡得情报）。"')
add("data/bunker_room_defs.gd", '"note": "纪念铭牌：已纪念英雄可回看完整档案与遗言"',
    '"note": "纪念铭牌：已纪念同伴可回看完整档案与遗言"')
add("data/bunker_room_defs.gd", "集齐英雄档案后开启", "集齐同伴档案后开启")
add("scenes/bunker/ui/bunker_room_panel.gd", '"★ 另需英雄遗物 %d 份（当前 %d）——击败驻守相位师获取"',
    '"★ 另需同伴遗物 %d 份（当前 %d）——击败驻守相位师获取"')
add("scenes/bunker/ui/bunker_room_panel.gd", '["英雄档案", "hero_archive"],', '["同伴档案", "hero_archive"],')


def main() -> int:
    by_file = {}
    for f, old, new in E:
        by_file.setdefault(f, []).append((old, new))
    total, applied = len(E), 0
    for f, pairs in by_file.items():
        p = REPO / f
        src = io.open(p, encoding="utf-8").read()
        for old, new in pairs:
            n = src.count(old)
            if n != 1:
                print("[SKIP] %s 锚定 %d 处（须 1）：%s" % (f, n, old[:50]))
                continue
            src = src.replace(old, new)
            applied += 1
        io.open(p, "w", encoding="utf-8", newline="\n").write(src)
    print("applied %d/%d" % (applied, total))
    return 0 if applied == total else 1


if __name__ == "__main__":
    sys.exit(main())
