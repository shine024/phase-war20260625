extends RefCounted
class_name LevelSpawnSequences
## v6.14: 关卡波次序列系统 —— 为每关生成"序列式 + 随机扰动"的波次配置。
## v10 解题式玩法: 波次 bias 改由关卡战术主题（LevelTacticalThemes）驱动，
##               每关有确定的"题面"（装甲突击/空中压制/…），取代原随机 roll。
##
## 背景：此前 100 关每关敌人完全运行时从时代池 `randi() % size` 随机抽，
## 没有节奏感，玩家无法预期。本表为每关生成可复现的波次序列：
##   - "第几波出什么类型的敌人"由序列固定（可复现 + 有节奏）
##   - 序列内具体 archetype 仍随机（保留扰动）
##
## 序列生成规则（程序化，无需手填 100 关数据）：
##   1. 每时代首关（Lv1/21/41/61/81）= 教学序列，全 basic，波次少
##   2. wave_index % 3 == 0 → 精英波（提高 elite 比例）
##   3. 最后波 → Boss 波（若该时代有 boss archetype）
##   4. 难度随时代内关卡进度递增（in_era / 20 越大，elite/boss 比例越高）
##   5. 种子 = level，保证同关序列可复现（RandomNumberGenerator）
##   6. v10: bias_tags 从战术主题 wave_patterns 加权抽取（主题确定性 + 波次扰动）
##
## WaveSpec 结构：
##   {
##     "wave_index": int,
##     "composition": {"basic": float, "elite": float, "boss": float},  # 比例和≈1.0
##     "archetype_bias_tags": Array[String]  # 偏好的 archetype tag（如 ["infantry"]），空=不限
##     "theme_id": String  # v10: 本关战术主题（预警/弹窗显示用）
##   }
##
## 查询接口：
##   LevelSpawnSequences.get_sequence_for_level(level) -> Array[Dictionary]
##   LevelSpawnSequences.get_wave_spec(level, wave_index) -> Dictionary  # 单波查询，越界返回 {}

const LevelEras = preload("res://data/level_eras.gd")
const TacticalThemes = preload("res://data/level_tactical_themes.gd")

## 序列缓存：level → Array[WaveSpec]（同关多次查询复用，避免重复生成）
static var _cache: Dictionary = {}


## 获取指定关卡的完整波次序列。
## 内部带缓存，同关复用。序列长度 = LevelEras.get_wave_total_for_level(level)。
static func get_sequence_for_level(level: int) -> Array:
	var lv: int = clampi(level, 1, 100)
	if _cache.has(lv):
		return _cache[lv]
	var seq: Array = _generate_sequence(lv)
	_cache[lv] = seq
	return seq


## 查询单波配置。wave_index 从 1 开始；越界返回空字典（调用方应回退默认逻辑）。
static func get_wave_spec(level: int, wave_index: int) -> Dictionary:
	var seq: Array = get_sequence_for_level(level)
	# wave_index 是 1-based，序列索引 0-based
	var idx: int = wave_index - 1
	if idx < 0 or idx >= seq.size():
		return {}
	return seq[idx]


## 程序化生成单关序列。
static func _generate_sequence(level: int) -> Array:
	var era: int = LevelEras.get_era(level)
	var in_era: int = ((level - 1) % 20) + 1  # 1..20，时代内进度
	var wave_total: int = LevelEras.get_wave_total_for_level(level)
	var is_tutorial: bool = (in_era == 1)  # 每时代首关 = 教学
	# v10: 本关战术主题（题面）——bias 生成与 composition 修正的数据源
	var theme_id: String = TacticalThemes.get_theme_id_for_level(level)

	# 种子 RNG：保证同关可复现
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 2654435761  # 大素数混洗，避免相邻关序列过于相似

	# 时代内难度进度（0.0~1.0）：首关 0，末关 1
	var progress: float = (in_era - 1) / 19.0 if in_era > 1 else 0.0

	var seq: Array = []
	for w in range(1, wave_total + 1):
		var spec: Dictionary = _make_wave_spec(w, wave_total, is_tutorial, progress, era, rng, theme_id)
		seq.append(spec)
	return seq


## 生成单波 WaveSpec。
## v10: theme_id 参数驱动 bias_tags（战术主题加权抽取）与 composition 修正（elite_delta）。
##      关卡级"战斗配制" = 战术主题（确定倾向）；波次内保留序列扰动（具体单位仍随机）。
##      主题查询失败/为空时回退原随机 roll 逻辑（防御性，不破坏旧行为）。
static func _make_wave_spec(wave_index: int, wave_total: int, is_tutorial: bool, progress: float, era: int, rng: RandomNumberGenerator, theme_id: String = "") -> Dictionary:
	var is_last_wave: bool = (wave_index >= wave_total)
	var is_elite_wave: bool = (wave_index > 1 and wave_index % 3 == 0)

	# v10: 主题 composition 修正（ELITE_PUSH +精英 / SWARM_RUSH -精英）
	var comp_mod: Dictionary = TacticalThemes.get_composition_mod(theme_id) if not theme_id.is_empty() else {}
	var elite_delta: float = float(comp_mod.get("elite_delta", 0.0))

	var basic: float = 1.0
	var elite: float = 0.0
	var boss: float = 0.0

	if is_tutorial:
		# 教学关：全 basic，节奏简单
		basic = 1.0
		elite = 0.0
		boss = 0.0
	else:
		# 基础比例：随进度提高 elite 基础概率（v10: 叠加主题修正后 clamp）
		elite = clampf(0.15 + progress * 0.25 + elite_delta, 0.0, 0.70)  # 0.15 ~ 0.70
		if is_elite_wave:
			elite = clampf(elite + 0.30, 0.0, 0.70)  # 精英波显著提 elite
		if is_last_wave and wave_total > 3:
			# 最后波倾向 boss（若该时代有 boss）
			boss = 0.40 + progress * 0.30  # 0.40 ~ 0.70
			elite = clampf(elite * 0.5, 0.0, 0.30)
		# 归一化
		basic = 1.0 - elite - boss
		if basic < 0.10:
			basic = 0.10
			var _sum: float = basic + elite + boss
			if _sum > 0.0:
				elite = elite / _sum * (1.0 - basic)
				boss = boss / _sum * (1.0 - basic)

	# archetype tag 偏好：v10 起由战术主题驱动（题面确定性）。
	# 注：用普通 Array 而非 Array[String] —— 三元表达式中含空数组分支（else []）会让 GDScript
	# 把整体推断为无类型 Array，赋值给 Array[String] 变量会触发运行时报错（见 v6.14 回归）。
	# 消费方 _pick_archetype_with_bias(pool, bias_tags: Array) 也是普通 Array，保持一致。
	var bias_tags: Array = []
	if is_tutorial:
		bias_tags = ["infantry"]
	elif not theme_id.is_empty():
		# v10: 主题加权抽取（主战波/护卫波/混合波），rng 保证同关序列可复现
		# v23.4: 传 era 做时代感知过滤——零匹配 tag 的波型槽剔除（题面必真）
		bias_tags = TacticalThemes.roll_wave_bias(theme_id, rng, era)
	else:
		# 回退：主题缺失时保留原随机 roll（防御性，正常不触达）
		var roll: int = rng.randi_range(0, 3)
		match roll:
			0:
				bias_tags = ["infantry"]
			1:
				bias_tags = ["vehicle", "armored"] if (progress > 0.3) else ["infantry"]
			2:
				bias_tags = ["aircraft"] if (progress > 0.5) else []
			_:
				bias_tags = []  # 不限

	return {
		"wave_index": wave_index,
		"composition": {
			"basic": basic,
			"elite": elite,
			"boss": boss,
		},
		"archetype_bias_tags": bias_tags,
		"theme_id": theme_id,
	}


## 根据波次 composition 决定本次抽签的类型（"basic"/"elite"/"boss"）。
## 调用方（battle_spawn_system）用它替代原有的 is_last_wave/is_elite_wave 启发式判断。
## boss_ids 为空时强制不返回 "boss"（避免无 boss 池却抽到 boss）。
static func pick_type_for_wave(spec: Dictionary, has_elite_pool: bool, has_boss_pool: bool) -> String:
	if spec.is_empty():
		return "basic"
	var comp: Dictionary = spec.get("composition", {})
	var basic_p: float = float(comp.get("basic", 1.0))
	var elite_p: float = float(comp.get("elite", 0.0))
	var boss_p: float = float(comp.get("boss", 0.0))
	# 无对应池时把概率归到 basic
	if not has_elite_pool:
		basic_p += elite_p
		elite_p = 0.0
	if not has_boss_pool:
		basic_p += boss_p
		boss_p = 0.0
	var total: float = basic_p + elite_p + boss_p
	if total <= 0.0:
		return "basic"
	var roll: float = randf() * total
	if roll < boss_p:
		return "boss"
	roll -= boss_p
	if roll < elite_p:
		return "elite"
	return "basic"


## 清空缓存（关卡切换/测试用）。
static func clear_cache() -> void:
	_cache.clear()
