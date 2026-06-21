extends RefCounted
class_name NPCDialogSystem
## v6.6(剧情): NPC 支线对话触发器
##
## 职责：
##   1. 检查某天/某地点是否有 NPC 支线对话应该触发
##   2. 返回播放指令（对话内容 + 副作用）给 city_map，由 city_map 复用 StoryDialoguePanel 播放
##   3. 不直接操作 UI（保持 RefCounted 静态工具属性，无节点依赖）
##
## 调用方：scenes/city_map.gd
##   - _on_day_started：调用 check_daily_npc_events(day) 检查每日触发
##   - _on_location_clicked：调用 check_location_npc_event(location_id) 检查地点触发
##
## 副作用应用（grant_flags/relationship_change）在对话播放完毕后由 city_map 回调 apply_post_effects 执行。

const NPCDialogues := preload("res://data/story/npc_dialogues.gd")

## 检查某天是否有 NPC 支线应触发（按 NPC 登场顺序遍历，返回第一个匹配的播放指令）
## 返回结构：{"npc_id":..., "entry":..., "lines":[...]} 或空字典
## 注意：force_location 非空的对话不在此处返回（留给 check_location_npc_event 处理）
static func check_daily_npc_events(day: int) -> Dictionary:
	var sm: Node = get_node_or_null("/root/StoryManager")
	var cm: Node = get_node_or_null("/root/CharacterManager")
	if sm == null or cm == null:
		return {}
	var flags: Dictionary = sm.get_all_story_flags() if sm.has_method("get_all_story_flags") else {}
	var used: Array = _collect_used_ids(flags)
	for npc_id in [NPCDialogues.NPC_LOCKE, NPCDialogues.NPC_HELEN, NPCDialogues.NPC_LINWEI,
					NPCDialogues.NPC_ZACK, NPCDialogues.NPC_REALIST, NPCDialogues.NPC_CHENMO]:
		# v6.6(剧情): chenmo（主角旁白）不依赖 CharacterManager 解锁状态，总是可触发
		if npc_id != NPCDialogues.NPC_CHENMO:
			if not cm.is_character_dialogue_available(npc_id):
				continue
		var rel: int = cm.get_relationship_value(npc_id)
		var entry: Dictionary = NPCDialogues.get_dialogue(npc_id, day, rel, flags, used)
		if entry.is_empty():
			continue
		# force_location 为空的对话才在"每日检查"触发；非空的留给地点检查
		var fl: String = String(entry.get("force_location", ""))
		if not fl.is_empty():
			continue
		return {"npc_id": npc_id, "entry": entry, "lines": entry.get("lines", [])}
	return {}

## 检查某地点是否有 NPC 支线应触发（按 force_location 匹配）
static func check_location_npc_event(location_id: String, day: int) -> Dictionary:
	var sm: Node = get_node_or_null("/root/StoryManager")
	var cm: Node = get_node_or_null("/root/CharacterManager")
	if sm == null or cm == null:
		return {}
	var flags: Dictionary = sm.get_all_story_flags() if sm.has_method("get_all_story_flags") else {}
	var used: Array = _collect_used_ids(flags)
	for npc_id in [NPCDialogues.NPC_LOCKE, NPCDialogues.NPC_LINWEI, NPCDialogues.NPC_ZACK,
					NPCDialogues.NPC_HELEN, NPCDialogues.NPC_REALIST, NPCDialogues.NPC_CHENMO]:
		# v6.6(剧情): chenmo（主角旁白）不依赖 CharacterManager 解锁状态
		if npc_id != NPCDialogues.NPC_CHENMO:
			if not cm.is_character_dialogue_available(npc_id):
				continue
		var rel: int = cm.get_relationship_value(npc_id)
		var entry: Dictionary = NPCDialogues.get_dialogue(npc_id, day, rel, flags, used)
		if entry.is_empty():
			continue
		var fl: String = String(entry.get("force_location", ""))
		if fl.is_empty() or fl != location_id:
			continue
		return {"npc_id": npc_id, "entry": entry, "lines": entry.get("lines", [])}
	return {}

## 应用对话播完后的副作用（由 city_map 在 story_dialogue_finished 后调用）
## 写入 grant_flags 到 StoryManager，relationship_change 到 CharacterManager
static func apply_post_effects(play_instruction: Dictionary) -> void:
	if play_instruction.is_empty():
		return
	var entry: Dictionary = play_instruction.get("entry", {})
	var effects: Dictionary = NPCDialogues.apply_post_effects(entry)
	var sm: Node = get_node_or_null("/root/StoryManager")
	var cm: Node = get_node_or_null("/root/CharacterManager")
	# 1. grant_flags
	if sm and sm.has_method("set_story_flag"):
		var grant: Dictionary = effects.get("grant_flags", {})
		for fk in grant:
			sm.set_story_flag(fk, grant[fk])
		# 2. 标记对话已播放（幂等）
		var did: String = effects.get("dialog_id", "")
		if not did.is_empty():
			sm.set_story_flag("dialog_used_" + did, true)
	# 3. relationship_change
	if cm and cm.has_method("update_relationship"):
		var rel_changes: Dictionary = effects.get("relationship_change", {})
		for npc_id in rel_changes:
			cm.update_relationship(npc_id, int(rel_changes[npc_id]))
	# 4. reveal_quest — 揭示隐藏任务（接入 QuestManager，补剧情.txt 第四幕真实者支线）
	var rq: String = effects.get("reveal_quest", "")
	if not rq.is_empty():
		if sm and sm.has_method("set_story_flag"):
			sm.set_story_flag("quest_revealed_" + rq, true)
		# 真正调用 QuestManager.reveal_quest 让任务出现在任务板
		var qm: Node = get_node_or_null("/root/QuestManager")
		if qm and qm.has_method("reveal_quest"):
			qm.reveal_quest(rq)

# ───────────────────────────────────────────────────────────────────
# 内部辅助
# ───────────────────────────────────────────────────────────────────

## 从 StoryManager 取 story_flags 时已含 dialog_used_ 前缀的标记，转成纯 id 列表
static func _collect_used_ids(story_flags: Dictionary) -> Array:
	var used: Array = []
	for key in story_flags:
		var ks: String = String(key)
		if ks.begins_with("dialog_used_") and bool(story_flags[key]):
			used.append(ks.substr(len("dialog_used_")))
	return used

## 安全获取节点（RefCounted 静态方法不能直接 get_node，用 Engine.main_loop 取树）
static func get_node_or_null(path: String) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(path)
