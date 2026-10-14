extends SceneTree
## 资源清点批（2026-10-13）一次性探针：load() 编译工作区改动文件，报解析错误。
## v6.68 修复批复用——注意 autoload（SignalBus）有活实例时 reload() 会误报 err=22，
## 以 load() 是否成功 + 是否出现 SCRIPT ERROR 行为准。

const FILES := [
	"res://scripts/signal_bus.gd",
	"res://scenes/main.gd",
	"res://scenes/world_map.gd",
	"res://scenes/bunker/truck_base.gd",
	"res://scenes/ui/modification_panel.gd",
	"res://scenes/ui/resource_bar.gd",
	"res://scenes/ui/card_info_panel.gd",
	"res://scenes/ui/unit_info_panel.gd",
	"res://scenes/ui/evolution_panel.gd",
	"res://scripts/node_finder.gd",
]


func _initialize() -> void:
	var bad := 0
	for f in FILES:
		var s = load(f)
		if s == null:
			print("PARSE-FAIL ", f)
			bad += 1
		else:
			print("OK        ", f)
	print("[parse check] %d/%d pass" % [FILES.size() - bad, FILES.size()])
	quit(0)
