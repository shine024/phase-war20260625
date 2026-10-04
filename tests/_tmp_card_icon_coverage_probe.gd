## 2026-10-03 战斗美术体检·C 维度终审探针：全量战斗卡过真实 UiAssetLoader
## card_icon_path_for 八级回退链，统计占位图/_thumb 缺失/空路径。
## 运行：--headless --path . --script tests/_tmp_card_icon_coverage_probe.gd
extends SceneTree

var _pass: int = 0
var _fail: int = 0

func _initialize() -> void:
	var GC := load("res://resources/game_constants.gd")
	var Loader := load("res://scripts/ui_asset_loader.gd")
	var DefaultCards := load("res://data/default_cards.gd")
	var all: Array = DefaultCards.create_all()
	var combat: Array = []
	for c in all:
		if c.card_type == GC.CardType.COMBAT_UNIT:
			combat.append(c)
	print("=== 卡图覆盖探针: %d 张战斗卡 / 全部 %d 张 ===" % [combat.size(), all.size()])
	var placeholder: Array = []
	var empty: Array = []
	var thumb_miss: Array = []
	var root_icon: Array = []
	for c in combat:
		var p: String = Loader.card_icon_path_for(c)
		if p.is_empty():
			empty.append(c.card_id)
			continue
		if p.contains("_enemy_placeholder"):
			placeholder.append(c.card_id)
			continue
		if p.begins_with("res://assets/card_icons/player/") or p.begins_with("res://assets/card_icons/enemy/"):
			# 主力链路：校验 384 缩略图是否在位（缺失=网格回退全分辨率，VRAM 压力）
			var t: String = Loader._to_thumbnail_path(p)
			if not t.is_empty() and not ResourceLoader.exists(t):
				thumb_miss.append("%s -> %s" % [c.card_id, t.get_file()])
		elif not p.contains("vis_player") and not p.contains("vis_enemy") and not p.contains("_thumb"):
			root_icon.append("%s -> %s" % [c.card_id, p.get_file()])
	print("占位图回退 (%d): %s" % [placeholder.size(), placeholder])
	print("空路径 (%d): %s" % [empty.size(), empty])
	print("thumb384 缺失 (%d): %s" % [thumb_miss.size(), thumb_miss.slice(0, 12)])
	print("非标准目录图标 (%d): %s" % [root_icon.size(), root_icon.slice(0, 12)])
	_fail = placeholder.size() + empty.size()
	print("=== 结果: %d pass / %d fail ===" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
