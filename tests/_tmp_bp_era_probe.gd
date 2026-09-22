extends Node
## Task 1.1b 实机落点截图：向 InstanceRegistry 注入 ≥9 张 bp_*（cold/modern/near 各 ≥3），
## 走 UiAssetLoader 卡面渲染链截图（SubViewport 直采免 DPI 缩放），自存图自退出。
## 跑法：godot --path . --resolution 1280x720 res://tests/_tmp_bp_era_probe.tscn
## 产物：res://.godot/agent_tools/pr_task11_bp_ingame.png

const BP_IDS := [
	# cold ≥3
	"bp_cold_001", "bp_cold_002", "bp_cold_003", "bp_cold_004",
	# modern ≥3
	"bp_mod_001", "bp_mod_002", "bp_mod_003", "bp_mod_004",
	# near ≥3
	"bp_near_001", "bp_near_002", "bp_near_003", "bp_near_004",
]

var _frames := 0
var _shot_done := false


func _ready() -> void:
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	var injected: Array[String] = []
	if ir != null and ir.has_method("create_instance"):
		for id in BP_IDS:
			var inst: CardResource = ir.create_instance(String(id))
			if inst != null:
				injected.append(String(id))
	print("[bp_probe] injected=%d/%d" % [injected.size(), BP_IDS.size()])

	# 卡面网格（UiAssetLoader 全回退链经 backpack 式渲染——此处直接用 UiAssetLoader.card_icon_for_list）
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.09, 0.12)
	root.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	root.add_child(grid)
	var UAL := preload("res://scripts/ui_asset_loader.gd")
	for id in injected:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(190, 260)
		grid.add_child(cell)
		var tex: Texture2D = UAL.card_icon_for_list(String(id))
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cell.add_child(tr)
		var lbl := Label.new()
		lbl.text = String(id)
		lbl.position = Vector2(6, 236)
		lbl.add_theme_font_size_override("font_size", 13)
		cell.add_child(lbl)
	add_child(root)


func _process(_d: float) -> void:
	_frames += 1
	if _frames == 30 and not _shot_done:
		_shot_done = true
		var img := get_viewport().get_texture().get_image()
		var out := "res://.godot/agent_tools/pr_task11_bp_ingame.png"
		var err := img.save_png(out)
		print("[bp_probe] shot=%s err=%d" % [out, err])
	if _frames > 40:
		get_tree().quit(0)
