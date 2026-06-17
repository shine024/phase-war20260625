extends RefCounted
## 批量更新改造模块图标路径工具
## 将所有改造模块的 icon 字段更新为引用 res://assets/ui/icons/mod_icons/mod_{slot_type}.png

const ICON_BASE := "res://assets/ui/icons/mod_icons/mod_"
const ICON_DIR := "F:/godot fair duet/create/phase-war/assets/ui/icons/mod_icons"

const FALLBACK_MAP: Dictionary = {
	"active": "armor_special",
	"deception": "stealth",
	"enemy_origin": "command",
	"enhancement": "fire_control",
	"fuze": "ammunition",
	"guidance": "radar",
	"helmet": "shield",
	"system": "command",
	"thrust": "engine",
	"weapons": "weapon_air",
}

const DEFAULT_FALLBACK: String = "weapon"


static func _load_existing_icons() -> PackedStringArray:
	var result: PackedStringArray = []
	var dir := DirAccess.open(ICON_DIR)
	if dir:
		dir.list_dir_begin()
		var file: String = dir.get_next()
		while file != "":
			if file.ends_with(".png") and not file.ends_with(".import"):
				result.append(file.trim_suffix(".png"))
			file = dir.get_next()
	return result


static func _get_icon_path(slot_type: String, existing_icons: PackedStringArray) -> String:
	for icon_name in existing_icons:
		if icon_name == slot_type:
			return ICON_BASE + slot_type + ".png"
	if FALLBACK_MAP.has(slot_type):
		var fb: String = FALLBACK_MAP[slot_type]
		for icon_name in existing_icons:
			if icon_name == fb:
				return ICON_BASE + fb + ".png"
	return ICON_BASE + DEFAULT_FALLBACK + ".png"


static func _update_file(filepath: String, existing_icons: PackedStringArray) -> int:
	var file := FileAccess.open(filepath, FileAccess.READ)
	if not file:
		print("Cannot open: ", filepath)
		return 0
	
	var content: String = file.get_as_text()
	file.close()
	
	var lines: PackedStringArray = content.split("\n")
	var count: int = 0
	var new_lines: PackedStringArray = []
	
	for i in range(lines.size()):
		var line: String = lines[i]
		
		# 检查是否是 slot_type 行
		if "slot_type" in line and "=" in line and "\"" in line:
			new_lines.append(line)
			
			# 提取 slot_type 值
			var regex: RegEx = RegEx.new()
			regex.compile("\"([^\"]+)\"")
			var slot_match: RegExMatch = regex.search(line)
			var slot_type: String = ""
			if slot_match:
				slot_type = slot_match.get_string(1)
			else:
				continue
			
			var icon_path: String = _get_icon_path(slot_type, existing_icons)
			
			# 检查下一行是否已有 icon
			var next_line: String = ""
			if i + 1 < lines.size():
				next_line = lines[i + 1]
			
			if "icon" not in next_line:
				# 在 slot_type 行后面插入 icon 行
				var indent: String = "\t\t"
				new_lines.append(indent + "icon = \"" + icon_path + "\",")
				count += 1
		
		else:
			new_lines.append(line)
	
	if count > 0:
		var new_content: String = "\n".join(new_lines)
		file = FileAccess.open(filepath, FileAccess.WRITE)
		file.store_string(new_content)
		file.close()
	
	return count


func main() -> void:
	print("Loading existing icons...")
	var existing_icons: PackedStringArray = _load_existing_icons()
	print("Found ", existing_icons.size(), " existing icons")
	
	var mod_files: PackedStringArray = PackedStringArray([
		"F:/godot fair duet/create/phase-war/data/modification_modules/infantry_mods.gd",
		"F:/godot fair duet/create/phase-war/data/modification_modules/armor_mods.gd",
		"F:/godot fair duet/create/phase-war/data/modification_modules/artillery_mods.gd",
		"F:/godot fair duet/create/phase-war/data/modification_modules/anti_air_mods.gd",
		"F:/godot fair duet/create/phase-war/data/modification_modules/air_mods.gd",
		"F:/godot fair duet/create/phase-war/data/modification_modules/recon_mods.gd",
		"F:/godot fair duet/create/phase-war/data/modification_modules/engineer_mods.gd",
		"F:/godot fair duet/create/phase-war/data/modification_modules/fort_mods.gd",
		"F:/godot fair duet/create/phase-war/data/modification_modules/universal_mods.gd",
		"F:/godot fair duet/create/phase-war/data/modification_modules/enhancement_mods.gd",
	])
	
	var total_updated: int = 0
	
	for filepath in mod_files:
		var count: int = _update_file(filepath, existing_icons)
		if count > 0:
			print("Updated: ", filepath.get_file(), " (", count, " icons)")
		total_updated += count
	
	print("\nTotal icons added: ", total_updated)


func _ready() -> void:
	main()
