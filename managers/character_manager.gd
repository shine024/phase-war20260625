extends Node
## 角色管理器：管理游戏中的角色和关系
## v6.8: 删除剧情模式后移除 NPCDialogues 依赖（city_map 专属，已删）

var _characters: Dictionary = {}
var _player_character: Dictionary = {}

signal relationship_changed(character_id: String, new_value: int)
signal character_unlocked(character_id: String)

func _ready() -> void:
	_initialize_characters()
	# SaveManager会自动调用load_state

## 初始化角色
func _initialize_characters() -> void:
	# 主角
	_player_character = {
		"id": "player",
		"name": "指挥官",
		"title": "相位师",
		"description": "来自未来的军事指挥官，拥有操控相位的能力",
		"portrait": "res://ui/portraits/player.png",
		"personality": {
			"bravery": 50,
			"wisdom": 50,
			"diplomacy": 50,
			"leadership": 50
		},
		"relationships": {},
		"unlocked": true
	}

	# 关键NPC
	_characters["thomas"] = {
		"id": "thomas",
		"name": "托马斯",
		"title": "忠诚的士兵",
		"description": "一战时期的士兵，成为你最信任的战友",
		"portrait": "res://ui/portraits/thomas.png",
		"personality": {
			"loyalty": 90,
			"bravery": 70,
			"humor": 30
		},
		"unlocked": true,
		"first_met_chapter": "chapter_1"
	}

	_characters["sophia"] = {
		"id": "sophia",
		"name": "索菲亚",
		"title": "科学家",
		"description": "二战时期的科学家，帮助你理解相位技术",
		"portrait": "res://ui/portraits/sophia.png",
		"personality": {
			"intelligence": 95,
			"curiosity": 80,
			"caution": 60
		},
		"unlocked": false,
		"unlock_chapter": "chapter_2"
	}

	_characters["victor"] = {
		"id": "victor",
		"name": "维克多",
		"title": "抵抗军领袖",
		"description": "冷战时期的抵抗军领袖，帮助你对抗强大的敌人",
		"portrait": "res://ui/portraits/victor.png",
		"personality": {
			"charisma": 85,
			"determination": 90,
			"strategy": 75
		},
		"unlocked": false,
		"unlock_chapter": "chapter_3"
	}

	_characters["aria"] = {
		"id": "aria",
		"name": "艾莉亚",
		"title": "黑客天才",
		"description": "现代时期的天才黑客，为你提供情报支持",
		"portrait": "res://ui/portraits/aria.png",
		"personality": {
			"intelligence": 98,
			"tech_savvy": 95,
			"rebellious": 70
		},
		"unlocked": false,
		"unlock_chapter": "chapter_4"
	}

	_characters["nova"] = {
		"id": "nova",
		"name": "诺瓦",
		"title": "未来战士",
		"description": "来自近未来的精英战士，与你的命运紧密相连",
		"portrait": "res://ui/portraits/nova.png",
		"personality": {
			"combat": 95,
			"honor": 90,
			"mystery": 80
		},
		"unlocked": false,
		"unlock_chapter": "chapter_5"
	}

	# ═══════════════════════════════════════════════════════════════
	# v6.6(剧情): docs/补剧情.txt 补充角色 — 与现有 legacy NPC 并存
	# 这些 NPC 的对话由 scripts/city/npc_dialog_system.gd + data/story/npc_dialogues.gd 驱动
	# 初始 unlocked=false，由 city_map 节点触发解锁
	# ═══════════════════════════════════════════════════════════════
	_characters["locke"] = {
		"id": "locke",
		"name": "洛克",
		"title": "引导者",
		"description": "比主角早来到无限城的相位师，引路人。止步于83关前。",
		"portrait": "res://ui/portraits/locke.png",
		"personality": {"loyalty": 80, "wisdom": 75, "cynicism": 60},
		"unlocked": false,
		"unlock_day": 1,
		"is_story_npc": true
	}
	_characters["linwei"] = {
		"id": "linwei",
		"name": "林薇",
		"title": "四叶草店主",
		"description": "市场区'四叶草'商店的店主，与E-10946有神秘关联。",
		"portrait": "res://ui/portraits/linwei.png",
		"personality": {"kindness": 85, "mystery": 70, "regret": 65},
		"unlocked": false,
		"unlock_day": 5,
		"is_story_npc": true
	}
	_characters["zack"] = {
		"id": "zack",
		"name": "扎克",
		"title": "训练场教官",
		"description": "训练场教官，停在48关三年。记忆中隐约有工程师的影子。",
		"portrait": "res://ui/portraits/zack.png",
		"personality": {"discipline": 90, "melancholy": 70, "patience": 80},
		"unlocked": false,
		"unlock_day": 8,
		"is_story_npc": true
	}
	_characters["helen"] = {
		"id": "helen",
		"name": "海伦",
		"title": "传奇指挥官 / 城市意识",
		"description": "曾经的传奇指挥官海伦。当入侵第一次撕开裂口，她带领全城扛了三年，最终放弃肉体，将意识与城市系统融合。这座城的每一声播报，都是她残留的意识在燃烧。",
		"portrait": "res://ui/portraits/helen.png",
		"personality": {"neutrality": 95, "authority": 85, "mystery": 90},
		"unlocked": false,
		"unlock_day": 1,
		"is_story_npc": true
	}
	_characters["realist"] = {
		"id": "realist",
		"name": "真实者",
		"title": "清醒者",
		"description": "自称看穿城市循环真相的组织代表。亦敌亦友，立场模糊。",
		"portrait": "res://ui/portraits/realist.png",
		"personality": {"conviction": 85, "manipulation": 75, "ambiguity": 80},
		"unlocked": false,
		"unlock_day": 25,
		"is_story_npc": true
	}

	# 陈末：主角身份。游戏背景.txt 设定：37岁中年社畜，相位师潜质，
	# 佩戴相位仪后进入超空间/无限城。这里作为 player 的元数据，不作为交互NPC。
	_player_character["real_name"] = "陈末"
	_player_character["background_detail"] = "37岁，某二线城市国企基层科员，独居，生活钝化。未来自己的留言激活了他的相位师潜质。"

## 获取角色信息
func get_character(character_id: String) -> Dictionary:
	if character_id == "player":
		return _player_character.duplicate(true)
	return _characters.get(character_id, {}).duplicate(true)

## 获取所有角色
func get_all_characters() -> Dictionary:
	var all_chars = _characters.duplicate(true)
	all_chars["player"] = _player_character.duplicate(true)
	return all_chars

## 获取已解锁角色
func get_unlocked_characters() -> Array:
	var unlocked = []

	if _player_character.get("unlocked", false):
		unlocked.append(_player_character)

	for char_id in _characters:
		var char_data = _characters[char_id]
		if char_data.get("unlocked", false):
			unlocked.append(char_data)

	return unlocked

## 解锁角色
func unlock_character(character_id: String) -> bool:
	if not _characters.has(character_id):
		return false

	var char_data = _characters[character_id]
	if char_data.get("unlocked", false):
		return false  # 已经解锁

	char_data["unlocked"] = true

	character_unlocked.emit(character_id)
	return true

## 更新关系
func update_relationship(character_id: String, change: int) -> void:
	if not _player_character.has("relationships"):
		_player_character["relationships"] = {}

	_player_character["relationships"][character_id] = _player_character["relationships"].get(character_id, 0) + change

	# 限制关系值范围
	_player_character["relationships"][character_id] = clampi(_player_character["relationships"][character_id], -100, 100)

	relationship_changed.emit(character_id, _player_character["relationships"][character_id])

## 获取关系值
func get_relationship_value(character_id: String) -> int:
	if _player_character.has("relationships"):
		return _player_character["relationships"].get(character_id, 0)
	return 0

## 获取关系描述
func get_relationship_description(character_id: String) -> String:
	var value = get_relationship_value(character_id)

	if value >= 80:
		return "挚友"
	elif value >= 50:
		return "好友"
	elif value >= 20:
		return "伙伴"
	elif value >= -20:
		return "熟人"
	elif value >= -50:
		return "疏远"
	elif value >= -80:
		return "敌对"
	else:
		return "仇敌"

## 检查角色对话可用性
func is_character_dialogue_available(character_id: String) -> bool:
	var char_data = get_character(character_id)
	if char_data.is_empty():
		return false

	return char_data.get("unlocked", false)

## 获取角色对话（legacy 硬编码占位）
## v6.8: 删除剧情模式后，story_npc 角色（洛克/林薇/扎克/海伦/真实者）的
## 数据驱动对话（NPCDialogues）随 city_map 一并移除；此处仅保留 legacy 占位。
## story_npc 角色无数据源时返回空数组。
func get_character_dialogue(character_id: String, _context = "") -> Array:
	if not is_character_dialogue_available(character_id):
		return []

	var char_data = _characters.get(character_id, {})

	# v6.6 story_npc 角色的数据驱动对话已随 city_map 移除，暂返回空
	if char_data.get("is_story_npc", false):
		return []

	# legacy 角色：硬编码占位对话
	var dialogues = []
	match character_id:
		"thomas":
			dialogues = [
				"指挥官，我们一定能胜利！",
				"我会一直跟随你，无论去哪个时代。",
				"敌人的攻势很猛，我们需要谨慎行事。"
			]
		"sophia":
			dialogues = [
				"根据我的分析，这个时代的相位能量很活跃。",
				"我有了一个新发现，或许能帮助我们的战斗。",
				"科学的力量真是不可思议。"
			]
		_:
			dialogues = ["你好！"]

	return dialogues

## v6.6(剧情): 判断角色是否为 story NPC
func is_story_npc(character_id: String) -> bool:
	var char_data = _characters.get(character_id, {})
	return char_data.get("is_story_npc", false)

## 保存角色数据（已废弃 - SaveManager自动调用save_state）
## 加载角色数据（已废弃 - SaveManager自动调用load_state）

## 保存状态（给SaveManager用）
func save_state() -> Dictionary:
	return {
		"player": _player_character,
		"npcs": _characters
	}

## 加载状态（给SaveManager用）
func load_state(data: Dictionary) -> void:
	if not data.is_empty():
		_player_character = data.get("player", _player_character)
		_characters = data.get("npcs", _characters)

## 获取玩家角色
func get_player_character() -> Dictionary:
	return _player_character.duplicate(true)

## 更新玩家属性
func update_player_attribute(attribute: String, value: int) -> void:
	if not _player_character.has("personality"):
		_player_character["personality"] = {}

	_player_character["personality"][attribute] = _player_character["personality"].get(attribute, 50) + value
	_player_character["personality"][attribute] = clampi(_player_character["personality"][attribute], 0, 100)
