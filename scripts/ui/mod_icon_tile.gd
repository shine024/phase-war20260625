extends RefCounted
## v37.1 改造图标座工厂（ModIconTile）——改造图标统一"稀有度发光底座 + 真图标"。
## 背景：改造库/已装列表/制造中心原为裸贴 26×26 暗色贴图（青橙扁平图在深底上既暗又无
## 稀有度信息，common 与 mythic 同貌）；详情操作台更是只显示字母框。显示点统一收口于此。
## 底座样式复用 CardFrameUi.tile_rarity_style（与符文/卡牌瓷砖同一套稀有度递进发光语言：
## common 无光中性 → mythic 2px 边框强光）。返回的是缓存共享 StyleBox——**勿就地改**，
## 要改先 duplicate（卡情报 ModsBlock 悬停档即此法）。
## glow_mode：0=常态；1=激活态（详情操作台/悬停等选中语境，发光增强，同符文已装备语言）。
## 本工厂产出的 tile 会嵌在按钮/可点击行内——tile 与子控件 mouse_filter 全 IGNORE
## （v26.16 教训：默认 STOP 会吃掉行按钮点击）。

const GCRef = preload("res://resources/game_constants.gd")
const DTRef = preload("res://resources/design_tokens.gd")
const CardFrameUiRef = preload("res://scripts/card_frame_ui.gd")
const UiAssetLoaderRef = preload("res://scripts/ui_asset_loader.gd")
const DecalDataRef = preload("res://data/mod_visual_decals.gd")  # v37.3: 形象件角标数据源


static func make(mod_data: Dictionary, size: int = 26, glow_mode: int = 0, dim := false) -> Control:
	var rarity := String(mod_data.get("rarity", "common"))
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(size, size)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_theme_stylebox_override("panel", CardFrameUiRef.tile_rarity_style(rarity, glow_mode))
	if dim:
		tile.modulate = Color(1, 1, 1, 0.45)

	# 内边距随尺寸走（20px 行 2px / 26px 行 3px / 44px 详情 5px），避免边框压住图标笔画
	var margin := clampi(int(size / 8.0), 2, 5)
	var box := MarginContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		box.add_theme_constant_override("margin_" + side, margin)
	tile.add_child(box)

	var icon_path := String(mod_data.get("icon", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var tex_rect := TextureRect.new()
		tex_rect.texture = UiAssetLoaderRef.load_tex(icon_path)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tex_rect)
	else:
		# 无图标兜底：底座已带稀有度边框+发光，首字母作第二编码（沿用 v1.5 色弱友好规则）
		var lbl := Label.new()
		lbl.text = rarity.substr(0, 1).to_upper() if not rarity.is_empty() else "?"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", DTRef.get_title_font_bold())
		lbl.add_theme_font_size_override("font_size", DTRef.FONT_SIZE_SMALL)
		lbl.add_theme_color_override("font_color", GCRef.get_rarity_color(rarity))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(lbl)

	# v37.3 形象件角标：带单位贴花的改造在 tile 左上角显示 ◈（琥珀），列表可扫读
	if mod_data.has("id") and DecalDataRef.MOD_MAP.has(String(mod_data["id"])):
		var chip := Label.new()
		chip.text = "◈"
		chip.add_theme_font_size_override("font_size", 12)
		chip.add_theme_color_override("font_color", GCRef.get_rarity_color("legendary"))
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		chip.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(chip)
	return tile
