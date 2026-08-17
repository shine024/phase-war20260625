extends Resource
class_name UnitStats
## 单位数值：战斗单位卡的属性。
##
## v3 重构：由 CardResource 的战斗卡字段直接派生（era + combat_kind + base_*）。
## 保留旧 platform_type/weapon_type 字段以兼容过渡期，新代码不应写入。

# ─────────────────────────────────────────────
#  核心属性（由 CardResource 战斗卡字段派生）
# ─────────────────────────────────────────────

@export var max_hp: float = 100.0
@export var move_speed: float = 80.0
## 格子战术护甲：参与 CardGridDamage 百分比减伤 def/(def+50)
@export var defense: float = 0.0
## 格子战术闪避率（0~1，轻装型固有）
@export var dodge_chance: float = 0.0
@export var attack_range: float = 120.0
@export var attack_interval: float = 1.0
@export var is_stationary: bool = false  # 炮台不移动

## @compat 兼容属性：attack_damage 读写映射到 attack_light
## 旧代码仍然读写 stats.attack_damage，内部等价于 attack_light
var attack_damage: float = 0.0:
	set(v):
		attack_light = v
	get:
		return attack_light

## 武器类型（GameConstants.WeaponType：DIRECT/INDIRECT/AERIAL）
var weapon_type: int = 0

## 部署速度（0-7，越大越快进入战场）
var deploy_speed: int = 3
## v6.9: 部署延迟百分比加成（负值=部署更快）
## 由 move_speed 类改造映射而来（玩家单位走格子战术，move_speed 为死属性，
## 故原"移动速度"改造统一重定向为部署延迟百分比）。系数 0.005，如 +30px → -15% 延迟。
## calculate_deploy_delay 末尾乘 (1 + deploy_delay_bonus)，下限 0.3 秒防极端。
var deploy_delay_bonus: float = 0.0

## 攻击维度（对不同类型单位的伤害）
@export var attack_light: float = 0.0   # 对轻装
@export var attack_armor: float = 0.0   # 对装甲
@export var attack_air: float = 0.0     # 对空中

## v5.0: 每种攻击目标独立的攻速参数
## 对轻装攻击参数
var attack_light_speed: float = 1.0   # 次/秒
var attack_light_windup: float = 0.2    # 前摇（秒）
var attack_light_active: float = 0.1    # 动作（秒）

## 对装甲攻击参数
var attack_armor_speed: float = 1.0   # 次/秒
var attack_armor_windup: float = 0.2  # 前摇（秒）
var attack_armor_active: float = 0.1   # 动作（秒）

## 对空中攻击参数
var attack_air_speed: float = 1.0   # 次/秒
var attack_air_windup: float = 0.2   # 前摇（秒）
var attack_air_active: float = 0.1    # 动作（秒）

## 防御维度（对不同类型单位攻击的防御）- 三攻三防系统（v6.2 对齐）
## v6.2: 防御维度与攻击维度对齐——按"攻击者的单位类型"选取防御值
## defense_light = 防轻装单位(LIGHT/SUPPORT)攻击
## defense_armor = 防装甲单位(ARMOR/FORT)攻击
## defense_air   = 防空中单位(AIR)攻击
@export var defense_light: float = 0.0  # 防轻装单位攻击
@export var defense_armor: float = 0.0  # 防装甲单位攻击
@export var defense_air: float = 0.0    # 防空中单位攻击

## 多武器槽（每项 Dictionary：damage, range, interval, timer）
var weapons: Array = []

## 武器槽位数组（3个槽位：轻装/装甲/对空）
## 从 CardResource 同步而来，用于战斗中选择对应武器
var weapon_slots: Array = []

# ─────────────────────────────────────────────
#  身份字段
# ─────────────────────────────────────────────

## 当前战斗单位卡的 card_id（用于战斗中判断特殊能力）
var card_id: String = ""

## 时代（GameConstants.Era）
var era: int = 0

## 战斗定位（0=轻装/1=装甲/2=支援/3=空中/4=堡垒）
var combat_kind: int = 0

## 单位子类（v6.2: GameConstants.UnitSubType，用于战斗定位差异化修正）
## NONE=普通单位, ARTILLERY=火炮, SUPPORT=辅助, FORT=堡垒, ANTI_AIR=防空特化
var unit_subtype: int = 0

## 战力（进化门槛用，v5.0新增）
var power: int = 0

## 强化等级 0-10（v5.0）
var enhance_level: int = 0

## 武器外观标签（纯显示）
var weapon_label: String = ""

# ─────────────────────────────────────────────
#  旧字段（deprecated，保留兼容）
# ─────────────────────────────────────────────

## @deprecated 旧底盘类型，新代码用 combat_kind
@export var platform_type: int = 0

## @deprecated 旧攻击类型（已废弃，保留用于兼容）
## 新代码使用新的 weapon_type 变量存储 WeaponTypeNew 枚举值
@export var legacy_weapon_type: int = 0

## @deprecated 旧平台卡 id，新代码用 card_id
var platform_card_id: String = ""

## @deprecated 旧武器卡 id 列表
var weapon_card_ids: Array[String] = []

# ─────────────────────────────────────────────
#  词条特殊属性（默认值表示"未启用"）
# ─────────────────────────────────────────────

## 伤害减免（0.0~1.0，来自 platform_armor 词条）
@export var damage_reduction: float = 0.0

## 暴击率（0.0~1.0，来自 crit_chance 词条）
@export var crit_chance: float = 0.0

## 暴击伤害加成（来自 crit_dmg_up 词条；基础暴击1.5x，每级+0.2x）
@export var crit_damage_bonus: float = 0.0

## 暴击抗性（0.0~1.0，来自 crit_resist 词条；v7.x 新增实装）
## 语义：作为被攻击方，降低被暴击的概率（从攻击者 crit_chance 中扣减，下限 0）。
## 此前 modification_registry 写入 result 但 UnitStats 无字段、unit_stats_table 不回写，
## 唯一含此效果的改造（infantry_mods inf 暴抗+0.10）完全空转。v7.x 补全数据链 + 战斗消费。
@export var crit_resist: float = 0.0

## 吸血率（0.0~1.0，来自 lifesteal 词条）
@export var lifesteal: float = 0.0

## 溅射伤害比例（0.0~1.0，来自 splash_dmg 词条）
@export var splash_damage: float = 0.0

## 穿甲率（0.0~1.0，来自 armor_break 词条）
@export var armor_penetration: float = 0.0

## v6.2: 条件型穿甲（相克 MOD 用）—— 仅对特定单位类型生效
## armor_pen_vs_light: 仅对 LIGHT/SUPPORT 目标的防御生效
## armor_pen_vs_armor: 仅对 ARMOR/FORT 目标的防御生效
## armor_pen_vs_air:   仅对 AIR 目标的防御生效
## 在 take_damage 中按自身 combat_kind 选取并叠加到基础 armor_penetration
var armor_pen_vs_light: float = 0.0
var armor_pen_vs_armor: float = 0.0
var armor_pen_vs_air: float = 0.0

## v6.6: 条件型对堡垒伤害加成（来自 attack_fort 改造，如温压弹/爆破装置）
## FORT 目标在 get_attack_vs() 被归入 ARMOR 维度吃 attack_armor，
## 此字段为额外的对堡垒特攻乘数：实际伤害 = attack_armor × (1 + attack_fort_bonus)
var attack_fort_bonus: float = 0.0

## v8: 条件型对轻装伤害加成（兵种固定机制：装甲碾压）
## 与 attack_fort_bonus 同模式：实际伤害 = attack_light × (1 + attack_light_bonus)
var attack_light_bonus: float = 0.0

## v8: 条件型对空中伤害加成（兵种固定机制：防空空域封锁）
## 实际伤害 = attack_air × (1 + attack_air_bonus)
var attack_air_bonus: float = 0.0

## v6.6: 溅射半径加成（来自 splash_radius 改造，如子母弹/近炸引信）
## _apply_splash 的半径 = 100 × (1 + splash_radius_bonus)，默认 0 时为 v9.3 三行布局基础半径
var splash_radius_bonus: float = 0.0

## v6.6: 主目标伤害惩罚（来自 single_target_penalty 改造，值是负小数）
## 子母弹等范围武器的单目标伤害平衡项：主目标伤害 × (1 + single_target_penalty)
var single_target_penalty: float = 0.0

## 连锁触发概率（0.0~1.0，来自 chain_lightning 词条）
@export var chain_chance: float = 0.0

## 击杀护盾（每次击杀获得的护盾量，基于 max_hp 百分比）
@export var shield_on_kill: float = 0.0

## 每秒回血（基于 max_hp 百分比，来自 nano_regen 词条）
@export var hp_regen: float = 0.0

# ─────────────────────────────────────────────
#  v8.6 现实/科幻战斗伤害类型
#  4 种持续伤害（dot）+ 真实伤害（命中追加，无视护甲）
# ─────────────────────────────────────────────

## 真实伤害（固定值，每次命中额外造成，无视护甲/减伤/闪避）
## 来源：射程类改造（膛线/瞄准镜/狙击等）+ 电磁武器即时伤害
var true_damage: float = 0.0

## 化学武器（中毒 dot）：命中概率挂毒，固定 DPS 持续 N 秒
var chem_chance: float = 0.0       ## 触发概率（0~1）
var chem_dps: float = 0.0          ## 每秒伤害
var chem_duration: float = 0.0     ## 持续秒数

## 燃烧弹/助燃剂（燃烧 dot）：命中概率挂燃烧，DPS 可叠加层数
var burn_chance: float = 0.0       ## 触发概率
var burn_dps: float = 0.0          ## 每层每秒伤害
var burn_duration: float = 0.0     ## 持续秒数

## 电磁静电：命中概率降攻速/命中（复用 ECM debuff meta）+ 小额真实伤害即时结算
var emp_chance: float = 0.0        ## 触发概率
var emp_true_damage: float = 0.0   ## 即时真实伤害量

## 纳米病毒（比例 dot）：命中概率挂病毒，按目标 maxHP 百分比每秒掉血（打肉盾专用）
var nano_chance: float = 0.0       ## 触发概率
var nano_pct: float = 0.0          ## 每秒掉 maxHP 的百分比（如 0.02 = 每秒 2%）
var nano_duration: float = 0.0     ## 持续秒数

## ── v9.1 组合技套路增益乘区（默认 0，向后兼容）──
var burn_dps_mult: float = 0.0        ## 燃烧 dot 总放大（套路1 燃烧催化剂）
var chem_dps_mult: float = 0.0        ## 化学 dot 总放大（套路6 污染蓄能器）
var emp_true_damage_bonus: float = 0.0 ## 电磁真实伤害加成（套路2 过载电容）
var beam_damage_bonus: float = 0.0    ## 光束类武器伤害加成（套路4 光纤链路）

# ─────────────────────────────────────────────
#  变异词条标记
# ─────────────────────────────────────────────

## 是否有武器伤害变异（双倍伤害概率）
var has_weapon_dmg_mutation: bool = false

## 是否有攻速变异（连续3次攻击加成）
var has_weapon_atkspd_mutation: bool = false

## 是否有暴击变异（暴击恢复生命）
var has_crit_mutation: bool = false

## 是否有吸血变异（低血量时吸血翻倍）
var has_lifesteal_mutation: bool = false

## 是否有回血变异（低血量时回复翻倍）
var has_hp_regen_mutation: bool = false

## 是否有平台HP变异（高血量时防御加成）
var has_platform_hp_mutation: bool = false

# ─────────────────────────────────────────────
#  v7.x 新机制字段（成长型 / debuff 型 / 兵种专属）
#  全部默认值 0/false，未装备相关改造时行为零变化（向后兼容）
# ─────────────────────────────────────────────

# ── 成长型：连击（攻击积累→满后爆发）──
## 连击当前计数（运行时递增，不存档）
var combo_counter: int = 0
## 连击触发阈值（0=禁用，5=5次命中后爆发）
var combo_max: int = 0
## 连击爆发倍率（0.3 = 爆发时额外 +30% 伤害）
var combo_bonus_mult: float = 0.3

# ── 成长型：怒气（受击积累→满后临时增益）──
## 怒气当前计数（运行时递增，不存档）
var rage_counter: int = 0
## 怒气触发阈值（0=禁用，8=受击8次后激活）
var rage_max: int = 0
## 怒气激活后的攻击力加成（0.35 = +35%）
var rage_bonus_mult: float = 0.35

# ── debuff 型：破甲叠加（每次命中降目标防御）──
## 每次命中降低目标防御的比例（0.08 = -8% 防御/层）
var armor_break_per_hit: float = 0.0
## 破甲叠加层数上限（5 = 最多叠 5 层，0=禁用）
var armor_break_max_stacks: int = 0

# ── debuff 型：标记系统（命中概率标记，被标记受额外伤害）──
## 标记触发概率（0.0~1.0，0.30 = 30% 概率标记）
var mark_chance: float = 0.0
## 标记持续时间（秒）
var mark_duration: float = 5.0
## 被标记目标受到的额外伤害比例（0.25 = +25% 伤害）
var mark_vuln_bonus: float = 0.0

# ── debuff 型：暴击标注系统（侦查命中概率标注，被标注目标受攻击暴击率提升）──
## 暴击标注触发概率（0.0~1.0，0.30 = 30% 概率标注）
var crit_mark_chance: float = 0.0
## 暴击标注持续时间（秒）
var crit_mark_duration: float = 5.0
## 被标注目标受到攻击时的暴击率加成（0.50 = +50% 暴击率）
var crit_mark_bonus: float = 0.50

# ── 兵种专属：工兵爆破（对堡垒/装甲百分比掉血）──
## 对 FORT/ARMOR 目标造成的当前 HP 百分比伤害（0.05 = 5%）
var siege_bonus_pct: float = 0.0

# ── 兵种专属：步兵巷战（受装甲/空军攻击减免）──
## 受 ARMOR/AIR 攻击时的伤害减免比例（0.50 = 减伤 50%）
var urban_defense_bonus: float = 0.0

# ── 兵种专属：炮兵反击（被攻击时标记攻击者）──
## 是否启用炮兵反击（被攻击时给攻击者挂标记）
var has_counter_battery: bool = false
## v8: 反炮兵剩余优先射击次数（兵种固定机制：火炮反炮兵）
## 被攻击标记攻击者后，下 N 次射击优先打标记目标；归零后清理标记回退常规索敌
var counter_battery_shots: int = 0

# ═══════════════════════════════════════════════════════════════
#  v7.x 第二批次新机制字段（复活/爆反拦截/亡语/区域控制/相位护盾）
# ═══════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════
#  v10 解题式玩法：转换型改造字段（劣势转优势）
# ═══════════════════════════════════════════════════════════════

# ── 回收无人机（工兵 eng_13：击杀→修复，吸血的设定合理版）──
## 击杀敌方时按目标最大HP比例修复自身（0.08 = 回收目标 8% max_hp 的纳米材料）
var salvage_repair_pct: float = 0.0

# ── 相位偏移（空军 air_15：受暴击→下次必暴，敌方优势转我方优势）──
## 是否启用相位偏移（受到暴击时获得一次必暴充能，_phase_shift_charged meta）
var phase_shift_counter: bool = false

# ── 电子劫持（通用 gen_14：敌方增益光环→抵消并转移）──
## 电子劫持半径（0=未启用；范围内敌方增益光环被抵消并转移给本单位）
var hijack_aura_radius: float = 0.0
## 电子劫持持续时间（秒）
var hijack_aura_duration: float = 4.0
## 电子劫持冷却（秒）
var hijack_aura_cd: float = 18.0

# ── 濒死复活（IFAK/急救包修复语义）──
## 是否启用死亡复活（HP归零时复活，每场战斗1次）
var revive_on_death: bool = false
## 复活时的血量比例（0.15 = 复活到 15% max_hp）
var revive_hp_ratio: float = 0.15
## 运行时标记：本战是否已复活过（防重复触发）
var has_revived: bool = false

# ── 爆反装甲（受击时反伤周围敌人）──
## 反伤比例（0.30 = 反弹30%实际伤害给攻击者）
var reflect_damage_pct: float = 0.0
## 反伤层数（-1=无限，3=触发3次后失效）
var reflect_charges: int = -1

# ── 拦截（概率伤害归零）──
## 拦截概率（0.30 = 30%概率完全免伤）
var intercept_chance: float = 0.0
## 拦截次数（-1=无限，3=拦截3次后失效）
var intercept_charges: int = -1

# ── 亡语治疗（死亡时治疗周围友军）──
## 死亡时治疗周围友军的比例（基于自身max_hp，0.20 = 治疗20%）
var death_heal_allies_pct: float = 0.0
## 亡语治疗半径（像素）
var death_heal_radius: float = 150.0

# ── 堡垒区域控制 ──
## 雷场伤害（敌人进入范围时触发的一次性爆炸伤害）
var minefield_damage: float = 0.0
## 区域减速比例（范围内敌方移速降低，0.40 = -40%移速）
var slow_aura_pct: float = 0.0
## 区域减速半径
var slow_aura_radius: float = 0.0
## 指挥光环加成（范围内友军暴击/命中加成，0.15 = +15%）
var command_aura_bonus: float = 0.0

## v8: 堡垒阵地坚守光环（兵种固定机制：堡垒阵地坚守）
## 范围内地面友军（非空中）受伤减免比例（0.10 = 减伤 10%）
var fort_shelter_aura: float = 0.0
## 堡垒光环半径（像素）
var fort_shelter_radius: float = 250.0

# ── 相位护盾（独立池分流）──
## 相位护盾池容量（伤害先扣相位池，池空才走常规护盾/hp）
var phase_shield_pool: float = 0.0
## 相位护盾每秒回复量
var phase_shield_regen: float = 0.0
## 是否启用激光指示器（命中100%标记目标，复用mark meta）
var laser_mark_on_hit: bool = false

# ─────────────────────────────────────────────
#  势力变体特殊属性（由 FactionCardGenerator 注入）
# ─────────────────────────────────────────────

## 势力命中精度加成（0.0~0.50，降低敌方闪避效果）
var faction_accuracy_bonus: float = 0.0

## 势力法则效果加成（倍率，1.0=无加成）
var faction_effect_bonus: float = 0.0

## 技能树特殊效果标记列表（由战斗系统按需读取）
var skill_tree_specials: Array = []

## v6.2: 根据目标单位类型获取有效穿甲率（基础 + 条件型）
## attacker_combat_kind 是攻击者自身类型（用于将来按攻击者类型限制）；
## target_combat_kind 决定激活哪个条件穿甲。
func get_effective_armor_penetration(target_combat_kind: int) -> float:
	var pen: float = armor_penetration  # 基础穿甲（对所有目标生效）
	# 条件型穿甲：按目标单位类型激活
	var is_light: bool = (target_combat_kind == 0 or target_combat_kind == 2)  # LIGHT/SUPPORT
	var is_armor: bool = (target_combat_kind == 1 or target_combat_kind == 4)  # ARMOR/FORT
	var is_air: bool = (target_combat_kind == 3)  # AIR
	if is_light:
		pen += armor_pen_vs_light
	if is_armor:
		pen += armor_pen_vs_armor
	if is_air:
		pen += armor_pen_vs_air
	return clampf(pen, 0.0, 1.0)

## 根据目标类型获取对应武器
## v6.2: SUPPORT 归入 LIGHT 槽、FORT 归入 ARMOR 槽（攻防维度对齐）
func get_weapon_for_target(target_combat_kind: int) -> WeaponResource:
	if weapon_slots.is_empty():
		return null

	const GC = preload("res://resources/game_constants.gd")
	match target_combat_kind:
		GC.CombatKind.LIGHT, GC.CombatKind.SUPPORT:
			return weapon_slots[0] if weapon_slots.size() > 0 else null
		GC.CombatKind.ARMOR, GC.CombatKind.FORT:
			return weapon_slots[1] if weapon_slots.size() > 1 else null
		GC.CombatKind.AIR:
			return weapon_slots[2] if weapon_slots.size() > 2 else null
		_:
			return weapon_slots[0] if weapon_slots.size() > 0 else null

## 把攻击乘区同步到 weapon_slots[].damage。
## 战斗 AI/AttackCalculator 的伤害结算（calculate_damage_with_weapon base_damage = weapon.damage）
## 读的是 weapon_slots[i].damage（WeaponResource 对象），而非 attack_damage/attack_*。
## 此前各乘区（强化/稀有度/军衔/相位场/符文/势力）只乘 attack_*/weapons[]，漏了 weapon_slots，
## 导致养成加成在实际开火伤害里失效（我方 DPS 偏低）。
## 此方法让 battle_spawn_system:913 / phase_instrument_manager:371/389 的
## has_method("_sync_weapon_slots_damage") 守卫真正生效，与敌方 _sync_enemy_weapon_slot_damage 对等。
## factor 语义：乘法累积（在当前 damage 基础上再乘 factor，如 1.0+atk_pct）。
func _sync_weapon_slots_damage(factor: float) -> void:
	if factor == 1.0:
		return
	for i in range(weapon_slots.size()):
		var w = weapon_slots[i]
		if w == null:
			continue
		# WeaponResource 是 Resource（非 Dictionary），用 "in" + 字段访问
		if "damage" in w:
			w.damage = maxf(0.1, float(w.damage) * factor)

