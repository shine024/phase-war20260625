# Wave 1 Detailed Execution (Battle UI)

- 目标：在战斗界面实现 Sleek Sci‑Fi 风格的 HUD 基线，与 Start Screen 的 neon 主题统一，包括健康、能量、相位仪、单位信息、战斗反馈等要素，确保可访问性、分辨率自适应和性能友好。

---

## 1) 设计令牌 (Design Tokens)

- 目标
  - 为 Battle HUD 提供统一的颜色、字体、圆角、发光等参数，确保风格与 Start Screen 一致。
- 产出
  - phase-war/resources/design_tokens.gd（或 design_tokens.json）
- 要点
  - 背景颜色、面板颜色、文本颜色、主强调色（cyan）、辅助颜色（purple）
  - 字体字号等级：small/medium/large
  - 圆角、发光开关、发光强度
- 验收标准
  - 文件存在，且 HUD 组件能通过引用令牌获取颜色/字号
  - 至少有一个 HUD 原型使用此令牌
- QA 场景
  - 打开 HUD 原型，核对颜色是否落在 neon cyan/purple 的范围内
  - 调整一个令牌，观察 HUD 相应变化

---

## 2) HUD 骨架: BattleHUD 场景与脚本

- 目标
  - 构建 Battle HUD 的骨架，确保核心区域清晰、可扩展，方便后续绑定数据
- 产出
  - phase-war/scenes/ui/battle_hud.tscn
  - phase-war/scenes/ui/battle_hud.gd
- 要点
  - 包含 HealthBar、EnergyBar、PhaseInstrumentPanel、UnitInfoPanel 的占位节点
  - 与现有管理器的数据接口对接点（后续绑定）
- 验收标准
  - 场景可实例化，四大区域存在且可访问
- QA 场景
  - 实例化 BattleHUD，检查 HealthBar、EnergyBar、PhaseInstrumentPanel、UnitInfoPanel 的节点存在

---

## 3) HealthBar / EnergyBar：Neon 风格

- 目标
  - 实现 neon 发光，平滑过渡的生命值与能量条
- 产出
  - phase-war/scenes/ui/components/health_bar.gd
  - phase-war/scenes/ui/components/health_bar.tscn
  - phase-war/scenes/ui/components/energy_bar.gd
  - phase-war/scenes/ui/components/energy_bar.tscn
- 要点
  - 使用设计令牌的颜色和 glow 设置
  - 值变化时有平滑过渡动画
- 验收标准
  - 颜色，透明度和发光符合令牌规范
  - 数值更新有平滑动画
- QA 场景
  - 从 100% 跳到 70%，动画在一定时间内完成并且视觉一致

---

## 4) PhaseInstrumentPanel：4 插槽

- 目标
  - 四槽位显示当前装配（平台 + 武器组合），槽位有占用指示和发光状态
- 产出
  - phase-war/scenes/ui/phase_instrument_panel.tscn
  - phase-war/scenes/ui/phase_instrument_panel.gd
- 要点
  - 槽位显示 4 个，空槽与占用槽有区分
  - 与 PhaseInstrumentManager 的数据绑定准备就绪
- 验收标准
  - 四槽位正确显示，填充后有高亮发光
- QA 场景
  - 给一个槽位填充一次，确认视觉反馈和文本更新

---

## 5) UnitInfoPanel：单位信息

- 目标
  - 左右或中心区域显示单位头像、血量、攻击力等核心信息，便于战斗判断
- 产出
  - phase-war/scenes/ui/unit_info_panel.tscn
  - phase-war/scenes/ui/unit_info_panel.gd
- 要点
  - 支持单位切换时信息刷新
- 验收标准
  - 信息清晰、字体可读、无排版冲突
- QA 场景
  - 切换单位，信息面板更新

---

## 6) Combat Feedback Layer

- 目标
  - 提供简单的战斗反馈：伤害数字、击中提示、技能冷却等
- 产出
  - phase-war/scenes/ui/components/floating_text.tscn
  - phase-war/scenes/ui/components/floating_text.gd
- 要点
  - 能够在击中处或 HUD 边缘显示文本并淡出
- 验收标准
  - 弹出文本位置、数值正确、持续时间合适
- QA 场景
  - 触发一次伤害文本，验证文本内容和动画

---

## 7) 背景 Parallax（2-3 层）

- 目标
  - 简化但有效的 parallax，使战斗画面更有深度且成本低
- 产出
  - phase-war/scenes/ui/background/battle_parallax.tscn
  - phase-war/scenes/ui/background/battle_parallax.gd
- 要点
  - 2-3 层背景、不同速度
- 验收标准
  - 背景滚动平滑、没有明显抖动、性能友好
- QA 场景
  - 在战斗场景中运行，观测不同分辨率的 parallax

---

## 8) Accessibility Presets

- 目标
  - 提供 High Contrast 与 Large Typography 两种可选模式
- 产出
  - 设计令牌中新增 high-contrast、large-typography 标志的切换逻辑
- 要点
  - 模式切换对 HUD 的颜色与字体生效
- QA 场景
  - 启用高对比度，确保文本清晰；启用大字号，检查文本不重叠

---

## 9) Input Navigation & Focus Hints

- 目标
  - HUD 控件可通过键盘/手柄导航，有清晰的焦点提示
- 产出
  - 焦点顺序与视觉聚焦效果
- QA 场景
  - 通过 Tab/方向键遍历按钮，确认焦点可见且可激活

---

## 10) Responsive Layout Validation

- 目标
  - HUD 在 1280x720、1920x1080 等分辨率自适应
- 产出
  - 响应式布局设计与文档
- QA 场景
  - 在多分辨率下对比布局是否稳定

---

## 11) Sound Cues (Optional MVP)

- 目标
  - 悬停/点击/状态变更有声音反馈
- 产出
  - 声音资源与触发逻辑
- QA 场景
  - 操作 HUD 时声音是否恰当

---

## 12) Documentation & Handoff

- 目标
  - 设计令牌、组件使用方法、API 的文档化
- 产出
  - README，设计指南、组件接口文档
- QA 场景
  - 文档可理解性、易于上手

---

## Final Notes

- Wave 1 的目标是建立一个可维护、风格一致且可扩展的战斗 HUD 基线。后续 Waves 将逐步接入 BattleManager、Phase Instrument 的实时数据绑定，以及更多美术资源的替换与完善。
- 如果你愿意，我也可以把这些 Wave 1 任务拆成可执行的 scripty patches（Markdown Patch 风格）并逐步提交到你的代码库中，确保版本可追溯。
- 需要我把 Wave 1 的每项任务再细化到可直接粘贴的逐步实现清单吗？比如给出具体的节点命名、文件路径、以及要修改/新增的具体验收测试用例。
