extends Node
## SupplyNetworkManager —— 动态补给网核心（v6.71，计划 §二）
##
## 职责（拍板决策 1-8 的状态真身）：
##   区域威胁（十区）、陷落/降级/回溯态、每关最近评分（覆盖式）、
##   关卡兑换（箱子三阶+货架+pity）、遗物、迷失池、游猎相位师。
## 日结时基 = SignalBus.bunker_day_ended（BunkerManager.sleep() 发射）——离线可玩（C2）。
##
## 静态表与纯函数在：
##   data/supply_threat.gd（威胁模型）/ data/supply_exchange.gd（箱子池）
##   data/relic_registry.gd（遗物）/ data/battle_evaluation.gd（评分）
##   data/supply_point_dialogues.gd（对话池）
##
## 勿动边界（计划 §十一）：主线解锁链（LevelProgressManager._unlock_next_level）、
## 教程步序、FeatureUnlockSchedule 既有条目、EBM 渗透的过期/上限/解锁门。
const NpcPhaseMasters := preload("res://data/npc_phase_masters.gd")  # 无 class_name，项目惯例 preload
const EnemyPhaseMastersT := preload("res://data/enemy_phase_masters.gd")  # 同上；展示名查询用

## 教程期休眠门（与 EBM.INCURSION_UNLOCK_CLEARED_LEVEL 同值同口径——
## 威胁系统在渗透解锁前整个不动；读 EBM 常量避免双写漂移）
const SUPPLY_UNLOCK_CLEARED_LEVEL: int = 25

## 游猎相位师激活门（通关即激活；常量 C3）
const ROAMING_UNLOCK_LEVELS: Array = [30, 60, 90]
## 游猎每日移动：randi_range(0,2) 关向 100，上限 2 关/日 ≤ 玩家行军速
const ROAMING_MOVE_MIN: int = 0
const ROAMING_MOVE_MAX: int = 2
const ROAMING_DAILY_CAP: int = 2
const ROAMING_FINAL_LEVEL: int = 100
## 游猎起始位 = 玩家 max_unlocked_level ± 3
const ROAMING_SPAWN_OFFSET: int = 3
## 游猎 3 位（data/npc_phase_masters.gd 池按 name 挑，各时代一人；勿硬编码到逻辑层）
const ROAMING_MASTER_NAMES: Array = ["旧日雷霆", "量子幽灵", "终焉之镰"]

## 收复战奖励量级 = 渗透轻结算 ×1.5（异族战是资源主力来源，拍板决策 4）
const RECONQUEST_REWARD_SCALE: float = 1.5
## 收复战遗物箱概率：首夺 45% / 复夺 20%（弹窗明示，C3）
const RECONQUEST_RELIC_FIRST_PCT: float = 45.0
const RECONQUEST_RELIC_REPEAT_PCT: float = 20.0

## 关卡态
const STATE_HELD: String = "held"
const STATE_FALLEN: String = "fallen"
const STATE_DEGRADED: String = "recovered_degraded"

const SAVE_KEY_THREAT := "region_threat"
const SAVE_KEY_SEED := "region_seed"
const SAVE_KEY_STATES := "level_state"
const SAVE_KEY_GRADES := "level_grades"
const SAVE_KEY_GRADE_BAK := "fallen_grade_backup"
const SAVE_KEY_PITY := "exchange_pity"
const SAVE_KEY_LOST := "lost_masters"
const SAVE_KEY_ROAMING := "roaming_masters"
const SAVE_KEY_GARRISON_LOST := "garrison_lost"
const SAVE_KEY_REWIND_SPENT := "rewind_spent_levels"

# ─────────────────────────────────────────────────────────────
#  运行时状态
# ─────────────────────────────────────────────────────────────

var region_threat: Dictionary = {}       # region(int) -> int
var region_seed: int = 0                 # 逐区 ±30% 确定性扰动的存档 seed
var level_state: Dictionary = {}         # level(int) -> STATE_*（缺省 held）
var level_grades: Dictionary = {}        # level(int) -> "S"/"A"/"B"/"C"（覆盖式最近评分）
var fallen_grade_backup: Dictionary = {} # level -> 评分（陷落时暂存，回溯恢复）
var exchange_pity: int = 0               # 兑换软保底（全局一份，非逐关）
var lost_masters: Array = []             # [{master_id, origin: roam/garrison, lost_day}]
var roaming_masters: Array = []          # [{master_id, level, active}]
var garrison_lost: Dictionary = {}       # master_id -> true（相位师关收复即永久失去该相位师）
var rewind_spent_levels: Dictionary = {} # level -> true（已走过回溯的关，回溯价只收一次不重复？——
                                         # 语义：每次 degraded→held 收一次；本表仅留档不参与定价）

var _connected_day_ended: bool = false

func _ready() -> void:
	# 日结时基：BunkerManager.sleep() → bunker_day_ended（懒加载管理器，
	# 连接放 _ready + 防重复；SignalBus 为前置 autoload 必在）
	if not _connected_day_ended:
		SignalBus.bunker_day_ended.connect(_on_day_ended)
		_connected_day_ended = true

# ─────────────────────────────────────────────────────────────
#  休眠门与基础查询
# ─────────────────────────────────────────────────────────────

## 教程期休眠：L25 未通关前整个威胁/陷落系统不动（复用 EBM 解锁门口径）
func is_dormant() -> bool:
	var ebm: Node = get_node_or_null("/root/EndlessBlackgateManager")
	if ebm != null and ebm.has_method("incursions_unlocked"):
		return not bool(ebm.incursions_unlocked())
	var lpm: Node = get_node_or_null("/root/LevelProgressManager")
	if lpm != null and "level_stars" in lpm:
		return int(lpm.get_level_stars(SUPPLY_UNLOCK_CLEARED_LEVEL)) <= 0
	return true

## 黑门本体已碎 → 世界和平态：威胁停增（陷落仍可清收复但不再新增）
func is_world_peace() -> bool:
	var ebm: Node = get_node_or_null("/root/EndlessBlackgateManager")
	if ebm != null and "gate_cleared_once" in ebm:
		return bool(ebm.gate_cleared_once)
	return false

func get_level_state(level: int) -> String:
	return String(level_state.get(level, STATE_HELD))

func is_held(level: int) -> bool:
	return get_level_state(level) == STATE_HELD

func is_fallen(level: int) -> bool:
	return get_level_state(level) == STATE_FALLEN

func is_degraded(level: int) -> bool:
	return get_level_state(level) == STATE_DEGRADED

func get_region_threat(region: int) -> int:
	return clampi(int(region_threat.get(region, 0)), 0, 999)

## 区域内活跃渗透点数（读 EBM incursions 列表按区域过滤）
func incursion_count_in_region(region: int) -> int:
	var ebm: Node = get_node_or_null("/root/EndlessBlackgateManager")
	if ebm == null or not "incursions" in ebm:
		return 0
	var count: int = 0
	var range_v: Vector2i = SupplyThreat.level_range_for_region(region)
	for inc in ebm.incursions:
		var lv: int = int(inc.get("host_level", -1))
		if lv >= range_v.x and lv <= range_v.y:
			count += 1
	return count

# ─────────────────────────────────────────────────────────────
#  日结（M1.1 威胁模型 + M4 游猎移动）
# ─────────────────────────────────────────────────────────────

func _on_day_ended(day: int) -> void:
	if not is_dormant():
		_daily_threat_tick()
	_roaming_daily_move(day)
	# 游猎移动后状态落一次存档可见变化（SupplyNetworkManager 在 Critical 链，
	# 存档由 SaveManager 统一收 save_state；此处只发 UI 刷新信号）
	SignalBus.supply_state_changed.emit(0)

## 威胁日结：基础增速×扰动 + 渗透加压 / 无渗透微衰减 −4；
## gate_cleared_once 后停增（世界和平态）。日结末陷落判定。
func _daily_threat_tick() -> void:
	if region_seed == 0:
		region_seed = randi()
	var threat_slow: int = get_relic_effect_sum("threat_slow")
	for region in range(1, SupplyThreat.REGION_COUNT + 1):
		var delta: int = SupplyThreat.daily_delta(region, region_seed, incursion_count_in_region(region))
		if is_world_peace():
			delta = 0
		if delta > 0 and threat_slow > 0:
			delta = maxi(0, delta - threat_slow)
		var next_val: int = get_region_threat(region) + delta
		region_threat[region] = clampi(next_val, 0, 999)
		SignalBus.threat_changed.emit(region)
	_resolve_falls()

## 陷落判定（日结末）：威胁≥阈值的区域各陷落 1 关（防御值升序），陷落回吐 −30。
## 仅已通关（stars>0）且 held 态的关会陷落。
func _resolve_falls() -> void:
	for region in range(1, SupplyThreat.REGION_COUNT + 1):
		if get_region_threat(region) < SupplyThreat.FALL_THRESHOLD:
			continue
		var range_v: Vector2i = SupplyThreat.level_range_for_region(region)
		var candidates: Array = []
		var lpm: Node = get_node_or_null("/root/LevelProgressManager")
		for lv in range(range_v.x, range_v.y + 1):
			if not is_held(lv):
				continue
			var stars: int = 0
			if lpm != null and lpm.has_method("get_level_stars"):
				stars = int(lpm.get_level_stars(lv))
			if stars > 0:
				candidates.append(lv)
		var victim: int = SupplyThreat.pick_fall_candidate(candidates)
		if victim <= 0:
			continue
		fall_level(victim)
		region_threat[region] = maxi(0, get_region_threat(region) - SupplyThreat.FALL_RELIEF)
		SignalBus.threat_changed.emit(region)

# ─────────────────────────────────────────────────────────────
#  威胁降压（唯一主动口：区域内异族战斗）
# ─────────────────────────────────────────────────────────────

## 清渗透战胜降压（−15）
func apply_clear_incursion_relief(level: int) -> void:
	_apply_relief(level, SupplyThreat.CLEAR_INCURSION_RELIEF)

## 收复战胜降压（−20）
func apply_reconquest_relief(level: int) -> void:
	_apply_relief(level, SupplyThreat.RECONQUEST_RELIEF)

func _apply_relief(level: int, amount: int) -> void:
	var region: int = SupplyThreat.region_for_level(level)
	region_threat[region] = maxi(0, get_region_threat(region) - amount)
	SignalBus.threat_changed.emit(region)

# ─────────────────────────────────────────────────────────────
#  状态机：held → fallen → recovered_degraded → (回溯) → held（M1.2）
# ─────────────────────────────────────────────────────────────

## 陷落：功能全停 + 评分暂存；相位师关同时永久失去驻守相位师（garrison_lost）。
func fall_level(level: int) -> void:
	if is_fallen(level):
		return
	level_state[level] = STATE_FALLEN
	# 评分恢复陷落前记录：陷落即暂存清出（弹窗/兑换不再可见）
	if level_grades.has(level):
		fallen_grade_backup[level] = level_grades[level]
		level_grades.erase(level)
	# 相位师关特例：驻守相位师战败迷失，入迷失池；回溯只恢复功能不救回人
	# （garrison_lost 由 add_lost_master 内部登记，勿在此先行置位——幂等检查会短路名册写入）
	var master_id: String = PhaseMasterGarrison.get_garrison_master_id(level)
	if not master_id.is_empty():
		add_lost_master(master_id, "garrison")
		SignalBus.feed_message.emit("⚠ 第%d区域 第%d关失守——驻守相位师%s战败迷失，步入了黑门。" % [
			SupplyThreat.region_for_level(level), level,
			_phase_master_display_name(master_id)])
	else:
		SignalBus.feed_message.emit("⚠ 第%d区域 第%d关失守——补给点陷落，异族接管了防线。" % [
			SupplyThreat.region_for_level(level), level])
	SignalBus.supply_state_changed.emit(level)

## 收复成功：fallen → recovered_degraded（纯资源点，仅最低档兑换、不可考评）
func mark_reconquered(level: int) -> void:
	if not is_fallen(level):
		return
	level_state[level] = STATE_DEGRADED
	SignalBus.feed_message.emit("第%d区域 第%d关已收复——补给点降级运作，时空回溯可恢复完整功能。" % [
		SupplyThreat.region_for_level(level), level])
	SignalBus.supply_state_changed.emit(level)

## 时空回溯激活：degraded → held，评分恢复陷落前记录；相位师关不救回人。
## 入口在关卡弹窗；投入资源由调用方（UI 侧）先行扣费，此处只做状态迁移。
func activate_time_rewind(level: int) -> bool:
	if not is_degraded(level):
		return false
	level_state[level] = STATE_HELD
	rewind_spent_levels[level] = true
	if fallen_grade_backup.has(level):
		level_grades[level] = String(fallen_grade_backup[level])
		fallen_grade_backup.erase(level)
	SignalBus.feed_message.emit("时空回溯完成——第%d关补给点恢复完整运作。" % level)
	SignalBus.supply_state_changed.emit(level)
	return true

## 回溯定价（按时代档，锚制造价量级；纯函数供 UI 弹窗展示）
func rewind_cost(level: int) -> Dictionary:
	var era: int = LevelEras.get_era(level)
	var factor: float = float(SupplyExchange.ERA_PRICE_FACTOR.get(era, 1.0))
	return {
		"nano_materials": roundi(600 * factor),
		"alloy": roundi(60 * factor),
	}

## 相位师是否已迷失（garrison 或 roam；查询侧过滤的判定核心）
func is_master_lost(master_id: String) -> bool:
	if garrison_lost.has(master_id):
		return true
	for m in lost_masters:
		if String(m.get("master_id", "")) == master_id:
			return true
	return false

## 驻守相位师遭遇过滤：已迷失的驻守相位师不再触发遭遇
func is_garrison_encounter_available(level: int) -> bool:
	var master_id: String = PhaseMasterGarrison.get_garrison_master_id(level)
	if master_id.is_empty():
		return true
	return not is_master_lost(master_id)

# ─────────────────────────────────────────────────────────────
#  评分（M2.2 覆盖式记最近一次）
# ─────────────────────────────────────────────────────────────

## 覆盖式记录（不打就按上次评分；再战以新评分覆盖，结算页提示 A→B）
func record_grade(level: int, grade: String) -> void:
	if grade.is_empty():
		return
	level_grades[level] = grade
	SignalBus.grade_recorded.emit(level, grade)

func get_grade(level: int) -> String:
	return String(level_grades.get(level, ""))

## 旧档折算补缺：按 level_stars 生成初始评分（已有评分的关不动）
func migrate_grades_from_stars(stars_dict: Dictionary) -> int:
	var migrated: int = 0
	for lv in stars_dict:
		var lv_int: int = int(lv)
		if level_grades.has(lv_int):
			continue
		var grade: String = BattleEvaluation.grade_from_stars(int(stars_dict[lv]))
		if not grade.is_empty():
			level_grades[lv_int] = grade
			migrated += 1
	return migrated

# ─────────────────────────────────────────────────────────────
#  兑换（M3.1 常驻 + M3.2 考评货架）
# ─────────────────────────────────────────────────────────────

## can-条件快照（镜像 manufacture_manager.craft_mod_blueprint_random 的 {ok,reason_zh,conditions[]}）
func get_exchange_conditions(level: int, box_tier: String) -> Dictionary:
	var conditions: Array = []
	var era: int = LevelEras.get_era(level)
	if is_fallen(level):
		return {"ok": false, "reason_zh": "补给点陷落中——先收复再兑换", "conditions": conditions}
	var grade: String = get_grade(level)
	if is_degraded(level) and box_tier != SupplyExchange.TIER_NORMAL:
		return {"ok": false, "reason_zh": "降级补给点仅开放普通补给箱", "conditions": conditions}
	if not SupplyExchange.tier_unlocked_by_grade(box_tier, grade):
		conditions.append({"ok": false, "text": "%s（当前 %s）" % [
			SupplyExchange.describe_gate(box_tier), grade if not grade.is_empty() else "未评级"]})
		return {"ok": false, "reason_zh": "评级不足", "conditions": conditions}
	conditions.append({"ok": true, "text": "评级 %s 达标" % grade})
	var cost: int = _exchange_cost_with_discount(box_tier, era)
	var can_pay: bool = BasicResourceManager.can_afford("energy_block", cost)
	conditions.append({"ok": can_pay, "text": "能量块 %d" % cost})
	if not can_pay:
		return {"ok": false, "reason_zh": "能量块不足", "conditions": conditions}
	return {"ok": true, "reason_zh": "", "conditions": conditions}

## 实付价 = 基础×时代系数 ×（1 − 遗物兑换折扣% − 收集度阶梯折扣%），向下取整至少 1
func _exchange_cost_with_discount(box_tier: String, era: int) -> int:
	var base: int = SupplyExchange.box_cost(box_tier, era)
	var discount_pct: int = get_relic_effect_sum("exchange_discount")
	var final: int = base
	if discount_pct > 0:
		final = int(floor(float(base) * (1.0 - float(clampi(discount_pct, 0, 50)) / 100.0)))
	return maxi(1, final)

## 兑换执行：扣费 → roll → 发放 → pity 记账 → 失败退款防御。
## 返回 {ok, reason_zh, reward:{key,label,...}}（UI 弹窗消费）。
func exchange_box(level: int, box_tier: String) -> Dictionary:
	var check: Dictionary = get_exchange_conditions(level, box_tier)
	if not bool(check.get("ok", false)):
		return {"ok": false, "reason_zh": String(check.get("reason_zh", "无法兑换")), "reward": {}}
	var era: int = LevelEras.get_era(level)
	var cost: int = _exchange_cost_with_discount(box_tier, era)
	BasicResourceManager.consume("energy_block", cost)
	var reward_key: String = SupplyExchange.roll_box(box_tier, exchange_pity)
	if reward_key.is_empty():
		# roll 异常退款防御
		BasicResourceManager.add_resource("energy_block", cost)
		return {"ok": false, "reason_zh": "补给网异常（已退款）", "reward": {}}
	var reward: Dictionary = _grant_exchange_reward(reward_key, era)
	if reward.is_empty():
		BasicResourceManager.add_resource("energy_block", cost)
		return {"ok": false, "reason_zh": "发放失败（已退款）", "reward": {}}
	# pity 记账：出遗物箱清零，否则 +1（软保底，非必出）
	if reward_key == SupplyExchange.RELIC_POOL_KEY:
		exchange_pity = 0
	else:
		exchange_pity += 1
	SignalBus.supply_state_changed.emit(level)
	return {"ok": true, "reason_zh": "兑换成功", "reward": reward, "cost": cost}

## 发放单格奖励（纯发放，失败返回空字典）；遗物箱格另行 roll 遗物。
func _grant_exchange_reward(key: String, era: int) -> Dictionary:
	match key:
		"res_nano":
			var amount: int = SupplyExchange.resource_pack_amount("res_nano", era)
			BasicResourceManager.add_resource("nano_materials", amount)
			return {"key": key, "label": "纳米材料包", "amount": amount}
		"res_alloy":
			var amount2: int = SupplyExchange.resource_pack_amount("res_alloy", era)
			BasicResourceManager.add_resource("alloy", amount2)
			return {"key": key, "label": "合金包", "amount": amount2}
		"res_crystal":
			var amount3: int = SupplyExchange.resource_pack_amount("res_crystal", era)
			BasicResourceManager.add_resource("crystal", amount3)
			return {"key": key, "label": "晶体包", "amount": amount3}
		"discount_coupon":
			IntelItemBag.add_item("discount_coupon", 1)
			return {"key": key, "label": "制造折扣券", "amount": 1}
		"captured_card":
			var dm: Node = get_node_or_null("/root/DropManager")
			if dm != null and dm.has_method("grant_random_capture_card"):
				var card: Dictionary = dm.grant_random_capture_card(era, 0)
				if not card.is_empty():
					return {"key": key, "label": "缴获风格卡", "card_id": String(card.get("card_id", ""))}
			return {}
		"mod_blueprint":
			var mm: Node = get_node_or_null("/root/ManufactureManager")
			if mm == null or not mm.has_method("get_mod_box_pool"):
				return {}
			var pool: Array = mm.get_mod_box_pool()
			var mod_id: String = ModManufacture.roll_box_mod(pool, 0)
			if mod_id.is_empty():
				return {}
			IntelItemBag.add_item("blueprint_" + mod_id, 1)
			return {"key": key, "label": "改造图纸", "mod_id": mod_id}
		"relic_box":
			return open_relic_box()
	return {}

## 遗物箱：必得 1 件未拥有（权重+未拥有优先）；全收集转资源包（C3 明示）。
func open_relic_box() -> Dictionary:
	var owned: Array = get_owned_relic_ids()
	var relic_id: String = RelicRegistry.roll_unowned(owned)
	if relic_id.is_empty():
		# 全收集兜底：转晶体资源包（口径常量明示于面板文案）
		var amount: int = 200
		BasicResourceManager.add_resource("crystal", amount)
		return {"key": "relic_box_full", "label": "遗物收集完成（转晶体包）", "amount": amount}
	IntelItemBag.add_item("relic_" + relic_id, 1)
	var relic: Dictionary = RelicRegistry.get_by_id(relic_id)
	return {"key": "relic_box", "label": "遗物：%s" % String(relic.get("name", relic_id)), "relic_id": relic_id}

## 已拥有遗物 id 集合（IntelItemBag「见过集合」口径：relic_ 前缀）
func get_owned_relic_ids() -> Array:
	var out: Array = []
	var inv: Dictionary = IntelItemBag.get_all_inventory()
	for r in RelicRegistry.get_all():
		var rid: String = String(r.get("id", ""))
		if int(inv.get("relic_" + rid, 0)) > 0:
			out.append(rid)
	return out

## 遗物效果聚合（含收集度阶梯）——supply/兑换/燃料/异族战结算消费
func get_relic_effect_sum(effect: String) -> int:
	return RelicRegistry.aggregate_effect(effect, get_owned_relic_ids())

## 考评结算 3 选 1 货架（M3.2）：按新评分档定池，能量定价，可放弃（不选即过期）
func roll_capture_shelf(grade: String) -> Array:
	return SupplyExchange.roll_shelf(grade)

## 货架购买：独立于常驻箱（不走 pity——货架是定向购买非随机 roll）
func buy_shelf_item(level: int, item_key: String, cost: int) -> Dictionary:
	if not BasicResourceManager.can_afford("energy_block", cost):
		return {"ok": false, "reason_zh": "能量块不足"}
	BasicResourceManager.consume("energy_block", cost)
	var era: int = LevelEras.get_era(level)
	var reward: Dictionary = _grant_exchange_reward(item_key, era)
	if reward.is_empty():
		BasicResourceManager.add_resource("energy_block", cost)
		return {"ok": false, "reason_zh": "发放失败（已退款）"}
	return {"ok": true, "reason_zh": "兑换成功", "reward": reward}

# ─────────────────────────────────────────────────────────────
#  游猎相位师 + 迷失池（M4）
# ─────────────────────────────────────────────────────────────

## 按激活门补激活（day_ended / 关卡进度变化时调用，幂等）
func activate_roaming_if_due() -> void:
	var lpm: Node = get_node_or_null("/root/LevelProgressManager")
	if lpm == null or not "max_unlocked_level" in lpm:
		return
	var unlocked: int = int(lpm.max_unlocked_level)
	for i in range(ROAMING_UNLOCK_LEVELS.size()):
		if unlocked >= int(ROAMING_UNLOCK_LEVELS[i]) and roaming_masters.size() <= i:
			var name_i: String = _roaming_name_for_slot(i)
			if name_i.is_empty():
				continue
			roaming_masters.append({
				"master_id": name_i,
				"level": clampi(unlocked - ROAMING_SPAWN_OFFSET, 1, ROAMING_FINAL_LEVEL),
				"active": true,
			})
			SignalBus.feed_message.emit("侦测到游猎相位师：%s 正向黑门独行（第%d关附近）" % [name_i, unlocked - ROAMING_SPAWN_OFFSET])
			SignalBus.supply_state_changed.emit(0)

func _roaming_name_for_slot(slot: int) -> String:
	if slot < 0 or slot >= ROAMING_MASTER_NAMES.size():
		return ""
	var wanted: String = String(ROAMING_MASTER_NAMES[slot])
	# 池校验：名字必须在 NPC 池存在（防拼写漂移），不存在退空
	for cfg in NpcPhaseMasters.get_all():
		if String(cfg.get("name", "")) == wanted:
			return wanted
	return ""

## 每日移动：randi_range(0,2) 关向 100，永不后退，上限 2 关/日；到 100 迷失
func _roaming_daily_move(day: int) -> void:
	activate_roaming_if_due()
	for m in roaming_masters:
		if not bool(m.get("active", true)):
			continue
		var move: int = mini(randi_range(ROAMING_MOVE_MIN, ROAMING_MOVE_MAX), ROAMING_DAILY_CAP)
		var lv: int = int(m.get("level", 1)) + move
		if lv >= ROAMING_FINAL_LEVEL:
			m["level"] = ROAMING_FINAL_LEVEL
			m["active"] = false
			lose_roaming_master(String(m.get("master_id", "")), "roam", day)
		else:
			m["level"] = lv

## 迷失池登记（roam/garrison 共用；幂等）
func add_lost_master(master_id: String, origin: String, day: int = 0) -> void:
	if is_master_lost(master_id):
		return
	lost_masters.append({"master_id": master_id, "origin": origin, "lost_day": day})
	garrison_lost[master_id] = true

## 迷失：入 lost_masters 名册 + feed 播报（哀而不祥）+ 情报舱留档
func lose_roaming_master(master_id: String, origin: String, day: int) -> void:
	if is_master_lost(master_id):
		return
	add_lost_master(master_id, origin, day)
	SignalBus.feed_message.emit("%s 步入了黑门……从此它的身影只在门中怪物的轮廓里出现。" % _phase_master_display_name(master_id))

## 同关遭遇检测（卡车停靠/到站同关 → 必遭遇；优先级链中由 game_manager 插在驻守之后）
func get_roaming_master_at(level: int) -> Dictionary:
	for m in roaming_masters:
		if bool(m.get("active", true)) and int(m.get("level", -1)) == level:
			return m
	return {}

## 游猎行踪总览（情报舱消费）
func get_roaming_overview() -> Array:
	return roaming_masters.duplicate(true)

## 迷失名册（补给中枢面板消费）
func get_lost_overview() -> Array:
	return lost_masters.duplicate(true)

## 黑门变体 boss 池：迷失相位师 id 列表（EBM begin_run 波次规划消费）
func blackgate_variant_pool() -> Array:
	var out: Array = []
	for m in lost_masters:
		out.append(String(m.get("master_id", "")))
	return out

func _phase_master_display_name(master_id: String) -> String:
	# 驻守表与 NPC 池共用 id 口径（garrison 值即 enemy_master_XXX / 游猎名即 NPC name），
	# 展示名从 enemy_phase_masters 静态表直取，失败回显 id
	var master: Dictionary = EnemyPhaseMastersT.get_master_by_id(master_id)
	if not master.is_empty():
		return String(master.get("name", master_id))
	return master_id

# ─────────────────────────────────────────────────────────────
#  收复战 pending（镜像 EBM 渗透 meta 键机制；main._consume_incursion_meta 消费）
# ─────────────────────────────────────────────────────────────

var pending_reconquest_level: int = 0

func request_reconquest(level: int) -> void:
	pending_reconquest_level = level

func consume_pending_reconquest() -> int:
	var lv: int = pending_reconquest_level
	pending_reconquest_level = 0
	return lv

## 收复战胜利结算：状态迁移 + 威胁降压 + 遗物箱掷点（返回遗物箱结果供弹窗）
func settle_reconquest_victory(level: int, is_first_capture: bool) -> Dictionary:
	mark_reconquered(level)
	apply_reconquest_relief(level)
	var relic_pct: float = RECONQUEST_RELIC_FIRST_PCT if is_first_capture else RECONQUEST_RELIC_REPEAT_PCT
	var relic_result: Dictionary = {}
	if randf() * 100.0 < relic_pct:
		relic_result = open_relic_box()
	return {"relic": relic_result}

## 是否首次收复该关（遗物箱 45%/20% 口径消费）：未曾回溯过=首夺
func is_first_capture(level: int) -> bool:
	return not rewind_spent_levels.has(level)

# ─────────────────────────────────────────────────────────────
#  存档（schema v10 段：SaveConstants.SK_SUPPLY_NETWORK）
# ─────────────────────────────────────────────────────────────

func save_state() -> Dictionary:
	return {
		SAVE_KEY_THREAT: region_threat.duplicate(),
		SAVE_KEY_SEED: region_seed,
		SAVE_KEY_STATES: level_state.duplicate(),
		SAVE_KEY_GRADES: level_grades.duplicate(),
		SAVE_KEY_GRADE_BAK: fallen_grade_backup.duplicate(),
		SAVE_KEY_PITY: exchange_pity,
		SAVE_KEY_LOST: lost_masters.duplicate(true),
		SAVE_KEY_ROAMING: roaming_masters.duplicate(true),
		SAVE_KEY_GARRISON_LOST: garrison_lost.duplicate(),
		SAVE_KEY_REWIND_SPENT: rewind_spent_levels.duplicate(),
	}

func load_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	var threat: Variant = data.get(SAVE_KEY_THREAT, {})
	if threat is Dictionary:
		region_threat = {}
		for k in threat:
			region_threat[int(k)] = clampi(int(threat[k]), 0, 999)
	region_seed = maxi(0, int(data.get(SAVE_KEY_SEED, 0)))
	var states: Variant = data.get(SAVE_KEY_STATES, {})
	if states is Dictionary:
		level_state = {}
		for k in states:
			var s: String = String(states[k])
			if s == STATE_FALLEN or s == STATE_DEGRADED or s == STATE_HELD:
				level_state[int(k)] = s
	var grades: Variant = data.get(SAVE_KEY_GRADES, {})
	if grades is Dictionary:
		level_grades = {}
		for k in grades:
			var g: String = String(grades[k])
			if not g.is_empty():
				level_grades[int(k)] = g
	var bak: Variant = data.get(SAVE_KEY_GRADE_BAK, {})
	if bak is Dictionary:
		fallen_grade_backup = {}
		for k in bak:
			fallen_grade_backup[int(k)] = String(bak[k])
	exchange_pity = maxi(0, int(data.get(SAVE_KEY_PITY, 0)))
	var lost: Variant = data.get(SAVE_KEY_LOST, [])
	if lost is Array:
		lost_masters = (lost as Array).duplicate(true)
	var roaming: Variant = data.get(SAVE_KEY_ROAMING, [])
	if roaming is Array:
		roaming_masters = (roaming as Array).duplicate(true)
	var glost: Variant = data.get(SAVE_KEY_GARRISON_LOST, {})
	if glost is Dictionary:
		garrison_lost = {}
		for k in glost:
			garrison_lost[String(k)] = true
	var rewind: Variant = data.get(SAVE_KEY_REWIND_SPENT, {})
	if rewind is Dictionary:
		rewind_spent_levels = {}
		for k in rewind:
			rewind_spent_levels[int(k)] = true

## 新游戏全清（_reset_manager_by_name 兜底链；必须排在 load_state 分支之前——v6.65 教训）
func reset_state() -> void:
	region_threat = {}
	region_seed = 0
	level_state = {}
	level_grades = {}
	fallen_grade_backup = {}
	exchange_pity = 0
	lost_masters = []
	roaming_masters = []
	garrison_lost = {}
	rewind_spent_levels = {}
	pending_reconquest_level = 0
