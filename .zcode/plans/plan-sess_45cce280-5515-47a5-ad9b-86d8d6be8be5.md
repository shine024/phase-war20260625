## 创建两个缺失的 UI 辅助脚本

创建 2 个新文件以修复 6 个 "Could not find script" 错误，恢复 card_enhancement_panel 和 modification_panel 的加载。

### 文件 1: `scripts/ui/panel_styles.gd`（新建）
- `extends RefCounted`, `class_name PanelStyles`（匹配 scripts/ui 现有模式如 FormatUtil）
- 全静态工厂方法，返回 `StyleBoxFlat`：
  - `make_panel_style(bg, border, border_w, corner_r, shadow_color=null, shadow_size=0)` — 4参数和6参数共用一个签名（用默认值 null/0 统一），构建带边框/圆角/可选阴影的 StyleBoxFlat
  - `make_card_style(bg, border, border_w, corner_r, padding)` — 5参数，带内边距的卡片样式
  - `make_chip_style(color)` — 标签 chip（半透明色填充 + 同色边框）
  - `make_stat_cell_style(color)` — 属性格（深底 + 顶/底 accent 色条强调）
  - `make_roster_item_style(selected, accent) → Dictionary` — 返回 `{bg, border, ...}` 字典（消费方未读键，但保留合理内容以符签名语义）
- 内部复用 `_make_flat(bg, border, border_w, corner_r, content_margin)` 私有辅助，避免重复样板

### 文件 2: `scripts/ui/geo_shapes.gd`（新建）
- `extends RefCounted`, `class_name GeoShapes`（被 const preload，内部 inner class 各自继承 Control）
- **inner class `HexagonSlot extends Control`** — 六边形词条槽（强化面板 5 格蜂巢）：
  - `enum State { LOCKED, EMPTY, FILLED }`
  - `var accent_color: Color`（消费方在 set_data 前赋值）
  - `func set_data(state, name, level, lock_label="")` — 统一 3/4 参数（默认空串）
  - `_init()` 设 custom_minimum_size ≈ (56, 64)，`queue_redraw()` 在 set_data 后触发
  - `_draw()` 用 `draw_colored_polygon` 画六边形 + 中心圆点；按 state 配色（LOCKED 暗灰+锁标文字、EMPTY 空虚+提示文字、FILLED accent色填充+词条名+Lv.x）
- **inner class `TierLadder extends Control`** — 战力档位阶梯条（改造面板 5 档）：
  - `func set_data(current_tier, required_tier, card_power)` — 3 int 参数
  - `_init()` 设 custom_minimum_size 高度 ≈ 40
  - `_draw()` 画 5 段水平阶梯条（GRUNT/VETERAN/ELITE/CHAMPION/OVERLORD），读 `PowerTiers.TIER_NAMES`/`TIER_COLORS`（文件已 preload PowerTiers）；当前档高亮（accent 描边）、要求档金边描边、未达档灰化，下方标档位中文名
- 设计 tokens 颜色统一从 `DT`（DesignTokens）取，与消费方口径一致

### 文件 3 & 4: `.uid` 文件（新建）
- `scripts/ui/panel_styles.gd.uid` 和 `scripts/ui/geo_shapes.gd.uid`
- 内容为 `uid://<22-char-base32>` 随机生成（参考现有 mod_effect_labels.gd.uid / format_util.gd.uid 格式）；Godot 首次导入会校验/接管，不冲突即可

### 不修改的文件
- `card_enhancement_panel.gd` / `modification_panel.gd` — **不动**。它们已正确使用 API，所有调用点签名已逐一核对一致，创建辅助文件后即可直接生效

### 验证
1. 用 `godot-validate` 技能（`--headless --check-only`）确认两个新脚本语法 + preload 解析无错（AGENTS.md 记录项目全量 --check-only 接近 5 分钟超时，若超时属既有现象，将以脚本独立 load 编译为补充验证）
2. Grep 静态核对：6 个错误行涉及的 API（`make_panel_style`/`make_card_style`/`make_chip_style`/`make_stat_cell_style`/`make_roster_item_style`/`HexagonSlot`/`TierLadder`/`State`/`set_data`/`accent_color`）在新文件中全部定义且签名匹配

### 风险
- 六边形/阶梯的视觉效果是"基于代码注释与 DesignTokens 推断的实现"，无原始设计稿可对照（mockup PNG 本地不可读）；功能层面（消除报错、API 可用）100% 闭环，视觉细节（六边形顶点角度、阶梯段宽）可能需实机微调
- 全部向后兼容：新文件是纯新增，不改任何现有代码