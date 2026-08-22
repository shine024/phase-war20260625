extends Node
## 存档管理：读写 save.json，协调 BlueprintManager / PhaseInstrumentManager / 背包 状态
## 写入固定为 user://save.json；读取优先该文件，再兼容旧版（项目根 / 旧 user 路径），避免仓库内 res 存档遮挡真存档
## ─── 预加载提取模块 ───
const SaveConstants = preload("res://scripts/systems/save_constants.gd")
const SaveMigration = preload("res://scripts/systems/save_migration.gd")
const IntelManualItems = preload("res://data/intel_manual_items.gd")
var DEBUG_SAVE_LOG := false

var _pending_backpack_ids: Array = []
var _is_exiting: bool = false
var _is_saving: bool = false
var _exit_save_done: bool = false
var _save_deferred_pending: bool = false
var _last_save_ms: int = 0
var _last_backup_ms: int = 0
var _save_dirty_during_battle: bool = false
var _battle_end_save_hooked: bool = false
var _backpack_signal_hooked: bool = false
## 兜底：上次成功保存时的额外卡ID列表（背包面板不可用时使用）
var _last_known_extra_ids: Array = []



var _slot_info_cache: Array = []
var _slot_info_cache_valid: bool = false
var _noncritical_save_cache: Dictionary = {}
var _last_noncritical_save_ms: int = 0

## 多存档位支持
var current_slot: int = 1
const MAX_SLOTS := 3

const SAVE_FILE_USER := "user://save.json"
const SAVE_SCHEMA_VERSION := 8  # v7.0: v7→v8 卡牌实例化养成（清空旧card_id-keyed养成数据）
const SAVE_MIN_INTERVAL_MS := 1200
const SAVE_BACKUP_INTERVAL_MS := 15000
const NONCRITICAL_SAVE_INTERVAL_MS := 10000
## 读档性能优化：默认使用轻量校验，减少 continue 卡顿。
const ENABLE_DETAILED_LOAD_VALIDATION := false
const DEFERRED_LOAD_BATCH_SIZE := 5
const CRITICAL_MANAGER_LOADS: Array = [
	# v7.0: InstanceRegistry 必须最先加载——背包/相位仪/养成消费者恢复时依赖实例表
	["/root/InstanceRegistry", "instances"],
	["/root/BlueprintManager", "blueprint"],
	["/root/PhaseInstrumentManager", "phase_instrument"],
	["/root/QuestManager", "quest"],
	["/root/BasicResourceManager", "basic_resources"],
	["/root/FactionSystemManager", "faction_system"],
	["/root/AffixManager", "affix_data"],
	["/root/LevelProgressManager", "level_progress"],
	["/root/DropManager", "drop_manager"],
	["/root/IntelItemBag", "intel_item_bag"],
	# v6.6: 情报手册（战斗实时查询，需 critical）
	["/root/IntelManual", "intel_manual"],
	# v8.x: 相位师技能树（get_active_effects 被战斗实时查询，需 critical）
	["/root/PhaseMasterSkillManager", "phase_master_skill"],
]
const DEFERRED_MANAGER_LOADS: Array = [
	["/root/LoreManager", "lore"],
	["/root/StatBoostManager", "stat_boost"],
	["/root/AchievementManager", "achievement"],
	["/root/DailyTaskManager", "daily_task"],
	["/root/CardEnhancementManager", "card_enhancement"],
	["/root/TutorialProgressionManager", "tutorial_progress"],
	["/root/DayClock", SK_DAY_CLOCK],
	# v9.x 清理：characters/challenge_records 管理器已删，旧档 key 静默跳过
	["/root/CardCollectionManager", "card_collection"],
	["/root/LeaderboardManager", "leaderboard"],
	# v6.6: 情报发现/进化/敌源MOD（deferred，非战斗实时）
	["/root/IntelDiscoveryManager", "intel_discovery"],
	["/root/IntelEvolutionManager", "intel_evolution"],
]
const CRITICAL_RESETTABLE_MANAGERS: Array[String] = [
	"BlueprintManager",
	"PhaseInstrumentManager",
	"QuestManager",
	"BasicResourceManager",
	"FactionSystemManager",
	"AffixManager",
	"LevelProgressManager",
	"IntelItemBag",
	# v6.6: 情报手册
	"IntelManual",
	# v8.x: 相位师技能树（修复新游戏未清空导致技能点跨档残留）
	"PhaseMasterSkillManager",
]
const DEFERRED_RESET_BATCH_SIZE := 4

const RESETTABLE_MANAGERS := [
	"BlueprintManager",
	"PhaseInstrumentManager",
	"QuestManager",
	"BasicResourceManager",
	"FactionSystemManager",
	"AffixManager",
	"LevelProgressManager",
	"LoreManager",
	"StatBoostManager",
	"CardEnhancementManager",
	"TutorialProgressionManager",
	"DayClock",
	"CardCollectionManager",
	"IntelItemBag",
	# v6.6: 情报系统（reset 靠 load_state({}) 清空字段）
	"IntelDiscoveryManager",
	"IntelEvolutionManager",
	# v6.6 修复: 新游戏清空未领取掉落（原 load_state({}) 无法清 pending_drops）
	"DropManager",
]

## ─── 存档数据键名常量（别名，定义见 scripts/systems/save_constants.gd）───
const SK_SCHEMA_VERSION: String = SaveConstants.SK_SCHEMA_VERSION
# v7.0: 卡牌实例表（必须最先加载）
const SK_INSTANCES: String = SaveConstants.SK_INSTANCES
const SK_BLUEPRINT: String = SaveConstants.SK_BLUEPRINT
const SK_BASIC_RESOURCES: String = SaveConstants.SK_BASIC_RESOURCES
const SK_PHASE_LAW: String = SaveConstants.SK_PHASE_LAW
const SK_QUEST: String = SaveConstants.SK_QUEST
const SK_FACTION_SYSTEM: String = SaveConstants.SK_FACTION_SYSTEM
const SK_AFFIX_DATA: String = SaveConstants.SK_AFFIX_DATA
const SK_LEVEL_PROGRESS: String = SaveConstants.SK_LEVEL_PROGRESS
const SK_DROP_MANAGER: String = SaveConstants.SK_DROP_MANAGER
# v7.x: SK_INTEL_ITEM_BAG 改为引用 SaveConstants（集中化，与其余4个情报键一致）
const SK_INTEL_ITEM_BAG: String = SaveConstants.SK_INTEL_ITEM_BAG
# v6.6: 情报系统存档键（与 DEFERRED/CRITICAL_MANAGER_LOADS 的 data_key 一致）
const SK_INTEL_MANUAL: String = SaveConstants.SK_INTEL_MANUAL
const SK_INTEL_DISCOVERY: String = SaveConstants.SK_INTEL_DISCOVERY
const SK_INTEL_EVOLUTION: String = SaveConstants.SK_INTEL_EVOLUTION
const SK_GAME: String = SaveConstants.SK_GAME
const SK_CURRENT_LEVEL: String = SaveConstants.SK_CURRENT_LEVEL
const SK_PHASE_SLOTS: String = SaveConstants.SK_PHASE_SLOTS
const SK_PHASE_SLOTS_ORDER: String = SaveConstants.SK_PHASE_SLOTS_ORDER
const SK_PHASE_INSTRUMENT: String = SaveConstants.SK_PHASE_INSTRUMENT
const SK_BACKPACK_EXTRA_IDS: String = SaveConstants.SK_BACKPACK_EXTRA_IDS
const SK_LORE: String = SaveConstants.SK_LORE
const SK_STAT_BOOST: String = SaveConstants.SK_STAT_BOOST
const SK_ACHIEVEMENT: String = SaveConstants.SK_ACHIEVEMENT
const SK_DAILY_TASK: String = SaveConstants.SK_DAILY_TASK
const SK_DAY_CLOCK: String = SaveConstants.SK_DAY_CLOCK
const SK_STATISTICS: String = "statistics"  # v7.x: 常量源已删，保留字面量兼容旧存档读取
const SK_CARD_ENHANCEMENT: String = SaveConstants.SK_CARD_ENHANCEMENT
# v7.x: SK_LAW_SHARDS 别名已删除（SaveConstants 常量本身已删，全项目零引用）
const SK_TUTORIAL_PROGRESS: String = SaveConstants.SK_TUTORIAL_PROGRESS
const SK_CHARACTERS: String = SaveConstants.SK_CHARACTERS
const SK_CHALLENGE_RECORDS: String = SaveConstants.SK_CHALLENGE_RECORDS
const SK_CARD_COLLECTION: String = SaveConstants.SK_CARD_COLLECTION
const SK_LEADERBOARD: String = SaveConstants.SK_LEADERBOARD
const SK_LEGACY_COMPANY_REP: String = SaveConstants.SK_LEGACY_COMPANY_REP
# v8.x: 相位师技能树（修复未接入存档导致技能点丢失的 BUG）
const SK_PHASE_MASTER_SKILL: String = SaveConstants.SK_PHASE_MASTER_SKILL
# v6.6(挂机): AFK 状态存档键别名
const SK_AFK: String = SaveConstants.SK_AFK

var _deferred_load_data: Dictionary = {}
var _deferred_manager_queue: Array = []
var _deferred_reset_queue: Array[String] = []
# v6.6(挂机): AFK 待加载数据（manager 可能晚于 autoload 创建，延迟重试应用）
var _pending_afk_load: Dictionary = {}
var _afk_load_retry_count: int = 0
const _AFK_LOAD_MAX_RETRIES: int = 60  # 重试上限（约 1 秒 @ 60fps），超时放弃保持默认
# v6.6(离线挂机): 上次活跃时间戳（epoch 秒），save_game 时刷新，离线奖励计算用
var _last_active_at: int = 0
var _load_game_perf_pending: bool = false
var _start_new_game_perf_pending: bool = false
var _load_game_parse_phase_open: bool = false
var _load_game_critical_phase_open: bool = false
var _load_game_deferred_phase_open: bool = false

func _ready() -> void:
	_sync_debug_log_flag()
	_ensure_battle_end_save_hook()
	_ensure_backpack_signal_hook()
	# 部分启动序下 SignalBus 可能晚于本节点就绪，下一帧重试一次挂钩。
	call_deferred("_ensure_backpack_signal_hook")
	# v6.6: 预加载 ToastManager，使其 _ready 连接 SignalBus.show_toast，
	# 否则仅当打开势力商店时才会实例化，期间所有 toast 提示静默失效
	call_deferred("_ensure_toast_manager")
	# v7.x(B2): about_to_quit 覆盖 get_tree().quit() 路径（程序化退出不会触发
	# WM_CLOSE_REQUEST，但会发 about_to_quit）。与 _notification(WM_CLOSE_REQUEST)
	# 形成双保险，确保任意退出路径都收尾存档。
	# 用字符串名 connect 规避 --check-only 静态分析对信号属性的误报。
	var tree := get_tree()
	if tree != null and tree.has_signal("about_to_quit"):
		tree.connect("about_to_quit", _on_about_to_quit)
	# 注：DebugLog 配在 ManagerLazyLoader（node_name=DebugLogManager），调用方统一用
	# /root/DebugLogManager 引用。v7.x(M6) 曾尝试在此 ensure_loaded("debug_log") 预加载，
	# 但 ManagerLazyLoader._instantiate_manager 对该脚本 .new() 失败（base GDScript 无 new），
	# 破坏启动。DebugLog 属诊断增强，非功能必需——保持按需/可选，不强制预加载。
	# 如需启用调试日志，可手动 ensure_loaded("debug_log") 或将其改为 autoload。

func _ensure_toast_manager() -> void:
	if ManagerLazyLoader and ManagerLazyLoader.has_method("ensure_loaded"):
		ManagerLazyLoader.ensure_loaded("toast")

func _sync_debug_log_flag() -> void:
	var debug_mgr: Node = get_node_or_null("/root/DebugLogManager")
	if debug_mgr != null and debug_mgr.has_method("is_channel_enabled"):
		DEBUG_SAVE_LOG = bool(debug_mgr.is_channel_enabled("save_manager", DEBUG_SAVE_LOG))

func _perf_phase_begin(phase_name: String) -> void:
	if PerformanceMetricsManager and PerformanceMetricsManager.has_method("begin_phase"):
		PerformanceMetricsManager.begin_phase(phase_name)

func _perf_phase_end(phase_name: String) -> void:
	if PerformanceMetricsManager and PerformanceMetricsManager.has_method("end_phase"):
		PerformanceMetricsManager.end_phase(phase_name)

func _finalize_load_game_perf_on_fail() -> void:
	if _load_game_parse_phase_open:
		_load_game_parse_phase_open = false
		_perf_phase_end("load_game_parse_json")
	if _load_game_critical_phase_open:
		_load_game_critical_phase_open = false
		_perf_phase_end("load_game_critical_managers")
	if _load_game_deferred_phase_open:
		_load_game_deferred_phase_open = false
		_perf_phase_end("load_game_deferred_managers")
	if _load_game_perf_pending:
		_load_game_perf_pending = false
		_perf_phase_end("load_game")

func _ensure_battle_end_save_hook() -> void:
	if _battle_end_save_hooked:
		return
	if SignalBus and SignalBus.has_signal("battle_ended"):
		if not SignalBus.battle_ended.is_connected(_on_battle_ended_flush_save):
			SignalBus.battle_ended.connect(_on_battle_ended_flush_save)
		_battle_end_save_hooked = true

func _ensure_backpack_signal_hook() -> void:
	if _backpack_signal_hooked:
		return
	if SignalBus == null:
		return
	if SignalBus.has_signal("card_added_to_backpack"):
		if not SignalBus.card_added_to_backpack.is_connected(_on_card_added_to_backpack_fallback):
			SignalBus.card_added_to_backpack.connect(_on_card_added_to_backpack_fallback)
	if SignalBus.has_signal("card_equipped"):
		if not SignalBus.card_equipped.is_connected(_on_card_equipped_remove_fallback):
			SignalBus.card_equipped.connect(_on_card_equipped_remove_fallback)
	# v7.x：换装原子信号——pending/last_known 一次性完成"移新卡 + 加旧卡"，避免双信号中间态导致背包重复
	if SignalBus.has_signal("card_swapped"):
		if not SignalBus.card_swapped.is_connected(_on_card_swapped_fallback):
			SignalBus.card_swapped.connect(_on_card_swapped_fallback)
	# v7.x：监听实例销毁，清理 pending/last_known 队列里的幽灵 instance_id
	# （进化消耗/拆解/相位仪清理触发，确保任何场景下存档不再写出已销毁的实例 id）
	if SignalBus.has_signal("instance_disposed"):
		if not SignalBus.instance_disposed.is_connected(_on_instance_disposed_purge):
			SignalBus.instance_disposed.connect(_on_instance_disposed_purge)
	_backpack_signal_hooked = true

## v7.x：实例销毁时清理 pending/last_known 里的幽灵 instance_id
func _on_instance_disposed_purge(instance_id: String) -> void:
	if instance_id.is_empty():
		return
	purge_backpack_card_id(instance_id)

func _on_card_added_to_backpack_fallback(card: CardResource) -> void:
	if card == null:
		return
	# v7.0: 用 instance_id 作身份；无 instance_id 回退 card_id（兼容）
	var cid: String = String(card.instance_id)
	if cid.is_empty():
		cid = String(card.card_id)
	if cid.is_empty():
		return
	enqueue_backpack_card_id(cid)

func _on_card_equipped_remove_fallback(_slot_index: int, card_id: String, _card_type: String) -> void:
	if card_id.is_empty():
		return
	var idx_pending: int = _pending_backpack_ids.find(card_id)
	if idx_pending >= 0:
		_pending_backpack_ids.remove_at(idx_pending)
	var idx_last: int = _last_known_extra_ids.find(card_id)
	if idx_last >= 0:
		_last_known_extra_ids.remove_at(idx_last)

## v7.x：换装原子回调——pending/last_known 一次性完成"移新卡出包 + 加旧卡入包"。
## 原 card_added_to_backpack(old) + card_equipped(new) 双信号被拆成两次独立记账，
## 中间态若有时序错位会导致 last_known 比 pending 多记一份，load_pending_cards 差值补齐兑现成重复卡。
## 这里复用两个既有回调形成原子事务：先移新卡（复用 equipped_remove），再加旧卡（复用 enqueue）。
func _on_card_swapped_fallback(_slot_index: int, old_card: CardResource, new_card_id: String) -> void:
	# 1. 新卡出包：从 pending/last_known 移除
	_on_card_equipped_remove_fallback(_slot_index, new_card_id, "")
	# 2. 旧卡入包：enqueue（presenter._on_card_swapped 会 consume 掉 pending 里的，对齐买卡路径）
	if old_card != null:
		var cid: String = String(old_card.instance_id)
		if cid.is_empty():
			cid = String(old_card.card_id)
		if not cid.is_empty():
			enqueue_backpack_card_id(cid)

## 背包懒加载兜底：在未实例化背包面板时，也可先把新增卡加入 pending 队列。
func enqueue_backpack_card_id(card_id: String) -> void:
	if card_id.is_empty():
		return
	_pending_backpack_ids.append(card_id)
	_last_known_extra_ids.append(card_id)

func _is_battle_active_now() -> bool:
	if BattleManager == null:
		return false
	return BattleManager.get("battle_active") == true

func _on_battle_ended_flush_save(_player_won: bool) -> void:
	if not _save_dirty_during_battle:
		return
	_save_dirty_during_battle = false
	# 结算链较重，稍延后一帧/短延时落盘，避开战斗结束同帧尖峰。
	var tree := get_tree()
	if tree == null:
		return
	var t := tree.create_timer(0.2)
	t.timeout.connect(func() -> void:
		if not _is_saving:
			save_game()
	)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_is_exiting = true
		# v6.6(离线挂机): 强制存档刷新 last_active_at 时间戳。
		# 否则直接关窗口不存档，下次打开会用旧时间戳计算离线奖励（或=0 不弹窗）。
		# save_game 内部因 _is_exiting=true 会绕过 throttle/battle-active 守卫强制写入。
		save_game()

# v7.x(B2): 程序化退出（get_tree().quit()）走这里——quit() 不触发 WM_CLOSE_REQUEST，
# 但会发 about_to_quit 信号。设 _is_exiting 让 save_game 绕过守卫强制收尾存档。
func _on_about_to_quit() -> void:
	_is_exiting = true
	save_game()

func _exit_tree() -> void:
	_is_exiting = true

func _user_save_byte_size() -> int:
	if not FileAccess.file_exists(SAVE_FILE_USER):
		return -1
	var rf: FileAccess = FileAccess.open(SAVE_FILE_USER, FileAccess.READ)
	if rf == null:
		return -1
	var n: int = int(rf.get_length())
	rf.close()
	return n

func _remove_file_at_user(virtual_path: String) -> void:
	if not FileAccess.file_exists(virtual_path):
		return
	var abs_path: String = ProjectSettings.globalize_path(virtual_path)
	var e: Error = DirAccess.remove_absolute(abs_path)
	if e != OK:
		push_warning("[SaveManager] 删除 %s 失败 (错误码 %s)" % [abs_path, e])

func _get_legacy_res_save_path() -> String:
	return ProjectSettings.globalize_path("res://") + "save.json"

func _get_legacy_user_save_path() -> String:
	return OS.get_user_data_dir().path_join("save.json")

## 获取指定存档位的主文件路径
func _slot_file(slot: int) -> String:
	return "user://save_slot_%d.json" % slot

func _slot_backup_file(slot: int) -> String:
	return "user://save_slot_%d_backup.json" % slot

func _slot_temp_file(slot: int) -> String:
	return "user://save_slot_%d.json.tmp" % slot

## 获取当前存档位的文件路径（兼容旧单存档）
func _current_save_file() -> String:
	return _slot_file(current_slot)

func _current_backup_file() -> String:
	return _slot_backup_file(current_slot)

func _current_temp_file() -> String:
	return _slot_temp_file(current_slot)

## 设置当前存档位
func set_slot(slot: int) -> void:
	current_slot = clampi(slot, 1, MAX_SLOTS)
	if DEBUG_SAVE_LOG:
		pass  # LOG: 切换到存档位

## 获取当前存档位
func get_slot() -> int:
	return current_slot

## 获取所有存档位的信息（是否存在、关卡）
func get_slot_info() -> Array:
	if _slot_info_cache_valid:
		return _slot_info_cache.duplicate(true)
	var info: Array = []
	for slot_num in range(1, MAX_SLOTS + 1):
		var slot_data: Dictionary = {"slot": slot_num, "exists": false, "level": 0}
		var path := _slot_file(slot_num)
		var backup_path := _slot_backup_file(slot_num)
		var read_path := ""
		if FileAccess.file_exists(path):
			slot_data["exists"] = true
			read_path = path
		# 主档不存在时，继续识别备份档（与 load_game 实际兜底保持一致）
		elif FileAccess.file_exists(backup_path):
			slot_data["exists"] = true
			read_path = backup_path
		# 兼容旧单存档（slot 1）
		if slot_num == 1 and not slot_data["exists"] and FileAccess.file_exists(SAVE_FILE_USER):
			slot_data["exists"] = true
			read_path = SAVE_FILE_USER
		if not read_path.is_empty():
			var f := FileAccess.open(read_path, FileAccess.READ)
			if f:
				var json := JSON.new()
				if json.parse(f.get_as_text()) == OK:
					var data = json.get_data()
					if data is Dictionary and data.has(SK_GAME):
						var gd: Dictionary = data[SK_GAME]
						if gd.has(SK_CURRENT_LEVEL):
							slot_data["level"] = int(gd[SK_CURRENT_LEVEL])
					f.close()
		info.append(slot_data)
	_slot_info_cache = info.duplicate(true)
	_slot_info_cache_valid = true
	return info

## 将旧单存档迁移到存档位 1（仅在 slot 1 为空且旧存档存在时执行）
func _migrate_old_save_if_needed() -> void:
	var slot1_path := _slot_file(1)
	if FileAccess.file_exists(slot1_path):
		return  # slot 1 已有存档，不迁移
	if not FileAccess.file_exists(SAVE_FILE_USER):
		return  # 无旧存档可迁移
	var old_f := FileAccess.open(SAVE_FILE_USER, FileAccess.READ)
	if old_f == null:
		return
	var content := old_f.get_as_text()
	old_f.close()
	# 读取并校验
	var json := JSON.new()
	if json.parse(content) != OK:
		return
	var data = json.get_data()
	if not data is Dictionary:
		return
	# 写入 slot 1
	var new_f := FileAccess.open(slot1_path, FileAccess.WRITE)
	if new_f:
		new_f.store_string(content)
		new_f.close()
		_slot_info_cache_valid = false
		if DEBUG_SAVE_LOG:
			pass  # LOG: 已迁移旧存档

func _resolve_read_save_path() -> String:
	# 优先当前存档位
	var slot_path := _current_save_file()
	if FileAccess.file_exists(slot_path):
		return slot_path
	# slot 1 兼容旧单存档
	if current_slot == 1 and FileAccess.file_exists(SAVE_FILE_USER):
		return SAVE_FILE_USER
	var res_p := _get_legacy_res_save_path()
	if FileAccess.file_exists(res_p):
		return res_p
	var leg_u := _get_legacy_user_save_path()
	if FileAccess.file_exists(leg_u):
		return leg_u
	return ""

## v6.6(离线挂机): 获取上次活跃时间戳（epoch 秒）。旧档/未存档返回 0。
func get_last_active_at() -> int:
	return _last_active_at

func has_save() -> bool:
	_migrate_old_save_if_needed()
	return _resolve_read_save_path() != ""

## 检查指定存档位是否有存档
func has_save_slot(slot: int) -> bool:
	var path := _slot_file(slot)
	if FileAccess.file_exists(path):
		return true
	if slot == 1 and FileAccess.file_exists(SAVE_FILE_USER):
		return true
	return false

## 删除指定存档位的全部文件（主档+备份+临时）。
## 仅删除磁盘文件，不重置当前内存中的管理器状态——删除后调用方按需自行重置。
## 返回 true 表示该槽位原本有存档（并已删除），false 表示槽位本就为空。
func delete_slot(slot: int) -> bool:
	slot = clampi(slot, 1, MAX_SLOTS)
	var had_save := has_save_slot(slot)
	_remove_file_at_user(_slot_file(slot))
	_remove_file_at_user(_slot_backup_file(slot))
	_remove_file_at_user(_slot_temp_file(slot))
	# 旧单存档（save.json）也归 slot 1
	if slot == 1:
		_remove_file_at_user(SAVE_FILE_USER)
	_slot_info_cache_valid = false
	return had_save

## 强制刷新槽位信息缓存（外部直接操作存档文件后调用，如存档面板的导入功能）。
func force_slot_info_refresh() -> void:
	_slot_info_cache_valid = false

## 自动备份当前存档
func _backup_current_save() -> void:
	var now_ms: int = Time.get_ticks_msec()
	if not _is_exiting and now_ms - _last_backup_ms < SAVE_BACKUP_INTERVAL_MS:
		return
	var cur := _current_save_file()
	if not FileAccess.file_exists(cur):
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		push_warning("[SaveManager] 无法打开user://目录进行备份")
		return
	var backup := _current_backup_file()
	if dir.copy(cur, backup) != OK:
		push_warning("[SaveManager] 存档备份失败")
	else:
		_last_backup_ms = now_ms
		if DEBUG_SAVE_LOG:
			pass  # LOG: 已创建存档备份

func _schedule_deferred_save() -> void:
	if _save_deferred_pending:
		return
	_save_deferred_pending = true
	var delay_sec: float = maxf(0.1, float(SAVE_MIN_INTERVAL_MS) / 1000.0)
	var tree := get_tree()
	if tree == null:
		_save_deferred_pending = false
		return
	var timer := tree.create_timer(delay_sec)
	timer.timeout.connect(func() -> void:
		_save_deferred_pending = false
		if not _is_saving:
			save_game()
	)

func _find_backpack_panel() -> Node:
	var paths: Array[String] = [
		"/root/Main/PopupLayer/BackpackOverlay/BackpackVBox/CenterRow/BackpackCenter/BackpackPanel",
		"/root/Main/PopupLayer/BackpackOverlay/BackpackVBox/CenterRow/BackpackCenter/backpack_panel",
		"/root/Main/PrepPanel/RootMargin/HBox/BackpackArea/Margin/VBox/BackpackScroll/BackpackPanel",
		"/root/Main/PrepPanel/BackpackArea/Margin/VBox/BackpackScroll/BackpackPanel",
	]
	for p in paths:
		var n: Node = get_node_or_null(p)
		if n != null and n.has_method("get_extra_card_ids"):
			return n
	return null

## v6.6(挂机): 通过 Main 桥接获取 AFK manager（RefCounted，非 autoload）。
## AFK manager 由 Main 在 _init_afk_manager 创建，可能晚于 SaveManager autoload 初始化。
## 返回 RefCounted 而非 Node（AFK manager 不在场景树中）。
func _get_afk_manager() -> RefCounted:
	var main_node: Node = get_node_or_null("/root/Main")
	if main_node != null and main_node.has_method("get_afk_manager"):
		return main_node.get_afk_manager()
	return null

func _collect_manager_state(data: Dictionary, node_path: String, data_key: String) -> void:
	var mgr: Node = get_node_or_null(node_path)
	# v7.x 性能：节点缺失时经 ManagerLazyLoader 实例化（autoload 延迟化的安全网）。
	# 避免延迟化的 manager 未被访问时漏存字段（数据丢失）。
	if mgr == null:
		var lazy_loader = get_node_or_null("/root/ManagerLazyLoader")
		if lazy_loader and lazy_loader.has_method("get_manager_by_name"):
			mgr = lazy_loader.get_manager_by_name(node_path.get_file())
	if mgr != null and mgr.has_method("save_state"):
		data[data_key] = mgr.save_state()

func _collect_noncritical_save_data(data: Dictionary, now_ms: int) -> void:
	var should_refresh: bool = _is_exiting or _noncritical_save_cache.is_empty() or (now_ms - _last_noncritical_save_ms >= NONCRITICAL_SAVE_INTERVAL_MS)
	if should_refresh:
		var fresh: Dictionary = {}
		_collect_manager_state(fresh, "/root/LoreManager", SK_LORE)
		_collect_manager_state(fresh, "/root/StatBoostManager", SK_STAT_BOOST)
		_collect_manager_state(fresh, "/root/AchievementManager", SK_ACHIEVEMENT)
		_collect_manager_state(fresh, "/root/DailyTaskManager", SK_DAILY_TASK)
		_collect_manager_state(fresh, "/root/CardEnhancementManager", SK_CARD_ENHANCEMENT)
		_collect_manager_state(fresh, "/root/TutorialProgressionManager", SK_TUTORIAL_PROGRESS)
		_collect_manager_state(fresh, "/root/DayClock", SK_DAY_CLOCK)
		# v9.x 清理：CharacterManager/ChallengeModeManager 已删（零消费僵尸管理器）；
		# 旧档 characters/challenge_records key 读档时静默跳过，新档不再写出
		_collect_manager_state(fresh, "/root/CardCollectionManager", SK_CARD_COLLECTION)
		_collect_manager_state(fresh, "/root/LeaderboardManager", SK_LEADERBOARD)
		# v6.6: 情报系统（deferred 收集）
		_collect_manager_state(fresh, "/root/IntelDiscoveryManager", SK_INTEL_DISCOVERY)
		_collect_manager_state(fresh, "/root/IntelEvolutionManager", SK_INTEL_EVOLUTION)
		# v6.6(挂机): AFK 配置/进度/累计奖励（通过 Main 桥接访问 RefCounted manager）
		var afk_mgr_save = _get_afk_manager()
		if afk_mgr_save != null and afk_mgr_save.has_method("save_state"):
			fresh[SK_AFK] = afk_mgr_save.save_state()
		_noncritical_save_cache = fresh
		_last_noncritical_save_ms = now_ms
	for key in _noncritical_save_cache.keys():
		data[key] = _noncritical_save_cache[key]

## 按名称重置管理器（新游戏用）。
## 设计说明（P1-1 复审结论）：此处与 _collect_manager_state 不同，**不**经 ManagerLazyLoader
## 兜底实例化——未被实例化的懒加载管理器本就没有内存态可清，跳过即正确；
## 若在此强行实例化，"新游戏"路径会一次性拉起 15+ 个 DEFERRED 管理器，破坏懒加载收益。
## 已实例化的管理器（如读档后开新档、或本会话早前访问过）则正常走 clear_all/reset 重置。
func _reset_manager_by_name(manager_name: String) -> void:
	var mgr: Node = get_node_or_null("/root/" + manager_name)
	if mgr == null:
		return
	if mgr.has_method("clear_all"):
		mgr.clear_all()
	elif mgr.has_method("reset_to_defaults"):
		mgr.reset_to_defaults()
	elif mgr.has_method("reset_progress"):
		mgr.reset_progress()
	elif mgr.has_method("load_state"):
		mgr.load_state({})

func _schedule_deferred_manager_resets() -> void:
	_deferred_reset_queue.clear()
	for manager_name in RESETTABLE_MANAGERS:
		if not CRITICAL_RESETTABLE_MANAGERS.has(manager_name):
			_deferred_reset_queue.append(manager_name)
	call_deferred("_process_deferred_manager_resets")

func _process_deferred_manager_resets() -> void:
	if _deferred_reset_queue.is_empty():
		if _start_new_game_perf_pending:
			_start_new_game_perf_pending = false
			_perf_phase_end("start_new_game")
		return
	var batch_count: int = mini(DEFERRED_RESET_BATCH_SIZE, _deferred_reset_queue.size())
	for _i in range(batch_count):
		var manager_name: String = _deferred_reset_queue.pop_front()
		_reset_manager_by_name(manager_name)
	if not _deferred_reset_queue.is_empty():
		call_deferred("_process_deferred_manager_resets")
	elif _start_new_game_perf_pending:
		_start_new_game_perf_pending = false
		_perf_phase_end("start_new_game")

func save_game() -> bool:
	_ensure_battle_end_save_hook()
	if not _is_exiting and _is_battle_active_now():
		_save_dirty_during_battle = true
		return true
	if _is_saving:
		return false
	# v7.3 修复 B2/H1: DEFERRED 管理器延迟加载窗口内禁止 save_game。
	# DEFERRED manager（Lore/StatBoost/Achievement/Statistics/CardEnhancement 等）load_state
	# 在 call_deferred 队列中分批完成（数帧）。若此窗口内触发 save_game（如返回标题），
	# 会对尚未 load_state 的 DEFERRED manager 调 save_state，写出空/默认数据覆盖存档。
	# 延迟到 DEFERRED 全部加载完再存（_is_exiting 时仍强制存以防数据完全丢失）。
	if not _is_exiting and (_load_game_deferred_phase_open or not _deferred_manager_queue.is_empty()):
		_schedule_deferred_save()
		return true
	var now_ms: int = Time.get_ticks_msec()
	if not _is_exiting and now_ms - _last_save_ms < SAVE_MIN_INTERVAL_MS:
		_schedule_deferred_save()
		return true
	_is_saving = true

	# 先备份当前存档
	_migrate_old_save_if_needed()
	_backup_current_save()

	var bm: Node = get_node_or_null("/root/BlueprintManager")
	var pm: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if bm == null:
		push_error("[SaveManager] BlueprintManager 未找到")
		_is_saving = false
		return false
	var data: Dictionary = {SK_SCHEMA_VERSION: SAVE_SCHEMA_VERSION}
	# v7.0: InstanceRegistry 必须最先收集（实例表是背包/相位仪/养成的数据源）
	_collect_manager_state(data, "/root/InstanceRegistry", SK_INSTANCES)
	if bm.has_method("save_state"):
		data[SK_BLUEPRINT] = bm.save_state()
	_collect_manager_state(data, "/root/BasicResourceManager", SK_BASIC_RESOURCES)
	# v9.x（P2-7范围B）：PhaseLawManager 存档收集已随法则系统退役移除
	_collect_manager_state(data, "/root/QuestManager", SK_QUEST)
	_collect_manager_state(data, "/root/FactionSystemManager", SK_FACTION_SYSTEM)
	_collect_manager_state(data, "/root/AffixManager", SK_AFFIX_DATA)
	_collect_manager_state(data, "/root/LevelProgressManager", SK_LEVEL_PROGRESS)
	ManagerLazyLoader.ensure_loaded("drop")  # DropManager 为 autoload+别名双层（ensure_loaded 幂等，命中 /root 复用）
	_collect_manager_state(data, "/root/DropManager", SK_DROP_MANAGER)
	_collect_manager_state(data, "/root/IntelItemBag", SK_INTEL_ITEM_BAG)
	# v6.6: 情报手册（critical，战斗实时查询）
	_collect_manager_state(data, "/root/IntelManual", SK_INTEL_MANUAL)
	# v8.x: 相位师技能树（critical，战斗实时查询 get_active_effects）
	_collect_manager_state(data, "/root/PhaseMasterSkillManager", SK_PHASE_MASTER_SKILL)
	_collect_noncritical_save_data(data, now_ms)
	var gmgr: Node = get_node_or_null("/root/GameManager")
	# 保存前同步 current_level：确保与 LevelProgressManager.max_unlocked_level 一致
	if gmgr != null and "current_level" in gmgr:
		var lpm_sync: Node = get_node_or_null("/root/LevelProgressManager")
		if lpm_sync != null and lpm_sync.has_method("get_max_unlocked_level"):
			var max_u_save: int = lpm_sync.get_max_unlocked_level()
			var cur: int = int(gmgr.current_level)
			if max_u_save > cur:
				gmgr.set_current_level(max_u_save)
		data[SK_GAME] = {SK_CURRENT_LEVEL: int(gmgr.current_level), "ng_plus": gmgr.ng_plus_active}
	else:
		# GameManager 不可用时仍写入默认值，避免校验缺失 game 字段
		data[SK_GAME] = {SK_CURRENT_LEVEL: 1, "ng_plus": false}
	# v6.6(离线挂机): 记录上次活跃时间戳（epoch 秒），供下次启动计算离线奖励
	_last_active_at = int(Time.get_unix_time_from_system())
	data["last_active_at"] = _last_active_at
	if pm != null and pm.has_method("get_slot_card_ids"):
		data[SK_PHASE_SLOTS] = pm.get_slot_card_ids()
		data[SK_PHASE_SLOTS_ORDER] = "rbgy"
	if pm != null and pm.has_method("save_state"):
		data[SK_PHASE_INSTRUMENT] = pm.save_state()
	var backpack: Node = _find_backpack_panel()
	if backpack != null and backpack.has_method("get_extra_card_ids"):
		var extra_ids: Array = backpack.get_extra_card_ids()
		data[SK_BACKPACK_EXTRA_IDS] = extra_ids
		_last_known_extra_ids = extra_ids.duplicate()
	elif not _last_known_extra_ids.is_empty():
		# 背包面板不可用时使用上次已知值，防止额外卡丢失
		data[SK_BACKPACK_EXTRA_IDS] = _last_known_extra_ids.duplicate()
		if not _is_exiting:
			push_warning("[SaveManager] 背包面板不可用，使用上次已知的额外卡ID (%d 张)" % _last_known_extra_ids.size())

	# 保存前清洗非法浮点值（inf/-inf/nan），防止写出不可解析的 JSON。
	data = SaveMigration.sanitize_save_variant(data)

	# JSON预检：确保序列化成功
	var json_str: String = JSON.stringify(data)
	if json_str.is_empty():
		push_error("[SaveManager] JSON序列化失败，存档数据异常")
		_is_saving = false
		return false

	var dir_swap := DirAccess.open("user://")
	if dir_swap == null:
		push_error("[SaveManager] 无法打开 user://，存档失败")
		_is_saving = false
		return false
	var temp_name := "save_slot_%d.json.tmp" % current_slot
	if dir_swap.file_exists(temp_name):
		dir_swap.remove(temp_name)

	var f: FileAccess = FileAccess.open(_current_temp_file(), FileAccess.WRITE)
	if f == null:
		var open_err: Error = FileAccess.get_open_error()
		push_error("[SaveManager] 无法写入临时存档 %s (错误码 %s)" % [_current_temp_file(), open_err])
		_is_saving = false
		return false
	f.store_string(json_str)
	var write_err: Error = f.get_error()
	f.close()
	if write_err != OK:
		push_error("[SaveManager] 写入临时存档失败: %s" % write_err)
		var toast_mgr_err2 = get_node_or_null("/root/ToastManager")
		if not _is_exiting and toast_mgr_err2 and toast_mgr_err2.has_method("show_error"):
			toast_mgr_err2.show_error("存档保存失败！")
		_is_saving = false
		return false

	dir_swap = DirAccess.open("user://")
	if dir_swap == null:
		push_error("[SaveManager] 无法打开 user:// 以替换正式存档")
		_is_saving = false
		return false
	# 原子写入：先将现有存档 rename 为 .prior（不删除），再 rename tmp 为正式文件
	var main_name := "save_slot_%d.json" % current_slot
	var prior_name := "save_slot_%d.json.prior" % current_slot
	var tmp_name := "save_slot_%d.json.tmp" % current_slot
	if dir_swap.file_exists(main_name):
		var prior_err: Error = dir_swap.rename(main_name, prior_name)
		if prior_err != OK:
			push_error("[SaveManager] 无法重命名旧存档为 prior: %s" % prior_err)
			_is_saving = false
			return false
	var ren_err: Error = dir_swap.rename(tmp_name, main_name)
	if ren_err != OK:
		push_error("[SaveManager] 无法将临时存档 rename 为正式存档: slot=%d tmp=%s main=%s err=%d" % [
			current_slot, tmp_name, main_name, int(ren_err)])
		#endregion
		# Windows 下退出阶段偶发 rename 失败；兜底为 tmp 直写正式存档，避免”退出后没档”
		var tmp_read: FileAccess = FileAccess.open(_current_temp_file(), FileAccess.READ)
		if tmp_read != null:
			var tmp_json: String = tmp_read.get_as_text()
			tmp_read.close()
			var main_write: FileAccess = FileAccess.open(_current_save_file(), FileAccess.WRITE)
			if main_write != null:
				main_write.store_string(tmp_json)
				main_write.close()
				var cleanup_dir := DirAccess.open("user://")
				var tmp_n := "save_slot_%d.json.tmp" % current_slot
				if cleanup_dir != null and cleanup_dir.file_exists(tmp_n):
					cleanup_dir.remove(tmp_n)
				if DEBUG_SAVE_LOG:
					pass  # LOG: rename失败，已使用临时存档直写恢复
				_is_saving = false
				return true
			push_error("[SaveManager] 临时存档读取失败，无法直写恢复: %s" % [{
				"slot": current_slot,
				"tmp_read_null": tmp_read == null,
			}])
		#endregion
		push_error("[SaveManager] 无法完成存档替换 rename: %s" % ren_err)
		# rename 失败且直写也失败：恢复 .prior 文件
		var prior_name_rollback := "save_slot_%d.json.prior" % current_slot
		var main_name_rollback := "save_slot_%d.json" % current_slot
		if FileAccess.file_exists(prior_name_rollback):
			if dir_swap.rename(prior_name_rollback, main_name_rollback) == OK:
				if DEBUG_SAVE_LOG:
					pass  # LOG: 已从 prior 恢复
		var toast_mgr_err3 = get_node_or_null("/root/ToastManager")
		if not _is_exiting and toast_mgr_err3 and toast_mgr_err3.has_method("show_error"):
			toast_mgr_err3.show_error("存档保存失败！")
		_is_saving = false
		return false
	if DEBUG_SAVE_LOG:
		pass  # LOG: 已保存到
	# 显示成功Toast
	var toast_mgr = get_node_or_null("/root/ToastManager")
	if not _is_exiting and toast_mgr and toast_mgr.has_method("show_success"):
		toast_mgr.show_success("游戏已保存")
	_last_save_ms = Time.get_ticks_msec()
	_slot_info_cache_valid = false
	_is_saving = false
	return true

## 获取待处理的背包ID
func get_pending_backpack_ids() -> Array:
	return _pending_backpack_ids.duplicate()

## 获取最近一次已知的背包额外卡ID（用于背包面板重建时的会话内恢复）
func get_last_known_backpack_ids() -> Array:
	return _last_known_extra_ids.duplicate()

## 直接设置 _last_known_extra_ids（供 BackpackPresenter 首次加载后同步完整列表）
func _set_last_known_extra_ids_direct(ids: Array) -> void:
	_last_known_extra_ids.clear()
	for id_val in ids:
		var sid: String = str(id_val) if id_val != null else ""
		if not sid.is_empty() and not _last_known_extra_ids.has(sid):
			_last_known_extra_ids.append(sid)

## 清除待处理的背包ID
func clear_pending_backpack_ids() -> void:
	_pending_backpack_ids.clear()

## 新存档初始背包卡牌 + 初始资源
func _enqueue_starter_backpack_cards() -> void:
	# v7.0: 初始卡牌实例化（独立养成身份）
	# v7.x: 能量卡系统移除，初始背包只发战斗卡（ww1_ft17，匹配第1关主题）。
	# 能量上限改由相位仪星级决定，无需初始能量卡。
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	for cid in ["ww1_ft17"]:
		var starter_id: String = cid
		if ir != null and ir.has_method("create_instance"):
			var inst: CardResource = ir.create_instance(cid)
			if inst != null and not inst.instance_id.is_empty():
				starter_id = inst.instance_id
		enqueue_backpack_card_id(starter_id)
	# ⚠️ 测试模式：初始资源各 10 万（开发/测试用，正式上线前需改回起步量）
	# 正式起步量参考：nano 1500 / alloy 800 / crystal 500 / energy 1000 / research 500
	# （单次强化约 ~100-500 纳米，起步量应让玩家初期体验几张卡强化、靠战斗积累）
	if BasicResourceManager:
		BasicResourceManager.add_resource("nano_materials", 100000)
		BasicResourceManager.add_resource("alloy", 100000)
		BasicResourceManager.add_resource("crystal", 100000)
		BasicResourceManager.add_resource("energy_block", 100000)
		BasicResourceManager.add_resource("research_points", 100000)
	# 测试模式：初始技能点 +100（相位师技能树 bonus_points，供测试解锁多分支）
	# PhaseMasterSkillManager 未注册存档 → 每次开新档都是干净 0 基线，加 100 不累积。
	var pmsm_starter: Node = get_node_or_null("/root/PhaseMasterSkillManager")
	if pmsm_starter != null and pmsm_starter.has_method("add_bonus_points"):
		pmsm_starter.add_bonus_points(100)

	# 初始情报：逐步发现（原"解锁所有情报"是测试残留，破坏探索乐趣）
	# v7.x 结构修复（P1-3）：本段与下方"初始蓝图/初始进化分支"原先因缩进错误整体嵌套在
	# if pmsm_starter 块内——PhaseMasterSkillManager 缺失或无 add_bonus_points 时会被静默跳过。
	# 现提升为函数级，var ml 在函数作用域声明。
	# 情报应在战斗中击败敌人后逐步揭示（IntelDiscoveryManager），不再开局全解锁。
	var ml = get_node_or_null("/root/ManagerLazyLoader")
	if ml and ml.has_method("ensure_loaded"):
		# 仅确保 IntelManual 加载，不再 unlock_all_intel（情报逐步发现）
		ml.ensure_loaded("intel_manual")

	# 初始蓝图：授予起步改造图纸 + 进化蓝图（其余改造图纸靠战斗掉落解锁）
	# v7.1: 不再开局全送所有改造图纸，仅授予 IntelManualItems.ALL_TYPES 中的基础起步图纸
	if ml and ml.has_method("ensure_loaded"):
		ml.ensure_loaded("intel_item_bag")
		var bag = get_node_or_null("/root/IntelItemBag")
		if bag:
			const IntelManualItems = preload("res://data/intel_manual_items.gd")
			# 授予起步改造图纸（7张基础图纸）
			for blueprint_id in IntelManualItems.ALL_TYPES:
				if not bag.has_item(blueprint_id):
					bag.add_item(blueprint_id, 1)

			# ⚠️ 测试模式：开局发放全部改造蓝图 + 全部进化蓝图（开发/测试用，上线前需改回）
			# 正式设计：改造/进化蓝图应靠战斗掉落（精英/Boss）逐步解锁，不开局全送。
			# 改造蓝图口径：ModificationRegistry 全集，排除 enhancement（强化词条，非改造模块）。
			#   → 与 modification_panel/_refresh_mod_list 同口径（blueprint_ 前缀，排除 blueprint_evol_）
			# 进化蓝图口径：IntelManualItems._collect_all_evolution_steps()（lineage 权威口径，
			#   与 UnitLineageConfig 判定对齐，避免 evolution_paths 的 15 个幽灵卡）。
			const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")
			const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")
			# ① 全部改造蓝图
			for mod_id in ModificationRegistry.get_all_ids():
				# 排除强化词条（source=enhancement，非可安装改造模块，有独立系统）
				if String(ModificationRegistry.get_data(mod_id).get("source", "")) == "enhancement":
					continue
				var mod_bp: String = BlueprintDefinitions.get_mod_blueprint_id(mod_id)
				if not mod_bp.is_empty() and not bag.has_item(mod_bp):
					bag.add_item(mod_bp, 1)
			# ② 全部进化蓝图（复用 lineage 口径的进化跳收集器）
			for step in IntelManualItems._collect_all_evolution_steps():
				var evo_bp: String = BlueprintDefinitions.get_evolution_blueprint_id(
					String(step.from), String(step.to))
				if not evo_bp.is_empty() and not bag.has_item(evo_bp):
					bag.add_item(evo_bp, 1)

	# v7.1: 移除 _grant_all_evolution_blueprints() 调用。
	# 进化蓝图现应通过战斗掉落（精英/Boss，20%概率）逐步解锁，不再开局全送。
	# 老存档已持有的进化蓝图由 IntelItemBag.load_state 保留，不受影响。
	# _grant_all_evolution_blueprints() 方法本体保留，供测试/调试手动调用。

	# 初始进化分支：发现所有情报进化分支（通过ManagerLazyLoader获取）
	if ml and ml.has_method("ensure_loaded"):
		ml.ensure_loaded("intel_evolution")
		var iem = get_node_or_null("/root/IntelEvolutionManager")
		if iem and iem.has_method("check_and_discover_branches"):
			iem.check_and_discover_branches()

	# 原逻辑新游戏时无条件全解锁所有敌源MOD，导致击杀掉落解锁机制失效。

	# v6.6: 改装/进化材料系统已被"蓝图系统"取代——
	# 玩家通过收集改造蓝图/进化蓝图（持久持有，不消耗）来解锁改造和进化，
	# 不再需要"材料库存"概念。下方"测试模式：开局全送"已通过 IntelItemBag
	# 发放所有蓝图，等效覆盖了原 TODO 的意图。


	# v6.6: 关键道具系统尚未实现（reserved），未来若新增消耗型关键道具，
	# 在此发放初始库存。当前游戏内无关键道具，故留空。

	# v7.x: 初始符文——赠送最基础的 common 符文，可组成「强袭」符文之语
	# （attack_01 力量 + defense_01 坚韧 → rw_2_05 强袭：攻击+18%/HP+18%）。
	# 1星相位仪已有2个符文槽，开局即可装备激活。
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim and pim.has_method("add_owned_rune"):
		for rune_id in ["attack_01", "defense_01"]:
			if pim.has_method("has_rune") and not pim.has_rune(rune_id):
				pim.add_owned_rune(rune_id)

## 辅助函数：为单个进化路径生成蓝图
func _process_evolution_blueprint_path(path_data: Dictionary) -> void:
	const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")
	# 获取IntelItemBag引用
	var bag = get_node_or_null("/root/IntelItemBag")
	if not bag:
		return
	# 按 stage 数值排序，而不是字符串键
	var sorted_entries = []
	for key in path_data.keys():
		var node = path_data[key]
		sorted_entries.append({"key": key, "stage": int(key), "node": node})
	sorted_entries.sort_custom(func(a, b): return a.stage < b.stage)

	var previous_card = ""
	for entry in sorted_entries:
		var card_id = entry.node.get("card_id", "")
		if not card_id.is_empty() and not previous_card.is_empty():
			var evo_bp_id = BlueprintDefinitions.get_evolution_blueprint_id(previous_card, card_id)
			bag.add_item(evo_bp_id, 1)
		previous_card = card_id

## 辅助函数：为隐藏分支生成蓝图
func _process_evolution_hidden_branches(branches_data: Dictionary) -> void:
	const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")
	# 获取IntelItemBag引用
	var bag = get_node_or_null("/root/IntelItemBag")
	if not bag:
		return
	for branch_name in branches_data.keys():
		var branch = branches_data[branch_name]
		# 按 stage 数值排序
		var sorted_entries = []
		for key in branch.keys():
			var node = branch[key]
			var stage = node.get("stage", 0)
			sorted_entries.append({"key": key, "stage": stage, "node": node})
		sorted_entries.sort_custom(func(a, b): return a.stage < b.stage)

		var branch_prev_card = ""
		for entry in sorted_entries:
			var card_id = entry.node.get("card_id", "")
			if not card_id.is_empty():
				if not branch_prev_card.is_empty():
					var evo_bp_id = BlueprintDefinitions.get_evolution_blueprint_id(branch_prev_card, card_id)
					bag.add_item(evo_bp_id, 1)
				branch_prev_card = card_id

## 授予所有进化蓝图
## 遍历所有进化路径，为每个进化节点生成对应的蓝图
func _grant_all_evolution_blueprints() -> void:
	# 加载所有进化路径类
	const InfantryEvolution = preload("res://data/evolution_paths/infantry_evolution.gd")
	const ArmorEvolution = preload("res://data/evolution_paths/armor_evolution.gd")
	const ArtilleryEvolution = preload("res://data/evolution_paths/artillery_evolution.gd")
	const AntiAirEvolution = preload("res://data/evolution_paths/anti_air_evolution.gd")
	const AirEvolution = preload("res://data/evolution_paths/air_evolution.gd")
	const ReconEvolution = preload("res://data/evolution_paths/recon_evolution.gd")
	const EngineerEvolution = preload("res://data/evolution_paths/engineer_evolution.gd")
	const FortEvolution = preload("res://data/evolution_paths/fort_evolution.gd")

	# 步兵进化路径
	_process_evolution_blueprint_path(InfantryEvolution.get_main_line())
	_process_evolution_hidden_branches(InfantryEvolution.get_hidden_branches())

	# 装甲兵进化路径（两条主线）
	_process_evolution_blueprint_path(ArmorEvolution.get_main_line())        # 机动路线
	_process_evolution_blueprint_path(ArmorEvolution.get_secondary_line())   # 重甲路线
	_process_evolution_hidden_branches(ArmorEvolution.get_hidden_branches())  # 豹系分支

	# 炮兵进化路径
	_process_evolution_blueprint_path(ArtilleryEvolution.get_main_line())
	_process_evolution_hidden_branches(ArtilleryEvolution.get_hidden_branches())

	# 防空兵进化路径
	_process_evolution_blueprint_path(AntiAirEvolution.get_main_line())
	_process_evolution_hidden_branches(AntiAirEvolution.get_hidden_branches())

	# 空中单位进化路径（两条主线）
	_process_evolution_blueprint_path(AirEvolution.get_main_line())           # 制空路线
	_process_evolution_blueprint_path(AirEvolution.get_secondary_line())      # 对地攻击路线
	_process_evolution_hidden_branches(AirEvolution.get_hidden_branches())    # 隐形轰炸机

	# 侦察/特种进化路径
	_process_evolution_blueprint_path(ReconEvolution.get_main_line())
	_process_evolution_hidden_branches(ReconEvolution.get_hidden_branches())

	# 工程/支援进化路径
	_process_evolution_blueprint_path(EngineerEvolution.get_main_line())
	_process_evolution_hidden_branches(EngineerEvolution.get_hidden_branches())

	# 堡垒单位进化路径（两条主线）
	_process_evolution_blueprint_path(FortEvolution.get_main_line())         # 防御路线
	_process_evolution_blueprint_path(FortEvolution.get_secondary_line())    # 防空路线
	_process_evolution_hidden_branches(FortEvolution.get_hidden_branches())   # 雷达站



## 处理一个待入包的卡牌ID（从pending中移除，标记为已处理）
func consume_pending_backpack_card_id(card_id: String) -> bool:
	if card_id.is_empty():
		return false
	var idx: int = _pending_backpack_ids.find(card_id)
	if idx >= 0:
		_pending_backpack_ids.remove_at(idx)
		# 同步从 last_known 移除一份，保持两队列同步。
		# 否则 last_known 会单调递增（只 enqueue 不 consume），load_pending_cards 的差值补齐
		# 逻辑会把多出的份额兑现成多一张卡（"买一张得两张"bug 的根因之一）。
		var idx_last: int = _last_known_extra_ids.find(card_id)
		if idx_last >= 0:
			_last_known_extra_ids.remove_at(idx_last)
		return true
	return false

## 直接添加待入包的卡牌ID（用于制造/掉落等场景）
func add_pending_backpack_card_id(card_id: String) -> void:
	if card_id.is_empty():
		return
	if not _pending_backpack_ids.has(card_id):
		_pending_backpack_ids.append(card_id)

## v7.x：无条件从 pending + last_known 两个队列清除一个卡牌ID（实例销毁时清理幽灵 id 用）。
## 与 consume_pending_backpack_card_id 的区别：consume 只在 pending 里有该 id 时才清 last_known，
## 而实例销毁场景下该 id 可能早已不在 pending（买卡时已 consume），但仍残留在 last_known 里。
## purge 两个队列都扫，确保幽灵 id 彻底清除，避免下次存档又把它写回 SK_BACKPACK_EXTRA_IDS。
func purge_backpack_card_id(card_id: String) -> void:
	if card_id.is_empty():
		return
	var idx_p: int = _pending_backpack_ids.find(card_id)
	if idx_p >= 0:
		_pending_backpack_ids.remove_at(idx_p)
	# last_known 可能有多份同名 id（历史 bug 可能重复入队），循环清除全部
	while true:
		var idx_l: int = _last_known_extra_ids.find(card_id)
		if idx_l < 0:
			break
		_last_known_extra_ids.remove_at(idx_l)

## 开始新游戏：重置所有管理器状态
func start_new_game() -> void:
	_perf_phase_begin("start_new_game")
	_start_new_game_perf_pending = true
	if DEBUG_SAVE_LOG:
		pass  # LOG: 开始新游戏，重置所有管理器
	# v7.x 修复：ir.clear_all() 必须在所有 manager reset 之前执行——
	# 部分 manager（如 PhaseInstrumentManager.load_state({})）在 reset 时可能接触实例表，
	# 若 clear_all 在其后执行会清空已建实例导致计数器与实例表不一致/撞号。
	var ir_pre: Node = get_node_or_null("/root/InstanceRegistry")
	if ir_pre != null and ir_pre.has_method("clear_all"):
		ir_pre.clear_all()
	# 关键管理器同步重置；其余管理器分批 deferred 重置，降低按钮点击同帧阻塞。
	for manager_name in CRITICAL_RESETTABLE_MANAGERS:
		_reset_manager_by_name(manager_name)
	_schedule_deferred_manager_resets()
	# 同步重置 GameManager.current_level
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and "current_level" in gm and gm.has_method("set_current_level"):
		gm.set_current_level(1)
	# v6.6(剧情): 全新开始时重置二周目标志（非 NG+ 路径）
	if gm != null and "ng_plus_active" in gm:
		gm.ng_plus_active = false
	# 删除当前存档位的文件
	_remove_file_at_user(_current_save_file())
	_remove_file_at_user(_current_backup_file())
	_remove_file_at_user(_current_temp_file())
	_noncritical_save_cache.clear()
	_last_noncritical_save_ms = 0
	_slot_info_cache_valid = false
	# 清除待处理的背包ID（开始新游戏时）
	_pending_backpack_ids.clear()
	_last_known_extra_ids.clear()
	# v7.0/v7.x: 实例表清空已提前到 CRITICAL manager reset 之前执行（见函数开头），
	# 避免 manager reset 时建的实例被 clear 清掉导致计数器撞号。
	# v6.6(挂机): 重置 AFK 状态（manager 是 RefCounted，经 Main 桥接调用 reset_progress）
	var afk_mgr_reset: RefCounted = _get_afk_manager()
	if afk_mgr_reset != null and afk_mgr_reset.has_method("reset_progress"):
		afk_mgr_reset.reset_progress()
	_pending_afk_load.clear()
	_afk_load_retry_count = 0
	# v6.6(离线挂机): 新游戏立即打时间戳，避免首次离线计算异常
	_last_active_at = int(Time.get_unix_time_from_system())
	# 新存档初始背包：全装型战斗卡 ×1，2星能量卡 ×2
	_enqueue_starter_backpack_cards()
	if DEBUG_SAVE_LOG:
		pass  # LOG: 新游戏已准备完毕
	if _deferred_reset_queue.is_empty() and _start_new_game_perf_pending:
		_start_new_game_perf_pending = false
		_perf_phase_end("start_new_game")

## v6.4: 开始二周目（NG+）— 重新开始但保留符文
func start_ng_plus() -> void:
	# 1. 保存当前符文列表
	var carried_runes: Array[String] = []
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim and pim.has_method("get_owned_runes"):
		carried_runes = pim.get_owned_runes()
	# 2. 执行 start_new_game（重置一切）
	start_new_game()
	# 3. 恢复符文到新周目
	if pim and pim.has_method("add_owned_rune"):
		for rune_id in carried_runes:
			pim.add_owned_rune(rune_id)
	# 4. 推进周目数
	var dc: Node = get_node_or_null("/root/DayClock")
	if dc and dc.has_method("reset_for_new_loop"):
		dc.reset_for_new_loop()
	# v6.6(剧情): 新周目重置剧情奖励倍率（倒计时×3 不应跨周目继承）
	ManagerLazyLoader.ensure_loaded("drop")  # DropManager 为 autoload+别名双层（ensure_loaded 幂等）
	var dm: Node = get_node_or_null("/root/DropManager")
	if dm and dm.has_method("reset_multiplier"):
		dm.reset_multiplier()
	# v6.6(剧情): 激活二周目模式（补剧情.txt 第十二幕：敌人属性×1.2）
	var gm_ng: Node = get_node_or_null("/root/GameManager")
	if gm_ng and "ng_plus_active" in gm_ng:
		gm_ng.ng_plus_active = true
		if "game_mode" in gm_ng:
			gm_ng.game_mode = GameManager.GameMode.NEW_GAME_PLUS
	# 5. 保存
	save_game()

func load_game() -> bool:
	_perf_phase_begin("load_game")
	_load_game_perf_pending = true
	_load_game_parse_phase_open = false
	_load_game_critical_phase_open = false
	_load_game_deferred_phase_open = false
	_migrate_old_save_if_needed()
	var path: String = _resolve_read_save_path()
	if path.is_empty():
		# 当前存档位无存档，尝试备份
		var backup := _current_backup_file()
		if FileAccess.file_exists(backup):
			if DEBUG_SAVE_LOG:
				pass  # LOG: 主存档不存在，尝试从备份恢复
			return _load_from_path(backup)
		_finalize_load_game_perf_on_fail()
		return false

	# 先尝试加载主存档
	if not _load_from_path(path):
		# 主存档加载失败，尝试备份
		var backup := _current_backup_file()
		if FileAccess.file_exists(backup):
			if DEBUG_SAVE_LOG:
				pass  # LOG: 主存档损坏，尝试从备份恢复
			return _load_from_path(backup)
		_finalize_load_game_perf_on_fail()
		return false
	return true

## 从指定路径加载存档（辅助方法）
func _load_from_path(path: String) -> bool:
	if path.is_empty():
		_finalize_load_game_perf_on_fail()
		return false
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[SaveManager] 无法读取存档: %s" % path)
		_finalize_load_game_perf_on_fail()
		return false
	var json_str: String = f.get_as_text()
	f.close()
	if json_str.strip_edges().is_empty():
		push_error("[SaveManager] 存档文件为空: %s" % path)
		_finalize_load_game_perf_on_fail()
		return false
	if not _load_game_parse_phase_open:
		_load_game_parse_phase_open = true
		_perf_phase_begin("load_game_parse_json")
	var json := JSON.new()
	var err: Error = json.parse(json_str)
	if err != OK:
		# 兼容旧坏档：若包含 inf/-inf/nan，尝试修复为 0 后重试解析。
		var repaired_json_str: String = SaveMigration.repair_non_finite_json_tokens(json_str)
		if repaired_json_str != json_str:
			var json_retry := JSON.new()
			var retry_err: Error = json_retry.parse(repaired_json_str)
			if retry_err == OK:
				json = json_retry
				var wf: FileAccess = FileAccess.open(path, FileAccess.WRITE)
				if wf != null:
					wf.store_string(repaired_json_str)
					wf.close()
					push_warning("[SaveManager] 检测到非有限数值(inf/nan)，已自动修复并重写: %s" % path)
			else:
				push_error("[SaveManager] JSON解析失败(修复后仍失败): %s  错误: %s  行: %d  内容前200字符: %s" % [
					path, json_retry.get_error_message(), json_retry.get_error_line(), repaired_json_str.left(200)])
				_finalize_load_game_perf_on_fail()
				return false
		else:
			push_error("[SaveManager] JSON解析失败: %s  错误: %s  行: %d  内容前200字符: %s" % [
				path, json.get_error_message(), json.get_error_line(),
				json_str.left(200)])
			_finalize_load_game_perf_on_fail()
			return false
	var data: Variant = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[SaveManager] 存档数据格式错误: %s" % path)
		_finalize_load_game_perf_on_fail()
		return false

	# 数据校验（性能模式默认走轻量校验；需要排查时可打开详细校验）
	if ENABLE_DETAILED_LOAD_VALIDATION:
		if not SaveMigration.validate_save_data(data, DEBUG_SAVE_LOG):
			# 详细错误已由 SaveMigration.validate_save_data 内部打印
			push_error("[SaveManager] 存档数据校验失败，拒绝加载: %s (schema v%s, 共 %d 个顶层键)" % [
				path, data.get(SK_SCHEMA_VERSION, "?"), data.size()])
			_finalize_load_game_perf_on_fail()
			return false
	else:
		SaveMigration.apply_fast_load_normalization(data)

	# 检查存档版本并迁移
	var version: int = data.get(SK_SCHEMA_VERSION, 1)
	if version < SAVE_SCHEMA_VERSION:
		SaveMigration.migrate_save_data(data, version, DEBUG_SAVE_LOG)
		_noncritical_save_cache.clear()
		_last_noncritical_save_ms = 0
		# v6.6(离线挂机): 读取上次活跃时间戳（旧档无此键 → 0 → 不弹离线窗）
		_last_active_at = int(data.get("last_active_at", 0))
		if _load_game_parse_phase_open:
			_load_game_parse_phase_open = false
			_perf_phase_end("load_game_parse_json")

	# 关键管理器同步加载，保证主流程稳定；其余管理器分批 deferred，降低 Continue 同帧尖峰。
	_load_game_critical_phase_open = true
	_perf_phase_begin("load_game_critical_managers")
	_load_manager_batch(data, CRITICAL_MANAGER_LOADS)
	if _load_game_critical_phase_open:
		_load_game_critical_phase_open = false
		_perf_phase_end("load_game_critical_managers")
	_load_game_deferred_phase_open = true
	_perf_phase_begin("load_game_deferred_managers")
	_schedule_deferred_manager_loads(data)

	# 特殊处理：phase_slots（仅旧档兼容，新版存档已在 load_state 内部恢复）
	var pm: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pm != null and data.has(SK_PHASE_SLOTS) and pm.has_method("set_slots_from_card_ids"):
		var pi_data: Dictionary = data.get(SK_PHASE_INSTRUMENT, {}) as Dictionary
		if not (pi_data.has("slot_card_ids")):
			var slot_ids: Array = data[SK_PHASE_SLOTS] as Array
			if String(data.get(SK_PHASE_SLOTS_ORDER, "")) != "rbgy" and pm.has_method("remap_legacy_green_first_slots"):
				slot_ids = pm.remap_legacy_green_first_slots(slot_ids)
			pm.set_slots_from_card_ids(slot_ids)

	# 特殊处理：backpack_extra_ids（必须先加载，避免后续操作被覆盖）
	if data.has(SK_BACKPACK_EXTRA_IDS) and data[SK_BACKPACK_EXTRA_IDS] is Array:
		## 类型已验证，直接使用（移除冗余的 as Array 强制转换）
		_pending_backpack_ids = data[SK_BACKPACK_EXTRA_IDS].duplicate()
		_last_known_extra_ids = _pending_backpack_ids.duplicate()
	else:
		_pending_backpack_ids = []

	# v7.x 修复（读档重复卡 bug）：此处原有一段把「相位仪槽位中的卡」追加进
	# _pending_backpack_ids / _last_known_extra_ids 的逻辑（"步骤②"）。
	#
	# 该逻辑是 v7.0 实例化改造前的旧设计残留——当时"背包=全卡池，槽位引用其中卡"，
	# 故槽位里的额外卡也要进背包列表。但 v7.x 实例化后槽位卡与背包卡互斥（一张卡
	# 要么在相位仪里、要么在背包里），装备(_on_card_equipped)/卸下(card_added_to_backpack)
	# /换装(card_swapped)三个信号链都已正确维护此互斥，存档时 SK_BACKPACK_EXTRA_IDS
	# 也已不含已装备的卡。
	#
	# 唯独这段读档逻辑把槽位卡（如 cold_t72#1）又塞回背包队列，打开背包后
	# load_pending_cards 把它兑现成一张背包卡 → 与槽位里的同一实例重复（同名同序号）。
	# 删除该块即可修复，存档数据本身无需迁移（重复是读档时动态注入的，非持久化数据）。

	# 特殊处理：game.current_level
	var gmgr_load: Node = get_node_or_null("/root/GameManager")
	if gmgr_load != null and data.has(SK_GAME) and data[SK_GAME] is Dictionary:
		var gdict: Dictionary = data[SK_GAME]
		if gdict.has(SK_CURRENT_LEVEL) and gmgr_load.has_method("set_current_level"):
			gmgr_load.set_current_level(int(gdict[SK_CURRENT_LEVEL]))
		# v6.6(剧情): 恢复二周目标志（补剧情.txt 第十二幕）
		if "ng_plus_active" in gmgr_load and gdict.has("ng_plus"):
			gmgr_load.ng_plus_active = bool(gdict["ng_plus"])

	# 旧存档常见：level_progress 已推进但 game.current_level 仍为 1，读档后主界面/教程判断会误以为新档
	var lpm_cursor: Node = get_node_or_null("/root/LevelProgressManager")
	var gmgr_cursor: Node = get_node_or_null("/root/GameManager")
	if lpm_cursor != null and gmgr_cursor != null and lpm_cursor.has_method("get_max_unlocked_level") and gmgr_cursor.has_method("set_current_level"):
		var max_u: int = lpm_cursor.get_max_unlocked_level()
		var gl0: int = int(gmgr_cursor.current_level)
		if max_u > 1 and gl0 <= 1:
			gmgr_cursor.set_current_level(max_u)

	# 特殊处理：legacy company
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm != null and data.has("company") and data["company"] is Dictionary:
		var legacy: Dictionary = data["company"].get("company_rep", {}) as Dictionary
		if not legacy.is_empty() and fsm.has_method("merge_legacy_company_rep"):
			fsm.merge_legacy_company_rep(legacy)

	# 特殊处理：phase instrument migration
	# v9.x（P2-7范围A）：migrate_law_slots... 已移除（法则卡链路退役，不再反向生成槽内法则卡）
	if pm != null:
		if pm.has_method("sync_law_slots_to_plm_if_has_law_cards"):
			pm.sync_law_slots_to_plm_if_has_law_cards()

	# v7.1: 移除 _ensure_mod_blueprints_exist() 调用。
	# 原逻辑每次读档无条件补齐全部改造图纸，导致新机制（图纸靠战斗掉落解锁）失效。
	# 老存档背包里已持有的图纸由 IntelItemBag.load_state 自行加载保留，不受影响。
	# 新图纸只能通过 intel_discovery_manager 的战斗掉落获得。

	# 这两个方法会在每次读档后无条件全解锁所有进化分支和敌源MOD，破坏情报系统的逐步发现机制。
	# 进化分支和敌源MOD应由 IntelEvolutionManager.check_and_discover_branches() 和
	#
	if DEBUG_SAVE_LOG:
		pass  # LOG: 已加载存档
	return true

## 安全加载管理器数据（类型检查+错误日志）
## 支持延迟加载管理器：如果管理器不在场景树中，尝试通过 ManagerLazyLoader 实例化

func _safe_load_manager(node_path: String, data: Dictionary, data_key: String) -> void:
	var manager: Node = get_node_or_null(node_path)
	if manager == null:
		# 尝试通过 ManagerLazyLoader 按需实例化
		var lazy_loader = get_node_or_null("/root/ManagerLazyLoader")
		if lazy_loader and lazy_loader.has_method("get_manager_by_name"):
			var node_name = node_path.get_file()
			manager = lazy_loader.get_manager_by_name(node_name)
	if manager == null:
		push_warning("[SaveManager] 管理器不存在且无法实例化: %s" % node_path)
		return

	if not data.has(data_key):
		return  # 数据中没有该字段，跳过

	var manager_data: Variant = data[data_key]

	# 类型检查：必须是Dictionary
	if typeof(manager_data) != TYPE_DICTIONARY:
		push_error("[SaveManager] %s 数据类型错误: 期望Dictionary，实际%s" % [data_key, type_string(typeof(manager_data))])
		return

	# 检查管理器是否有 load_state 方法
	if not manager.has_method("load_state"):
		push_warning("[SaveManager] %s 没有 load_state 方法" % node_path)
		return

	# 尝试加载数据
	manager.load_state(manager_data)

func _load_manager_batch(data: Dictionary, loads: Array) -> void:
	for entry in loads:
		if entry is Array and entry.size() >= 2:
			_safe_load_manager(String(entry[0]), data, String(entry[1]))

func _schedule_deferred_manager_loads(data: Dictionary) -> void:
	_deferred_load_data = data
	_deferred_manager_queue = DEFERRED_MANAGER_LOADS.duplicate(true)
	call_deferred("_process_deferred_manager_loads")
	# v6.6(挂机): AFK manager 是 RefCounted（非 autoload），用专用桥接加载。
	# manager 可能晚于 autoload 创建，故延迟重试直到就绪。
	if data.has(SK_AFK):
		_pending_afk_load = data[SK_AFK]
		_afk_load_retry_count = 0
		call_deferred("_load_afk_state")


## v6.6(挂机): 应用 AFK 存档到 manager。manager 未就绪时延迟重试（上限 _AFK_LOAD_MAX_RETRIES 次）。
func _load_afk_state() -> void:
	if _pending_afk_load.is_empty():
		return
	var afk_mgr: RefCounted = _get_afk_manager()
	if afk_mgr == null:
		_afk_load_retry_count += 1
		if _afk_load_retry_count <= _AFK_LOAD_MAX_RETRIES:
			call_deferred("_load_afk_state")
		else:
			# 超时放弃，保持默认（旧档/异常情况）
			_pending_afk_load.clear()
			_afk_load_retry_count = 0
		return
	if afk_mgr.has_method("load_state") and _pending_afk_load is Dictionary:
		afk_mgr.load_state(_pending_afk_load)
	# 加载完成后刷新面板显示（若面板已就绪）
	var afk_panel: Node = get_node_or_null("/root/Main/PopupLayer/AFKOverlay/CenterContainer/AFKPanel")
	if afk_panel != null and afk_panel.has_method("refresh_after_load"):
		afk_panel.refresh_after_load()
	_pending_afk_load.clear()
	_afk_load_retry_count = 0

func _process_deferred_manager_loads() -> void:
	if _deferred_manager_queue.is_empty():
		_deferred_load_data.clear()
		if _load_game_deferred_phase_open:
			_load_game_deferred_phase_open = false
			_perf_phase_end("load_game_deferred_managers")
		if _load_game_perf_pending:
			_load_game_perf_pending = false
			_perf_phase_end("load_game")
		return
	var batch_count: int = mini(DEFERRED_LOAD_BATCH_SIZE, _deferred_manager_queue.size())
	for _i in range(batch_count):
		var entry = _deferred_manager_queue.pop_front()
		if entry is Array and entry.size() >= 2:
			_safe_load_manager(String(entry[0]), _deferred_load_data, String(entry[1]))
	if not _deferred_manager_queue.is_empty():
		call_deferred("_process_deferred_manager_loads")
	else:
		_deferred_load_data.clear()
		if _load_game_deferred_phase_open:
			_load_game_deferred_phase_open = false
		if _load_game_perf_pending:
			_load_game_perf_pending = false
			_perf_phase_end("load_game")
