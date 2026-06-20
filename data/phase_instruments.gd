extends RefCounted
## 相位仪配置表：通用 + 势力专属

const SOURCE_SHOP := "shop"
const SOURCE_DROP := "drop"
const DROP_STANDARD_MULT := 1.5

const STANDARD_PROPERTY_POOL: Array[Dictionary] = [
	{"id":"pi_atk","name":"卡牌伤害+%","rarity":"Common","min_star":1},
	{"id":"pi_def","name":"防御+%","rarity":"Common","min_star":1},
	{"id":"pi_hp","name":"生命+%","rarity":"Common","min_star":1},
	{"id":"pi_xp","name":"经验+%","rarity":"Common","min_star":1},
	{"id":"pi_drop","name":"掉落+%","rarity":"Common","min_star":1},
	{"id":"pi_energy_out","name":"能量输出+%","rarity":"Common","min_star":1},
	{"id":"pi_energy_rec","name":"能量恢复+%","rarity":"Common","min_star":1},
	{"id":"pi_energy_cost","name":"能量消耗-X","rarity":"Uncommon","min_star":3},
	{"id":"pi_deploy_range","name":"部署范围+%","rarity":"Common","min_star":2},
	{"id":"pi_crit","name":"暴击率+%","rarity":"Uncommon","min_star":2},
	{"id":"pi_crit_dmg","name":"暴击伤害+%","rarity":"Uncommon","min_star":2},
	{"id":"pi_move_speed","name":"移速+%","rarity":"Uncommon","min_star":2},
	{"id":"pi_attack_speed","name":"攻速+%","rarity":"Uncommon","min_star":3},
]

const RARE_PROPERTY_POOL: Array[Dictionary] = [
	{"id":"pi_r_first_deploy","name":"初次部署","rarity":"Rare","min_star":2},
	{"id":"pi_r_kill_energy","name":"战斗续能","rarity":"Rare","min_star":3},
	{"id":"pi_r_law_boost","name":"法则共鸣","rarity":"Rare","min_star":3},
	{"id":"pi_r_energy_fountain","name":"能量涌泉","rarity":"Rare","min_star":3},
	{"id":"pi_r_dmg_reflect","name":"伤害反射","rarity":"Rare","min_star":4},
	{"id":"pi_r_respawn","name":"相位重生","rarity":"Epic","min_star":5},
	{"id":"pi_r_shield","name":"初始护盾","rarity":"Epic","min_star":5},
	{"id":"pi_r_cascade","name":"连锁反应","rarity":"Epic","min_star":5},
	{"id":"pi_r_overload","name":"过载强化","rarity":"Epic","min_star":6},
	{"id":"pi_r_last_stand","name":"最后意志","rarity":"Epic","min_star":6},
	{"id":"pi_r_energy_burst","name":"能量爆发","rarity":"Epic","min_star":6},
	{"id":"pi_r_scale","name":"越战越强","rarity":"Legendary","min_star":7},
	{"id":"pi_r_free_deploy","name":"零成本部署","rarity":"Legendary","min_star":7},
]

static func _round2(v: float) -> float:
	return floor(v * 100.0 + 0.5) / 100.0

static func _format_percent(v: float) -> String:
	var p: float = v * 100.0
	if is_equal_approx(p, float(int(round(p)))):
		return str(int(round(p)))
	return "%.1f" % p

static func get_standard_property_value(property_id: String, star: int, source: String = SOURCE_SHOP) -> float:
	var s: int = clampi(star, 1, 7)
	var mult: float = DROP_STANDARD_MULT if source == SOURCE_DROP else 1.0
	match property_id:
		"pi_atk":
			return _round2(float(s) * 0.02 * mult)
		"pi_def":
			return _round2(float(s) * 0.01 * mult)
		"pi_hp":
			return _round2(float(s) * 0.015 * mult)
		"pi_xp":
			return _round2(float(s) * 0.03 * mult)
		"pi_drop":
			return _round2(float(s) * 0.02 * mult)
		"pi_energy_out":
			return _round2(float(s) * 0.02 * mult)
		"pi_energy_rec":
			return _round2(float(s) * 0.03 * mult)
		"pi_energy_cost":
			return float(floor(float(s) / 2.0))
		"pi_deploy_range":
			return _round2(float(s) * 0.03 * mult)
		"pi_crit":
			return _round2(float(s) * 0.01 * mult)
		"pi_crit_dmg":
			return _round2(float(s) * 0.03 * mult)
		"pi_move_speed":
			return _round2(float(s) * 0.02 * mult)
		"pi_attack_speed":
			return _round2(float(s) * 0.015 * mult)
	return 0.0

static func build_property_display(property_id: String, value: float) -> String:
	match property_id:
		"pi_atk": return "卡牌伤害 +%s%%" % _format_percent(value)
		"pi_def": return "防御 +%s%%" % _format_percent(value)
		"pi_hp": return "生命 +%s%%" % _format_percent(value)
		"pi_xp": return "经验 +%s%%" % _format_percent(value)
		"pi_drop": return "掉落 +%s%%" % _format_percent(value)
		"pi_energy_out": return "能量输出 +%s%%" % _format_percent(value)
		"pi_energy_rec": return "能量恢复 +%s%%" % _format_percent(value)
		"pi_energy_cost": return "能量消耗 -%d" % int(round(value))
		"pi_deploy_range": return "部署范围 +%s%%" % _format_percent(value)
		"pi_crit": return "暴击率 +%s%%" % _format_percent(value)
		"pi_crit_dmg": return "暴击伤害 +%s%%" % _format_percent(value)
		"pi_move_speed": return "移速 +%s%%" % _format_percent(value)
		"pi_attack_speed": return "攻速 +%s%%" % _format_percent(value)
		"pi_r_first_deploy": return "初次部署：首次部署任何单位不消耗能量"
		"pi_r_kill_energy": return "战斗续能：每击杀 1 个敌人恢复 20 点能量"
		"pi_r_law_boost": return "法则共鸣：所有法则效果 +20%"
		"pi_r_energy_fountain": return "能量涌泉：每 10 秒获得 10 点免费能量"
		"pi_r_dmg_reflect": return "伤害反射：受到伤害的 25% 反弹给攻击者"
		"pi_r_respawn": return "相位重生：单位死亡 50% 几率立即重新部署（冷却 15 秒）"
		"pi_r_shield": return "初始护盾：战斗开始时所有单位获得 200 点护盾"
		"pi_r_cascade": return "连锁反应：单位死亡时对周围敌人造成攻击力 50% 的伤害"
		"pi_r_overload": return "过载强化：单位生命 <50% 时伤害 +25%"
		"pi_r_last_stand": return "最后意志：单位死亡前最后攻击伤害 ×2.5"
		"pi_r_energy_burst": return "能量爆发：施放法则时所有单位 5 秒内伤害 +25%"
		"pi_r_scale": return "越战越强：每存在 10 秒单位全属性 +3%（上限 45%）"
		"pi_r_free_deploy": return "零成本部署：部署消耗有 30% 几率为 0（每单位限 1 次）"
	return property_id

static func build_default_shop_properties(star: int) -> Array[Dictionary]:
	var s: int = clampi(star, 1, 7)
	var available: Array[Dictionary] = []
	for d in STANDARD_PROPERTY_POOL:
		if s >= int(d.get("min_star", 1)):
			available.append(d)
	available.shuffle()
	var chosen: Array[Dictionary] = []
	var cnt: int = mini(s, available.size())
	for i in range(cnt):
		var pdef: Dictionary = available[i]
		var pid: String = String(pdef.get("id", ""))
		var val: float = get_standard_property_value(pid, s, SOURCE_SHOP)
		chosen.append({"id": pid, "value": val, "display": build_property_display(pid, val), "rarity": String(pdef.get("rarity", "Common"))})
	return chosen

# ─────────────────────────────────────────────
#  v6.6: 7星相位仪主动特殊能力定义
#  type: periodic(周期触发) | on_battle_start(开局一次性) | passive(被动常驻)
#  低星配降级版（数值减半/间隔更长/持续时间更短）
# ─────────────────────────────────────────────

## 1. 火炮连发（新星势力）
## 每 interval 秒连发 shots 发，每发间隔 shot_interval 秒，对敌方随机单位造成伤害
static func ability_artillery_barrage(star: int) -> Dictionary:
	var interval: float = 10.0
	var shots: int = 7
	var shot_interval: float = 1.0
	match star:
		4: interval = 20.0; shots = 3; shot_interval = 1.5
		6: interval = 15.0; shots = 5; shot_interval = 1.2
	return {
		"id": "artillery_barrage",
		"name": "火炮连发",
		"type": "periodic",
		"params": {"interval": interval, "shots": shots, "shot_interval": shot_interval, "target": "enemy_random"},
		"description": "每%d秒连发%d发，每发间隔%.1f秒" % [int(interval), shots, shot_interval],
	}

## 2. 幻影克隆（螺旋势力）— 同一战斗卡可放2个单位，克隆体+攻/血
static func ability_phantom_clone(star: int) -> Dictionary:
	var atk_bonus: float = 1.0   # +100%
	var hp_bonus: float = 0.8    # +80%
	match star:
		3: atk_bonus = 0.2; hp_bonus = 0.15
		5: atk_bonus = 0.5; hp_bonus = 0.4
	return {
		"id": "phantom_clone",
		"name": "幻影克隆",
		"type": "passive",
		"params": {"deploy_count": 2, "clone_atk_bonus": atk_bonus, "clone_hp_bonus": hp_bonus},
		"description": "每张战斗卡可放置2个单位，克隆体攻击+%d%%、血量+%d%%" % [int(atk_bonus * 100), int(hp_bonus * 100)],
	}

## 3. 直射穿透（影幕势力）— 100%穿透，每穿一个目标衰减
static func ability_piercing_shot(star: int) -> Dictionary:
	var pen_ratio: float = 1.0   # 100%
	var falloff: float = 0.1     # 每穿一个衰减10%
	match star:
		3: pen_ratio = 0.4; falloff = 0.2
		6: pen_ratio = 0.7; falloff = 0.15
	return {
		"id": "piercing_shot",
		"name": "直射穿透",
		"type": "passive",
		"params": {"pen_ratio": pen_ratio, "falloff_per_target": falloff},
		"description": "直射攻击%d%%穿透，每穿透一个目标衰减%d%%" % [int(pen_ratio * 100), int(falloff * 100)],
	}

## 4. 免能量（擎天势力）— 布置卡片免能量（7星=全免，低星=减半/减30%）
static func ability_free_energy(star: int) -> Dictionary:
	var cost_mult: float = 0.0   # 7星：完全免费
	match star:
		4: cost_mult = 0.7
		6: cost_mult = 0.5
	return {
		"id": "free_energy",
		"name": "免能量部署",
		"type": "passive",
		"params": {"deploy_cost_multiplier": cost_mult},
		"description": "部署能量消耗减至%d%%" % [int(cost_mult * 100)],
	}

## 5. 核子轰炸（永纪势力）— 每 N 秒对敌方全体造成大量伤害
static func ability_nuclear_bombardment(star: int) -> Dictionary:
	var interval: float = 30.0
	var dmg_mult: float = 1.0   # 基于攻击力的倍率
	match star:
		2: interval = 60.0; dmg_mult = 0.5
		5: interval = 45.0; dmg_mult = 0.75
	return {
		"id": "nuclear_bombardment",
		"name": "核子轰炸",
		"type": "periodic",
		"params": {"interval": interval, "dmg_mult": dmg_mult, "target": "enemy_all"},
		"description": "每%d秒对敌方全体造成核子轰炸" % [int(interval)],
	}

## 6. 致命酸雨（神盾势力）— 开局触发，持续 N 秒敌方按百分比掉血
static func ability_acid_rain(star: int) -> Dictionary:
	var duration: float = 30.0
	var hp_pct_per_sec: float = 0.02   # 每秒掉2%最大血量
	match star:
		4: duration = 12.0; hp_pct_per_sec = 0.015
		6: duration = 20.0; hp_pct_per_sec = 0.018
	return {
		"id": "acid_rain",
		"name": "致命酸雨",
		"type": "on_battle_start",
		"params": {"duration": duration, "hp_pct_per_sec": hp_pct_per_sec, "target": "enemy_all"},
		"description": "开局触发致命酸雨，持续%d秒，敌方每秒掉%.1f%%最大血量" % [int(duration), hp_pct_per_sec * 100],
	}

## 7. 巨型能量罩（通用势力）— 开局我方全体获得固定血量护盾
static func ability_mega_shield(star: int) -> Dictionary:
	var shield_amount: float = 20000.0
	match star:
		4: shield_amount = 5000.0
		6: shield_amount = 10000.0
	return {
		"id": "mega_shield",
		"name": "巨型能量罩",
		"type": "on_battle_start",
		"params": {"shield_amount": shield_amount, "target": "player_all"},
		"description": "开局为我方全体笼罩%.0f血量护盾" % [shield_amount],
	}


## 通用相位仪布局（平衡型）
## v6.2：移除 red/blue 法则槽，新增 rune 符文槽（替代法则系统）
## 槽位类型：green=战斗卡(max6), yellow=能量卡(max2), rune=符文(max6)
## 每个星级的分配不同，体现策略变化——不是每级都平均增长
const _STAR_LAYOUT := {
	1: {"green": 1, "yellow": 1, "rune": 1, "spawn_range_ratio": 0.30},   # 3格：起步
	2: {"green": 2, "yellow": 1, "rune": 1, "spawn_range_ratio": 0.40},   # 4格：+1战斗
	3: {"green": 2, "yellow": 1, "rune": 3, "spawn_range_ratio": 0.55},   # 6格：侧重符文
	4: {"green": 3, "yellow": 2, "rune": 2, "spawn_range_ratio": 0.70},   # 7格：侧重战斗+能量
	5: {"green": 4, "yellow": 1, "rune": 4, "spawn_range_ratio": 0.82},   # 9格：均衡扩展
	6: {"green": 3, "yellow": 2, "rune": 5, "spawn_range_ratio": 0.92},   # 10格：侧重符文
	7: {"green": 5, "yellow": 2, "rune": 4, "spawn_range_ratio": 1.00},   # 11格：侧重战斗（高星追求火力）
}

## 势力专属布局 - 每个势力有独特的格子分配特点
## v6.2：red/blue 法则槽全部改为 rune 符文槽
## 每个势力的槽位分配有独特侧重——不全是满配6+6，有取舍

# aether_dynamics (神盾): 防御特化 - 偏能量+符文，战斗卡少
const _FACTION_LAYOUT_AEGIS := {
	2: {"green": 1, "yellow": 2, "rune": 2, "spawn_range_ratio": 0.40},
	4: {"green": 2, "yellow": 2, "rune": 3, "spawn_range_ratio": 0.70},
	6: {"green": 3, "yellow": 2, "rune": 4, "spawn_range_ratio": 0.92},
	7: {"green": 3, "yellow": 2, "rune": 6, "spawn_range_ratio": 1.00},   # 11格：极限符文
}

# helix_recon (螺旋): 侦查特化 - 极限战斗卡，符文少
const _FACTION_LAYOUT_HELIX := {
	1: {"green": 2, "yellow": 1, "rune": 1, "spawn_range_ratio": 0.30},
	3: {"green": 4, "yellow": 1, "rune": 1, "spawn_range_ratio": 0.55},
	5: {"green": 6, "yellow": 1, "rune": 2, "spawn_range_ratio": 0.82},   # 9格：满战斗卡
	7: {"green": 6, "yellow": 2, "rune": 3, "spawn_range_ratio": 1.00},   # v6.6: 11格（幻影核）
}

# nova_arms (新星): 火力特化 - 战斗+符文均衡，能量少
const _FACTION_LAYOUT_NOVA := {
	2: {"green": 2, "yellow": 1, "rune": 2, "spawn_range_ratio": 0.40},
	4: {"green": 3, "yellow": 1, "rune": 3, "spawn_range_ratio": 0.70},
	6: {"green": 4, "yellow": 1, "rune": 4, "spawn_range_ratio": 0.92},
	7: {"green": 5, "yellow": 1, "rune": 5, "spawn_range_ratio": 1.00},   # 11格：战斗+符文双高
}

# iron_wall_corp (铁幕): 坦克特化 - 偏能量+战斗，符文中等
const _FACTION_LAYOUT_IRON := {
	3: {"green": 3, "yellow": 2, "rune": 2, "spawn_range_ratio": 0.55},
	5: {"green": 4, "yellow": 2, "rune": 3, "spawn_range_ratio": 0.82},
	7: {"green": 5, "yellow": 2, "rune": 3, "spawn_range_ratio": 1.00},   # 10格：堆战斗+能量
}

# void_research (影幕): 爆发特化 - 极限符文，战斗卡少
const _FACTION_LAYOUT_UMBRA := {
	1: {"green": 1, "yellow": 1, "rune": 2, "spawn_range_ratio": 0.30},
	3: {"green": 1, "yellow": 1, "rune": 4, "spawn_range_ratio": 0.55},
	6: {"green": 2, "yellow": 1, "rune": 6, "spawn_range_ratio": 0.92},   # 9格：满符文
	7: {"green": 3, "yellow": 1, "rune": 6, "spawn_range_ratio": 1.00},   # v6.6: 10格（虚空穿）
}

# quantum_logistics (擎天): 资源特化 - 战斗+能量均衡，符文少
const _FACTION_LAYOUT_ATLAS := {
	2: {"green": 2, "yellow": 2, "rune": 1, "spawn_range_ratio": 0.40},
	4: {"green": 3, "yellow": 2, "rune": 2, "spawn_range_ratio": 0.70},
	6: {"green": 4, "yellow": 2, "rune": 3, "spawn_range_ratio": 0.92},
	7: {"green": 5, "yellow": 2, "rune": 4, "spawn_range_ratio": 1.00},   # v6.6: 11格（零点能）
}

# frontier_union (永纪): 时间特化 - 三类均衡
const _FACTION_LAYOUT_EON := {
	2: {"green": 2, "yellow": 1, "rune": 2, "spawn_range_ratio": 0.40},
	5: {"green": 3, "yellow": 2, "rune": 3, "spawn_range_ratio": 0.82},
	7: {"green": 4, "yellow": 2, "rune": 4, "spawn_range_ratio": 1.00},   # 10格：均衡
}

static func _make_def(id: String, name: String, faction_id: String, is_generic: bool, star: int, output_rate: float, acquire_rule: String, special_traits: Array = [], active_ability: Dictionary = {}) -> Dictionary:
	# 根据势力选择布局
	var layout: Dictionary
	if is_generic:
		layout = _STAR_LAYOUT.get(clampi(star, 1, 7), _STAR_LAYOUT[1])
	else:
		# 势力专属：根据 faction_id 选择对应布局
		match faction_id:
			"aether_dynamics":
				layout = _FACTION_LAYOUT_AEGIS.get(star, _STAR_LAYOUT[clampi(star, 1, 7)])
			"helix_recon":
				layout = _FACTION_LAYOUT_HELIX.get(star, _STAR_LAYOUT[clampi(star, 1, 7)])
			"nova_arms":
				layout = _FACTION_LAYOUT_NOVA.get(star, _STAR_LAYOUT[clampi(star, 1, 7)])
			"iron_wall_corp":
				layout = _FACTION_LAYOUT_IRON.get(star, _STAR_LAYOUT[clampi(star, 1, 7)])
			"void_research":
				layout = _FACTION_LAYOUT_UMBRA.get(star, _STAR_LAYOUT[clampi(star, 1, 7)])
			"quantum_logistics":
				layout = _FACTION_LAYOUT_ATLAS.get(star, _STAR_LAYOUT[clampi(star, 1, 7)])
			"frontier_union":
				layout = _FACTION_LAYOUT_EON.get(star, _STAR_LAYOUT[clampi(star, 1, 7)])
			_:
				layout = _STAR_LAYOUT.get(clampi(star, 1, 7), _STAR_LAYOUT[1])

	var rep_req: int = 0 if is_generic else int(star) * 600
	var energy_block_price: int = 20 + int(star) * 15
	# 提高能量恢复倍率：从 0.35 提高到 0.55
	var recovery_rate: float = float(snapped(output_rate * 0.55, 0.01))

	var properties: Array[Dictionary] = build_default_shop_properties(star)
	var card_damage_bonus: float = get_standard_property_value("pi_atk", star, SOURCE_SHOP)
	var defense_bonus: float = get_standard_property_value("pi_def", star, SOURCE_SHOP)
	var xp_bonus: float = get_standard_property_value("pi_xp", star, SOURCE_SHOP)
	var drop_bonus: float = get_standard_property_value("pi_drop", star, SOURCE_SHOP)
	var energy_cost_reduction: int = int(get_standard_property_value("pi_energy_cost", star, SOURCE_SHOP))

	return {
		"id": id,
		"name": name,
		"faction_id": faction_id,
		"is_generic": is_generic,
		"star": star,
		# v6.2: 槽位结构（red/blue 法则槽废弃，改用 rune 符文槽）
		"slot_counts": {
			"green": int(layout.get("green", 1)),
			"yellow": int(layout.get("yellow", 1)),
			"rune": int(layout.get("rune", 1)),
		},
		# 兼容字段：保留 red=0/blue=0 防止老代码报错（渐进迁移）
		"rune_slot_count": int(layout.get("rune", 1)),
		"energy_output_rate": output_rate,
		"energy_recovery_rate": recovery_rate,
		"spawn_range_ratio": float(layout.get("spawn_range_ratio", 0.3)),
		"acquire_rule": acquire_rule,
		"required_rep": rep_req,
		"price_energy_block": energy_block_price,
		"source": SOURCE_SHOP,
		"base_id": id,
		"properties": properties,
		# 新增属性加成
		"card_damage_bonus": card_damage_bonus,
		"defense_bonus": defense_bonus,
		"xp_bonus": xp_bonus,
		"drop_bonus": drop_bonus,
		"energy_cost_reduction": energy_cost_reduction,
		# 独特特性
		"special_traits": special_traits,
		# v6.6: 主动特殊能力（7星完整版，低星降级版）。{} 表示无主动能力。
		"active_ability": active_ability,
	}

static func _build_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# 通用 12 款（覆盖 1-7 星），每个都有独特特性
	out.append(_make_def("pi_generic_01", "巡航I型", "generic", true, 1, 0.80, "generic_store", ["新手友好：战斗胜利后额外获得5点相位经验"]))
	out.append(_make_def("pi_generic_02", "巡航II型", "generic", true, 2, 0.95, "generic_store", ["能量循环：每10秒恢复1点能量"]))
	out.append(_make_def("pi_generic_03", "巡航III型", "generic", true, 3, 1.10, "generic_store", ["快速部署：部署范围提升10%"]))
	out.append(_make_def("pi_generic_04", "锋线III型", "generic", true, 3, 1.18, "generic_store", ["攻击优化：平台卡和武器卡伤害+5%"]))
	out.append(_make_def("pi_generic_05", "锋线IV型", "generic", true, 4, 1.30, "generic_store", ["战斗大师：卡牌伤害+8%，防御+4%"]))
	out.append(_make_def("pi_generic_06", "壁垒IV型", "generic", true, 4, 1.22, "generic_store", ["坚固防御：所有单位防御+8%，受到的伤害-5%"], ability_mega_shield(4)))
	out.append(_make_def("pi_generic_07", "壁垒V型", "generic", true, 5, 1.35, "generic_store", ["钢铁意志：防御+10%，能量消耗-1"]))
	out.append(_make_def("pi_generic_08", "脉冲V型", "generic", true, 5, 1.45, "generic_store", ["能量激流：能量输出+15%，能量恢复+20%"]))
	out.append(_make_def("pi_generic_09", "脉冲VI型", "generic", true, 6, 1.62, "generic_store", ["过载模式：卡牌伤害+12%，能量消耗-2"], ability_mega_shield(6)))
	out.append(_make_def("pi_generic_10", "星链VI型", "generic", true, 6, 1.74, "generic_store", ["资源富集：经验获取+20%，掉落率+15%"]))
	out.append(_make_def("pi_generic_11", "星链VII型", "generic", true, 7, 1.92, "generic_store", ["全能战士：所有属性+10%，能量消耗-3"]))
	out.append(_make_def("pi_generic_12", "天穹VII型", "generic", true, 7, 2.05, "generic_store", ["天界祝福：卡牌伤害+15%，防御+10%，经验+25%，掉落+20%"], ability_mega_shield(7)))
	# 势力专属 23 款（7 势力，每个 3~4 款），每个都有独特的势力特性
	# 神盾系列 - 防御特化
	out.append(_make_def("pi_aegis_01", "神盾-前哨", "aether_dynamics", false, 2, 1.00, "faction_reputation_or_quest", ["神盾力场：防御+6%，受到的伤害-3%"]))
	out.append(_make_def("pi_aegis_02", "神盾-方阵", "aether_dynamics", false, 4, 1.28, "faction_reputation_or_quest", ["方阵防御：防御+10%，每15秒获得1点临时护盾"], ability_acid_rain(4)))
	out.append(_make_def("pi_aegis_03", "神盾-穹顶", "aether_dynamics", false, 6, 1.66, "faction_reputation_or_quest", ["穹顶庇护：防御+15%，受到的伤害-10%，能量消耗-2"], ability_acid_rain(6)))
	out.append(_make_def("pi_aegis_04", "神盾-壁垒核", "aether_dynamics", false, 7, 1.94, "faction_reputation_or_quest", ["绝对防御：防御+20%，受到的伤害-15%，每10秒恢复2点能量"], ability_acid_rain(7)))

	# 螺旋系列 - 侦查与机动
	out.append(_make_def("pi_helix_01", "螺旋-猎线", "helix_recon", false, 1, 0.88, "faction_reputation_or_quest", ["猎手直觉：经验获取+8%"]))
	out.append(_make_def("pi_helix_02", "螺旋-织网", "helix_recon", false, 3, 1.16, "faction_reputation_or_quest", ["神经网络：部署范围+15%，经验+12%"], ability_phantom_clone(3)))
	out.append(_make_def("pi_helix_03", "螺旋-神经束", "helix_recon", false, 5, 1.44, "faction_reputation_or_quest", ["神经加速：能量恢复+25%，经验+18%，部署范围+10%"], ability_phantom_clone(5)))
	# v6.6 新增：螺旋7星-幻影核（幻影克隆完整版）
	out.append(_make_def("pi_helix_04", "螺旋-幻影核", "helix_recon", false, 7, 2.00, "faction_reputation_or_quest", ["幻影核心：克隆体攻击+100%、血量+80%"], ability_phantom_clone(7)))

	# 新星系列 - 火力输出
	out.append(_make_def("pi_nova_01", "新星-回路", "nova_arms", false, 2, 1.04, "faction_reputation_or_quest", ["回路超频：卡牌伤害+8%"]))
	out.append(_make_def("pi_nova_02", "新星-灼流", "nova_arms", false, 4, 1.34, "faction_reputation_or_quest", ["灼流爆发：卡牌伤害+15%，能量输出+10%"], ability_artillery_barrage(4)))
	out.append(_make_def("pi_nova_03", "新星-超弦", "nova_arms", false, 7, 2.10, "faction_reputation_or_quest", ["超弦毁灭：卡牌伤害+25%，能量输出+20%，能量消耗-3"], ability_artillery_barrage(7)))
	out.append(_make_def("pi_nova_04", "新星-裂变庭", "nova_arms", false, 6, 1.76, "faction_reputation_or_quest", ["裂变反应：卡牌伤害+20%，每击杀一个敌人恢复1点能量"], ability_artillery_barrage(6)))

	# 铁幕系列 - 坦克与生存
	out.append(_make_def("pi_iron_01", "铁幕-重锚", "iron_wall_corp", false, 3, 1.08, "faction_reputation_or_quest", ["重锚稳固：防御+8%，最大生命+10%"]))
	out.append(_make_def("pi_iron_02", "铁幕-铸链", "iron_wall_corp", false, 5, 1.36, "faction_reputation_or_quest", ["铸链锁甲：防御+14%，受到的伤害-8%，能量消耗-1"]))
	out.append(_make_def("pi_iron_03", "铁幕-王座", "iron_wall_corp", false, 7, 1.98, "faction_reputation_or_quest", ["王座威严：防御+20%，受到的伤害-12%，最大生命+25%"]))

	# 影幕系列 - 潜行与爆发
	out.append(_make_def("pi_umbra_01", "影幕-薄刃", "void_research", false, 1, 0.92, "faction_reputation_or_quest", ["薄刃一击：首次攻击伤害+20%"]))
	out.append(_make_def("pi_umbra_02", "影幕-折光", "void_research", false, 3, 1.20, "faction_reputation_or_quest", ["折光隐匿：卡牌伤害+10%，暴击率+8%"], ability_piercing_shot(3)))
	out.append(_make_def("pi_umbra_03", "影幕-寂静域", "void_research", false, 6, 1.70, "faction_reputation_or_quest", ["寂静杀场：卡牌伤害+18%，暴击率+15%，暴击伤害+25%"], ability_piercing_shot(6)))
	# v6.6 新增：影幕7星-虚空穿（直射穿透完整版）
	out.append(_make_def("pi_umbra_04", "影幕-虚空穿", "void_research", false, 7, 2.06, "faction_reputation_or_quest", ["虚空贯穿：100%穿透，每穿一个目标衰减10%"], ability_piercing_shot(7)))

	# 擎天系列 - 支援与资源
	out.append(_make_def("pi_atlas_01", "擎天-工蜂", "quantum_logistics", false, 2, 0.98, "faction_reputation_or_quest", ["工蜂采集：掉落率+10%"]))
	out.append(_make_def("pi_atlas_02", "擎天-梁柱", "quantum_logistics", false, 4, 1.26, "faction_reputation_or_quest", ["梁柱支撑：掉落率+18%，经验+10%"], ability_free_energy(4)))
	out.append(_make_def("pi_atlas_03", "擎天-桥核", "quantum_logistics", false, 6, 1.64, "faction_reputation_or_quest", ["桥核链接：掉落率+25%，经验+20%，每15秒获得1点免费能量"], ability_free_energy(6)))
	# v6.6 新增：擎天7星-零点能（免能量完整版）
	out.append(_make_def("pi_atlas_04", "擎天-零点能", "quantum_logistics", false, 7, 1.98, "faction_reputation_or_quest", ["零点能源：所有卡片部署免能量"], ability_free_energy(7)))

	# 永纪系列 - 时间与控制
	out.append(_make_def("pi_eon_01", "永纪-秒针", "frontier_union", false, 2, 1.02, "faction_reputation_or_quest", ["秒针精算：能量恢复+15%"], ability_nuclear_bombardment(2)))
	out.append(_make_def("pi_eon_02", "永纪-时阶", "frontier_union", false, 5, 1.48, "faction_reputation_or_quest", ["时阶掌控：能量恢复+30%，能量消耗-2，所有技能冷却-10%"], ability_nuclear_bombardment(5)))
	out.append(_make_def("pi_eon_03", "永纪-终式", "frontier_union", false, 7, 2.08, "faction_reputation_or_quest", ["终式预言：能量恢复+40%，能量消耗-3，每5秒有20%几率获得额外回合"], ability_nuclear_bombardment(7)))
	return out

static func get_all() -> Array[Dictionary]:
	return _build_all()

static func get_by_id(instrument_id: String) -> Dictionary:
	for d in _build_all():
		if String(d.get("id", "")) == instrument_id:
			return d
	return {}

static func get_default_id() -> String:
	return "pi_generic_01"

# ─────────────────────────────────────────────
#  显示名称映射
# ─────────────────────────────────────────────

## 槽位颜色中文名称映射
## v6.2: 新增 rune（符文）槽，废弃 red/blue（法则槽）
static func get_slot_color_name(color_key: String) -> String:
	match color_key:
		"green":  return "战斗卡"
		"yellow": return "能量卡"
		"rune":   return "符文"
		# 兼容旧调用（返回空字符串，表示已废弃）
		"red":    return ""
		"blue":   return ""
		_:        return "未知"

## 槽位颜色对应的颜色值（用于UI显示）
static func get_slot_color_value(color_key: String) -> Color:
	match color_key:
		"green":  return Color(0.3, 0.9, 0.5, 1.0)
		"yellow": return Color(0.95, 0.85, 0.2, 1.0)
		"rune":   return Color(0.75, 0.45, 0.95, 1.0)  # 紫色（符文专属色）
		# 兼容旧调用
		"red":    return Color(0.5, 0.5, 0.5, 0.3)    # 灰色淡化
		"blue":   return Color(0.5, 0.5, 0.5, 0.3)
		_:        return Color(0.7, 0.7, 0.7, 1.0)

## 获取相位仪的所有槽位颜色列表（按显示顺序）
## v6.2: green(战斗卡) → yellow(能量卡) → rune(符文)
static func get_all_slot_colors() -> Array:
	return ["green", "yellow", "rune"]

## 判断某颜色槽位是否已废弃（法则系统迁移用）
static func is_slot_color_deprecated(color_key: String) -> bool:
	return color_key in ["red", "blue"]

## 获取星级中文名称
static func get_star_name(star: int) -> String:
	match star:
		1: return "一星"
		2: return "二星"
		3: return "三星"
		4: return "四星"
		5: return "五星"
		6: return "六星"
		7: return "七星"
		_: return "未知"

