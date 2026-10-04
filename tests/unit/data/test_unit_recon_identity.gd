extends GdUnitTestSuite
## v6.38.1 回归锁：侦察身份判定（用户实机主诉"骑兵斥候/暴风 兵种标记错位"批）。
##
## 三条不变式：
## ① 侦察身份 = UnitRoles.RECON_PREFIXES 前缀表（潜入开局/定向爆破/搭档协同角色/
##    侦察改造安装门共用），暴风突击队等普通步兵不在表内——面板"步兵/侦察单位"
##    复合文案已随本批退役（real_world_unit_labels.gd）。
## ② platform_cold_scout（冷战侦察平台）名字即侦察，必须命中（本批补漏）。
## ③ 缴获/敌方前缀归一：captured_/foe_ 实例卡剥前缀后查表——缴获的骑兵斥候
##    不得因前缀丢失侦察身份（unit_stats_table._is_recon_card 与
##    recon_mods._matches_card 同口径）。

const UnitRolesRef := preload("res://data/unit_roles.gd")
const UnitStatsTableRef := preload("res://resources/unit_stats_table.gd")
const ReconModsRef := preload("res://data/modification_modules/recon_mods.gd")


func test_native_recon_cards_resolve_recon_role() -> void:
	assert_int(UnitRolesRef.resolve_role("ww1_inf_cavalry", 0, 0)).is_equal(UnitRolesRef.ROLE_RECON)
	assert_int(UnitRolesRef.resolve_role("cold_spetsnaz", 0, 0)).is_equal(UnitRolesRef.ROLE_RECON)
	assert_int(UnitRolesRef.resolve_role("mod_ranger", 0, 0)).is_equal(UnitRolesRef.ROLE_RECON)
	assert_int(UnitRolesRef.resolve_role("fut_spectre", 0, 0)).is_equal(UnitRolesRef.ROLE_RECON)
	assert_int(UnitRolesRef.resolve_role("fut_inf_scout_mech", 0, 0)).is_equal(UnitRolesRef.ROLE_RECON)


func test_scout_platform_is_recon_after_v6381() -> void:
	# 冷战侦察平台：名字即侦察，v6.38.1 前漏标（拿步兵巷战掩蔽、装不上侦察改造）
	assert_int(UnitRolesRef.resolve_role("platform_cold_scout", 0, 0)).is_equal(UnitRolesRef.ROLE_RECON)


func test_plain_infantry_stays_infantry() -> void:
	# 暴风突击队/毛瑟班 = 普通步兵，不得冒充侦察
	assert_int(UnitRolesRef.resolve_role("ww1_storm", 0, 0)).is_equal(UnitRolesRef.ROLE_INFANTRY)
	assert_int(UnitRolesRef.resolve_role("ww1_mauser", 0, 0)).is_equal(UnitRolesRef.ROLE_INFANTRY)


func test_captured_and_foe_prefixes_keep_recon_identity() -> void:
	# 缴获/敌方镜像实例卡：剥前缀后判定，身份不丢
	assert_bool(UnitStatsTableRef._is_recon_card("captured_ww1_inf_cavalry")).is_true()
	assert_bool(UnitStatsTableRef._is_recon_card("captured_foe_ww1_inf_cavalry")).is_true()
	assert_bool(UnitStatsTableRef._is_recon_card("foe_platform_cold_scout")).is_true()
	assert_bool(UnitStatsTableRef._is_recon_card("captured_ww1_storm")).is_false()
	assert_int(UnitRolesRef.resolve_role("captured_ww1_inf_cavalry", 0, 0)).is_equal(UnitRolesRef.ROLE_RECON)
	# 缴获工兵同口径（支援主类 + 工程前缀）
	assert_int(UnitRolesRef.resolve_role("captured_ww1_sup_engineer", 2, 2)).is_equal(UnitRolesRef.ROLE_ENGINEER)


func test_captured_recon_card_accepts_recon_mods() -> void:
	# 侦察改造安装门：缴获版同样可装
	assert_bool(ReconModsRef._matches_card("captured_ww1_inf_cavalry")).is_true()
	assert_bool(ReconModsRef._matches_card("ww1_inf_cavalry")).is_true()
	assert_bool(ReconModsRef._matches_card("platform_cold_scout")).is_true()
	assert_bool(ReconModsRef._matches_card("captured_ww1_storm")).is_false()
