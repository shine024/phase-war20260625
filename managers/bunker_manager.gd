extends Node
## 余烬要塞全局状态管理器 v21 P1
## 设计文档：docs/design_ember_bunker.md
## 挂载方式：ManagerLazyLoader.ensure_loaded("bunker")（非 autoload），
## 实例化后常驻 /root/BunkerManager，跨场景存活——战斗结束时仍能推进修复进度。
##
## 职责：房间状态机 / 天数 / 精神值 / 修复经济；P2 接存档段，P3 接英雄碎片。

const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")
const HeroArchiveTexts = preload("res://data/hero_archive_texts.gd")
const ManufacturePools = preload("res://data/manufacture_pools.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const TruckTravel = preload("res://data/truck_travel.gd")
const LevelInformationData = preload("res://data/level_information.gd")

## 运行期状态
var _day: int = 1
var _sanity: float = 100.0
var _rooms: Dictionary = {}        # room_id -> {"state": int, "level": int, "progress": float(0-1)}
var _hero_fragments: Array = []    # 已解锁英雄 master id（P3：遗物碎片，击败相位师掉落）
var _narrative_stage: int = 1
var _announced_stage: int = 1      # 已播报过切换字幕的情感阶段
var _completed_today: Array = []    # 今日（自上次睡觉起）完成修复的房间 id
var _bootstrap_granted := false    # 首次进基地应急储备是否已发放（存档持久化）
var _ration_day: int = 0           # 每日配给最后领取的天数（0=从未领过；同一天只发一次）
var _ending_id := ""               # P4 观星台终局抉择（rewrite/keep/depart；空=未抉择）
var _ending_day: int = 0           # 抉择发生的天数（结局徽记展示用）
var _intro_shown := false          # 首次进基地引导卡是否已展示（v22.4 P1-5）
var _win_streak := 0               # v29 R2a 连胜计数（运行态不入档；≥3 胜场精神消耗 -2，败场归零）
var _comic_seen := false           # 序章漫画开场是否已播过（v24，新档 comic_intro 收尾/醒来演出落档）

# ── v26 批次3：分析仪 / 地表探索 / 战利品打印 ──
var _analyzer_slot: Dictionary = {}   # 在机缴获卡 {archetype_id, rarity, battles_left}；空=空闲
var _analyzer_baked: int = 0          # 今日已出炉数
var _analyzer_baked_day: int = 0      # 出炉计数日界标记
var _expedition_day: int = 0          # 地表探索最后派遣天（日 1 次）
var _loot_print_day: int = 0          # 仓库战利品打印最后触发天（日 1 张）
# v26 批次4 补齐：兵棋室沙盘 / 荣誉室敬礼 / 气象站预报 / 相位实验室洗点
var _sandbox_instance_id := ""        # 沙盘演武卡（未上阵，后台吃 50% 经验）；空=未设置
var _salute_day: int = 0              # 出征仪式最后敬礼天（日 1 次）
var _salute_armed := false            # 已敬礼待生效（下一场战斗掉落 +10%，结算时消耗）
var _weather_day: int = -1            # 今日天气预报生成天（-1=从未生成）
var _weather_idx: int = 0             # 今日天气索引（WEATHERS 表）
var _weather_armed := false           # 已锁定预报（下一场战斗生效，结算时消耗）
var _respec_free_day: int = 0         # 洗点免费额度已用天（Lv3 每日首免）
var _battle_log: Array = []           # v26.12b 战斗日志（最近60条 {day,level,won}）——移动基地统计终端数据源
var _pending_battle_level: int = 0    # 开打时抓的关卡号（battle_ended 时 current_level 可能已被胜利推进）
var _pending_battle_endless: bool = false  # 开打时抓的黑门无尽标记（battle_ended 时 GameManager 已复位，事后查不到）
# ── v26.19 卡车行军（停哪打哪：出击=停靠关；行车耗燃料×地形，睡觉推进+回充）──
var _fuel := -1.0            # 燃料储备；<0=未初始化哨兵（首次读取按满罐结算，旧档免迁移）
var _engine_level := 1       # 引擎/传动 Lv1-5：速度与罐容随级提升
var _parked_level := 0       # 停靠关卡（0=未初始化哨兵→懒解析为战线前沿，旧档不被拽回第1关）
var _travel_dest := 0        # 行驶目的地（0=未在途）
var _travel_days_total := 0  # 行程总天数（大地图路线进度分母；0=未在途）
var _travel_started_unix := 0.0  # 出发时刻（unix 秒；v26.21 实时行军）
var _travel_ends_unix := 0.0     # 预计到站时刻（unix 秒）
var _fuel_regen_unix := 0.0      # v26.25 燃料自动回复结算时刻（unix 秒；0=未起算，首读置now——离线补结算走读侧累计）

## 荣誉陈列室解锁所需碎片数（P3 定 10：让中期玩家够得着；30 全收集是观星台条件）
const HONOR_HALL_FRAGMENT_GATE := 10

## 食堂每日配给（v22.3：替代基地内无法工作的 AFK 死键——AFKModeManager 由
## main.gd 创建注入，基地嵌入实例永远拿不到，面板所有按钮空守卫静默无效）。
## 量锚定日均纳米收入（~200-400）：食堂造价 200 纳米+100 合金，约两天回本。
const DAILY_RATION := {"nano": 120, "alloy": 40}

## v26 批次3 常量：分析仪每日限额/出炉场次；地表探索日 1 次
const ANALYZER_DAILY_LIMIT := 3
const ANALYZER_BAKE_BATTLES := 2
const EXPEDITION_CARD_CHANCE := 0.4   # 40% 带回缴获卡，否则资源包
const EXPEDITION_RESOURCES := {"nano": 80, "energy": 30, "alloy": 15}
const EXPEDITION_RES_NAMES := {"nano": "纳米", "energy": "能量块", "alloy": "合金"}
# v26 批次4 补齐常量
const SANDBOX_EXP_RATIO := 0.5        # 兵棋室 Lv3 沙盘演武：后台卡吃 50% 单卡经验
const SALUTE_DROP_BONUS := 0.10       # 荣誉室 Lv3 出征仪式：本场掉落收益 +10%
const RESPEC_BASE_COST := 100         # 相位实验室洗点基准费（纳米）；Lv2 半价 / Lv3 每日首免
## 气象站 Lv2 天气预报表：每日随机一条，出击前可锁定（下一场战斗我方全队属性乘区）
const WEATHERS: Array = [
	{"id": "sunny", "name": "晴朗", "desc": "视野良好，火力全开", "hp_pct": 0.0, "atk_pct": 0.08, "def_pct": 0.0},
	{"id": "tailwind", "name": "顺风", "desc": "风势助力机动与装填", "hp_pct": 0.0, "atk_pct": 0.05, "def_pct": 0.05},
	{"id": "highland", "name": "高地驻守", "desc": "地势有利，耐受提升", "hp_pct": 0.10, "atk_pct": 0.0, "def_pct": 0.05},
	{"id": "mud", "name": "泥泞", "desc": "行进困难，但依托掩体", "hp_pct": 0.12, "atk_pct": -0.05, "def_pct": 0.0},
	{"id": "storm", "name": "相位风暴", "desc": "高危高回报——攻击暴涨，防护削弱", "hp_pct": 0.0, "atk_pct": 0.15, "def_pct": -0.08},
]

## ───────────────────────── 生命周期 ─────────────────────────

## 数据初始化放 _init（而非 _ready）：ManagerLazyLoader 在 root 未就绪时会
## call_deferred 挂载，实例先被 get_manager() 返回但尚未进树——_ready 未跑、
## _rooms 为空的窗口期任何查询/修复调用都会踩空。
func _init() -> void:
	_init_rooms_from_defs()

func _ready() -> void:
	# 战斗结束 → 扣精神值 + 推进修复进度（本节点常驻 root，跨场景存活）
	if SignalBus and not SignalBus.battle_ended.is_connected(_on_battle_ended):
		SignalBus.battle_ended.connect(_on_battle_ended)
	# v26.12b：开打时抓关卡号（battle_ended 时 GameManager.current_level 可能已被胜利推进成下一关）
	if SignalBus and not SignalBus.battle_started.is_connected(_on_battle_started):
		SignalBus.battle_started.connect(_on_battle_started)

## v26.12b：战斗日志只读副本（移动基地统计终端消费）
func get_battle_log() -> Array:
	return _battle_log.duplicate(true)

func _on_battle_started() -> void:
	if GameManager != null:
		_pending_battle_level = int(GameManager.current_level)
		# 黑门无尽标记必须开打时抓：GameManager 的 battle_ended handler 先于本节点执行
		# 并在 _settle_endless_battle 里复位 _is_endless_battle，事后查恒 false
		_pending_battle_endless = GameManager.has_method("is_endless_battle") \
			and GameManager.is_endless_battle()

## ───────────────────── v26.19 卡车行军（停泊/燃料/引擎） ─────────────────────
## 数值真身在 data/truck_travel.gd（TruckTravel）；本节只管状态与结算。

## 停靠关卡：哨兵 0 → 懒解析为战线前沿（旧档不被拽回第 1 关；新档=第 1 关）
func get_parked_level() -> int:
	if _parked_level < 1:
		var lv := 0
		var lp := get_node_or_null("/root/LevelProgressManager")
		if lp != null and lp.has_method("get_max_unlocked_level"):
			lv = int(lp.get_max_unlocked_level())
		if lv < 1 and GameManager != null:
			lv = int(GameManager.get("current_level"))
		_parked_level = clampi(lv, 1, 100)
	return _parked_level

func get_fuel() -> float:
	if _fuel < 0.0:
		_fuel = float(get_fuel_cap())
	_sync_fuel_regen()
	return _fuel

## v26.25 燃料自动回复结算（读侧累计，写侧不额外触发）：按距上次结算的真实时长
## 增量回复并前移时间戳——离线/挂机/切场景的时长在下一次读取时一次性补齐；
## 时钟回拨（dt<0）只前移时间戳不倒扣；哨兵未初始化（_fuel<0）与满罐不累计。
func _sync_fuel_regen() -> void:
	var now := Time.get_unix_time_from_system()
	if _fuel_regen_unix <= 0.0:
		_fuel_regen_unix = now
		return
	var dt := now - _fuel_regen_unix
	_fuel_regen_unix = now
	if dt <= 0.0 or _fuel < 0.0:
		return
	var cap := float(get_fuel_cap())
	if _fuel >= cap:
		return
	_fuel = minf(cap, _fuel + dt / 60.0 * TruckTravel.regen_per_minute(_engine_level))

func get_fuel_cap() -> int:
	return TruckTravel.TANK_BASE + TruckTravel.TANK_PER_LV * (_engine_level - 1)

func get_engine_level() -> int:
	return _engine_level

func is_traveling() -> bool:
	return _travel_dest > 0 and _travel_ends_unix > 0.0

func get_travel_dest() -> int:
	return _travel_dest

## 剩余天数（实时行军：由剩余秒数换算，向上取整）
func get_travel_days_left() -> int:
	var rem := _travel_seconds_left()
	if rem <= 0.0:
		return 0
	return maxi(1, int(ceil(rem / TruckTravel.SECONDS_PER_DAY)))

func get_travel_days_total() -> int:
	return _travel_days_total

func _travel_seconds_left() -> float:
	if not is_traveling():
		return 0.0
	return maxf(0.0, _travel_ends_unix - Time.get_unix_time_from_system())

## 路线已走比例 0..1（大地图光点走位/路线两段绘制用；时间驱动）
func get_travel_progress() -> float:
	if not is_traveling() or _travel_days_total <= 0:
		return 0.0
	var total: float = float(_travel_days_total) * TruckTravel.SECONDS_PER_DAY
	if total <= 0.0:
		return 0.0
	return clampf(1.0 - _travel_seconds_left() / total, 0.0, 1.0)

func _process(_delta: float) -> void:
	# v26.21 实时行军：每帧对表，到点即到站（玩家在任何场景都成立）
	if _travel_dest > 0:
		_check_travel_arrival()

## 实时到站结算：unix 时间基准——挂机/离线/切场景都计时，读档后 _process 立即补结算
func _check_travel_arrival() -> void:
	if _travel_dest <= 0 or _travel_ends_unix <= 0.0:
		return
	if Time.get_unix_time_from_system() < _travel_ends_unix:
		return
	var dest := _travel_dest
	_parked_level = dest
	_travel_dest = 0
	_travel_days_total = 0
	_travel_started_unix = 0.0
	_travel_ends_unix = 0.0
	_sync_current_level_to_park()
	if SignalBus and SignalBus.has_signal("show_toast"):
		var nm := String(LevelInformationData.get_shared().get_level_display_name(dest))
		SignalBus.show_toast.emit("移动基地抵达 第%d关「%s」——可在此出击" % [dest, nm if nm != "" else str(dest)])
	_emit_travel_changed()

## 行军可行性预检（UI 规划弹窗与 start_travel 共用；不改任何状态）
func plan_travel(dest: int) -> Dictionary:
	if is_traveling():
		return {"ok": false, "reason": "卡车正在行驶中（剩 %d 天）" % get_travel_days_left()}
	var from := get_parked_level()
	dest = clampi(dest, 1, 100)
	if dest == from:
		return {"ok": false, "reason": "卡车已停靠该节点"}
	var cost := TruckTravel.fuel_cost(from, dest)
	if get_fuel() < float(cost) or float(cost) > get_fuel() - float(TruckTravel.RESERVE_FLOOR):
		var eta := TruckTravel.regen_minutes_until(get_fuel(), cost + TruckTravel.RESERVE_FLOOR, _engine_level)
		return {"ok": false, "reason": "燃料不够出车（本次需 %d，现有 %d）——自动回复 +%.0f/分钟，约 %d 分钟后够用；也可用能量块 1:1 充能（基地发电机工位）" % [
			cost, int(get_fuel()), TruckTravel.regen_per_minute(_engine_level), eta], "cost": cost}
	return {"ok": true, "cost": cost, "days": TruckTravel.travel_days(from, dest, _engine_level)}

## 启程：预检通过后即扣燃料、进入在途（到站靠睡觉推进）
func start_travel(dest: int) -> Dictionary:
	var plan := plan_travel(dest)
	if not bool(plan.get("ok", false)):
		return plan
	_fuel = maxf(0.0, get_fuel() - float(int(plan["cost"])))
	_travel_dest = clampi(dest, 1, 100)
	_travel_days_total = maxi(1, int(plan["days"]))
	_travel_started_unix = Time.get_unix_time_from_system()
	_travel_ends_unix = _travel_started_unix + float(_travel_days_total) * TruckTravel.SECONDS_PER_DAY
	_emit_travel_changed()
	return {"ok": true, "cost": int(plan["cost"]), "days": _travel_days_total}

## v26.25 能量块 → 燃料 1:1 充能（补满为止；能量块不足则把余额全部充入）
func charge_fuel_to_full() -> Dictionary:
	if BasicResourceManager == null:
		return {"ok": false, "reason": "资源系统未就绪"}
	_sync_fuel_regen()
	var need := TruckTravel.fuel_needed_to_fill(_fuel, get_fuel_cap())
	if need <= 0:
		return {"ok": false, "reason": "燃料已满（%d/%d）" % [int(_fuel), get_fuel_cap()]}
	var energy_id := BunkerRoomDefs.res_full_id("energy")
	var have := int(BasicResourceManager.get_total(energy_id))
	var spend := mini(need, have)
	if spend <= 0:
		return {"ok": false, "reason": "能量块不足（现有 %d）——战斗掉落/挂机可获得" % have}
	BasicResourceManager.consume(energy_id, spend)
	_fuel = minf(float(get_fuel_cap()), _fuel + float(spend))
	_emit_travel_changed()
	return {"ok": true, "charged": spend, "reason": "充能 +%d 燃料（能量块 1:1，剩 %d）" % [spend, have - spend]}

## 引擎升级（纳米+合金，价目见 TruckTravel.ENGINE_UPGRADES）
func upgrade_engine() -> Dictionary:
	if _engine_level >= TruckTravel.ENGINE_MAX_LV:
		return {"ok": false, "reason": "引擎已满级（Lv%d）" % TruckTravel.ENGINE_MAX_LV}
	var cost: Dictionary = TruckTravel.upgrade_cost(_engine_level)
	for short_id in cost:
		if BasicResourceManager == null or not BasicResourceManager.can_afford(
				BunkerRoomDefs.res_full_id(String(short_id)), int(cost[short_id])):
			return {"ok": false, "reason": "资源不足：需 %s" % BunkerRoomDefs.cost_text(cost)}
	for short_id2 in cost:
		BasicResourceManager.consume(BunkerRoomDefs.res_full_id(String(short_id2)), int(cost[short_id2]))
	_engine_level += 1
	_fuel = minf(get_fuel(), float(get_fuel_cap()))
	_emit_travel_changed()
	return {"ok": true, "reason": "引擎升级到 Lv%d" % _engine_level}

## 战后把 current_level 拉回停靠关——GameManager 胜利后会把 current_level 推进到
## 战线前沿（quest/挂机读它），但"现在能打哪"由停靠点决定，deferred 等各 handler 落定
func _sync_current_level_to_park() -> void:
	if GameManager != null and GameManager.has_method("set_current_level"):
		GameManager.set_current_level(get_parked_level())

func _emit_travel_changed() -> void:
	if SignalBus and SignalBus.has_signal("truck_travel_changed"):
		SignalBus.truck_travel_changed.emit()

func _init_rooms_from_defs() -> void:
	_rooms.clear()
	for def in BunkerRoomDefs.get_all_rooms():
		_rooms[def["id"]] = {
			"state": int(def.get("initial", BunkerRoomDefs.STATE_LOCKED)),
			"level": 1,
			"progress": 0.0,
			"upgrading": false,
			"upg_progress": 0.0,
		}
	# 存档恢复（P2 接 SaveManager 前的会话内兜底）：bunker_main 切场景时写 Engine meta
	if Engine.has_meta("bunker_runtime_state"):
		load_state_dict(Engine.get_meta("bunker_runtime_state"))
		Engine.remove_meta("bunker_runtime_state")

## 场景卸载前由 bunker_main 调用：把状态寄存到 Engine meta，跨 change_scene 存活
func stash_runtime_state() -> void:
	Engine.set_meta("bunker_runtime_state", get_state_dict())

## ───────────────────────── 查询 ─────────────────────────

func get_day() -> int:
	return _day

func get_sanity() -> float:
	return _sanity

func get_narrative_stage() -> int:
	return _narrative_stage

func get_room_state(room_id: String) -> int:
	return int(_rooms.get(room_id, {}).get("state", BunkerRoomDefs.STATE_LOCKED))

func get_room_progress(room_id: String) -> float:
	return float(_rooms.get(room_id, {}).get("progress", 0.0))

func get_room_level(room_id: String) -> int:
	return int(_rooms.get(room_id, {}).get("level", 1))

func is_reactor_online() -> bool:
	return get_room_state("reactor") == BunkerRoomDefs.STATE_ACTIVE

## 反应堆未上线时，深层设施（needs_power：通讯室/荣誉室）修复进度冻结；
## 上层房间靠基地备用电池供电，不受影响。反应堆自身当然不冻结。
func is_repair_frozen(room_id: String) -> bool:
	if room_id == "reactor" or is_reactor_online():
		return false
	var def := BunkerRoomDefs.get_room(room_id)
	return bool(def.get("needs_power", false))

## ───────────────────────── 修复经济 ─────────────────────────

## 首次进入基地发放一次性应急储备（P2）：新档 0 资源无法修复兵棋室（200 纳米），
## "进基地→无钱修→出不去"是死局。250 纳米够开工首间，80 合金留作小目标。
## bootstrap_granted 随存档持久化，新游戏重置后重发。
func maybe_grant_bootstrap() -> void:
	if _bootstrap_granted:
		return
	_bootstrap_granted = true
	if BasicResourceManager == null:
		return
	BasicResourceManager.add_resource(BunkerRoomDefs.res_full_id("nano"), 250)
	BasicResourceManager.add_resource(BunkerRoomDefs.res_full_id("alloy"), 80)

## 启动修复。返回 {"ok": bool, "reason": String}；成功即扣资源并入修复中状态。
func start_repair(room_id: String) -> Dictionary:
	var def := BunkerRoomDefs.get_room(room_id)
	if def.is_empty():
		return {"ok": false, "reason": "未知房间"}
	if def.get("is_terminal", false):
		return {"ok": false, "reason": "终局房间：需满足特定条件才能开启"}
	if get_room_state(room_id) != BunkerRoomDefs.STATE_LOCKED:
		return {"ok": false, "reason": "该房间不在可修复状态"}
	if not _rooms.has(room_id):
		return {"ok": false, "reason": "房间状态未初始化"}
	# P3：荣誉陈列室碎片门槛（10 位英雄遗物）
	if room_id == "honor_hall" and _hero_fragments.size() < HONOR_HALL_FRAGMENT_GATE:
		return {"ok": false, "reason": "需要 %d 份同伴遗物（当前 %d）——去击败驻守的相位师" % [
			HONOR_HALL_FRAGMENT_GATE, _hero_fragments.size()]}
	# 成本校验与扣除（BasicResourceManager 为 autoload）
	var cost: Dictionary = def.get("cost", {})
	if not cost.is_empty():
		if BasicResourceManager == null:
			return {"ok": false, "reason": "资源系统未就绪"}
		for short_id in cost:
			var full_id: String = BunkerRoomDefs.res_full_id(short_id)
			var amount: int = int(cost[short_id])
			if not BasicResourceManager.can_afford(full_id, amount):
				return {"ok": false, "reason": "资源不足（需 %s）" % BunkerRoomDefs.cost_text(cost)}
		for short_id in cost:
			BasicResourceManager.consume(
				BunkerRoomDefs.res_full_id(short_id), int(cost[short_id]))
	_rooms[room_id]["state"] = BunkerRoomDefs.STATE_REPAIRING
	_rooms[room_id]["progress"] = 0.0
	_emit_room_changed(room_id)
	return {"ok": true, "reason": "开始修复"}

## 战斗结束回调：每场推进所有"修复中/升级中"房间一格；胜利/失败扣精神值。
## P3：胜利 + 相位师战斗 → 掉落英雄遗物碎片（ GameManager 在同一信号链上先跑且
## 延迟清除 _current_phase_master，此处读取安全）。
func _on_battle_ended(player_won: bool) -> void:
	# v26.12b：记录战斗日志（仅关卡战斗）。黑门无尽 run 不记——world_map 进门前把
	# current_level 对齐 100，且唯一终局是 end_battle(false)（"永不判胜"），混入会
	# 把无尽 run 记成"第100关·负"污染胜率统计；无尽战报由 EndlessBlackgateManager
	# .settle_run 自行记账（波数/击杀/星髓/最佳）。
	var fought := _pending_battle_level
	var was_endless := _pending_battle_endless
	_pending_battle_level = 0
	_pending_battle_endless = false
	if fought > 0 and not was_endless:
		# v26.13：日志扩展伤害/时长（统计终端曲线数据源）
		var _bs: Dictionary = _read_battle_stats()
		_battle_log.append({
			"day": _day, "level": fought, "won": bool(player_won),
			"kills": int(_bs.get("player_kills", 0)),
			"damage": int(_bs.get("damage_dealt", 0)),
			"duration": int(float(_bs.get("battle_time", 0.0))),
		})
		if _battle_log.size() > 60:
			_battle_log = _battle_log.slice(_battle_log.size() - 60)
	advance_after_battle(player_won)
	if player_won and GameManager != null and GameManager.has_method("is_phase_master_battle") \
			and GameManager.is_phase_master_battle():
		var master: Dictionary = GameManager.get_current_phase_master()
		var master_id := str(master.get("id", ""))
		if not master_id.is_empty():
			record_hero_fragment(master_id)
	# v26.19：current_level 回归停靠关（GameManager 的胜利推进在其自身 handler 里已落定）
	call_deferred("_sync_current_level_to_park")

## v26.12c：读战斗统计引擎的我方击杀数（main.tscn 墓碑节点内的 BattleInfoDisplay；
## 不在场——如从移动基地外的非常规流程结束时——返回 0，日志照记）
func _read_battle_stats() -> Dictionary:
	var tree := get_tree()
	if tree == null:
		return {}
	var disp: Node = tree.root.find_child("BattleInfoDisplay", true, false)
	if disp != null and disp.has_method("get_battle_stats"):
		return disp.call("get_battle_stats") as Dictionary
	return {}

func advance_after_battle(player_won: bool) -> Array:
	# 兵棋室 Lv2 战前简报：胜利精神消耗 10→8；失败 -20 不变
	# v29 R2a（设计审查 F-15）：连胜 3 场起胜场消耗再 -2（下限 6）——满精神原本
	# 10-12 场胜仗就强制回基地睡觉，与燃料税叠加对主动玩家节奏税过重；
	# 连胜减免让"状态好连续推进"的体验成立（_win_streak 运行态，读档重置=软机制）。
	if player_won:
		_win_streak += 1
	else:
		_win_streak = 0
	var win_cost: float = 20.0
	if player_won:
		win_cost = get_battle_sanity_win_cost()
		if _win_streak >= 3:
			win_cost = maxf(6.0, win_cost - 2.0)
	adjust_sanity(-win_cost if player_won else -20.0)
	var completed: Array = []
	for room_id in _rooms:
		if int(_rooms[room_id]["state"]) != BunkerRoomDefs.STATE_REPAIRING:
			continue
		if is_repair_frozen(room_id):
			continue  # 反应堆未上线：进度冻结
		var def := BunkerRoomDefs.get_room(room_id)
		var battles_needed: int = max(1, int(def.get("battles", 1)))
		_rooms[room_id]["progress"] = float(_rooms[room_id]["progress"]) + 1.0 / battles_needed
		if float(_rooms[room_id]["progress"]) >= 1.0:
			_rooms[room_id]["progress"] = 1.0
			_rooms[room_id]["state"] = BunkerRoomDefs.STATE_ACTIVE
			completed.append(room_id)
			_completed_today.append(room_id)
			_emit_room_changed(room_id)
	# 升级进度：与修复同构，每场推进一格；深层设施同样受反应堆冻结约束。
	# 升级中房间保持 ACTIVE（功能不中断），完成后进 _completed_today 进日结算。
	for room_id in _rooms:
		if not bool(_rooms[room_id].get("upgrading", false)):
			continue
		if is_repair_frozen(room_id):
			continue
		var upg := get_next_upgrade(room_id)
		if upg.is_empty():
			_rooms[room_id]["upgrading"] = false
			continue
		var battles_needed: int = max(1, int(upg.get("battles", 1)))
		_rooms[room_id]["upg_progress"] = float(_rooms[room_id].get("upg_progress", 0.0)) \
				+ 1.0 / battles_needed
		if float(_rooms[room_id]["upg_progress"]) >= 1.0:
			_rooms[room_id]["upg_progress"] = 0.0
			_rooms[room_id]["upgrading"] = false
			_rooms[room_id]["level"] = int(_rooms[room_id]["level"]) + 1
			completed.append(room_id)
			# 升级完工带 #up 后缀（与修复完工区分；消费方走
			# BunkerRoomDefs.completed_entry_label 统一解析）
			_completed_today.append(room_id + "#up")
			_emit_room_changed(room_id)
	# v26 批次3：分析仪在机卡每场推进（出炉即烧毁入账，见 _analyzer_tick）
	_analyzer_tick()
	return completed

## ───────────────────────── 房间升级（v26 批次1） ─────────────────────────

## 房间最高等级（无升级档的房间恒 1）
func get_max_room_level(room_id: String) -> int:
	return BunkerRoomDefs.get_max_level(room_id)

## 下一级升级定义（已满级/无升级档返回 {}）
func get_next_upgrade(room_id: String) -> Dictionary:
	return BunkerRoomDefs.get_upgrade_def(room_id, get_room_level(room_id) + 1)

func is_upgrading(room_id: String) -> bool:
	return bool(_rooms.get(room_id, {}).get("upgrading", false))

func get_upgrade_progress(room_id: String) -> float:
	return float(_rooms.get(room_id, {}).get("upg_progress", 0.0))

## 升级资格检查。返回 {"ok": bool, "reason": String}。
func can_start_upgrade(room_id: String) -> Dictionary:
	var def := BunkerRoomDefs.get_room(room_id)
	if def.is_empty():
		return {"ok": false, "reason": "未知房间"}
	if def.get("is_terminal", false):
		return {"ok": false, "reason": "终局房间不可升级"}
	if get_room_state(room_id) != BunkerRoomDefs.STATE_ACTIVE:
		return {"ok": false, "reason": "房间须先修复可用"}
	if is_upgrading(room_id):
		return {"ok": false, "reason": "升级进行中"}
	var upg := get_next_upgrade(room_id)
	if upg.is_empty():
		return {"ok": false, "reason": "已达最高等级"}
	if BasicResourceManager == null:
		return {"ok": false, "reason": "资源系统未就绪"}
	var cost: Dictionary = upg.get("cost", {})
	for short_id in cost:
		if not BasicResourceManager.can_afford(BunkerRoomDefs.res_full_id(short_id), int(cost[short_id])):
			return {"ok": false, "reason": "资源不足（需 %s）" % BunkerRoomDefs.cost_text(cost)}
	return {"ok": true, "reason": "可升级"}

## 开始升级：即扣资源，升级进度由完成战斗推进（与修复同构）。
## 返回 {"ok": bool, "reason": String}。
func start_upgrade(room_id: String) -> Dictionary:
	var check := can_start_upgrade(room_id)
	if not check.get("ok", false):
		return check
	var upg := get_next_upgrade(room_id)
	var cost: Dictionary = upg.get("cost", {})
	for short_id in cost:
		BasicResourceManager.consume(BunkerRoomDefs.res_full_id(short_id), int(cost[short_id]))
	_rooms[room_id]["upgrading"] = true
	_rooms[room_id]["upg_progress"] = 0.0
	_emit_room_changed(room_id)
	return {"ok": true, "reason": "开始升级到 Lv%d" % (get_room_level(room_id) + 1)}

## ───────────────────── 升级效果查询（等级驱动，UI/各系统消费） ─────────────────────

## 精神值上限：入口大厅 Lv3 → 110
func get_sanity_cap() -> float:
	return 110.0 if get_room_level("entry_hall") >= 3 else 100.0

## 睡觉回精神量：宿舍 Lv1/2/3 → 20/30/40
func get_sleep_recovery() -> float:
	return [20.0, 30.0, 40.0][clampi(get_room_level("dormitory") - 1, 0, 2)]

## 每日配给：食堂 Lv1/2/3 → ×1/×1.5/×2；反应堆 Lv2 电网增容再 +10%
func get_daily_ration() -> Dictionary:
	var mult: float = [1.0, 1.5, 2.0][clampi(get_room_level("mess_hall") - 1, 0, 2)]
	if get_room_level("reactor") >= 2:
		mult *= 1.1
	var out := {}
	for short_id in DAILY_RATION:
		out[short_id] = int(round(float(DAILY_RATION[short_id]) * mult))
	return out

## 医疗费用：医疗室 Lv3 → 50→30 纳米
func get_medical_cost() -> int:
	return 30 if get_room_level("medical") >= 3 else 50

## 医疗疗效：医疗室 Lv2 → 40→60
func get_medical_recovery() -> float:
	return 60.0 if get_room_level("medical") >= 2 else 40.0

## 出击胜利精神消耗：兵棋室 Lv2 → 8（失败 -20 恒定，走 advance_after_battle）
func get_battle_sanity_win_cost() -> float:
	return 8.0 if get_room_level("war_room") >= 2 else 10.0

## 制造资源消耗乘区：工坊 Lv1/2/3 → 1.0/0.9/0.8（制造系统批次2 消费）
func get_manufacture_discount() -> float:
	return [1.0, 0.9, 0.8][clampi(get_room_level("workshop") - 1, 0, 2)]

## 改造安装费折扣：工坊 Lv3 → 0.85（改造面板消费）
func get_mod_install_discount() -> float:
	return 0.85 if get_room_level("workshop") >= 3 else 1.0

## 全局情报获取乘区：档案室 Lv3 → 1.1（intel_manual._add_intel 消费）
func get_intel_gain_multiplier() -> float:
	return 1.1 if get_room_level("archive") >= 3 else 1.0

## 商店每日免费刷新加成：通讯室 Lv2 → +1（商店面板消费）
func get_shop_free_refresh_bonus() -> int:
	return 1 if get_room_level("comms") >= 2 else 0

## 势力声望获取乘区：通讯室 Lv3 → 1.15（势力系统消费）
func get_faction_rep_multiplier() -> float:
	return 1.15 if get_room_level("comms") >= 3 else 1.0

## 分析仪是否上线：档案室 Lv2（分析仪交互批次3 消费）
func is_analyzer_online() -> bool:
	return get_room_level("archive") >= 2

## 档案室 Lv3 → 制造 epic+ 权重 ×1.5（ManufactureManager.get_effective_pool 消费）
func get_pool_high_boost() -> float:
	return 1.5 if get_room_level("archive") >= 3 else 1.0

## ───────────────────── 档案室：分析仪（v26 批次3） ─────────────────────

func analyzer_baked_today() -> int:
	return _analyzer_baked if _analyzer_baked_day == _day else 0

## 分析仪状态快照（房间面板 UI 消费）
func analyzer_state() -> Dictionary:
	return {
		"online": is_analyzer_online(),
		"slot": _analyzer_slot.duplicate(),
		"baked_today": analyzer_baked_today(),
		"daily_limit": ANALYZER_DAILY_LIMIT,
		"battles_needed": ANALYZER_BAKE_BATTLES,
	}

## 放入缴获卡：即时销毁入机，打 ANALYZER_BAKE_BATTLES 场后出炉入账情报。
## 返回 {"ok": bool, "reason": String}
func analyzer_insert(instance_id: String) -> Dictionary:
	if not is_analyzer_online():
		return {"ok": false, "reason": "分析仪未上线（需档案室 Lv2）"}
	if not _analyzer_slot.is_empty():
		return {"ok": false, "reason": "分析仪已在工作中（同时间只能烧一张）"}
	if analyzer_baked_today() >= ANALYZER_DAILY_LIMIT:
		return {"ok": false, "reason": "今日分析额度已用完（每日 %d 张）" % ANALYZER_DAILY_LIMIT}
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir == null:
		return {"ok": false, "reason": "实例系统未就绪"}
	var inst: CardResource = ir.get_instance(instance_id)
	if inst == null:
		return {"ok": false, "reason": "卡牌不存在"}
	var cid := String(inst.card_id)
	if not cid.begins_with("captured_"):
		return {"ok": false, "reason": "只能放入缴获兵种卡"}
	# 上阵中的卡先卸下才能烧
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim != null and pim.has_method("get_slot_card_ids"):
		if instance_id in pim.get_slot_card_ids():
			return {"ok": false, "reason": "该卡已上阵，先卸下再分析"}
	var archetype := cid.substr("captured_".length())
	_analyzer_slot = {
		"archetype_id": archetype,
		"rarity": String(inst.rarity),
		"battles_left": ANALYZER_BAKE_BATTLES,
	}
	ir.dispose_instance(instance_id)
	if SignalBus and SignalBus.has_signal("backpack_changed"):
		SignalBus.backpack_changed.emit()
	return {"ok": true, "reason": "已放入分析仪（%d 场战斗后出炉）" % ANALYZER_BAKE_BATTLES}

## 每场战斗推进在机卡（advance_after_battle 尾部调用）；
## 出炉 → 按品质给情报（档案室 Lv3 全局 +10% 由 _add_intel 内部乘区自动生效）
func _analyzer_tick() -> void:
	if _analyzer_slot.is_empty():
		return
	_analyzer_slot["battles_left"] = int(_analyzer_slot.get("battles_left", 0)) - 1
	if int(_analyzer_slot["battles_left"]) > 0:
		return
	var archetype := String(_analyzer_slot.get("archetype_id", ""))
	var rarity := String(_analyzer_slot.get("rarity", "common"))
	_analyzer_slot = {}
	if archetype.is_empty():
		return
	var amount := ManufacturePools.analyzer_yield(rarity)
	IntelManual.register_analyzer_analysis(archetype, amount)
	_analyzer_baked_day = _day
	_analyzer_baked += 1
	var pid := String(EnemyCardModMap.get_config(archetype).get("player_card_id", ""))
	var display: String = DefaultCards.get_safe_display_name(pid) if not pid.is_empty() else archetype
	if SignalBus and SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit("分析仪出炉：「%s」情报 +%d%%" % [display, int(round(amount * 100.0))])

## ───────────────────── 缴获卡生成（分析仪燃料/仓库打印共用） ─────────────────────

## 随机生成一张缴获卡（manifest 全敌形池均匀随机 + 品质滚动）并入包。
## 池源用 EnemyUnitManifest.drop_card_id——与 CapturedUnitCards 动态注册的
## 模板集同源，保证 create_instance 必有模板（EnemyCardModMap 键含 platform_*
## 等无 captured 模板的条目，不能直接用）。
## 返回 {"name", "rarity", "instance_id"}；失败返回 {}。
func print_random_captured_card() -> Dictionary:
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir == null:
		return {}
	var entries := EnemyUnitManifest.get_entries()
	if entries.is_empty():
		return {}
	var entry: Dictionary = entries[randi() % entries.size()]
	var drop_id := String(entry.get("drop_card_id", ""))
	if drop_id.is_empty():
		return {}
	var inst: CardResource = ir.create_instance(drop_id)
	if inst == null:
		return {}
	ManufacturePools.apply_captured_quality(inst)
	if SignalBus and SignalBus.has_signal("card_added_to_backpack"):
		SignalBus.card_added_to_backpack.emit(inst)
	return {
		"name": String(entry.get("display_name", drop_id)),
		"rarity": String(inst.rarity),
		"instance_id": String(inst.instance_id),
	}

## ───────────────────── 仓库：战利品打印（v26 批次3，Lv3） ─────────────────────

func is_loot_printer_online() -> bool:
	return get_room_level("depot") >= 3## 气象站：地表探索在线（Lv3）
func is_expedition_online() -> bool:
	return get_room_level("weather_station") >= 3

func expedition_used_today() -> bool:
	return _expedition_day == _day and _day > 0

## 地表探索：日 1 次，即时结算——40% 缴获卡 / 60% 资源包。
## 返回 {"ok", "reason", "rewards": Array[String]}
func start_expedition() -> Dictionary:
	if not is_expedition_online():
		return {"ok": false, "reason": "地表探索未解锁（需气象站 Lv3）"}
	if get_room_state("weather_station") != BunkerRoomDefs.STATE_ACTIVE:
		return {"ok": false, "reason": "气象站尚未修复"}
	if expedition_used_today():
		return {"ok": false, "reason": "侦察队今日已派出，明天再来"}
	_expedition_day = _day
	var rewards: Array = []
	if randf() < EXPEDITION_CARD_CHANCE:
		var card_res := print_random_captured_card()
		if card_res.is_empty():
			rewards.append("什么也没找到")
		else:
			rewards.append("缴获卡「%s」（%s）" % [str(card_res.get("name", "")), str(card_res.get("rarity", ""))])
	else:
		if BasicResourceManager == null:
			return {"ok": false, "reason": "资源系统未就绪"}
		for short_id in EXPEDITION_RESOURCES:
			BasicResourceManager.add_resource(BunkerRoomDefs.res_full_id(short_id), int(EXPEDITION_RESOURCES[short_id]))
			rewards.append("%s×%d" % [EXPEDITION_RES_NAMES.get(short_id, short_id), int(EXPEDITION_RESOURCES[short_id])])
	return {"ok": true, "reason": "侦察队带回：" + "、".join(rewards), "rewards": rewards}

## ───────────────────── 兵棋室：沙盘演武（v26 批次4，Lv3） ─────────────────────
## 设计：1 张未上阵卡后台吃 50% 经验（战后结算按单卡经验 × SANDBOX_EXP_RATIO 发放）。

func is_sandbox_online() -> bool:
	return get_room_level("war_room") >= 3

## 设置沙盘卡；校验实例存在、未上阵、未重复设置。
## 返回 {"ok", "reason"}
func set_sandbox_card(instance_id: String) -> Dictionary:
	if not is_sandbox_online():
		return {"ok": false, "reason": "沙盘演武未解锁（需兵棋室 Lv3）"}
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir == null or instance_id.is_empty():
		return {"ok": false, "reason": "实例系统未就绪"}
	var inst: CardResource = ir.get_instance(instance_id) if ir.has_method("get_instance") else null
	if inst == null:
		return {"ok": false, "reason": "卡牌不存在（可能已销毁）"}
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim != null and pim.has_method("get_slot_card_ids"):
		if instance_id in pim.get_slot_card_ids():
			return {"ok": false, "reason": "该卡已上阵，沙盘只收未上阵的卡"}
	if _sandbox_instance_id == instance_id:
		return {"ok": false, "reason": "该卡已在沙盘中"}
	_sandbox_instance_id = instance_id
	return {"ok": true, "reason": "「%s」进入沙盘演武——每场战斗后台获得 50% 经验" % inst.display_name}

func clear_sandbox_card() -> void:
	_sandbox_instance_id = ""

func get_sandbox_instance_id() -> String:
	return _sandbox_instance_id

## 战后结算调用：给沙盘卡发放 50% 单卡经验。返回实际发放值（0=未设置/未解锁）。
func grant_sandbox_exp(per_card_exp: int) -> int:
	if _sandbox_instance_id.is_empty() or not is_sandbox_online():
		return 0
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir == null or not ir.has_method("add_experience"):
		return 0
	var exp := int(round(float(per_card_exp) * SANDBOX_EXP_RATIO))
	if exp <= 0:
		return 0
	# 沙盘卡可能在战斗间隙被销毁——静默跳过并清槽
	if ir.has_method("has_instance") and not ir.has_instance(_sandbox_instance_id):
		_sandbox_instance_id = ""
		return 0
	ir.add_experience(_sandbox_instance_id, exp)
	return exp

## ───────────────────── 荣誉室：出征仪式（v26 批次4，Lv3） ─────────────────────
## 设计：日 1 次敬礼，本场（下一场战斗）掉落收益 +10%；结算时消耗。

func is_salute_online() -> bool:
	return get_room_level("honor_hall") >= 3

func salute_used_today() -> bool:
	return _salute_day == _day

func is_salute_armed() -> bool:
	return _salute_armed

## 敬礼：武装 +10% 掉落加成到下一场战斗。
## 返回 {"ok", "reason"}
func do_salute() -> Dictionary:
	if not is_salute_online():
		return {"ok": false, "reason": "出征仪式未解锁（需荣誉室 Lv3）"}
	if get_room_state("honor_hall") != BunkerRoomDefs.STATE_ACTIVE:
		return {"ok": false, "reason": "荣誉室尚未修复"}
	if salute_used_today():
		return {"ok": false, "reason": "今日已敬礼，明天再来"}
	if _salute_armed:
		return {"ok": false, "reason": "已有仪式加成在身——先出击消耗它"}
	_salute_day = _day
	_salute_armed = true
	return {"ok": true, "reason": "出征仪式完成——下一场战斗掉落收益 +%d%%" % int(SALUTE_DROP_BONUS * 100)}

## 战斗结算调用：返回本场掉落乘区（敬礼武装→1.1 并消耗；否则 1.0）。
func consume_salute() -> float:
	if not _salute_armed:
		return 1.0
	_salute_armed = false
	return 1.0 + SALUTE_DROP_BONUS

## ───────────────────── 气象站：天气预报（v26 批次4，Lv2） ─────────────────────
## 设计：每日随机一条环境预报，出击前可锁定（下一场战斗我方全队属性乘区，结算时消耗）。
## 项目无天气系统，本实现为独立轻量预报（WEATHERS 表），不影响其他系统数值。

func is_forecast_online() -> bool:
	return get_room_level("weather_station") >= 2

## 今日预报；Lv2 前返回空字典。日切换时惰性重掷。
func get_today_weather() -> Dictionary:
	if not is_forecast_online():
		return {}
	if _weather_day != _day:
		_weather_day = _day
		_weather_idx = randi() % WEATHERS.size()
		_weather_armed = false
	return WEATHERS[_weather_idx]

func is_weather_armed() -> bool:
	return _weather_armed

## 锁定今日预报：效果生效于下一场战斗。返回 {"ok", "reason", "weather"}
func lock_weather() -> Dictionary:
	if not is_forecast_online():
		return {"ok": false, "reason": "天气预报未解锁（需气象站 Lv2）"}
	if get_room_state("weather_station") != BunkerRoomDefs.STATE_ACTIVE:
		return {"ok": false, "reason": "气象站尚未修复"}
	if _weather_armed:
		return {"ok": false, "reason": "预报已锁定——先出击消耗它"}
	var w := get_today_weather()
	if w.is_empty():
		return {"ok": false, "reason": "今日无预报"}
	_weather_armed = true
	return {"ok": true, "reason": "已锁定预报「%s」——下一场战斗生效" % str(w.get("name", "")), "weather": w}

## 战斗生成调用：锁定中的天气属性乘区 {hp_pct, atk_pct, def_pct}；未锁定返回全 0。
func get_active_weather_bonus() -> Dictionary:
	if not _weather_armed:
		return {"hp_pct": 0.0, "atk_pct": 0.0, "def_pct": 0.0}
	_weather_armed = false
	var w: Dictionary = WEATHERS[_weather_idx] if _weather_idx >= 0 and _weather_idx < WEATHERS.size() else {}
	return {
		"hp_pct": float(w.get("hp_pct", 0.0)),
		"atk_pct": float(w.get("atk_pct", 0.0)),
		"def_pct": float(w.get("def_pct", 0.0)),
	}

## ───────────────────── 相位实验室：洗点费（v26 批次4） ─────────────────────
## 设计：Lv2 洗点费 -50% / Lv3 每日 1 次免费。基准费 RESPEC_BASE_COST（纳米），
## 由相位仪面板（phase_instrument_selector）在洗点时收取。

## 当前洗点费用（纳米）：Lv3 且今日未用免费额度→0；Lv≥2→半价；否则→基准价。
func get_respec_cost() -> int:
	var lv := get_room_level("phase_lab")
	if lv >= 3:
		return 0 if _respec_free_day != _day else int(RESPEC_BASE_COST * 0.5)
	if lv >= 2:
		return int(RESPEC_BASE_COST * 0.5)
	return RESPEC_BASE_COST

## 洗点完成回调：若本次费用为 0（用掉免费额度）则记账。
func notify_respec_done(cost_paid: int) -> void:
	if cost_paid <= 0 and get_room_level("phase_lab") >= 3:
		_respec_free_day = _day

## ───────────────────────── 日循环 / 精神值 ─────────────────────────

## 睡觉：天数 +1，精神值恢复（随宿舍等级 20/30/40），推进情感阶段，产出日结算数据。
## 返回 {"day", "sanity_before", "sanity_after", "completed_today", "stage"}。
func sleep() -> Dictionary:
	_day += 1
	var before: float = _sanity
	adjust_sanity(get_sleep_recovery())
	var new_stage: int = BunkerRoomDefs.narrative_stage_for_day(_day)
	if new_stage != _narrative_stage:
		_narrative_stage = new_stage
	# v26.19：睡觉回充燃料；v26.21 起行程由实时时间推进，睡觉不再 tick 行程
	_fuel = minf(float(get_fuel_cap()), get_fuel() + float(TruckTravel.SLEEP_REFUEL))
	# v26 批次3：仓库 Lv3 战利品打印——每天醒来随机 1 张缴获卡入包
	var loot_printed := {}
	if is_loot_printer_online() and _loot_print_day != _day \
			and get_room_state("depot") == BunkerRoomDefs.STATE_ACTIVE:
		_loot_print_day = _day
		loot_printed = print_random_captured_card()
	var summary := {
		"day": _day,
		"sanity_before": before,
		"sanity_after": _sanity,
		"completed_today": _completed_today.duplicate(),
		"stage": _narrative_stage,
		"loot_printed": loot_printed,
		"fuel": get_fuel(),
		"fuel_cap": get_fuel_cap(),
	}
	_completed_today.clear()
	if SignalBus and SignalBus.has_signal("bunker_day_ended"):
		SignalBus.bunker_day_ended.emit(_day)
	_emit_travel_changed()
	return summary

## 医疗室治疗：费用/疗效随医疗室等级提升（基础 纳米50 · 精神+40）。返回 {"ok", "reason"}。
func medical_treatment() -> Dictionary:
	if _sanity >= get_sanity_cap() - 0.5:
		return {"ok": false, "reason": "精神状态良好，无需治疗"}
	if BasicResourceManager == null:
		return {"ok": false, "reason": "资源系统未就绪"}
	var cost := get_medical_cost()
	var nano_id: String = BunkerRoomDefs.res_full_id("nano")
	if not BasicResourceManager.can_afford(nano_id, cost):
		return {"ok": false, "reason": "纳米材料不足（需 %d）" % cost}
	BasicResourceManager.consume(nano_id, cost)
	var recover := get_medical_recovery()
	adjust_sanity(recover)
	return {"ok": true, "reason": "精神 +%d" % int(round(recover))}

func adjust_sanity(delta: float) -> void:
	_sanity = clampf(_sanity + delta, 0.0, get_sanity_cap())

## ───────────────────── 食堂：每日配给（v22.3） ─────────────────────

func is_ration_claimed_today() -> bool:
	return _ration_day == _day and _day > 0

## 每天一次的免费补给（睡觉推进天数后重置）。量随食堂等级/反应堆电网提升。
## 返回 {"ok", "reason"}。
func claim_daily_ration() -> Dictionary:
	if get_room_state("mess_hall") != BunkerRoomDefs.STATE_ACTIVE:
		return {"ok": false, "reason": "食堂尚未修复"}
	if is_ration_claimed_today():
		return {"ok": false, "reason": "今日配给已领取，明天再来"}
	if BasicResourceManager == null:
		return {"ok": false, "reason": "资源系统未就绪"}
	var ration := get_daily_ration()
	for short_id in ration:
		BasicResourceManager.add_resource(
			BunkerRoomDefs.res_full_id(short_id), int(ration[short_id]))
	_ration_day = _day
	return {"ok": true, "reason": "每日配给已发放：%s" % BunkerRoomDefs.cost_text(ration)}

## 精神值档位（UI 光点表现/掉落惩罚用）：0 正常 / 1 偏低(<50) / 2 低(<30)
func sanity_tier() -> int:
	if _sanity < 30.0:
		return 2
	elif _sanity < 50.0:
		return 1
	return 0

## v22.4（P1-4）：低精神掉落惩罚——精神值从装饰数值变真资源。
## tier 0→1.0 / 1(<50)→0.9 / 2(<30)→0.75。战后货币奖励乘此系数（结算面板同步展示）。
## 反应堆 Lv3 应急协议：惩罚减半（0.9→0.95 / 0.75→0.875）。
func get_drop_reward_multiplier() -> float:
	var halve := get_room_level("reactor") >= 3
	match sanity_tier():
		1: return 0.95 if halve else 0.9
		2: return 0.875 if halve else 0.75
		_: return 1.0

## v22.4（P0-2）：今日完工房间（结算面板"要塞"反馈行数据源）
func get_completed_today() -> Array:
	return _completed_today.duplicate()

## v22.4（P1-5）：首次进基地引导卡（只展示一次，随存档持久化）
func is_intro_shown() -> bool:
	return _intro_shown

func mark_intro_shown() -> void:
	_intro_shown = true

## v24：序章漫画开场已播标记（bunker_main 醒来演出触发时落档）
func is_comic_seen() -> bool:
	return _comic_seen

func mark_comic_seen() -> void:
	_comic_seen = true

# ───────────────────── P3：英雄遗物碎片 ─────────────────────

## 记录一位牺牲英雄的遗物碎片（去重）。返回是否为新解锁。
func record_hero_fragment(master_id: String) -> bool:
	if _hero_fragments.has(master_id):
		return false
	_hero_fragments.append(master_id)
	if SignalBus and SignalBus.has_signal("hero_archive_unlocked"):
		SignalBus.hero_archive_unlocked.emit(master_id)
	return true

func get_hero_fragments() -> Array:
	return _hero_fragments.duplicate()

func get_hero_fragment_count() -> int:
	return _hero_fragments.size()

func has_hero_fragment(master_id: String) -> bool:
	return _hero_fragments.has(master_id)

# ───────────────────── P3：情感阶段切换 ─────────────────────

## 消费一次未播报的阶段跃迁：返回新阶段号（无跃迁返回 0）。
## bunker_main 在 _ready / 日结算关闭后调用，命中即播全屏字幕。
func consume_stage_transition() -> int:
	if _narrative_stage > _announced_stage:
		_announced_stage = _narrative_stage
		return _announced_stage
	return 0

# ───────────────────── P4 预留：观星台解锁条件 ─────────────────────

## 返回 {"ok": bool, "reasons": Array[String]}（P4 消费；缺项为未满足原因）
func is_observatory_unlockable() -> Dictionary:
	var reasons: Array[String] = []
	for room_id in _rooms:
		if room_id == "observatory":
			continue
		if int(_rooms[room_id]["state"]) != BunkerRoomDefs.STATE_ACTIVE:
			var def := BunkerRoomDefs.get_room(room_id)
			reasons.append("房间未修复：%s" % def.get("name", room_id))
	if _hero_fragments.size() < 30:
		reasons.append("同伴档案 %d/30" % _hero_fragments.size())
	if LevelProgressManager != null and LevelProgressManager.has_method("get_max_unlocked_level") \
			and LevelProgressManager.get_max_unlocked_level() < 100:
		reasons.append("尚未通关第 100 关")
	if reasons.is_empty():
		return {"ok": true, "reasons": []}
	return {"ok": false, "reasons": reasons}

## ───────────────────── P4：观星台终局抉择（v22.3 接 UI） ─────────────────────

## 已抵达的结局：{"id", "day", ...结局文案}；未抉择返回空字典。
func get_chosen_ending() -> Dictionary:
	if _ending_id.is_empty():
		return {}
	var ending: Dictionary = HeroArchiveTexts.observatory_ending(_ending_id)
	if ending.is_empty():
		return {}
	ending["id"] = _ending_id
	ending["day"] = _ending_day
	return ending

## 锁定终局抉择（不可反悔）。返回 {"ok", "reason", "ending"}。
func choose_ending(id: String) -> Dictionary:
	if not _ending_id.is_empty():
		return {"ok": false, "reason": "结局已定", "ending": get_chosen_ending()}
	var ending: Dictionary = HeroArchiveTexts.observatory_ending(id)
	if ending.is_empty():
		return {"ok": false, "reason": "未知结局：%s" % id}
	_ending_id = id
	_ending_day = _day
	return {"ok": true, "reason": "终局已记录", "ending": get_chosen_ending()}

## ───────────────────────── 调试（P1 专用，P2 移除） ─────────────────────────

func debug_grant_resources() -> void:
	if BasicResourceManager == null:
		return
	BasicResourceManager.add_resource(BunkerRoomDefs.res_full_id("nano"), 500)
	BasicResourceManager.add_resource(BunkerRoomDefs.res_full_id("alloy"), 300)
	BasicResourceManager.add_resource(BunkerRoomDefs.res_full_id("crystal"), 50)
	BasicResourceManager.add_resource(BunkerRoomDefs.res_full_id("energy"), 100)

## ───────────────────────── 存档序列化（SaveManager 段） ─────────────────────────

## SaveManager 收集入口（_collect_manager_state 按此方法名收集）
func save_state() -> Dictionary:
	return {
		"day": _day,
		"sanity": _sanity,
		"rooms": _rooms.duplicate(true),
		"hero_fragments": _hero_fragments.duplicate(),
		"narrative_stage": _narrative_stage,
		"announced_stage": _announced_stage,
		"bootstrap_granted": _bootstrap_granted,
		"ration_day": _ration_day,
		"ending_id": _ending_id,
		"ending_day": _ending_day,
		"intro_shown": _intro_shown,
		"comic_seen": _comic_seen,
		"analyzer_slot": _analyzer_slot.duplicate(),
		"analyzer_baked": _analyzer_baked,
		"analyzer_baked_day": _analyzer_baked_day,
		"expedition_day": _expedition_day,
		"loot_print_day": _loot_print_day,
		"sandbox_instance_id": _sandbox_instance_id,
		"salute_day": _salute_day,
		"salute_armed": _salute_armed,
		"weather_day": _weather_day,
		"weather_idx": _weather_idx,
		"weather_armed": _weather_armed,
		"respec_free_day": _respec_free_day,
		"battle_log": _battle_log.duplicate(true),
	# v26.19 卡车行军（哨兵值原样存：fuel<0 / parked=0 表示"未初始化"，读侧懒解析）
	# v26.25：fuel 经 get_fuel() 读取=顺带结算自动回复后入档；regen 时间戳随档持久化（离线回复）
	"fuel": get_fuel(),
	"fuel_regen_unix": _fuel_regen_unix,
	"engine_level": _engine_level,
		"parked_level": _parked_level,
		"travel_dest": _travel_dest,
		"travel_days_total": _travel_days_total,
		"travel_started_unix": _travel_started_unix,
		"travel_ends_unix": _travel_ends_unix,
	}

## SaveManager 应用入口（_safe_load_manager 按此方法名加载）；空字典=新游戏全重置
func load_state(data: Dictionary) -> void:
	if data.is_empty():
		reset_to_defaults()
		return
	_day = int(data.get("day", 1))
	_sanity = float(data.get("sanity", 100.0))
	_narrative_stage = int(data.get("narrative_stage", BunkerRoomDefs.narrative_stage_for_day(_day)))
	_announced_stage = int(data.get("announced_stage", _narrative_stage))
	_bootstrap_granted = bool(data.get("bootstrap_granted", false))
	_ration_day = int(data.get("ration_day", 0))
	_ending_id = str(data.get("ending_id", ""))
	_ending_day = int(data.get("ending_day", 0))
	_intro_shown = bool(data.get("intro_shown", false))
	_comic_seen = bool(data.get("comic_seen", false))
	# v26.12b：战斗日志回读（增量 key，旧档缺省=空日志；先重置再覆盖）
	_battle_log = []
	var saved_log: Variant = data.get("battle_log", [])
	if saved_log is Array:
		for entry in saved_log:
			if entry is Dictionary:
				_battle_log.append({
					"day": int(entry.get("day", 0)),
					"level": int(entry.get("level", 0)),
					"won": bool(entry.get("won", false)),
					"kills": int(entry.get("kills", 0)),
				})
	_pending_battle_level = 0
	_pending_battle_endless = false
	# v26 批次3：分析仪/探索/打印状态回读
	_analyzer_slot = {}
	var saved_slot: Variant = data.get("analyzer_slot", {})
	if saved_slot is Dictionary and not (saved_slot as Dictionary).is_empty():
		var ss: Dictionary = saved_slot
		_analyzer_slot = {
			"archetype_id": str(ss.get("archetype_id", "")),
			"rarity": str(ss.get("rarity", "common")),
			"battles_left": maxi(0, int(ss.get("battles_left", ANALYZER_BAKE_BATTLES))),
		}
	_analyzer_baked = maxi(0, int(data.get("analyzer_baked", 0)))
	_analyzer_baked_day = int(data.get("analyzer_baked_day", 0))
	_expedition_day = int(data.get("expedition_day", 0))
	_loot_print_day = int(data.get("loot_print_day", 0))
	# v26 批次4 补齐：沙盘/敬礼/预报/洗点状态回读
	_sandbox_instance_id = str(data.get("sandbox_instance_id", ""))
	_salute_day = int(data.get("salute_day", 0))
	_salute_armed = bool(data.get("salute_armed", false))
	_weather_day = int(data.get("weather_day", -1))
	_weather_idx = clampi(int(data.get("weather_idx", 0)), 0, WEATHERS.size() - 1)
	_weather_armed = bool(data.get("weather_armed", false))
	_respec_free_day = int(data.get("respec_free_day", 0))
	# v26.19 卡车行军回读（哨兵缺省：fuel<0→首读满罐；parked=0→首读战线前沿）
	_fuel = float(data.get("fuel", -1.0))
	# v26.25 回复时间戳：旧档缺 key=0 → 首读置 now（不追溯补发）；
	# 带档读取则由下一次 get_fuel() 按离线时长一次性补结算（与实时到站同口径）
	_fuel_regen_unix = maxf(0.0, float(data.get("fuel_regen_unix", 0.0)))
	_engine_level = clampi(int(data.get("engine_level", 1)), 1, TruckTravel.ENGINE_MAX_LV)
	_parked_level = clampi(int(data.get("parked_level", 0)), 0, 100)
	_travel_dest = clampi(int(data.get("travel_dest", 0)), 0, 100)
	_travel_days_total = maxi(0, int(data.get("travel_days_total", 0)))
	_travel_started_unix = float(data.get("travel_started_unix", 0.0))
	_travel_ends_unix = float(data.get("travel_ends_unix", 0.0))
	# 兼容当日旧档（v26.19 剩余天数字段）：换算成 unix 到站时刻
	var legacy_days_left := maxi(0, int(data.get("travel_days_left", 0)))
	if _travel_dest > 0 and _travel_ends_unix <= 0.0 and legacy_days_left > 0:
		_travel_started_unix = Time.get_unix_time_from_system()
		_travel_ends_unix = _travel_started_unix + float(legacy_days_left) * TruckTravel.SECONDS_PER_DAY
	_hero_fragments = []
	for f in data.get("hero_fragments", []):
		_hero_fragments.append(str(f))
	_completed_today = []
	var saved_rooms: Dictionary = data.get("rooms", {})
	for room_id in _rooms:
		if saved_rooms.has(room_id):
			var sr: Dictionary = saved_rooms[room_id]
			_rooms[room_id]["state"] = int(sr.get("state", _rooms[room_id]["state"]))
			# 等级按 defs 上限收敛（防旧档/改档后 level 越界）
			_rooms[room_id]["level"] = clampi(int(sr.get("level", 1)), 1,
				BunkerRoomDefs.get_max_level(room_id))
			_rooms[room_id]["progress"] = float(sr.get("progress", 0.0))
			_rooms[room_id]["upgrading"] = bool(sr.get("upgrading", false))
			_rooms[room_id]["upg_progress"] = float(sr.get("upg_progress", 0.0))
	# v22.1：定义初始点亮的房间不被旧档的 LOCKED 覆盖——旧档在兵棋室改为
	# initial ACTIVE 之前存盘的，会把 LOCKED 一并存进 rooms 段，读回后玩家
	# 依然无法从基地出击。这里按 defs 抬底：仅 LOCKED→ACTIVE（修复中/已点亮
	# 等更高状态原样保留）。
	for room_id in _rooms:
		var def: Dictionary = BunkerRoomDefs.get_room(room_id)
		if def.is_empty():
			continue
		if int(def.get("initial", BunkerRoomDefs.STATE_LOCKED)) == BunkerRoomDefs.STATE_ACTIVE \
				and int(_rooms[room_id]["state"]) == BunkerRoomDefs.STATE_LOCKED:
			_rooms[room_id]["state"] = BunkerRoomDefs.STATE_ACTIVE

## 新游戏重置（_reset_manager_by_name 链第二优先命中）
func reset_to_defaults() -> void:
	_day = 1
	_sanity = 100.0
	_hero_fragments = []
	_completed_today = []
	_narrative_stage = 1
	_announced_stage = 1
	_bootstrap_granted = false
	_ration_day = 0
	_ending_id = ""
	_ending_day = 0
	_intro_shown = false
	_comic_seen = false
	_analyzer_slot = {}
	_analyzer_baked = 0
	_analyzer_baked_day = 0
	_expedition_day = 0
	_loot_print_day = 0
	_sandbox_instance_id = ""
	_salute_day = 0
	_salute_armed = false
	_weather_day = -1
	_weather_idx = 0
	_weather_armed = false
	_respec_free_day = 0
	# v26.19 卡车行军复位（哨兵值同 load_state：fuel<0 / parked=0 → 首读懒解析）
	_fuel = -1.0
	_fuel_regen_unix = 0.0
	_engine_level = 1
	_parked_level = 0
	_travel_dest = 0
	_travel_days_total = 0
	_travel_started_unix = 0.0
	_travel_ends_unix = 0.0
	for room_id in _rooms:
		var def := BunkerRoomDefs.get_room(room_id)
		_rooms[room_id]["state"] = int(def.get("initial", BunkerRoomDefs.STATE_LOCKED))
		_rooms[room_id]["level"] = 1
		_rooms[room_id]["progress"] = 0.0
		_rooms[room_id]["upgrading"] = false
		_rooms[room_id]["upg_progress"] = 0.0

## 兼容旧调用名（会话内快照/冒烟测试）
func get_state_dict() -> Dictionary:
	return save_state()

func load_state_dict(data: Dictionary) -> void:
	load_state(data)

func _emit_room_changed(room_id: String) -> void:
	if SignalBus and SignalBus.has_signal("bunker_room_state_changed"):
		SignalBus.bunker_room_state_changed.emit(room_id, get_room_state(room_id))
