extends RefCounted
class_name FactionCardBonuses
## 势力卡牌加成配置表
##
## 定义 7 势力 × 10 级的加成规则。
## 提供：
##   - get_bonus(faction_id, level) -> Dictionary
##   - format_name(base_name, faction_id, level) -> String
##   - calculate_power(base_power, bonus) -> int
##   - validate_all_bonuses() -> PackedStringArray
##
## 加成字典字段说明：
##   name_prefix:    String  - 变体卡名前缀（如"钢壁"）
##   name_suffix:    String  - 变体卡名后缀（如"III型"）
##   hp_bonus:       float   - HP加成比例（正=增，负=减）
##   atk_light_bonus:float   - 对轻装攻击加成
##   atk_armor_bonus:float   - 对装甲攻击加成
##   atk_air_bonus: float     - 对空攻击加成
##   def_light_bonus:float   - 防轻装武器加成
##   def_armor_bonus:float   - 防装甲武器加成
##   def_air_bonus: float     - 防空武器加成
##   energy_cost_reduce:float - 能量消耗减少（正=减）
##   deploy_speed_bonus:int  - 部署速度加成（整数，可为负）
##   attack_speed_bonus:float- 攻击速度加成
##   range_bonus:    int      - 射程加成（格数）
##   dodge_bonus:    float   - 闪避率加成
##   crit_chance_bonus:float  - 暴击率加成
##   crit_damage_bonus:float  - 暴击伤害加成
##   accuracy_bonus: float   - 命中精度加成
##   hp_regen_pct:    float   - 每秒HP回复百分比
##   damage_reduction_bonus:float - 减伤加成
##   effect_bonus:   float   - 法则效果加成
##   power_mult_override:float  - 战力倍率覆盖（0=自动计算）

# ═══════════════════════════════════════════════════════════
#  势力名称映射
# ═══════════════════════════════════════════════════════════

const FACTION_NAMES: Dictionary = {
	"iron_wall_corp": "钢壁",
	"nova_arms": "新星",
	"aether_dynamics": "以太",
	"quantum_logistics": "量子",
	"helix_recon": "螺旋",
	"void_research": "虚空",
	"frontier_union": "边境",
}

# ═══════════════════════════════════════════════════════════
#  7 势力 × 10 级 加成表
# ═══════════════════════════════════════════════════════════

## 辅助：快速构建加成字典（未列出的字段默认0）
static func _b(
	name_suf: String,
	hp: float = 0.0,
	atk_light: float = 0.0, atk_armor: float = 0.0, atk_air: float = 0.0,
	def_light: float = 0.0, def_armor: float = 0.0, def_air: float = 0.0,
	energy: float = 0.0, deploy: int = 0,
	atk_spd: float = 0.0, rng: int = 0,
	dodge: float = 0.0, crit_c: float = 0.0, crit_d: float = 0.0,
	acc: float = 0.0, hp_regen: float = 0.0,
	dmg_red: float = 0.0, effect: float = 0.0,
	power_mul: float = 0.0
) -> Dictionary:
	return {
		"name_suffix": name_suf,
		"hp_bonus": hp,
		"atk_light_bonus": atk_light,
		"atk_armor_bonus": atk_armor,
		"atk_air_bonus": atk_air,
		"def_light_bonus": def_light,
		"def_armor_bonus": def_armor,
		"def_air_bonus": def_air,
		"energy_cost_reduce": energy,
		"deploy_speed_bonus": deploy,
		"attack_speed_bonus": atk_spd,
		"range_bonus": rng,
		"dodge_bonus": dodge,
		"crit_chance_bonus": crit_c,
		"crit_damage_bonus": crit_d,
		"accuracy_bonus": acc,
		"hp_regen_pct": hp_regen,
		"damage_reduction_bonus": dmg_red,
		"effect_bonus": effect,
		"power_mult_override": power_mul,
	}

static var FACTION_BONUS_TABLE: Dictionary = {
	# ─── 钢壁防务公司 (iron_wall_corp) ───
	# 防御/堡垒：HP↑↑、三维防御↑↑、部署速度↓、攻击力↓
	"iron_wall_corp": {
		1: _b("I型",    0.08, -0.03, 0, 0, 0.08, 0.08, 0.08),
		2: _b("II型",   0.12, -0.05, 0, 0, 0.12, 0.12, 0.12),
		3: _b("III型",  0.18, -0.05, 0, 0, 0.15, 0.15, 0.15, 0, -1),
		4: _b("IV型",   0.22, -0.08, 0, 0, 0.20, 0.20, 0.20, 0, -1),
		5: _b("V型",    0.28, -0.08, 0, 0, 0.25, 0.25, 0.25, 0, -1),
		6: _b("VI型",   0.35, -0.10, 0, 0, 0.30, 0.30, 0.30, 0, -2),
		7: _b("精锐型", 0.40, -0.10, 0, 0, 0.35, 0.35, 0.35, 0, -2),
		8: _b("冠军型", 0.50, -0.12, 0, 0, 0.42, 0.42, 0.42, 0, -2),
		9: _b("英雄型", 0.60, -0.15, 0, 0, 0.50, 0.50, 0.50, 0, -2),
		10: _b("传奇型", 0.75, -0.18, 0, 0, 0.60, 0.60, 0.60, 0, -3),
	},

	# ─── 新星兵工制造 (nova_arms) ───
	# 攻击/火力：三维攻击↑↑、攻击速度↑、HP↓、防御↓
	"nova_arms": {
		1: _b("I型",    -0.05, 0.10, 0.08, 0.05, -0.05, -0.05, -0.05, 0, 0, 0.00),
		2: _b("II型",   -0.08, 0.15, 0.12, 0.08, -0.08, -0.08, -0.08, 0, 0, 0.03),
		3: _b("III型",  -0.10, 0.22, 0.18, 0.12, -0.10, -0.10, -0.10, 0, 0, 0.05),
		4: _b("IV型",   -0.12, 0.28, 0.22, 0.15, -0.12, -0.12, -0.12, 0, 0, 0.08),
		5: _b("V型",    -0.15, 0.35, 0.28, 0.20, -0.15, -0.15, -0.15, 0, 0, 0.10),
		6: _b("VI型",   -0.18, 0.42, 0.35, 0.25, -0.18, -0.18, -0.18, 0, 0, 0.12),
		7: _b("精锐型", -0.20, 0.50, 0.42, 0.30, -0.20, -0.20, -0.20, 0, 0, 0.15),
		8: _b("冠军型", -0.25, 0.60, 0.50, 0.38, -0.25, -0.25, -0.25, 0, 0, 0.18),
		9: _b("英雄型", -0.28, 0.70, 0.58, 0.45, -0.28, -0.28, -0.28, 0, 0, 0.20),
		10: _b("传奇型", -0.35, 0.85, 0.70, 0.55, -0.35, -0.35, -0.35, 0, 0, 0.25),
	},

	# ─── 以太动力重工 (aether_dynamics) ───
	# 机动/能量效率：部署速度↑↑、能量消耗↓、攻击速度↑、HP↓
	"aether_dynamics": {
		1: _b("α型", -0.03, 0, 0, 0, 0, 0, 0, -0.05, 1, 0.00),
		2: _b("β型", -0.05, 0, 0, 0, 0, 0, 0, -0.08, 1, 0.03),
		3: _b("γ型", -0.08, 0, 0, 0, 0, 0, 0, -0.10, 2, 0.05),
		4: _b("δ型", -0.10, 0, 0, 0, 0, 0, 0, -0.12, 2, 0.08),
		5: _b("ε型", -0.12, 0, 0, 0, 0, 0, 0, -0.15, 3, 0.10),
		6: _b("ζ型", -0.15, 0, 0, 0, 0, 0, 0, -0.18, 3, 0.12),
		7: _b("η型", -0.18, 0, 0, 0, 0, 0, 0, -0.20, 4, 0.15),
		8: _b("θ型", -0.20, 0, 0, 0, 0, 0, 0, -0.23, 4, 0.18),
		9: _b("ι型", -0.22, 0, 0, 0, 0, 0, 0, -0.25, 5, 0.20),
		10: _b("Ω型", -0.25, 0, 0, 0, 0, 0, 0, -0.30, 6, 0.25),
	},

	# ─── 量子后勤集团 (quantum_logistics) ───
	# 资源/补给/续航：HP↑、生命回复↑、攻防均衡小幅提升、无惩罚
	"quantum_logistics": {
		1: _b("I型",    0.05, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0, 0, 0, 0, 0, 0, 0, 0, 0.002),
		2: _b("II型",   0.08, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0, 0, 0, 0, 0, 0, 0, 0, 0.003),
		3: _b("III型",  0.12, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0, 0, 0, 0, 0, 0, 0, 0, 0.005),
		4: _b("IV型",   0.15, 0.10, 0.10, 0.10, 0.10, 0.10, 0.10, 0, 0, 0, 0, 0, 0, 0, 0, 0.008),
		5: _b("V型",    0.20, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0, 0, 0, 0, 0, 0, 0, 0, 0.010),
		6: _b("VI型",   0.25, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0, 0, 0, 0, 0, 0, 0, 0, 0.012),
		7: _b("精锐型", 0.30, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0, 0, 0, 0, 0, 0, 0, 0, 0.015),
		8: _b("冠军型", 0.38, 0.22, 0.22, 0.22, 0.22, 0.22, 0.22, 0, 0, 0, 0, 0, 0, 0, 0, 0.020),
		9: _b("英雄型", 0.45, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0, 0, 0, 0, 0, 0, 0, 0, 0.025),
		10: _b("传奇型", 0.55, 0.30, 0.30, 0.30, 0.30, 0.30, 0.30, 0, 0, 0, 0, 0, 0, 0, 0, 0.030),
	},

	# ─── 螺旋侦察系统 (helix_recon) ───
	# 侦察/闪避/精准：闪避率↑、命中↑、射程↑、攻击↑(轻装)、防御↓
	"helix_recon": {
		1: _b("I型",    0, 0.05, 0, 0, -0.03, 0, 0, 0, 0, 0, 0, 0.03, 0.05, 0),
		2: _b("II型",   0, 0.08, 0, 0, -0.05, 0, 0, 0, 0, 0, 1, 0.05, 0.08, 0),
		3: _b("III型",  0, 0.12, 0, 0, -0.08, 0, 0, 0, 0, 0, 1, 0.08, 0.12, 0),
		4: _b("IV型",   0, 0.15, 0, 0, -0.10, 0, 0, 0, 0, 0, 1, 0.10, 0.15, 0),
		5: _b("V型",    0, 0.20, 0, 0, -0.12, 0, 0, 0, 0, 0, 2, 0.13, 0.18, 0),
		6: _b("VI型",   0, 0.25, 0, 0, -0.15, 0, 0, 0, 0, 0, 2, 0.16, 0.22, 0),
		7: _b("精锐型", 0, 0.30, 0, 0, -0.18, 0, 0, 0, 0, 0, 2, 0.20, 0.25, 0),
		8: _b("冠军型", 0, 0.38, 0, 0, -0.22, 0, 0, 0, 0, 0, 3, 0.24, 0.30, 0),
		9: _b("英雄型", 0, 0.45, 0, 0, -0.25, 0, 0, 0, 0, 0, 3, 0.28, 0.35, 0),
		10: _b("传奇型", 0, 0.55, 0, 0, -0.30, 0, 0, 0, 0, 0, 4, 0.35, 0.42, 0),
	},

	# ─── 虚空相位研究所 (void_research) ───
	# 法则/特殊效果：暴击↑、特效伤害↑、法则效率↑、基础攻防小幅提升
	"void_research": {
		1: _b("I型",    0.03, 0.03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.03, 0.05, 0.05),
		2: _b("II型",   0.05, 0.05, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.05, 0.10, 0.08),
		3: _b("III型",  0.08, 0.08, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.08, 0.15, 0.12),
		4: _b("IV型",   0.10, 0.10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.10, 0.20, 0.15),
		5: _b("V型",    0.13, 0.13, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.13, 0.25, 0.20),
		6: _b("VI型",   0.16, 0.16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.16, 0.32, 0.25),
		7: _b("精锐型", 0.20, 0.20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.20, 0.40, 0.30),
		8: _b("冠军型", 0.25, 0.25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.25, 0.50, 0.38),
		9: _b("英雄型", 0.30, 0.30, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.30, 0.62, 0.45),
		10: _b("传奇型", 0.38, 0.38, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.38, 0.80, 0.55),
	},

	# ─── 边境联合公司 (frontier_union) ───
	# 多面手/通用加成：全属性均衡小幅提升，无惩罚，数值低于专精势力
	"frontier_union": {
		1: _b("I型",    0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04),
		2: _b("II型",   0.06, 0.06, 0.06, 0.06, 0.06, 0.06, 0.06),
		3: _b("III型",  0.09, 0.09, 0.09, 0.09, 0.09, 0.09, 0.09),
		4: _b("IV型",   0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12),
		5: _b("V型",    0.16, 0.16, 0.16, 0.16, 0.16, 0.16, 0.16),
		6: _b("VI型",   0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20),
		7: _b("精锐型", 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25),
		8: _b("冠军型", 0.32, 0.32, 0.32, 0.32, 0.32, 0.32, 0.32),
		9: _b("英雄型", 0.38, 0.38, 0.38, 0.38, 0.38, 0.38, 0.38),
		10: _b("传奇型", 0.48, 0.48, 0.48, 0.48, 0.48, 0.48, 0.48),
	},
}

# ═══════════════════════════════════════════════════════════
#  查询接口
# ═══════════════════════════════════════════════════════════

## 根据 (faction_id, level) 获取加成字典
## 返回空字典表示无效的势力或等级
static func get_bonus(faction_id: String, level: int) -> Dictionary:
	var faction_table: Dictionary = FACTION_BONUS_TABLE.get(faction_id, {})
	if faction_table.is_empty():
		return {}
	var bonus: Dictionary = faction_table.get(level, {})
	if bonus.is_empty():
		return {}
	return bonus.duplicate(true)

## 格式化势力变体卡名
## 返回格式: "{前缀}·{基础名} {后缀}"，如 "钢壁·虎式坦克 III型"
static func format_name(base_name: String, faction_id: String, level: int) -> String:
	var bonus: Dictionary = get_bonus(faction_id, level)
	if bonus.is_empty():
		return base_name
	var prefix: String = FACTION_NAMES.get(faction_id, "")
	var suffix: String = String(bonus.get("name_suffix", ""))
	return "%s·%s %s" % [prefix, base_name, suffix]

## 根据加成计算变体战力
## power_mult_override > 0 时使用覆盖值，否则自动计算
static func calculate_power(base_power: int, bonus: Dictionary) -> int:
	if bonus.is_empty() or base_power <= 0:
		return base_power
	var override: float = float(bonus.get("power_mult_override", 0.0))
	if override > 0.0:
		return maxi(1, int(float(base_power) * override))
	# 自动估算：取攻防加成均值作为倍率
	var hp_mul: float = 1.0 + float(bonus.get("hp_bonus", 0.0))
	var atk_l_mul: float = 1.0 + float(bonus.get("atk_light_bonus", 0.0))
	var atk_a_mul: float = 1.0 + float(bonus.get("atk_armor_bonus", 0.0))
	var def_l_mul: float = 1.0 + float(bonus.get("def_light_bonus", 0.0))
	var def_a_mul: float = 1.0 + float(bonus.get("def_armor_bonus", 0.0))
	var avg_mul: float = (hp_mul + atk_l_mul + atk_a_mul + def_l_mul + def_a_mul) / 5.0
	return maxi(1, int(float(base_power) * avg_mul))

## 校验所有加成数据完整性
## 返回错误信息数组，空数组表示全部通过
static func validate_all_bonuses() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var expected_levels: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	for faction_id in FACTION_BONUS_TABLE.keys():
		var faction_table: Dictionary = FACTION_BONUS_TABLE[faction_id] as Dictionary
		if faction_table.is_empty():
			errors.append("势力 %s 加成表为空" % faction_id)
			continue
		if not FACTION_NAMES.has(faction_id):
			errors.append("势力 %s 缺少名称映射" % faction_id)
		for lv in expected_levels:
			if not faction_table.has(lv):
				errors.append("势力 %s 缺少等级 %d" % [faction_id, lv])
				continue
			var b: Dictionary = faction_table[lv] as Dictionary
			if not b.has("name_suffix"):
				errors.append("势力 %s 等级 %d 缺少 name_suffix" % [faction_id, lv])
	return errors
