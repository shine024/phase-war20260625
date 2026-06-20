extends Node
## 故事管理器：管理游戏剧情和对话

## 故事节点类型
enum StoryNodeType {
	DIALOGUE,      # 对话
	NARRATION,     # 旁白
	CHOICE,        # 选择
	BATTLE,        # 战斗
	REWARD         # 奖励
}

## 主角角色
var player_character: Dictionary = {
	"name": "指挥官",
	"title": "相位师",
	"background": "来自未来的军事指挥官，拥有操控相位的能力",
	"reputation": {}
}

## 故事章节
var _story_chapters: Array = []
var _current_chapter: String = ""
var _current_node_index: int = 0

# v6.3: 剧情模式章节进度
var _completed_chapters: Array[String] = []  ## 已完成的章节ID
var _unlocked_chapters: Array[String] = []   ## 已解锁的章节ID

signal story_chapter_started(chapter_id: String)
signal story_node_reached(node_index: int)
signal story_choice_made(choice_result: String)
signal story_chapter_completed(chapter_id: String)

func _ready() -> void:
	_initialize_story_chapters()
	# SaveManager会自动调用load_state

## 初始化故事章节
## v6.6 说明：此处硬编码的 chapter_1 是旧引擎遗留的示例数据，
## 当前 v6.3 剧情系统的真实数据源是 data/story_chapters.gd（8 章，覆盖一战→近未来），
## 由 game_manager.gd 的战前/战后对话流程驱动（SignalBus.story_show_pre_battle_dialogue 等）。
## 本方法保留是为兼容旧测试和未来扩展，新剧情内容请添加到 story_chapters.gd。
func _initialize_story_chapters() -> void:
	# 第一章：初到时代
	_story_chapters.append({
		"chapter_id": "chapter_1",
		"title": "穿越时空",
		"description": "你第一次穿越到一战时代，一切都显得陌生而危险",
		"story_nodes": [
			{
				"type": StoryNodeType.NARRATION,
				"text": "一阵眩晕过后，你发现自己站在了1916年的战场上...",
				"speaker": "旁白",
				"duration": 3.0
			},
			{
				"type": StoryNodeType.DIALOGUE,
				"text": "指挥官，我们需要你的帮助！敌军正在逼近！",
				"speaker": "士兵汤姆",
				"character_portrait": "res://ui/portraits/soldier_thomas.png",
				"voice": "soldier"
			},
			{
				"type": StoryNodeType.CHOICE,
				"text": "你决定如何应对？",
				"choices": [
					{
						"text": "立即部署防御",
						"result": "immediate_defense",
						"reputation_change": {"bravery": 10}
					},
					{
						"text": "先观察敌情",
						"result": "observe_first",
						"reputation_change": {"wisdom": 10}
					},
					{
						"text": "寻求盟友支援",
						"result": "call_ally",
						"reputation_change": {"diplomacy": 10}
					}
				]
			},
			{
				"type": StoryNodeType.BATTLE,
				"battle_id": "chapter_1_battle_1",
				"description": "击败进攻的敌军",
				"difficulty": 1.0
			},
			{
				"type": StoryNodeType.DIALOGUE,
				"text": "太精彩了！指挥官，你的战术简直是天才！",
				"speaker": "士兵汤姆",
				"character_portrait": "res://ui/portraits/soldier_thomas.png",
				"voice": "soldier"
			}
		]
	})

## 开始故事章节
func start_chapter(chapter_id: String) -> void:
	var chapter = _get_chapter_by_id(chapter_id)
	if chapter.is_empty():
		push_error("Chapter not found: %s" % chapter_id)
		return

	_current_chapter = chapter_id
	_current_node_index = 0

	story_chapter_started.emit(chapter_id)

	# 显示故事UI
	if SignalBus and SignalBus.has_signal("show_story_ui"):
		var first_node = chapter.get("story_nodes", [{}])[0]
		SignalBus.show_story_ui.emit(chapter, first_node)

## 获取章节剧情节点
func get_chapter_nodes(chapter_id: String) -> Array:
	var chapter = _get_chapter_by_id(chapter_id)
	if chapter.is_empty():
		return []

	return chapter.get("story_nodes", [])

## 做出剧情选择
func make_choice(choice_index: int) -> void:
	var chapter = _get_chapter_by_id(_current_chapter)
	if chapter.is_empty():
		return

	var nodes = chapter.get("story_nodes", [])
	if _current_node_index >= nodes.size():
		return

	var current_node = nodes[_current_node_index]
	if current_node["type"] != StoryNodeType.CHOICE:
		return

	var choices = current_node.get("choices", [])
	if choice_index >= 0 and choice_index < choices.size():
		var choice = choices[choice_index]
		var result = choice.get("result", "")
		var reputation_change = choice.get("reputation_change", {})

		# 更新玩家声望
		for attr in reputation_change:
			_update_player_reputation(attr, reputation_change[attr])

		story_choice_made.emit(result)

		# 继续到下一个节点
		_advance_to_next_node()

## 推进到下一个节点
func _advance_to_next_node() -> void:
	var chapter = _get_chapter_by_id(_current_chapter)
	if chapter.is_empty():
		return

	var nodes = chapter.get("story_nodes", [])
	_current_node_index += 1

	if _current_node_index >= nodes.size():
		# 章节完成
		story_chapter_completed.emit(_current_chapter)
	else:
		# 显示下一个节点
		var next_node = nodes[_current_node_index]
		if SignalBus and SignalBus.has_signal("show_story_node"):
			SignalBus.show_story_node.emit(next_node)

	story_node_reached.emit(_current_node_index)

## 更新玩家属性
func _update_player_reputation(attribute: String, amount: int) -> void:
	if not player_character.has("reputation"):
		player_character["reputation"] = {}

	player_character["reputation"][attribute] = player_character["reputation"].get(attribute, 0) + amount

## 获取章节信息
func _get_chapter_by_id(chapter_id: String) -> Dictionary:
	for chapter in _story_chapters:
		if chapter.get("chapter_id", "") == chapter_id:
			return chapter
	return {}


## 保存状态（给SaveManager用）
func save_state() -> Dictionary:
	return {
		"current_chapter": _current_chapter,
		"current_node": _current_node_index,
		"player_reputation": player_character.get("reputation", {}),
		# v6.3: 剧情模式章节进度
		"completed_chapters": _completed_chapters.duplicate(),
		"unlocked_chapters": _unlocked_chapters.duplicate(),
	}

## 加载状态（给SaveManager用）
func load_state(data: Dictionary) -> void:
	if not data.is_empty():
		_current_chapter = data.get("current_chapter", "")
		_current_node_index = data.get("current_node", 0)
		var reputation = data.get("player_reputation", {})
		if not reputation.is_empty():
			player_character["reputation"] = reputation
		# v6.3: 加载章节进度
		_completed_chapters.clear()
		for cid in data.get("completed_chapters", []):
			_completed_chapters.append(str(cid))
		_unlocked_chapters.clear()
		for cid in data.get("unlocked_chapters", []):
			_unlocked_chapters.append(str(cid))
		# 确保至少第一章已解锁
		_ensure_first_chapter_unlocked()

## 获取玩家角色
func get_player_character() -> Dictionary:
	return player_character.duplicate(true)

## 重置故事进度
func reset_story_progress() -> void:
	_current_chapter = ""
	_current_node_index = 0
	player_character["reputation"] = {}
	_completed_chapters.clear()
	_unlocked_chapters.clear()
	_ensure_first_chapter_unlocked()

# ═══════════════════════════════════════════════════════════════════
# v6.3: 剧情模式章节进度管理
# ═══════════════════════════════════════════════════════════════════

const StoryChaptersData = preload("res://data/story_chapters.gd")

## 确保第一章已解锁
func _ensure_first_chapter_unlocked() -> void:
	var first_id: String = StoryChaptersData.get_first_chapter_id()
	if not first_id.is_empty() and not _unlocked_chapters.has(first_id):
		_unlocked_chapters.append(first_id)

## 章节是否已解锁
func is_chapter_unlocked(chapter_id: String) -> bool:
	return _unlocked_chapters.has(chapter_id)

## 章节是否已完成
func is_chapter_completed(chapter_id: String) -> bool:
	return _completed_chapters.has(chapter_id)

## 解锁章节
func unlock_chapter(chapter_id: String) -> void:
	if not _unlocked_chapters.has(chapter_id):
		_unlocked_chapters.append(chapter_id)

## 标记章节完成
func complete_chapter(chapter_id: String) -> void:
	if not _completed_chapters.has(chapter_id):
		_completed_chapters.append(chapter_id)
	# 自动解锁下一章
	var next_id: String = StoryChaptersData.get_next_chapter_id(chapter_id)
	if not next_id.is_empty():
		unlock_chapter(next_id)

## 获取章节完成进度（0.0-1.0）
func get_story_progress() -> float:
	var total: int = StoryChaptersData.get_chapter_count()
	if total == 0:
		return 0.0
	return float(_completed_chapters.size()) / float(total)

## 剧情模式是否全部完成
func is_campaign_completed() -> bool:
	return _completed_chapters.size() >= StoryChaptersData.get_chapter_count()

## 获取已完成的章节数
func get_completed_count() -> int:
	return _completed_chapters.size()
