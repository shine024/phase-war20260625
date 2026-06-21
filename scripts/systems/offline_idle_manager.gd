extends RefCounted
class_name OfflineIdleManager
## 离线挂机管理器 — 游戏关闭期间按时间戳计算离线奖励（封顶 8 小时）
##
## 核心机制：
##   游戏关闭 → save_game() 记录 last_active_at (epoch 秒)
##   游戏重开 → load_game() → 计算 elapsed = now - last_active_at
##   离线超阈值 → 按波次估算 battles_per_hour × capped 时长 = 战斗次数 N
##   聚合货币(get_drops_for_level × N) + 掉落模拟(generate_battle_drops 抽样)
##   弹"欢迎回来"窗 → 玩家领取 → 入账


# ── 常量 ──

## 离线时长封顶（8 小时）
const MAX_OFFLINE_SECONDS: int = 8 * 3600
## 离线不足此阈值不弹窗（5 分钟）
const MIN_OFFLINE_THRESHOLD: int = 5 * 60
## 单场战斗固定开销（部署+结算，秒）
const BATTLE_OVERHEAD_SEC: float = 20.0
## 掉落模拟的战斗次数上限（超过则抽样放大，避免性能问题）
const DROP_SIM_MAX_BATTLES: int = 50
## battles_per_hour 下限保护（避免极短战斗导致离线奖励爆炸）
const MIN_BATTLES_PER_HOUR: float = 10.0


# ── 引用 ──

var _main: Node = null


# ── 初始化 ──

func init(main_node: Node) -> void:
	_main = main_node


# ── 核心计算 ──

## 计算离线奖励（不实际入账，返回聚合结果供 UI 显示）。
## 返回空字典表示无离线奖励（离线不足/无时间戳）；否则返回:
##   {
##     "elapsed_sec": int,      # 实际离线秒数（未封顶）
##     "capped_sec": int,       # 封顶后用于计算的秒数
##     "battles": int,          # 折算战斗次数
##     "level": int,            # 奖励来源关卡
##     "era": int,              # 关卡时代
##     "currencies": {id: count},  # 货币聚合（确定性）
##     "drop_preview_count": int,  # 掉落预估总件数（实际入账会重新生成）
##   }
func compute_offline_rewards(last_active_at: int, now: int) -> Dictionary:
	# 无时间戳（旧档）或时间异常 → 不弹窗
	if last_active_at <= 0 or now <= last_active_at:
		return {}
	var elapsed: int = now - last_active_at
	if elapsed < MIN_OFFLINE_THRESHOLD:
		return {}

	var capped: int = mini(elapsed, MAX_OFFLINE_SECONDS)
	var level: int = _resolve_reward_level()
	var era: int = LevelEras.get_era(level)
	var bph: float = _estimate_battles_per_hour(level)
	var battles: int = maxi(1, int(float(capped) * bph / 3600.0))

	# 货币聚合：get_drops_for_level 是纯静态无副作用，× battles
	var currencies: Dictionary = {}
	var drops_per: Dictionary = BasicResources.get_drops_for_level(level)
	for id in drops_per.keys():
		currencies[id] = int(drops_per[id]) * battles

	# 掉落预估件数：抽样模拟少量战斗，按比例放大，仅用于显示
	var drop_preview_count: int = _estimate_drop_count(era, level, battles)

	return {
		"elapsed_sec": elapsed,
		"capped_sec": capped,
		"battles": battles,
		"level": level,
		"era": era,
		"currencies": currencies,
		"drop_preview_count": drop_preview_count,
	}


## 实际入账离线奖励（玩家点领取后调用）。
## 货币按聚合值精确入账；掉落实际重新生成（带随机性，符合游戏惯例）。
func grant_rewards(result: Dictionary) -> void:
	if result.is_empty():
		return
	var level: int = int(result.get("level", 1))
	var era: int = int(result.get("era", 0))
	var battles: int = int(result.get("battles", 0))
	if battles <= 0:
		return

	# 1. 货币入账（确定性，与弹窗显示一致）
	var currencies: Dictionary = result.get("currencies", {})
	var brm: Node = _get_node("/root/BasicResourceManager")
	if brm != null and brm.has_method("add_resource"):
		for id in currencies.keys():
			var amount: int = int(currencies[id])
			if amount > 0:
				brm.add_resource(String(id), amount)

	# 2. 掉落入账：实际生成 min(battles, DROP_SIM_MAX_BATTLES) 场掉落并 claim。
	# 注意：generate_battle_drops 会覆盖 pending_drops（pending_drops = drops），
	# 故必须累加返回的 Array，最后一次性塞回 pending 再 claim，否则只保留最后一场。
	# 不做放大（少生成 = 少掉落，保守）。离线掉落本就是额外福利。
	var dm: Node = _get_node("/root/DropManager")
	if dm == null or not dm.has_method("generate_battle_drops"):
		return
	# 快照当前 pending（避免污染实时 pending_drops）
	var saved_pending: Array = []
	if "pending_drops" in dm:
		saved_pending = (dm.pending_drops as Array).duplicate()
		dm.pending_drops.clear()

	var aggregated: Array = []
	var sim_count: int = mini(battles, DROP_SIM_MAX_BATTLES)
	for _i in range(sim_count):
		var drops: Array = dm.generate_battle_drops(era, level, true, 3)  # 胜利 + 3 星
		for d in drops:
			aggregated.append(d)

	# 把聚合掉落塞回 pending，claim（分发到各 manager）
	if "pending_drops" in dm:
		dm.pending_drops = aggregated
	if dm.has_method("claim_drops") and not aggregated.is_empty():
		dm.claim_drops()

	# 恢复实时 pending（防御性）
	if "pending_drops" in dm:
		dm.pending_drops = saved_pending


# ── 内部逻辑 ──

## 关卡来源解析（回退链）：
## 1. 在线挂机 CYCLE 模式 → 第一个有效 slot 关卡
## 2. 在线挂机 PUSH 模式 → push_level
## 3. 都无效/未配过挂机 → LevelProgressManager.get_max_unlocked_level()
func _resolve_reward_level() -> int:
	var afk_mgr = _get_afk_manager()
	if afk_mgr != null:
		# CYCLE：取第一个非 0 slot
		if afk_mgr.mode == AFKModeManager.Mode.CYCLE:
			var slots: Array = afk_mgr.slots
			for i in range(slots.size()):
				if int(slots[i]) > 0:
					return int(slots[i])
		# PUSH：取 push_level
		elif afk_mgr.mode == AFKModeManager.Mode.PUSH:
			if afk_mgr.push_level > 0:
				return afk_mgr.push_level
	# 回退：最高解锁关
	var lp: Node = _get_node("/root/LevelProgressManager")
	if lp != null and lp.has_method("get_max_unlocked_level"):
		return maxi(1, lp.get_max_unlocked_level())
	return 1


## battles_per_hour 估算：基于关卡波次数 × 波次间隔 + 固定开销
func _estimate_battles_per_hour(level: int) -> float:
	var waves: int = LevelEras.get_wave_total_for_level(level)
	var interval: float = LevelEras.get_wave_interval_for_level(level)
	var battle_duration: float = float(waves) * interval + BATTLE_OVERHEAD_SEC
	if battle_duration <= 0.0:
		return MIN_BATTLES_PER_HOUR
	var bph: float = 3600.0 / battle_duration
	return maxf(MIN_BATTLES_PER_HOUR, bph)


## 掉落预估总件数（抽样模拟少量战斗，按比例放大用于显示）
func _estimate_drop_count(era: int, level: int, battles: int) -> int:
	var dm: Node = _get_node("/root/DropManager")
	if dm == null or not dm.has_method("generate_battle_drops"):
		return 0
	# 快照并清空 pending
	var saved_pending: Array = []
	if "pending_drops" in dm:
		saved_pending = (dm.pending_drops as Array).duplicate()
		dm.pending_drops.clear()

	# 抽样：模拟少量场，统计件数，按比例放大
	var sample_n: int = mini(battles, 10)
	var sample_count: int = 0
	for _i in range(sample_n):
		var drops: Array = dm.generate_battle_drops(era, level, true, 3)
		sample_count += drops.size()
	# 恢复 pending
	if "pending_drops" in dm:
		dm.pending_drops = saved_pending

	if sample_n <= 0:
		return 0
	# 按比例放大到 battles 场
	var per_battle: float = float(sample_count) / float(sample_n)
	return int(per_battle * float(battles))


# ── 辅助 ──

func _get_afk_manager() -> RefCounted:
	if _main != null and _main.has_method("get_afk_manager"):
		return _main.get_afk_manager()
	return null


func _get_node(path: String) -> Node:
	if _main != null:
		return _main.get_node_or_null(path)
	return null
