extends SceneTree
## v7.x 面板统一改造 · 运行时检查（不依赖 GdUnit，headless --script 模式）
## 用法：Godot --headless --path . --script tests/ui_unified_check.gd
## 说明：所有检查放 _process 首帧执行——SceneTree._init 阶段 autoload 全局名
## 尚未注册（引用 BasicResourceManager/SignalBus 的面板脚本会编译失败），
## 且 add_child 后 _ready 要等主循环跑起来才触发。这是本项目 --script 模式的既有特性。

var _fails: Array[String] = []
var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true

	# ── 基础设施（纯静态） ──
	var DT = load("res://resources/design_tokens.gd")
	if DT.FONT_SIZE_XSMALL != 10 or DT.FONT_SIZE_BODY != 14:
		_fails.append("DesignTokens 字号档位缺失")
	if DT.get_panel_accent("store") != DT.COLOR_GOLD:
		_fails.append("PANEL_ACCENTS.store 映射错误")
	if DT.get_panel_accent("nonexistent") != DT.COLOR_ACCENT_CYAN:
		_fails.append("PANEL_ACCENTS 未知 key 未回退青色")

	var PS = load("res://scripts/ui/panel_styles.gd")
	var frame: StyleBoxFlat = PS.make_panel_frame(DT.COLOR_GOLD)
	if frame == null or frame.corner_radius_top_left != 12:
		_fails.append("make_panel_frame 圆角规格错误")
	var btn_styles: Dictionary = PS.make_button_styles(DT.COLOR_ACCENT_CYAN)
	for k in ["normal", "hover", "pressed", "disabled", "focus"]:
		if btn_styles.get(k) == null:
			_fails.append("make_button_styles 缺少 %s 态" % k)
	var close_styles: Dictionary = PS.make_close_button_styles()
	if close_styles.get("hover") == null or close_styles.get("normal") == null:
		_fails.append("make_close_button_styles 缺态")

	# ── PanelChrome 实例化 ──
	var ChromeScript = load("res://scenes/ui/components/panel_chrome.gd")
	var host := VBoxContainer.new()
	root.add_child(host)
	var chrome = ChromeScript.attach_to(host, "测试标题", DT.COLOR_GOLD, "副标题")
	if chrome.title_label == null or chrome.title_label.text != "测试标题":
		_fails.append("PanelChrome 标题构建失败")
	if chrome.subtitle_label == null or chrome.subtitle_label.text != "副标题":
		_fails.append("PanelChrome 副标题构建失败")
	if chrome.close_button == null or chrome.close_button.text != "✕":
		_fails.append("PanelChrome 关闭按钮构建失败")
	if host.get_child(0) != chrome:
		_fails.append("PanelChrome 未插入容器首位")
	# 注：GDScript lambda 按值捕获，用数组承载标志
	var fired := [false]
	chrome.closed.connect(func() -> void: fired[0] = true)
	chrome.close_button.emit_signal("pressed")
	if not fired[0]:
		_fails.append("PanelChrome closed 信号未随 ✕ 触发")
	host.queue_free()

	# ── 迁移面板脚本编译检查（load 即编译；autoload 已就绪才可解析 BasicResourceManager 等） ──
	var migrated_scripts: Array[String] = [
		"res://scenes/ui/store_panel.gd",
		"res://scenes/ui/quest_panel.gd",
		"res://scenes/ui/drops_inventory_panel.gd",
		"res://scenes/ui/achievement_panel.gd",
		"res://scenes/ui/settings_panel.gd",
		"res://scenes/ui/occupation_panel.gd",
		"res://scenes/ui/faction_panel.gd",
		"res://scenes/ui/intelligence_hub_panel.gd",
		"res://scenes/ui/collection_panel.gd",
		"res://scenes/ui/reinforcement_panel.gd",
		"res://scenes/ui/leaderboard/leaderboard_panel.gd",
		"res://scenes/ui/player_master_panel.gd",
		"res://scenes/ui/help_panel.gd",
		"res://scenes/ui/manufacture_panel.gd",
		"res://scenes/ui/phase_master_skill_panel.gd",
		"res://scenes/ui/afk_panel.gd",
		"res://scenes/ui/mvp_panel.gd",
		"res://scenes/ui/backpack_panel.gd",
		"res://scenes/main.gd",
		"res://managers/ui_lazy_loader.gd",
		"res://scripts/signal_bus.gd",
	]
	for sp in migrated_scripts:
		if load(sp) == null:
			_fails.append("脚本加载失败: %s" % sp)

	# ── 迁移面板 tscn 解析检查 ──
	var migrated_scenes: Array[String] = [
		"res://scenes/ui/store_panel.tscn",
		"res://scenes/ui/quest_panel.tscn",
		"res://scenes/ui/drops_inventory_panel.tscn",
		"res://scenes/ui/achievement_panel.tscn",
		"res://scenes/ui/settings_panel.tscn",
		"res://scenes/ui/occupation_panel.tscn",
		"res://scenes/ui/faction_panel.tscn",
		"res://scenes/ui/intelligence_hub_panel.tscn",
		"res://scenes/ui/collection_panel.tscn",
		"res://scenes/ui/reinforcement_panel.tscn",
		"res://scenes/ui/leaderboard_panel.tscn",
		"res://scenes/ui/player_master_panel.tscn",
		"res://scenes/ui/help_panel.tscn",
		"res://scenes/ui/manufacture_panel.tscn",
		"res://scenes/ui/phase_master_skill_panel.tscn",
		"res://scenes/ui/afk_panel.tscn",
		"res://scenes/ui/mvp_panel.tscn",
		"res://scenes/ui/backpack_panel.tscn",
		"res://scenes/main.tscn",
	]
	for sp in migrated_scenes:
		if load(sp) == null:
			_fails.append("场景加载失败: %s" % sp)

	# ── store_panel 实例化烟测（chrome 接线 + 框架生效） ──
	var smoke_scene: PackedScene = load("res://scenes/ui/store_panel.tscn")
	var smoke: Control = smoke_scene.instantiate()
	root.add_child(smoke)
	if not (smoke is PanelContainer):
		_fails.append("store_panel 根不是 PanelContainer")
	if smoke.custom_minimum_size != DT.PANEL_SIZE_MEDIUM:
		_fails.append("store_panel 未套用 MEDIUM 档: %s" % str(smoke.custom_minimum_size))
	var chrome_found := false
	for child in smoke.get_node("Margin/VBox").get_children():
		if child.get_script() == ChromeScript:
			chrome_found = true
	if not chrome_found:
		_fails.append("store_panel 未挂 PanelChrome")
	smoke.queue_free()

	if _fails.is_empty():
		print("✅ ui_unified_check 全部通过")
		quit(0)
	else:
		for f in _fails:
			printerr("❌ ", f)
		quit(1)
	return true
