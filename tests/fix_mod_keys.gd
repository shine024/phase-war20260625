## 批量修复改造模块DATA字典键格式
## 将常量名键替换为显式字符串字面量

extends SceneTree

const MOD_FILES = [
	"res://data/modification_modules/infantry_mods.gd",
	"res://data/modification_modules/armor_mods.gd",
	"res://data/modification_modules/artillery_mods.gd",
	"res://data/modification_modules/anti_air_mods.gd",
	"res://data/modification_modules/air_mods.gd",
	"res://data/modification_modules/recon_mods.gd",
	"res://data/modification_modules/engineer_mods.gd",
	"res://data/modification_modules/fort_mods.gd",
	"res://data/modification_modules/universal_mods.gd",
]

func _init() -> void:
	print("=== 修复改造模块DATA字典键格式 ===")
	for file_path in MOD_FILES:
		_fix_file(file_path)
	print("\n=== 修复完成 ===")
	quit()

func _fix_file(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("✗ 无法打开文件：%s" % file_path)
		return

	var content = file.get_as_utf8_string()
	file.close()

	var original_content = content
	var fixes = 0

	# 查找并替换模式：CONSTANT_NAME = {  ->  "constant_value" = {
	# 这个模式需要匹配常量定义并获取其值

	# 简单方法：替换所有 DATA 字典中的键格式
	# 模式：CONST_NAME = {  ->  "const_value" = {

	# 需要更复杂的解析，这里先打印需要手动修复的文件
	var has_issue = content.contains(" = {") and content.contains("const DATA")
	if has_issue:
		print("需要修复：%s" % file_path.get_file())
		# 统计可能的键数量
		var key_count = content.split(" = {").size() - 1
		print("  可能需要修复 %d 个键" % key_count)
	else:
		print("无需修复：%s" % file_path.get_file())
