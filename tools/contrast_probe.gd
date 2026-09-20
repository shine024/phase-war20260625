extends SceneTree
## S3 WCAG 对比度全量测算探针（一次性工具，非门禁；2026-09-20 标准集合批）
## 跑法：godot --headless --rendering-driver opengl3 --path . --script tools/contrast_probe.gd
## 口径：WCAG 2.x SC 1.4.3/1.4.11——普通文本 ≥4.5:1；大字号（≥24px 或 ≥18.66px 粗体）
## 与 UI 构件 ≥3:1。扁平 token 矩阵（文本色 × 底色）；贴图底（PanelStyles 纹理）不在
## 算术范围内，有疑点时用截图取色补测。

const DT = preload("res://resources/design_tokens.gd")

# 文本色 token（正文字号为主 → 4.5 阈值；金色大字/语义色按需看 LARGE 列）
const TEXT_TOKENS := [
	"COLOR_TEXT", "COLOR_TEXT_BRIGHT", "COLOR_TEXT_MID", "COLOR_TEXT_DIM", "COLOR_TEXT_FAINT",
	"COLOR_GOLD", "COLOR_GREEN_BRIGHT", "COLOR_GREEN_UP", "COLOR_RED_DOWN",
	"COLOR_AMBER", "COLOR_AMBER_DEEP", "COLOR_CYAN_TECH", "COLOR_CYAN_TECH_SOFT",
	"COLOR_VIOLET", "COLOR_VIOLET_SOFT", "COLOR_ENERGY", "COLOR_HEALTH",
	"COLOR_ACCENT_CYAN", "COLOR_ACCENT_PURPLE", "COLOR_HOVER_WHITE",
]

# 底色 token（暗底为主）
const BG_TOKENS := [
	"COLOR_VOID", "COLOR_PANEL_DEEP", "COLOR_SLOT_LOCKED", "COLOR_CARD",
	"COLOR_CARD_HI", "COLOR_PANEL", "COLOR_BG",
]


func _lum(c: Color) -> float:
	var ch := [c.r, c.g, c.b]
	var out := 0.0
	var w := [0.2126, 0.7152, 0.0722]
	for i in 3:
		var v: float = ch[i]
		v = v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
		out += w[i] * v
	return out


func _ratio(fg: Color, bg: Color) -> float:
	var l1 := _lum(fg)
	var l2 := _lum(bg)
	if l1 < l2:
		var t := l1
		l1 = l2
		l2 = t
	return (l1 + 0.05) / (l2 + 0.05)


func _initialize() -> void:
	print("=== WCAG 对比度全量测算（design_tokens 扁平矩阵）===")
	print("%-22s" % "文本 token", " ", "%-18s" % "底色", "  比值    判定")
	var cmap: Dictionary = (DT as Script).get_script_constant_map()
	var fails: Array = []
	var large_only: Array = []
	for tn in TEXT_TOKENS:
		if not cmap.has(tn):
			print("[跳过] 无此 token: ", tn)
			continue
		var fg: Color = cmap[tn]
		for bn in BG_TOKENS:
			var bg: Color = cmap[bn]
			var r := _ratio(fg, bg)
			var verdict := "OK"
			if r < 3.0:
				verdict = "FAIL"
				fails.append("%s on %s = %.2f" % [tn, bn, r])
			elif r < 4.5:
				verdict = "仅大字号"
				large_only.append("%s on %s = %.2f" % [tn, bn, r])
			print("%-22s" % tn, " ", "%-18s" % bn, "  %.2f   %s" % [r, verdict])
	print("")
	print("—— FAIL（<3:1，任何字号都不达标）：%d 处" % fails.size())
	for f in fails:
		print("  ✗ ", f)
	print("—— 仅大字号（3:1~4.5:1，用于 ≥24px/粗体标题可，正文不可）：%d 处" % large_only.size())
	for f in large_only:
		print("  △ ", f)
	print("CONTRAST_PROBE_DONE fails=%d large_only=%d" % [fails.size(), large_only.size()])
	quit(0)
