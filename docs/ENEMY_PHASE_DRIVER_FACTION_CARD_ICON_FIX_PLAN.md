# 敌方相位师势力前缀卡图引用错误修复计划

**日期**：2026-08-04
**分支**：`feat/v6.14-system-integration`
**状态**：✅ 已实施（代码改动完成，待用户实机验证）
**范围**：一战时代 4 个相位师（master_001~004，势力相关）的产兵卡图引用

---

## 一、问题现象

用户反馈：**今天运行游戏时，发现敌方相位师部署的战斗卡（带势力前缀名的卡）引用卡图错误**。

具体表现：
- 敌方相位师是**势力相关**的（钢铁/烈焰/雷霆/虚空 4 个一战势力相位师）
- 产兵带**势力前缀名**（如 `steel_titan_basic`、`flame_raider_basic`）
- 但**卡图引用错误**——和正常敌方卡（如 `ww1_arm_rolls_e`）的图不一致，甚至不同势力的同类平台显示**完全相同的图**

用户预期（原话）：
> "正常来说，如果敌方相位师是势力相关的，敌方卡引用的还是敌方卡的图，只是名称前面加个前缀。"

---

## 二、根因分析

### 2.1 受影响范围

**仅一战时代 4 个相位师**（`master_001~004`），它们的 `platforms` 字段存**势力前缀平台 ID**：

| 相位师 | 势力 | platforms（legacy 平台 ID） |
|--------|------|-----------|
| master_001 | steel（钢铁） | `steel_fortress_basic`, `steel_titan_basic` |
| master_002 | flame（烈焰） | `flame_raider_basic`, `flame_siege_basic` |
| master_003 | thunder（雷霆） | `thunter_striker_basic`, `thunter_sniper_basic`（注意源数据 `thunter` 拼写） |
| master_004 | void（虚空） | `void_stealth_basic`, `void_mage_basic` |

这 8 个 base ID（含 basic/advanced/expert 三档共约 20 条）**只在 `EnemyEquipmentArmorModules.LEGACY_WAR_PLATFORMS`（数值定义）中存在**，**不在 `EnemyArchetypes` 配置里**（卡图/视觉数据）。

其他时代相位师（二战/冷战/现代/未来）的 `platforms` 字段存**真实 archetype ID**（如 `ww2_arm_panther_e`、`cold_arm_t72_e`），走"直引模式"，卡图正常。

### 2.2 根因链（5 个代码位置共同作用）

**位置 1：`enemy_phase_field_driver.gd:508-519`（产兵入口分流）**
```gdscript
var arch_cfg := EnemyArchetypes.get_config(pid_str)
if not arch_cfg.is_empty():
    # 直引 archetype 模式  ← 其他时代走这里（卡图正常）
    direct_archetype_ids[pid_str] = pid_str
else:
    var pdata := EnemyPhaseEquipment.get_war_platform(pid_str)
    if not pdata.is_empty():
        # 旧平台卡模式  ← 一战 8 个 ID 走这里（卡图错误根因）
        legacy_platform_ids.append(pid_str)
```
一战 8 个 ID 在 `EnemyArchetypes` 查不到 cfg → 走"旧平台卡回退"路径。

**位置 2：`enemy_phase_field_driver.gd:686-692`（视觉 archetype 派生）**
```gdscript
var visual_archetype_id: String = ""
if not direct_archetype_id.is_empty():
    visual_archetype_id = direct_archetype_id
else:
    visual_archetype_id = _pick_visual_archetype_for_platform(era, platform_type_str)
```
旧平台卡模式下 `visual_archetype_id` 由 `_pick_visual_archetype_for_platform(era=0, platform_type)` **粗粒度派生**。

**位置 3：`enemy_phase_field_driver.gd:1113-1141`（`_pick_visual_archetype_for_platform`）**
```gdscript
func _pick_visual_archetype_for_platform(era: int, platform_type: String) -> String:
    var target_tags: Array = _PLATFORM_TYPE_TO_TAGS.get(platform_type, [])
    # 按 tag 匹配该时代 archetype，取 HP 最高的
    return String(candidates[0])
```
- `titan` 类型 → 匹配 `["vehicle","tank","armored"]` → 一战时代 HP 最高载具 → 同一张载具图
- `raider` 类型 → 匹配 `["vehicle","fast"]` → 同一张载具图
- `striker`/`sniper`/`stealth`/`mage` → 匹配步兵类 → 同一张步兵图

**问题**：所有 `titan` 类平台（钢铁/烈焰）都映射到**同一张**载具图，所有步兵类平台（雷霆/虚空）都映射到**同一张**步兵图。**丢失势力/平台身份**——用户看到的"不同势力同类平台用同一张图"。

**位置 4：`enemy_phase_field_driver.gd:682`（platform_card_id 赋值）**
```gdscript
stats.platform_card_id = platform_id  # = "steel_titan_basic"（legacy ID）
```
**关键不一致**：`stats.platform_card_id` 是 legacy 平台 ID（`steel_titan_basic`），但 `visual_archetype_id` 是派生 archetype（如 `ww1_arm_rolls_e`）。两者语义不同。

**位置 5：`construct_unit.gd:473-500`（格子战敌方呈现 `apply_card_grid_enemy_presentation`）**
```gdscript
var card_res: CardResource = DefaultCards.get_card_by_id(stats.platform_card_id)
# ↑ "steel_titan_basic" 不在 DefaultCards → 返回 null
if card_res == null and not stats.platform_card_id.is_empty():
    card_res = EnemyPhaseEquipment.get_equipment_blueprint(stats.platform_card_id)
    # ↑ 返回 _card_resource_from_war_platform（用平台数值 cfg，不是真实兵种卡）
# ...
var arch_for_icon: String = _visual_archetype_id  # = 派生 archetype（visual）
# ↑ 卡图用 visual_archetype 解析（粗粒度但路径正确）
# 但 card_res 仍是 legacy 平台蓝图卡（错误）
```

**4 个连锁错误**：
1. **卡图（texture）**：用 visual_archetype（派生）解析——粗粒度，同类平台用同一张图
2. **卡资源（card_res）**：用 platform_card_id（legacy）合成平台蓝图卡——**不是真实兵种卡**
3. **缩放（scale）**：`CardFootAnchors.get_visual_scale(card_res)` 查 `steel_titan_basic` 查不到 → **缩放错误**（用默认值，而真实兵种如 ww1 载具应有特定缩放）
4. **势力底/名称条**：`apply_battle_card_chrome` / `sync_name_strip` 用错误 card_res → 显示平台蓝图名（"马克V型坦克平台"）而非兵种名（"劳斯莱斯装甲车"）

### 2.3 为什么"今天"才暴露

近期改动（v7.x 卡牌实例化重构、v6.14 全系统贯通）引入了 `setup_with_enemy_visual` 注入机制和 `apply_card_grid_enemy_presentation` 路径。旧路径下 `card_res` 用 `synthetic_card_for_archetype(visual_archetype_id)` 生成（至少 card_id 正确），新路径下改成先查 `DefaultCards.get_card_by_id(platform_card_id)` 再回退——platform_card_id 是 legacy ID 导致合成出错误的平台蓝图卡。用户今天才在实机游戏中观察这些单位，发现卡图/缩放/名称不一致。

---

## 三、修复方案

### 3.1 方案对比

| 方案 | 描述 | 优点 | 缺点 |
|------|------|------|------|
| **A 精确映射表（推荐）** | 保留 legacy 平台 ID，新增 ID→真实 ww1 archetype 的精确映射表，卡图/数值/缩放都用映射目标；名称显示为「势力前缀·真实兵种名」 | 符合用户预期（引用敌方卡图+名称加前缀）；改动局部；保留势力差异化 | 需维护映射表 |
| B 改用直引 archetype | 把一战 4 相位师 platforms 改成真实 ww1 archetype ID | 最干净，彻底绕过 legacy | 失去势力前缀身份（用户明确想要前缀）；改数据文件 |
| C 只修 card_res 不一致 | 让格子战呈现统一用 visual_archetype 解析 card_res | 最小改动 | 不解决"同类平台用同一张图"粗粒度问题，不满足用户诉求 |

**推荐方案 A**：精确映射表。完全符合用户原话"引用敌方卡的图，只是名称前面加个前缀"。

### 3.2 方案 A 详细设计

#### 3.2.1 新增数据：势力前缀平台→真实 archetype 精确映射表

**文件**：合并进 `enemy_phase_field_driver.gd` 的 const 段（约 L130-160 附近，与 `_PLATFORM_TYPE_TO_TAGS` 同区）

```gdscript
## 势力前缀平台 ID → 真实 ww1 archetype 精确映射（卡图/数值/缩放统一走映射目标）
## 解决：一战 4 相位师的 platforms 存 legacy 平台 ID（如 steel_titan_basic），
## 不在 EnemyArchetypes 配置里，导致卡图引用错误（粗粒度派生 + card_res 不一致）。
## 映射后：卡图/数值/缩放用真实 archetype，名称显示为「势力前缀·真实兵种名」。
const LEGACY_PLATFORM_TO_ARCHETYPE: Dictionary = {
	# 钢铁势力（steel）—— 厚甲重武器
	"steel_fortress_basic":    {"archetype": "ww1_fort_artillery", "prefix": "钢铁"},
	"steel_titan_basic":       {"archetype": "ww1_arm_rolls_e",    "prefix": "钢铁"},
	"steel_fortress_advanced": {"archetype": "ww1_fort_artillery", "prefix": "钢铁"},
	"steel_titan_advanced":    {"archetype": "ww1_arm_rolls_e",    "prefix": "钢铁"},
	"steel_fortress_expert":   {"archetype": "ww1_fort_artillery", "prefix": "钢铁"},
	"steel_titan_expert":      {"archetype": "ww1_arm_rolls_e",    "prefix": "钢铁"},
	# 烈焰势力（flame）—— 快攻突击
	"flame_raider_basic":   {"archetype": "ww1_arm_rolls_mk2", "prefix": "烈焰"},
	"flame_siege_basic":    {"archetype": "ww1_arty_mortar",   "prefix": "烈焰"},
	"flame_raider_advanced": {"archetype": "ww1_arm_rolls_mk2", "prefix": "烈焰"},
	"flame_siege_advanced":  {"archetype": "ww1_arty_mortar",   "prefix": "烈焰"},
	"flame_raider_expert":   {"archetype": "ww1_arm_rolls_mk2", "prefix": "烈焰"},
	"flame_siege_expert":    {"archetype": "ww1_arty_mortar",   "prefix": "烈焰"},
	# 雷霆势力（thunder）—— 步兵精锐（注意源数据是 thunter 拼写）
	"thunter_striker_basic":    {"archetype": "ww1_inf_storm_e", "prefix": "雷霆"},
	"thunter_sniper_basic":     {"archetype": "ww1_inf_rifle",   "prefix": "雷霆"},
	"thunter_striker_advanced": {"archetype": "ww1_inf_storm_e", "prefix": "雷霆"},
	"thunter_sniper_advanced":  {"archetype": "ww1_inf_rifle",   "prefix": "雷霆"},
	"thunter_striker_expert":   {"archetype": "ww1_inf_storm_e", "prefix": "雷霆"},
	# 虚空势力（void）—— 隐秘特种
	"void_stealth_basic":    {"archetype": "ww1_inf_mp18",   "prefix": "虚空"},
	"void_mage_basic":       {"archetype": "ww1_sup_mg_nest", "prefix": "虚空"},
	"void_stealth_advanced": {"archetype": "ww1_inf_mp18",   "prefix": "虚空"},
	"void_mage_advanced":    {"archetype": "ww1_sup_mg_nest", "prefix": "虚空"},
	"void_stealth_expert":   {"archetype": "ww1_inf_mp18",   "prefix": "虚空"},
	"void_mage_expert":      {"archetype": "ww1_sup_mg_nest", "prefix": "虚空"},
}
```

**映射选择依据 + 已验证卡图存在（2026-08-04）**：

| 势力 | 平台类型 | 映射目标 archetype | 卡图文件 | 验证状态 |
|------|---------|-------------------|---------|---------|
| 钢铁 | fortress（要塞） | `ww1_fort_artillery` | `enemy/vis_enemy_073.png`（FORT 段 idx 1） | ✅ 存在 |
| 钢铁 | titan（坦克） | `ww1_arm_rolls_e` | `enemy/vis_enemy_041.png`（FIXED 段 idx 5） | ✅ 存在 |
| 烈焰 | raider（突击车） | `ww1_arm_rolls_mk2` | `enemy/ww1_arm_rolls_mk2.png`（POOL 段直接 id） | ✅ 存在 |
| 烈焰 | siege（攻城） | `ww1_arty_mortar` | `enemy/vis_enemy_039.png`（FIXED 段 idx 3） | ✅ 存在 |
| 雷霆 | striker（突击兵） | `ww1_inf_storm_e` | `enemy/vis_enemy_040.png`（FIXED 段 idx 4） | ✅ 存在 |
| 雷霆 | sniper（狙击） | `ww1_inf_rifle` | `enemy/vis_enemy_037.png`（FIXED 段 idx 1） | ✅ 存在 |
| 虚空 | stealth（潜行） | `ww1_inf_mp18` | `enemy/vis_enemy_036.png`（FIXED 段 idx 0） | ✅ 存在 |
| 虚空 | mage（法师） | `ww1_sup_mg_nest` | `enemy/vis_enemy_038.png`（FIXED 段 idx 2） | ✅ 存在 |

> ✅ **已用 `ls` 实测**：全部 8 个目标 archetype 的卡图 PNG 文件均存在。
> ✅ **archetype_config 可解析**：`ww1_fort_artillery`（FORT 段）/`ww1_arm_rolls_mk2`（POOL 段）虽不在 `enemy_archetypes.json`，但经 `EnemyUnitManifest._make_fort_row`/`_make_pool_row` 生成 `archetype_config`，由 `EnemyArchetypes._ensure_manifest_merged()` 合并，`get_config()` 可正常返回。

#### 3.2.2 改动 1：产兵入口读映射表（`enemy_phase_field_driver.gd:508-519`）

```gdscript
# 原逻辑：
var arch_cfg := EnemyArchetypes.get_config(pid_str)
if not arch_cfg.is_empty():
    direct_archetype_ids[pid_str] = pid_str
else:
    # legacy 回退...

# 改为：先查映射表
var mapping: Dictionary = LEGACY_PLATFORM_TO_ARCHETYPE.get(pid_str, {})
if not mapping.is_empty():
    # 势力前缀平台：映射到真实 archetype（走直引模式）
    var mapped_arch: String = String(mapping.get("archetype", ""))
    valid_platforms.append(pid_str)
    direct_archetype_ids[pid_str] = mapped_arch  # ← 映射到真实 archetype
    _platform_faction_prefix[pid_str] = String(mapping.get("prefix", ""))  # 记录势力前缀
elif not arch_cfg.is_empty():
    direct_archetype_ids[pid_str] = pid_str
else:
    # legacy 回退（无映射的兜底）...
```

**新增字段**（类成员变量区，约 L184 `_visual_archetype_id` 附近）：
```gdscript
var _platform_faction_prefix: Dictionary = {}  # pid → 势力前缀（如 "钢铁"），供格子战名称显示
```

**效果**：映射表里的 legacy ID 走"直引模式"，`direct_archetype_id` = 真实 archetype（如 `ww1_arm_rolls_e`），后续卡图/数值/缩放全部用真实 archetype，彻底绕开粗粒度派生。

#### 3.2.3 改动 2：记录势力前缀到 meta（`enemy_phase_field_driver.gd:707-712`）

```gdscript
unit.set_meta("archetype_id", effective_archetype)
unit.set_meta("spawn_platform_id", platform_id)
# 新增：记录势力前缀（供格子战名称显示）
if _platform_faction_prefix.has(platform_id):
    unit.set_meta("faction_prefix", String(_platform_faction_prefix[platform_id]))
```

#### 3.2.4 改动 3：格子战名称加前缀（`card_grid_unit_visuals.gd` 的 `sync_name_strip`）

```gdscript
# 在 sync_name_strip 里，显示名前加势力前缀
static func sync_name_strip(host: Node2D, unit_spr: Sprite2D, card: CardResource, face_right: bool) -> void:
    # ... 原逻辑取 display_name ...
    var display_name: String = String(card.display_name) if card != null else ""
    # 新增：敌方产兵且带 faction_prefix meta 时，名称加前缀
    if unit != null and not display_name.is_empty():
        var prefix: String = String(unit.get_meta("faction_prefix", ""))
        if not prefix.is_empty():
            display_name = "%s·%s" % [prefix, display_name]
    # ... 设置到 Label ...
```

> ⚠️ 实施时需确认 `sync_name_strip` 当前签名是否已带 `unit` 参数。若未带，需补一个可选参数（参考 `apply_battle_unit_presentation` 的 unit 参数模式）。

#### 3.2.5 改动 4（可选）：情报面板名称同步（`card_info_panel.gd`）

`_show_enemy_construct_unit`（点击敌方产兵单位）显示名称时也加势力前缀：
```gdscript
var prefix: String = String(unit.get_meta("faction_prefix", ""))
if not prefix.is_empty():
    title_text = "%s·%s" % [prefix, base_name]
```

### 3.3 不改的地方（向后兼容）

1. **其他时代相位师**（二战/冷战/现代/未来）：platforms 已是真实 archetype ID，走直引模式，零变化。
2. **legacy 平台卡数据**（`EnemyEquipmentArmorModules.LEGACY_WAR_PLATFORMS`）：保留原数值定义，映射表只用于视觉/卡图派生。平台 stats 仍可用于其他用途（如 `_apply_enemy_phase_instrument_bonus` 的 tier 判定、套路补兵匹配）。
3. **`_pick_visual_archetype_for_platform`**：保留作为无映射时的兜底（万一未来新增 legacy 平台且未加映射）。
4. **存档/序列化**：`spawn_platform_id` meta 仍存 legacy ID（兼容套路补兵的精准匹配），不影响存档。
5. **势力底 tint**（`enemy_phase_field_driver.gd:291-300` 的 `enemy_faction` → 颜色映射）：不动，基地底座色继续按势力区分。

---

## 四、实施步骤与验证记录

### 阶段 1：验证映射目标 archetype 卡图存在 ✅ 已完成
- ✅ 8 个目标 archetype 的卡图 PNG 全部存在（`ls` 实测：vis_enemy_036/037/038/039/040/041/073 + ww1_arm_rolls_mk2.png）
- ✅ archetype_config 经 manifest 合并可正常解析（`ww1_fort_artillery`/`ww1_arm_rolls_mk2` 经 FORT/POOL 段注入）
- ✅ captured card 缓存可命中（`captured_ww1_arm_rolls_e` 等在 `data/captured_card_stats.gd` 存在）

### 阶段 2：实施代码改动 ✅ 已完成（4 文件 5 处改动）
1. ✅ `enemy_phase_field_driver.gd`：新增 `LEGACY_PLATFORM_TO_ARCHETYPE` const（24 条映射）+ `_platform_faction_prefix` 成员变量
2. ✅ `enemy_phase_field_driver.gd`：产兵入口读映射表（命中→走直引模式 + 记录前缀）
3. ✅ `enemy_phase_field_driver.gd`：记录 `faction_prefix` meta
4. ✅ `card_grid_unit_visuals.gd`：`sync_name_strip` 加 `unit` 参数 + 读取 `faction_prefix` 加前缀
5. ✅ `card_info_panel.gd`：`_show_enemy_construct_unit` 名称加势力前缀
6. ✅ `construct_unit.gd`（计划外发现的额外 bug）：`apply_card_grid_enemy_presentation` 的 card_res 改用真实 archetype 反查

### 阶段 3：验证 ✅ 已完成
1. ✅ **gdparse 语法检查**：4 个改动文件全部 `gdparse OK`
   ```
   OK: scenes/units/enemy_phase_field_driver.gd
   OK: scripts/card_grid_unit_visuals.gd
   OK: scenes/ui/card_info_panel.gd
   OK: scenes/units/construct_unit.gd
   ```
2. ✅ **映射表完整性**：24 条映射 key 与 `LEGACY_WAR_PLATFORMS` 24 个 key 完全一致（含 `thunter` 拼写 + 补全 `thunter_sniper_expert`）
3. ✅ **映射目标 archetype 可解析**：8 个 unique archetype 全部在 `EnemyUnitManifest` 有 visual_id 映射（卡图可解析）
4. ✅ **faction_prefix meta 链路**：写入（enemy_phase_field_driver L768-769）→ 读取（card_grid_unit_visuals L184 + card_info_panel L1709）完整
5. ⚠️ **Godot `--check-only` 全项目兜底**：因项目体量（42 autoload + 133 卡）5 分钟超时（项目既有现象，AGENTS.md 已记录），改用 gdparse 单文件 + Grep 链路核对替代
6. 🔲 **实机验证**（待用户）：进第 1~4 关（一战相位师），观察 4 个势力产兵的卡图/名称/缩放

### 实机验证预期
进第 1~4 关（一战相位师），观察 4 个势力产兵：
- 钢铁势力产兵显示 `ww1_arm_rolls_e`/`ww1_fort_artillery` 卡图 + "钢铁·劳斯莱斯装甲车"/"钢铁·要塞炮台"
- 烈焰势力产兵显示 `ww1_arm_rolls_mk2`/`ww1_arty_mortar` 卡图 + "烈焰·劳斯莱斯 Mk.II 装甲车"/"烈焰·迫击炮"
- 雷霆势力产兵显示 `ww1_inf_storm_e`/`ww1_inf_rifle` 卡图 + "雷霆·暴风突击队"/"雷霆·步枪兵"
- 虚空势力产兵显示 `ww1_inf_mp18`/`ww1_sup_mg_nest` 卡图 + "虚空·MP18 突击队"/"虚空·机枪阵地"
- 缩放正确（载具/步兵各自的 VISUAL_SCALE）
- 势力底色 tint 不受影响（已有逻辑继续生效）
- 不同势力同类平台**不再显示同一张图**

---

## 五、风险评估

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 映射目标 archetype 无卡图 | 已排除 | — | 阶段 1 已实测 8 个 PNG 全存在 |
| 套路补兵匹配失效（`spawn_platform_id` 仍是 legacy ID） | 极低 | 同类平台间补兵可能跨势力 | 保留 `spawn_platform_id = platform_id`（legacy），补兵按原逻辑匹配，不受影响 |
| 势力前缀影响存档/序列化 | 无 | — | meta 不进存档，`spawn_platform_id` 不变 |
| `sync_name_strip` 签名不带 unit 参数 | 中 | 需补参数 | 实施时先 Read 确认签名，必要时补可选参数（参考 `apply_battle_unit_presentation` 的 unit 参数模式） |
| 用户期望的"前缀"样式不同（中文名 vs 英文 faction_id） | 中 | 显示不符预期 | 前缀用中文势力名（钢铁/烈焰/雷霆/虚空），与用户描述一致；实施前可确认 |

---

## 六、关键文件清单（已实施）

| 文件 | 改动类型 | 改动内容 | 行数 |
|------|---------|---------|------|
| `scenes/units/enemy_phase_field_driver.gd` | 改 | 新增 `LEGACY_PLATFORM_TO_ARCHETYPE` const（24 条映射）+ `_platform_faction_prefix` 成员变量 + 产兵入口读映射（走直引模式）+ 记录 `faction_prefix` meta | +57 |
| `scenes/units/construct_unit.gd` | 改 | `apply_card_grid_enemy_presentation`：敌方产兵（`_visual_archetype_id` 非空）时优先从 `arch_for_icon` 反查真实兵种卡（resolve_card_for_archetype → captured card），避免用错误的平台蓝图卡导致缩放/势力底错位 | +24 |
| `scripts/card_grid_unit_visuals.gd` | 改 | `sync_name_strip` 新增 `unit` 可选参数 + 读取 `faction_prefix` meta 加势力前缀；`apply_battle_unit_presentation` 调用处传 `unit` | +7 |
| `scenes/ui/card_info_panel.gd` | 改 | `_show_enemy_construct_unit` 读取 `faction_prefix` meta，name_label/platform_name 加势力前缀 | +9 |

**实施时发现的额外 bug**（计划外，已在 construct_unit.gd 一并修复）：
原 `apply_card_grid_enemy_presentation` 的 `card_res` 解析（L473-475）在 `platform_card_id` 是 legacy ID 时会命中 `get_equipment_blueprint` 返回**平台蓝图卡**（card_id=`steel_titan_basic`），导致后续 `CardFootAnchors.get_visual_scale(card_res)` 查不到缩放 + `apply_battle_card_chrome` 用错 card_res。即使卡图（tex）从 visual_archetype 正确解析，card_res 仍是错的 → 缩放/势力底/名称全部错位。修复：`_visual_archetype_id` 非空时优先 `resolve_card_for_archetype(arch_for_icon)` 拿真实 captured 兵种卡（如 `captured_ww1_arm_rolls_e`）。

**不改的文件**：
- `data/enemy_phase_masters_ww1.gd`（platforms 字段保留 legacy ID，不改数据）
- `data/enemy_equipment_armor_modules.gd`（legacy 平台数值保留）
- `data/enemy_archetypes.gd` / `data/enemy_unit_manifest.gd`（卡图配置不改）

---

## 七、与现有架构的兼容性

1. **v7.x 卡牌实例化隔离**：本次改动**不涉及玩家卡/养成**，只改敌方相位师产兵的视觉派生，与 InstanceRegistry/养成铁律零交集。
2. **v6.8 加成收敛**：势力加成（我方停用、敌方保留）不受影响——映射表只影响卡图/名称，不碰数值加成链。
3. **v6.14 相位师装备派生**：`get_enriched_equipment` 的 runes/spawn_sequence 派生不受影响——映射表在产兵入口生效，晚于装备派生。
4. **AGENTS.md 卡图单一真理源**：`CardFootAnchors` 缩放查询现在能正确命中真实 archetype（如 `ww1_arm_rolls_e`），不再因查 `steel_titan_basic` 失败而用默认缩放。
5. **v9.0 套路补兵**：`spawn_platform_id` meta 仍存 legacy ID，`_pick_reactive_platform`/补兵匹配逻辑零变化。

---

## 八、实施总结

### 已完成（2026-08-04）
按推荐方案 A（精确映射表）实施全部改动，4 文件 5 处改动（+1 处计划外 bug 修复）：

| 文件 | 改动 |
|------|------|
| `scenes/units/enemy_phase_field_driver.gd` | +`LEGACY_PLATFORM_TO_ARCHETYPE` const（24 条）+ `_platform_faction_prefix` 成员 + 产兵入口读映射 + 记录 `faction_prefix` meta |
| `scenes/units/construct_unit.gd` | `apply_card_grid_enemy_presentation`：`_visual_archetype_id` 非空时优先 `resolve_card_for_archetype` 拿真实 captured 兵种卡（修复缩放/势力底错位） |
| `scripts/card_grid_unit_visuals.gd` | `sync_name_strip` 加 `unit` 参数 + 读取 `faction_prefix` 加势力前缀 |
| `scenes/ui/card_info_panel.gd` | `_show_enemy_construct_unit` 名称加势力前缀 |

### 验证结果
- ✅ gdparse 语法检查 4/4 通过
- ✅ 映射表 24 条 key 与 LEGACY_WAR_PLATFORMS 24 个 key 完全一致
- ✅ 8 个映射目标 archetype 卡图全部存在
- ✅ faction_prefix meta 写入/读取链路完整
- ⚠️ Godot --check-only 全项目兜底因项目体量超时（既有现象），改用 gdparse + Grep 替代
- 🔲 待用户实机验证一战 4 关产兵卡图/名称/缩放

### 向后兼容
- 其他时代相位师零变化（已是真实 archetype ID，走原直引模式）
- legacy 平台数值数据保留（`spawn_platform_id` meta 仍存 legacy ID，套路补兵匹配不受影响）
- 存档/势力底 tint 不受影响
- v7.x 卡牌实例化隔离零交集（只改敌方产兵视觉）
