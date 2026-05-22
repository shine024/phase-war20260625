extends RefCounted
class_name CardBackgroundUi
## 势力底图叠层（`assets/cards/backgrounds/bg_<id>.png`，5:8）

const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const CompanyDefinitions = preload("res://data/company_definitions.gd")

const BG_NEUTRAL := "neutral"

const FACTION_BG_IDS: Array[String] = [
	"neutral",
	"iron_wall_corp",
	"nova_arms",
	"aether_dynamics",
	"quantum_logistics",
	"helix_recon",
	"void_research",
	"frontier_union",
]


static func normalize_faction_id(faction_id: String) -> String:
	var fid := faction_id.strip_edges().to_lower()
	if fid.is_empty():
		return BG_NEUTRAL
	if fid in FACTION_BG_IDS:
		return fid
	# 公司 id 与底图文件名一致
	if CompanyDefinitions.get_by_id(fid) != null:
		return fid
	return BG_NEUTRAL


static func background_path_for(faction_id: String) -> String:
	var fid := normalize_faction_id(faction_id)
	if fid == BG_NEUTRAL:
		return "res://assets/cards/backgrounds/bg_neutral.png"
	return "res://assets/cards/backgrounds/bg_%s.png" % fid


static func has_background(faction_id: String = BG_NEUTRAL) -> bool:
	return ResourceLoader.exists(background_path_for(faction_id), "Texture2D")


static func load_background(faction_id: String) -> Texture2D:
	return UiAssetLoader.load_tex(background_path_for(faction_id))  # UiAssetLoader 无反向依赖本类


## 缴获卡默认 neutral；进化分支势力待 Blueprint 存档字段扩展后可读。
static func resolve_faction_id_for_card(card: CardResource) -> String:
	if card == null:
		return BG_NEUTRAL
	# 预留：从蓝图进化记录解析势力底
	if BlueprintManager != null and BlueprintManager.has_method("get_blueprint_faction_branch"):
		var branch: String = String(BlueprintManager.get_blueprint_faction_branch(card.card_id))
		if not branch.is_empty():
			return normalize_faction_id(branch)
	return BG_NEUTRAL


static func ensure_overlay(host: Control) -> TextureRect:
	var tr := host.get_node_or_null("CardBackgroundOverlay") as TextureRect
	if tr != null:
		return tr
	tr = TextureRect.new()
	tr.name = "CardBackgroundOverlay"
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tr.grow_vertical = Control.GROW_DIRECTION_BOTH
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.z_index = -1
	host.add_child(tr)
	host.move_child(tr, 0)
	return tr


static func apply_to_host(host: Control, faction_id: String) -> void:
	if host == null:
		return
	var tr := ensure_overlay(host)
	var tex := load_background(faction_id)
	tr.texture = tex
	tr.visible = tex != null


static func clear_overlay(host: Control) -> void:
	if host == null:
		return
	var tr := host.get_node_or_null("CardBackgroundOverlay") as TextureRect
	if tr:
		tr.texture = null
		tr.visible = false
