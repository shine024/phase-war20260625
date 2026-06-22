extends Node
## 故事管理器（精简版 v6.8）
##
## 历史职责：原承载 v6.3 章节流程 + v6.6 story_flags 通用标记 + v6.7 node_triggered。
## v6.8 删除剧情模式后，v6.3 章节逻辑（_story_chapters / 章节 unlock/complete / player_character）
## 全部移除；保留 v6.6 通用剧情标记系统 + v6.7 剧情节点触发追踪，它们被以下系统依赖：
##   - game_manager: 必败战标记（StoryFlags.PROLOGUE_COMPLETED / GUARDIAN_*）
##   - game_manager: v6.7 tutorial 任务去重（mark_node_triggered / is_node_triggered）
##   - quest_manager: 真实者分支选择存档（set_story_flag / get_story_flag）
##   - character_manager: 角色解锁标记

# v6.6(剧情): 通用剧情标记系统 — 承载补剧情.txt 中的 story_flags
# 用于分支剧情、NPC触发、真实者支线、83关通过等标记
var _story_flags: Dictionary = {}  ## {flag_key: Variant} 通用键值对式剧情标记
# v6.6(剧情): 已触发的剧情节点ID集合
var _triggered_node_ids: Array[String] = []

func _ready() -> void:
	# SaveManager会自动调用load_state
	pass


## 保存状态（给SaveManager用）
func save_state() -> Dictionary:
	return {
		# v6.6(剧情): 通用剧情标记 + 已触发节点
		"story_flags": _story_flags.duplicate(true),
		"triggered_node_ids": _triggered_node_ids.duplicate(),
	}

## 加载状态（给SaveManager用）
## 老存档里的 current_chapter / completed_chapters / unlocked_chapters / player_reputation
## 等字段在 v6.8 删除剧情模式后已废弃，此处用 .get() 忽略（向前兼容）
func load_state(data: Dictionary) -> void:
	if not data.is_empty():
		# v6.6(剧情): 加载通用剧情标记 + 已触发节点（旧存档自然兜底空值）
		_story_flags = data.get("story_flags", {})
		_triggered_node_ids.clear()
		for nid in data.get("triggered_node_ids", []):
			_triggered_node_ids.append(str(nid))

## 重置故事进度（新游戏 / 切换存档槽时调用）
func reset_story_progress() -> void:
	# v6.6(剧情): 重置通用标记与触发节点
	_story_flags.clear()
	_triggered_node_ids.clear()

# ═══════════════════════════════════════════════════════════════════
# v6.6(剧情): 通用 story_flags 标记系统 + 剧情节点触发追踪
# 承载 docs/补剧情.txt 中的 realist_contacted / linwei_mention_10946 /
# passed_83 / truth_revealed / zack_engineer_memory / linwei_return 等分支标记
# ═══════════════════════════════════════════════════════════════════

## 设置剧情标记（默认 true，也可传任意值承载分支选择结果）
func set_story_flag(key: String, value: Variant = true) -> void:
	_story_flags[key] = value

## 获取剧情标记值（不存在则返回 default）
func get_story_flag(key: String, default: Variant = false) -> Variant:
	return _story_flags.get(key, default)

## 剧情标记是否存在（分支已触发判定）
func has_story_flag(key: String) -> bool:
	return _story_flags.has(key)

## 布尔型剧情标记是否为 true（含隐式转换，便于条件门控）
func is_story_flag_true(key: String) -> bool:
	var v: Variant = _story_flags.get(key, false)
	if v is bool:
		return v
	return bool(v)

## 清除剧情标记
func clear_story_flag(key: String) -> void:
	_story_flags.erase(key)

## 获取所有剧情标记（调试/存档导出用）
func get_all_story_flags() -> Dictionary:
	return _story_flags.duplicate()

## 标记剧情节点已触发
func mark_node_triggered(node_id: String) -> void:
	if not node_id.is_empty() and not _triggered_node_ids.has(node_id):
		_triggered_node_ids.append(node_id)

## 剧情节点是否已触发过（防止同一节点重复触发）
func is_node_triggered(node_id: String) -> bool:
	return _triggered_node_ids.has(node_id)

## 获取所有已触发节点ID（调试用）
func get_triggered_node_ids() -> Array[String]:
	return _triggered_node_ids.duplicate()
