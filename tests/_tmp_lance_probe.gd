extends Node
## 记录7 临时探针：背包卡格里相位刺刀班（drop_phase_lance）的卡图显示复现。
## 跑法（带窗口，自存图自退出）：
##   godot --rendering-driver opengl3 --path . res://tests/_tmp_lance_probe.tscn
## 产物：.godot/agent_tools/lance_backpack.png

const CardItemScene := preload("res://scenes/ui/backpack_card_item.tscn")
const DefaultCards = preload("res://data/default_cards.gd")


func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(1280, 720)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(holder)
	# 网格尺寸（backpack_panel CARD_SLOT_MIN 口径）逐卡摆放：相位刺刀班 + 对照组
	var ids := ["drop_phase_lance", "ww1_mauser", "drop_smg_mk2", "drop_railgun",
		"drop_thunder_field", "ww1_arty_m81", "ww2_garand", "cold_t72"]
	for i in range(ids.size()):
		var card: CardResource = DefaultCards.get_card_by_id(ids[i])
		print("[probe] %s -> card=%s" % [ids[i], "null" if card == null else card.card_id])
		if card != null:
			print("[probe]   icon_path=%s" % UiAssetLoader.card_icon_path_for_list(card))
		var item := CardItemScene.instantiate()
		item.custom_minimum_size = Vector2(96, 138)
		item.position = Vector2(20 + (i % 8) * 120, 20)
		holder.add_child(item)
		item.set_card(card)
	var row2 := ["ww1_mp18", "ww2_thompson", "cold_ak", "mod_marine"]
	for j in range(row2.size()):
		var card2: CardResource = DefaultCards.get_card_by_id(row2[j])
		var item2 := CardItemScene.instantiate()
		item2.custom_minimum_size = Vector2(96, 138)
		item2.position = Vector2(20 + j * 120, 200)
		holder.add_child(item2)
		item2.set_card(card2)
	# 大图（详情弹窗口径 560x720 的 art 区模拟）：直接贴 512 图看构图
	var big := TextureRect.new()
	big.texture = load("res://assets/card_icons/player/drop_phase_lance.png")
	big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	big.size = Vector2(340, 460)
	big.position = Vector2(560, 20)
	holder.add_child(big)
	var lab := Label.new()
	lab.text = "COVERED 340x460"
	lab.position = Vector2(560, 4)
	holder.add_child(lab)
	for k in range(6):
		await get_tree().process_frame
	var img: Image = vp.get_texture().get_image()
	img.save_png("res://.godot/agent_tools/lance_backpack.png")
	print("LANCE_PROBE_SAVED")
	get_tree().quit()
