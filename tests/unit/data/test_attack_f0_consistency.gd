extends GdUnitTestSuite
## attack_f0 攻击姿态归一回归锁（v6.15b；2026-09-20 自 tests/_tmp_attack_f0_audit.gd 正名入册）
## 契约：AttackPoseAnim 换 texture 零补偿——`attack_f0.png` 的内容高比必须=卡图内容高比
## （±6%）且内容矩形中心 x 对齐（±4%），否则单位每次开火大小跳/横向跳。
## 硬指标越带即 FAIL；rw 宽比与 alpha 质心差是软记录（攻击姿态动势属合法形变，不判败）。
## 新做攻击姿态资产：先跑 `python tools/normalize_attack_f0.py` 归一（映射导出
## `tests/attack_f0_map_export.gd`），再过本锁入库。

const MANIFEST := preload("res://data/enemy_unit_manifest.gd")

func _content_metrics(img: Image) -> Dictionary:
	var rect := img.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return {}
	var sum_w: float = 0.0
	var sum_wx: float = 0.0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if img.get_pixel(x, y).a > 0.25:
				sum_w += 1.0
				sum_wx += float(x)
	var cx: float = sum_wx / maxf(sum_w, 1.0) / float(img.get_width())
	return {
		"rw": float(rect.size.x) / float(img.get_width()),
		"rh": float(rect.size.y) / float(img.get_height()),
		"cx": cx,
		"rcx": (float(rect.position.x) + float(rect.size.x) * 0.5) / float(img.get_width()),
	}

func test_attack_f0_matches_card_art_metrics() -> void:
	var bad: Array = []
	var checked := 0
	for row in MANIFEST.get_entries():
		if row is not Dictionary:
			continue
		var aid := String(row.get("archetype_id", ""))
		if aid.is_empty():
			continue
		var card_p: String = MANIFEST.get_unit_icon_path_for_archetype(aid, false)
		var atk_p := "res://assets/effects/unit_anims/%s/attack_f0.png" % aid
		if card_p.is_empty() or not ResourceLoader.exists(card_p):
			continue
		if not ResourceLoader.exists(atk_p):
			continue
		var card_tex: Texture2D = load(card_p)
		var atk_tex: Texture2D = load(atk_p)
		if card_tex == null or atk_tex == null:
			continue
		var card_img: Image = card_tex.get_image()
		var atk_img: Image = atk_tex.get_image()
		if card_img == null or atk_img == null:
			continue
		card_img.decompress()
		atk_img.decompress()
		var mc := _content_metrics(card_img)
		var ma := _content_metrics(atk_img)
		if mc.is_empty() or ma.is_empty():
			continue
		checked += 1
		var rh: float = ma["rh"] / maxf(mc["rh"], 0.0001)
		var d_rcx: float = ma["rcx"] - mc["rcx"]
		if rh < 0.94 or rh > 1.06 or absf(d_rcx) > 0.04:
			bad.append("%s rh=%.3f dRectCx=%+.3f" % [aid, rh, d_rcx])
	print("attack_f0 lock: checked=%d 越带=%d" % [checked, bad.size()])
	assert_int(checked).override_failure_message("attack_f0 锁零样本：manifest/资产链断了？").is_greater(0)
	assert_array(bad).override_failure_message(
		"attack_f0 与卡图占比/位置越带 %d 项：%s（重跑 python tools/normalize_attack_f0.py 归一后入库）"
		% [bad.size(), str(bad)]).is_empty()
