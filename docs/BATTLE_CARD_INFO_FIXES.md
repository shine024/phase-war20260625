# 战卡信息错误修复方案

## 问题诊断

通过全面检查项目，发现以下可能导致战卡信息错误的根源：

### 1. 显示名称回退链问题
- **文件**: `data/default_cards.gd`
- **问题**: `get_safe_display_name()` 可能返回原始ID而非人类可读名称
- **影响**: UI显示ID而非卡牌名称

### 2. 已弃用字段访问
- **文件**: `scenes/ui/card_info_panel.gd:404-418`
- **问题**: 代码仍在检查已弃用的 `platform_type` 字段
- **影响**: 可能导致信息缺失或错误

### 3. UI显示逻辑空引用风险
- **文件**: `scenes/ui/backpack_card_item.gd`
- **问题**: `DefaultCards.safe_name(c)` 可能在某些情况下返回空值
- **影响**: 卡牌显示为空白或错误

### 4. 缓存构建时序问题
- **文件**: `data/default_cards.gd`
- **问题**: 缓存可能在某些时序下未正确初始化
- **影响**: 无法找到卡牌定义

## 修复计划

### 修复1: 改进 get_safe_display_name() 增加错误日志

在 `data/default_cards.gd` 中，改进 `get_safe_display_name()` 函数：

```gdscript
static func get_safe_display_name(card_id: String) -> String:
    if card_id.is_empty():
        push_warning("[DefaultCards] get_safe_display_name: card_id 为空")
        return ""

    _ensure_card_cache()
    var c: CardResource = _id_lookup_cache.get(card_id) as CardResource

    if c != null and not c.display_name.is_empty() and not _looks_like_id(c.display_name):
        return c.display_name

    # 尝试敌方相位装备（platform 或 weapon）
    var eq_data: Dictionary = EnemyPhaseEquipment.get_war_platform(card_id)
    if not eq_data.is_empty():
        var eq_name: String = String(eq_data.get("name", ""))
        if not eq_name.is_empty():
            return eq_name

    eq_data = EnemyPhaseEquipment.get_war_weapon(card_id)
    if not eq_data.is_empty():
        var eq_name: String = String(eq_data.get("name", ""))
        if not eq_name.is_empty():
            return eq_name

    # 尝试敌方原型表（enemy_* 格式）
    var arch_cfg: Dictionary = EnemyArchetypes.get_config(card_id)
    var arch_name: String = String(arch_cfg.get("display_name", "")) if not arch_cfg.is_empty() else ""
    if not arch_name.is_empty() and not _looks_like_id(arch_name):
        return arch_name

    # 所有回退都失败，记录警告
    push_error("[DefaultCards] 无法找到卡牌名称: %s" % card_id)
    return card_id
```

### 修复2: 移除已弃用字段检查

在 `scenes/ui/card_info_panel.gd` 中，移除对 `platform_type` 的检查：

```gdscript
func _build_card_affix_summary(card: CardResource) -> String:
    if card.card_type != GC.CardType.COMBAT_UNIT:
        return ""

    var tree := Engine.get_main_loop() as SceneTree
    if tree == null or tree.root == null:
        return ""

    var root: Node = tree.root
    var mll: Node = root.get_node_or_null("ManagerLazyLoader")
    if mll and mll.has_method("ensure_loaded"):
        mll.ensure_loaded("affix")

    var bm: Node = root.get_node_or_null("BlueprintManager")
    var am: Node = root.get_node_or_null("AffixManager")

    var era: int = 0
    var gm: Node = root.get_node_or_null("GameManager")
    if gm and "current_level" in gm:
        era = GC.get_era_for_level(int(gm.current_level))

    # 移除旧的 platform_type 检查，改用直接从 card 获取属性
    var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, era)
    if bm and bm.has_method("apply_growth_to_stats"):
        bm.apply_growth_to_stats(stats, card, [])
    if am and am.has_method("apply_affixes_to_stats"):
        am.apply_affixes_to_stats(stats, card, [])

    return _build_affix_summary_lines(stats)
```

### 修复3: 添加 safe_name() 的错误处理

在 `data/default_cards.gd` 中，改进 `safe_name()` 函数：

```gdscript
static func safe_name(card: CardResource) -> String:
    if card == null:
        push_warning("[DefaultCards] safe_name: card 为 null")
        return ""

    if not card.display_name.is_empty() and not _looks_like_id(card.display_name):
        return card.display_name

    var fallback: String = get_safe_display_name(card.card_id)
    if fallback.is_empty():
        push_error("[DefaultCards] safe_name: 无法获取卡牌 %s 的名称" % card.card_id)
        return card.card_id

    return fallback
```

### 修复4: 改进缓存构建日志

在 `data/default_cards.gd` 中，添加调试日志：

```gdscript
static func _ensure_card_cache() -> void:
    if not _all_cards_cache.is_empty():
        return
    if _cache_building:
        push_warning("[DefaultCards] 缓存正在构建中，防止重入")
        return

    _cache_building = true
    _all_cards_cache = create_all()
    for c in _all_cards_cache:
        if c is CardResource:
            _id_lookup_cache[c.card_id] = c
        else:
            push_error("[DefaultCards] create_all() 返回了非 CardResource 对象")
    _cache_building = false

    print("[DefaultCards] 缓存构建完成，共 %d 张卡牌" % _all_cards_cache.size())
```

## 测试验证

需要验证以下场景：

1. **新游戏启动**：所有默认卡牌名称正确显示
2. **存档加载**：迁移后的存档卡牌名称正确显示
3. **敌方卡牌**：敌方掉落的卡牌名称正确显示
4. **能量卡**：能量卡名称正确显示
5. **法则卡**：法则卡名称正确显示
6. **边缘情况**：
   - 空card_id
   - 无效的card_id
   - 缓存未初始化

## 执行优先级

1. **高优先级**: 修复1 和 修复3（影响显示名称）
2. **中优先级**: 修复2（移除已弃用字段）
3. **低优先级**: 修复4（改进日志）
