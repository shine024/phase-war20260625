extends RefCounted
class_name FactionSkillTree

## 技能节点数据结构
## id:          唯一ID
## name:        显示名称
## desc:        描述
## faction_id:  所属势力
## tier:        等级门槛（势力等级 >= tier 才能解锁）
## cost:        声望点消耗
## branch:      分支ID（同tier同branch只能选1个）
## effect_type: 效果类型（combat/deploy/resource/special）
## effects:     效果字典

const SKILL_TREE: Dictionary = {
	# ═══════════ 钢壁防务技能树 ═══════════
	"iron_wall_corp": [
		{"id": "sk_iron_def1", "name": "钢铁意志", "desc": "所有钢壁变体HP+8%",
		 "tier": 2, "cost": 1, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"hp": 0.08}}},
		{"id": "sk_iron_def2", "name": "快速部署", "desc": "所有钢壁变体部署速度+1",
		 "tier": 2, "cost": 1, "branch": "B", "effect_type": "deploy",
		 "effects": {"deploy_speed": 1}},
		{"id": "sk_iron_def3", "name": "复合装甲", "desc": "所有钢壁变体三维防御+12%",
		 "tier": 3, "cost": 1, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"def_light": 0.12, "def_armor": 0.12, "def_air": 0.12}}},
		{"id": "sk_iron_res1", "name": "声望加成", "desc": "战后钢壁声望+15%",
		 "tier": 3, "cost": 1, "branch": "B", "effect_type": "resource",
		 "effects": {"reputation_bonus": 0.15}},
		{"id": "sk_iron_def4", "name": "不屈防线", "desc": "HP低于30%时防御+25%",
		 "tier": 4, "cost": 2, "branch": "A", "effect_type": "special",
		 "effects": {"conditional": {"hp_below": 0.3, "stat_bonus": {"def_light": 0.25, "def_armor": 0.25}}}},
		{"id": "sk_iron_res2", "name": "纳米回收", "desc": "钢壁变体死亡返还15%部署能量",
		 "tier": 4, "cost": 2, "branch": "B", "effect_type": "special",
		 "effects": {"on_death_energy_return": 0.15}},
		{"id": "sk_iron_def5", "name": "壁垒强化", "desc": "所有钢壁变体HP+15%, 三维防御+10%",
		 "tier": 5, "cost": 2, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"hp": 0.15, "def_light": 0.10, "def_armor": 0.10, "def_air": 0.10}}},
		{"id": "sk_iron_dep1", "name": "要塞模式", "desc": "堡垒类部署-20%能量",
		 "tier": 5, "cost": 2, "branch": "B", "effect_type": "deploy",
		 "effects": {"energy_reduction": {"combat_kind": 4, "amount": 0.20}}},
		{"id": "sk_iron_sp1", "name": "钢铁壁垒", "desc": "钢壁变体周围2格友军防御+15%",
		 "tier": 7, "cost": 3, "branch": "A", "effect_type": "special",
		 "effects": {"aura": {"radius": 2.0, "stat_bonus": {"def_light": 0.15, "def_armor": 0.15}}}},
		{"id": "sk_iron_res3", "name": "军工效率", "desc": "声望获取+25%, 商店价格-10%",
		 "tier": 7, "cost": 3, "branch": "B", "effect_type": "resource",
		 "effects": {"reputation_bonus": 0.25, "shop_discount": 0.10}},
		{"id": "sk_iron_ult1", "name": "不可摧毁", "desc": "钢壁变体每60秒获得10%HP护盾",
		 "tier": 10, "cost": 5, "branch": "A", "effect_type": "special",
		 "effects": {"periodic_shield": {"interval": 60.0, "pct": 0.10}}},
		{"id": "sk_iron_ult2", "name": "钢铁洪流", "desc": "同时场上每多1个钢壁变体, 全体攻防+5%",
		 "tier": 10, "cost": 5, "branch": "B", "effect_type": "special",
		 "effects": {"stacking_bonus": {"per_unit": 1, "max": 5, "stat_bonus": {"atk_light": 0.05, "atk_armor": 0.05, "def_light": 0.05, "def_armor": 0.05}}}},
	],

	# ═══════════ 新星兵工技能树 ═══════════
	"nova_arms": [
		{"id": "sk_nova_atk1", "name": "火力全开", "desc": "新星变体三维攻击+10%",
		 "tier": 2, "cost": 1, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"atk_light": 0.10, "atk_armor": 0.10, "atk_air": 0.10}}},
		{"id": "sk_nova_spd1", "name": "快速装填", "desc": "新星变体攻击速度+8%",
		 "tier": 2, "cost": 1, "branch": "B", "effect_type": "combat",
		 "effects": {"stat_bonus": {"attack_speed": 0.08}}},
		{"id": "sk_nova_atk2", "name": "穿甲弹头", "desc": "新星变体对装甲伤害+15%",
		 "tier": 3, "cost": 1, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"atk_armor": 0.15}}},
		{"id": "sk_nova_res1", "name": "战利品猎人", "desc": "战后掉落率+12%",
		 "tier": 3, "cost": 1, "branch": "B", "effect_type": "resource",
		 "effects": {"drop_bonus": 0.12}},
		{"id": "sk_nova_atk3", "name": "过载射击", "desc": "攻击速度>1.5时暴击率+10%",
		 "tier": 4, "cost": 2, "branch": "A", "effect_type": "special",
		 "effects": {"conditional": {"atk_speed_above": 1.5, "crit_bonus": 0.10}}},
		{"id": "sk_nova_dep1", "name": "突击部署", "desc": "新星轻装/装甲部署-15%能量",
		 "tier": 4, "cost": 2, "branch": "B", "effect_type": "deploy",
		 "effects": {"energy_reduction": {"combat_kind": [0, 1], "amount": 0.15}}},
		{"id": "sk_nova_atk4", "name": "弹幕理论", "desc": "新星变体攻击+12%, 攻速+5%",
		 "tier": 5, "cost": 2, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"atk_light": 0.12, "atk_armor": 0.12, "attack_speed": 0.05}}},
		{"id": "sk_nova_sp1", "name": "击杀续能", "desc": "新星变体击杀敌人回复2%最大能量",
		 "tier": 5, "cost": 2, "branch": "B", "effect_type": "special",
		 "effects": {"on_kill_energy": 0.02}},
		{"id": "sk_nova_atk5", "name": "火力压制", "desc": "新星变体攻击使目标攻速-15%,持续3秒",
		 "tier": 7, "cost": 3, "branch": "A", "effect_type": "special",
		 "effects": {"on_hit_debuff": {"attack_speed_reduction": 0.15, "duration": 3.0}}},
		{"id": "sk_nova_res2", "name": "军工革新", "desc": "经验+20%, 强化成本-10%",
		 "tier": 7, "cost": 3, "branch": "B", "effect_type": "resource",
		 "effects": {"xp_bonus": 0.20, "enhance_discount": 0.10}},
		{"id": "sk_nova_ult1", "name": "末日火力", "desc": "新星变体首次攻击伤害+50%",
		 "tier": 10, "cost": 5, "branch": "A", "effect_type": "special",
		 "effects": {"first_hit_damage": 0.50}},
		{"id": "sk_nova_ult2", "name": "弹雨如注", "desc": "新星变体每次攻击有15%概率触发额外攻击",
		 "tier": 10, "cost": 5, "branch": "B", "effect_type": "special",
		 "effects": {"extra_attack_chance": 0.15}},
	],

	# ═══════════ 以太动力技能树 ═══════════
	"aether_dynamics": [
		{"id": "sk_aeth_spd1", "name": "极速部署", "desc": "以太变体部署速度+1",
		 "tier": 2, "cost": 1, "branch": "A", "effect_type": "deploy",
		 "effects": {"deploy_speed": 1}},
		{"id": "sk_aeth_dep1", "name": "能量节约", "desc": "以太变体部署-10%能量",
		 "tier": 2, "cost": 1, "branch": "B", "effect_type": "deploy",
		 "effects": {"energy_reduction": {"combat_kind": [0, 1, 2, 3], "amount": 0.10}}},
		{"id": "sk_aeth_spd2", "name": "高速机动", "desc": "以太变体移动速度+12%",
		 "tier": 3, "cost": 1, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"move_speed": 0.12}}},
		{"id": "sk_aeth_res1", "name": "能量回收", "desc": "战后额外获得10%能量",
		 "tier": 3, "cost": 1, "branch": "B", "effect_type": "resource",
		 "effects": {"energy_recover": 0.10}},
		{"id": "sk_aeth_spd3", "name": "闪电战术", "desc": "部署速度>5时首次攻击伤害+20%",
		 "tier": 4, "cost": 2, "branch": "A", "effect_type": "special",
		 "effects": {"conditional": {"deploy_speed_above": 5, "first_hit_damage": 0.20}}},
		{"id": "sk_aeth_dep2", "name": "空投支援", "desc": "空中单位部署-20%能量",
		 "tier": 4, "cost": 2, "branch": "B", "effect_type": "deploy",
		 "effects": {"energy_reduction": {"combat_kind": 3, "amount": 0.20}}},
		{"id": "sk_aeth_def1", "name": "闪避本能", "desc": "以太变体闪避率+10%",
		 "tier": 5, "cost": 2, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"dodge": 0.10}}},
		{"id": "sk_aeth_res2", "name": "战场补给", "desc": "声望+15%, 掉落率+8%",
		 "tier": 5, "cost": 2, "branch": "B", "effect_type": "resource",
		 "effects": {"reputation_bonus": 0.15, "drop_bonus": 0.08}},
		{"id": "sk_aeth_sp1", "name": "蜂群协同", "desc": "场上每多1个以太变体, 全体攻速+4%",
		 "tier": 7, "cost": 3, "branch": "A", "effect_type": "special",
		 "effects": {"stacking_bonus": {"per_unit": 1, "max": 5, "stat_bonus": {"attack_speed": 0.04}}}},
		{"id": "sk_aeth_res3", "name": "高效后勤", "desc": "经验+20%, 强化成本-15%",
		 "tier": 7, "cost": 3, "branch": "B", "effect_type": "resource",
		 "effects": {"xp_bonus": 0.20, "enhance_discount": 0.15}},
		{"id": "sk_aeth_ult1", "name": "光速打击", "desc": "以太变体部署速度>6时,攻击附带15%额外伤害",
		 "tier": 10, "cost": 5, "branch": "A", "effect_type": "special",
		 "effects": {"conditional": {"deploy_speed_above": 6, "damage_bonus": 0.15}}},
		{"id": "sk_aeth_ult2", "name": "无限续航", "desc": "以太变体每30秒回复5%最大HP",
		 "tier": 10, "cost": 5, "branch": "B", "effect_type": "special",
		 "effects": {"periodic_heal": {"interval": 30.0, "pct": 0.05}}},
	],

	# ═══════════ 量子后勤技能树 ═══════════
	"quantum_logistics": [
		{"id": "sk_quant_hp1", "name": "强化装甲", "desc": "量子变体HP+10%",
		 "tier": 2, "cost": 1, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"hp": 0.10}}},
		{"id": "sk_quant_res1", "name": "资源优化", "desc": "战后声望+15%",
		 "tier": 2, "cost": 1, "branch": "B", "effect_type": "resource",
		 "effects": {"reputation_bonus": 0.15}},
		{"id": "sk_quant_hp2", "name": "纳米修复", "desc": "量子变体HP回复+3%/秒",
		 "tier": 3, "cost": 1, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"hp_regen": 0.03}}},
		{"id": "sk_quant_dep1", "name": "快速建造", "desc": "堡垒/支援部署速度+1",
		 "tier": 3, "cost": 1, "branch": "B", "effect_type": "deploy",
		 "effects": {"deploy_speed": 1, "combat_kind_filter": [2, 4]}},
		{"id": "sk_quant_hp3", "name": "生命护盾", "desc": "量子变体受到的伤害-10%",
		 "tier": 4, "cost": 2, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"damage_reduction": 0.10}}},
		{"id": "sk_quant_res2", "name": "后勤专家", "desc": "掉落率+15%, 经验+10%",
		 "tier": 4, "cost": 2, "branch": "B", "effect_type": "resource",
		 "effects": {"drop_bonus": 0.15, "xp_bonus": 0.10}},
		{"id": "sk_quant_sp1", "name": "战场医疗", "desc": "量子变体死亡时周围2格友军回复10%HP",
		 "tier": 5, "cost": 2, "branch": "A", "effect_type": "special",
		 "effects": {"on_death_ally_heal": {"radius": 2.0, "pct": 0.10}}},
		{"id": "sk_quant_dep2", "name": "移动指挥", "desc": "移动基地部署-25%能量",
		 "tier": 5, "cost": 2, "branch": "B", "effect_type": "deploy",
		 "effects": {"energy_reduction": {"combat_kind": 4, "amount": 0.25}}},
		{"id": "sk_quant_sp2", "name": "持续修复光环", "desc": "量子变体周围3格友军每秒回复2%HP",
		 "tier": 7, "cost": 3, "branch": "A", "effect_type": "special",
		 "effects": {"aura": {"radius": 3.0, "hp_regen_pct": 0.02}}},
		{"id": "sk_quant_res3", "name": "供应链精通", "desc": "声望+25%, 商店-15%",
		 "tier": 7, "cost": 3, "branch": "B", "effect_type": "resource",
		 "effects": {"reputation_bonus": 0.25, "shop_discount": 0.15}},
		{"id": "sk_quant_ult1", "name": "不朽协议", "desc": "量子变体首次致命伤害时恢复30%HP(每单位一次)",
		 "tier": 10, "cost": 5, "branch": "A", "effect_type": "special",
		 "effects": {"death_save": {"pct": 0.30, "once": true}}},
		{"id": "sk_quant_ult2", "name": "量子纠缠", "desc": "场上每多1个量子变体, 全体HP回复+3%/秒",
		 "tier": 10, "cost": 5, "branch": "B", "effect_type": "special",
		 "effects": {"stacking_bonus": {"per_unit": 1, "max": 5, "stat_bonus": {"hp_regen": 0.03}}}},
	],

	# ═══════════ 螺旋侦察技能树 ═══════════
	"helix_recon": [
		{"id": "sk_helix_acc1", "name": "精准瞄准", "desc": "螺旋变体精准+10%",
		 "tier": 2, "cost": 1, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"accuracy": 0.10}}},
		{"id": "sk_helix_spd1", "name": "快速侦察", "desc": "螺旋变体部署速度+1",
		 "tier": 2, "cost": 1, "branch": "B", "effect_type": "deploy",
		 "effects": {"deploy_speed": 1}},
		{"id": "sk_helix_dodge1", "name": "光学迷彩", "desc": "螺旋变体闪避+8%",
		 "tier": 3, "cost": 1, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"dodge": 0.08}}},
		{"id": "sk_helix_res1", "name": "情报收益", "desc": "声望+15%, 掉落+10%",
		 "tier": 3, "cost": 1, "branch": "B", "effect_type": "resource",
		 "effects": {"reputation_bonus": 0.15, "drop_bonus": 0.10}},
		{"id": "sk_helix_range1", "name": "远程锁定", "desc": "螺旋变体射程+1",
		 "tier": 4, "cost": 2, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"range": 1}}},
		{"id": "sk_helix_dep1", "name": "隐蔽部署", "desc": "轻装/支援部署-15%能量",
		 "tier": 4, "cost": 2, "branch": "B", "effect_type": "deploy",
		 "effects": {"energy_reduction": {"combat_kind": [0, 2], "amount": 0.15}}},
		{"id": "sk_helix_crit1", "name": "弱点分析", "desc": "螺旋变体暴击率+8%, 暴击伤害+15%",
		 "tier": 5, "cost": 2, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"crit_chance": 0.08, "crit_damage": 0.15}}},
		{"id": "sk_helix_res2", "name": "侦察网络", "desc": "经验+15%, 强化-10%",
		 "tier": 5, "cost": 2, "branch": "B", "effect_type": "resource",
		 "effects": {"xp_bonus": 0.15, "enhance_discount": 0.10}},
		{"id": "sk_helix_sp1", "name": "精确打击", "desc": "螺旋变体对HP<30%目标伤害+30%",
		 "tier": 7, "cost": 3, "branch": "A", "effect_type": "special",
		 "effects": {"conditional": {"target_hp_below": 0.3, "damage_bonus": 0.30}}},
		{"id": "sk_helix_res3", "name": "战略情报", "desc": "声望+20%, 经验+20%",
		 "tier": 7, "cost": 3, "branch": "B", "effect_type": "resource",
		 "effects": {"reputation_bonus": 0.20, "xp_bonus": 0.20}},
		{"id": "sk_helix_ult1", "name": "先发制人", "desc": "螺旋变体部署后首次攻击伤害+60%",
		 "tier": 10, "cost": 5, "branch": "A", "effect_type": "special",
		 "effects": {"first_hit_damage": 0.60}},
		{"id": "sk_helix_ult2", "name": "全视之眼", "desc": "螺旋变体攻击无视20%防御",
		 "tier": 10, "cost": 5, "branch": "B", "effect_type": "special",
		 "effects": {"armor_penetration": 0.20}},
	],

	# ═══════════ 虚空相位技能树 ═══════════
	"void_research": [
		{"id": "sk_void_crit1", "name": "相位暴击", "desc": "虚空变体暴击率+10%",
		 "tier": 2, "cost": 1, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"crit_chance": 0.10}}},
		{"id": "sk_void_effect1", "name": "法则共鸣", "desc": "虚空变体效果+8%",
		 "tier": 2, "cost": 1, "branch": "B", "effect_type": "combat",
		 "effects": {"stat_bonus": {"effect": 0.08}}},
		{"id": "sk_void_crit2", "name": "暴击精通", "desc": "虚空变体暴击伤害+20%",
		 "tier": 3, "cost": 1, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"crit_damage": 0.20}}},
		{"id": "sk_void_res1", "name": "虚空采集", "desc": "声望+15%, 掉落+10%",
		 "tier": 3, "cost": 1, "branch": "B", "effect_type": "resource",
		 "effects": {"reputation_bonus": 0.15, "drop_bonus": 0.10}},
		{"id": "sk_void_sp1", "name": "相位闪避", "desc": "虚空变体受到暴击时30%概率闪避",
		 "tier": 4, "cost": 2, "branch": "A", "effect_type": "special",
		 "effects": {"conditional": {"on_crit_received", "dodge_chance": 0.30}}},
		{"id": "sk_void_dep1", "name": "虚空传送", "desc": "支援/空中部署-15%能量",
		 "tier": 4, "cost": 2, "branch": "B", "effect_type": "deploy",
		 "effects": {"energy_reduction": {"combat_kind": [2, 3], "amount": 0.15}}},
		{"id": "sk_void_atk1", "name": "维度撕裂", "desc": "虚空变体三维攻击+12%",
		 "tier": 5, "cost": 2, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"atk_light": 0.12, "atk_armor": 0.12, "atk_air": 0.12}}},
		{"id": "sk_void_res2", "name": "研究突破", "desc": "经验+20%, 声望+10%",
		 "tier": 5, "cost": 2, "branch": "B", "effect_type": "resource",
		 "effects": {"xp_bonus": 0.20, "reputation_bonus": 0.10}},
		{"id": "sk_void_sp2", "name": "虚空吸取", "desc": "虚空变体击杀敌人回复5%最大HP",
		 "tier": 7, "cost": 3, "branch": "A", "effect_type": "special",
		 "effects": {"on_kill_heal_pct": 0.05}},
		{"id": "sk_void_res3", "name": "维度研究", "desc": "声望+25%, 强化-15%",
		 "tier": 7, "cost": 3, "branch": "B", "effect_type": "resource",
		 "effects": {"reputation_bonus": 0.25, "enhance_discount": 0.15}},
		{"id": "sk_void_ult1", "name": "虚空湮灭", "desc": "虚空变体暴击时触发额外20%最大HP伤害",
		 "tier": 10, "cost": 5, "branch": "A", "effect_type": "special",
		 "effects": {"on_crit_bonus_damage_pct": 0.20}},
		{"id": "sk_void_ult2", "name": "相位穿梭", "desc": "虚空变体每45秒获得2秒无敌",
		 "tier": 10, "cost": 5, "branch": "B", "effect_type": "special",
		 "effects": {"periodic_invuln": {"interval": 45.0, "duration": 2.0}}},
	],

	# ═══════════ 边境联合技能树 ═══════════
	"frontier_union": [
		{"id": "sk_front_hp1", "name": "老兵体质", "desc": "边境变体HP+8%",
		 "tier": 2, "cost": 1, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"hp": 0.08}}},
		{"id": "sk_front_atk1", "name": "万金油", "desc": "边境变体三维攻击+6%",
		 "tier": 2, "cost": 1, "branch": "B", "effect_type": "combat",
		 "effects": {"stat_bonus": {"atk_light": 0.06, "atk_armor": 0.06, "atk_air": 0.06}}},
		{"id": "sk_front_def1", "name": "全面防护", "desc": "边境变体三维防御+8%",
		 "tier": 3, "cost": 1, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"def_light": 0.08, "def_armor": 0.08, "def_air": 0.08}}},
		{"id": "sk_front_res1", "name": "多面手", "desc": "声望+10%, 掉落+10%, 经验+10%",
		 "tier": 3, "cost": 1, "branch": "B", "effect_type": "resource",
		 "effects": {"reputation_bonus": 0.10, "drop_bonus": 0.10, "xp_bonus": 0.10}},
		{"id": "sk_front_spd1", "name": "快速反应", "desc": "边境变体部署速度+1",
		 "tier": 4, "cost": 2, "branch": "A", "effect_type": "deploy",
		 "effects": {"deploy_speed": 1}},
		{"id": "sk_front_dep1", "name": "全兵种减耗", "desc": "所有类型部署-10%能量",
		 "tier": 4, "cost": 2, "branch": "B", "effect_type": "deploy",
		 "effects": {"energy_reduction": {"combat_kind": [0, 1, 2, 3, 4], "amount": 0.10}}},
		{"id": "sk_front_all1", "name": "全能强化", "desc": "边境变体HP+8%, 三维攻防+5%",
		 "tier": 5, "cost": 2, "branch": "A", "effect_type": "combat",
		 "effects": {"stat_bonus": {"hp": 0.08, "atk_light": 0.05, "atk_armor": 0.05, "atk_air": 0.05, "def_light": 0.05, "def_armor": 0.05, "def_air": 0.05}}},
		{"id": "sk_front_res2", "name": "多方经营", "desc": "声望+15%, 经验+15%, 商店-10%",
		 "tier": 5, "cost": 2, "branch": "B", "effect_type": "resource",
		 "effects": {"reputation_bonus": 0.15, "xp_bonus": 0.15, "shop_discount": 0.10}},
		{"id": "sk_front_sp1", "name": "协同作战", "desc": "场上每有一个不同类型单位, 全体+3%攻防",
		 "tier": 7, "cost": 3, "branch": "A", "effect_type": "special",
		 "effects": {"variety_bonus": {"per_type": 1, "max": 5, "stat_bonus": {"atk_light": 0.03, "atk_armor": 0.03, "def_light": 0.03, "def_armor": 0.03}}}},
		{"id": "sk_front_res3", "name": "外交优势", "desc": "声望+25%, 强化-15%, 商店-10%",
		 "tier": 7, "cost": 3, "branch": "B", "effect_type": "resource",
		 "effects": {"reputation_bonus": 0.25, "enhance_discount": 0.15, "shop_discount": 0.10}},
		{"id": "sk_front_ult1", "name": "联合打击", "desc": "边境变体攻击使目标防御-10%,持续5秒",
		 "tier": 10, "cost": 5, "branch": "A", "effect_type": "special",
		 "effects": {"on_hit_debuff": {"defense_reduction": 0.10, "duration": 5.0}}},
		{"id": "sk_front_ult2", "name": "百战之师", "desc": "边境变体HP+15%, 三维攻防+8%, 闪避+5%",
		 "tier": 10, "cost": 5, "branch": "B", "effect_type": "combat",
		 "effects": {"stat_bonus": {"hp": 0.15, "atk_light": 0.08, "atk_armor": 0.08, "atk_air": 0.08, "def_light": 0.08, "def_armor": 0.08, "def_air": 0.08, "dodge": 0.05}}},
	],
}

## 获取势力技能列表
static func get_skills_for_faction(faction_id: String) -> Array:
	return SKILL_TREE.get(faction_id, []).duplicate(true)

## 获取指定tier的技能
static func get_skills_at_tier(faction_id: String, tier: int) -> Array:
	var all: Array = get_skills_for_faction(faction_id)
	var out: Array = []
	for s in all:
		if int(s.get("tier", 0)) == tier:
			out.append(s)
	return out

## 获取技能定义
static func get_skill(faction_id: String, skill_id: String) -> Dictionary:
	for s in get_skills_for_faction(faction_id):
		if s.get("id", "") == skill_id:
			return s.duplicate(true)
	return {}

## 计算势力可用技能点总数
static func max_skill_points_at_level(level: int) -> int:
	match level:
		0, 1: return 0
		2: return 1
		3: return 2
		4: return 3
		5: return 5
		6: return 7
		7: return 9
		8: return 11
		9: return 13
		10: return 15
		_: return 15

## 获取所有势力ID
static func get_all_faction_ids() -> Array:
	return SKILL_TREE.keys()
