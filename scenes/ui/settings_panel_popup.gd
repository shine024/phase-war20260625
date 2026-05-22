extends Control
## 设置面板弹窗：在主场景中显示的设置界面

const SettingsPanelScene = preload("res://scenes/ui/settings_panel.tscn")

signal closed()

var settings_content: Node = null

func _ready() -> void:
	# 加载设置面板场景
	if SettingsPanelScene:
		settings_content = SettingsPanelScene.instantiate()
		add_child(settings_content)

		# 连接关闭信号
		if settings_content.has_signal("closed"):
			settings_content.closed.connect(_on_closed)

func _on_closed() -> void:
	# 勿 hide() 父节点 CenterContainer：全屏 SettingsOverlay 仍会 visible 并吞掉所有点击。
	# 由 Main 监听 closed 后统一 _close_overlay(SettingsOverlay)。
	closed.emit()

func refresh() -> void:
	# 刷新设置显示（如果需要）
	pass
