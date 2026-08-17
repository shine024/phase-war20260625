# 非战斗场景性能修复计划（2026-08-17，机器 B 实测定稿）

> 背景：用户反馈"战场外还是卡"。本计划基于机器 B（GT 620M / 老笔记本）带渲染管线实测：
> 探针 `tests/ui_spike_probe.tscn`、`tests/ui_perf_probe.tscn`（**未提交，仅存在于机器 B 工作区**，
> 若在机器 A 执行本计划，验证步骤用替代方案，见各条"验证"）。
>
> 实测基线（清掉环境干扰后）：主界面空闲 60fps 满帧 / 零尖峰；关 vsync 135~164fps。
> 以下 4 个问题是实测确认的真实存在，按优先级排列。

---

## P0-1：bullet.gd 预加载不存在的纹理 → 整个脚本解析失败（战斗已坏）

**现象**：任何模式启动都有
```
SCRIPT ERROR: Parse Error: Preload file "res://assets/effects/projectiles/weapons_realistic/weapon_artillery_muzzle.png" does not exist.
ERROR: Failed to load script "res://scenes/units/bullet.gd" with error "Parse error".
```

**根因**：commit `86995c71`（v10 AI 修复批次）在 `scenes/units/bullet.gd:18` 新增：
```gdscript
const ARTILLERY_MUZZLE_TEX := preload("res://assets/effects/projectiles/weapons_realistic/weapon_artillery_muzzle.png")
```
该文件在 git 全历史中**从未存在**（`git log --all -- "*weapon_artillery_muzzle*"` 为空）。
目录里现存的同类纹理：`weapon_artillery_ballistic.png`、`weapon_artillery_impact.png`，
以及 `assets/effects/particle_textures/muzzle_heavy.png`（火炮炮口焰语义）。

**修复**（一行）：`scenes/units/bullet.gd:18` 改为
```gdscript
const ARTILLERY_MUZZLE_TEX := preload("res://assets/effects/particle_textures/muzzle_heavy.png")
```
（用 `muzzle_heavy.png`——用法在 :719 `VfxImpactFactory.spawn_impact_sprite(...)` 打炮口焰，
语义最匹配；若视觉风格要贴 weapons_realistic 系列，备选 `weapon_artillery_ballistic.png`。）

**验证**：跑任意战斗，启动日志不再出现上述 SCRIPT ERROR，弹道单位开火有弹丸/命中特效。

---

## P0-2：SubViewportContainer(stretch) 强制战场视口 UPDATE_ALWAYS → 非战斗每帧全量渲染

**实测证据**（机器 B，`tests/vp_mode_check2.gd` 最小对照实验）：
```
[VPMODE2] 无container入树: child=1      # tscn 里写的 UPDATE_ONCE
[VPMODE2] 1秒后: child=4                # 被 SubViewportContainer(stretch=true) 改写成 UPDATE_ALWAYS
```
Godot 4.5 引擎行为：`stretch=true` 的 SubViewportContainer 在入树时把子 SubViewport 的
`render_target_update_mode` 强制改为 4（ALWAYS）。

**影响**：项目里"非战斗冻结视口"的优化（`scenes/main.gd:1026` 设 DISABLED、
`scripts/systems/main_reward.gd:17` 设 ONCE）**从进主界面起就被容器覆盖，从未生效**。
战场视口（1280×580，Battlefield 全场景）在逛地图/开面板/看养成时每帧渲染。
实测禁用后每帧省 ~1.2ms（vsync off 137→164fps），战场内容多时浪费更大。

**关键事实**：容器只在**入树时**改写；入树之后再 set 的值会保留（机器 B 实测确认）。
所以只需在主场景就绪后、非战斗时补设一次即可。

**修复**：`scenes/main.gd` 的 `_deferred_non_critical_init()`（约 :155）**末尾**追加：
```gdscript
	# v9.x 性能：SubViewportContainer(stretch) 入树时会把子视口强制 UPDATE_ALWAYS，
	# tscn/战斗结束还原的 UPDATE_ONCE 全被覆盖，非战斗期战场每帧空渲染。
	# 入树后补设一次即生效（容器不会再次改写）。挂机运行中除外（缩略图需要持续渲染）。
	if not _is_in_battle() and (_afk_manager == null or not _afk_manager.is_running):
		var boot_vp: Node = get_node_or_null("BattleContainer/SubViewportContainer/SubViewport")
		if boot_vp is SubViewport:
			boot_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
```
注意：`_deferred_non_critical_init` 里 `_init_afk_manager()` 在前面已执行（:161），
`_afk_manager` 已非 null，判断可用。

**不需要动的**：`main_battle_setup.gd:64`（战斗开始设 ALWAYS）、`main_reward.gd:17`（战毕设 ONCE）、
`_freeze_subviewport_if_not_in_battle` / `_restore_subviewport_if_needed`（面板开关联动，入树后设置均有效）。

**验证**：
- 机器 B：跑 `tests/vp_mode_check.gd`（SceneTree 脚本），期望"入树1秒后: 1"（修前为 4）。
- 通用：进主界面看战场背景仍在（UPDATE_ONCE 会渲染最后一帧后停住，视觉无变化——
  非战斗时战场本来就无动态元素，扫描线 v9 已改静态）；打开面板/关闭面板往返无异常。

---

## P1：情报中心（IntelligenceHubPanel）打开同步冻结 1.2~3 秒

**实测**（机器 B，两次独立测量）：首开同步耗时 1245/1068ms、3046/2794ms（系统脏时更糟）。

**热点**：`scenes/ui/intelligence_hub_panel.gd`
- `_ready()`（:24）同步跑 `_setup_evolution_tab()`（:50，EvolutionAtlasView 全卡图谱一次性构建）
  + `_refresh_lore()`（:78，lore 网格整表销毁重建）；
- `refresh()`（:41）每次打开都重跑 `_refresh_lore()` + `_atlas.refresh()`（main.gd
  `_notify_panel_opened` 对 "info" 走 refresh 契约）。
- 同文件符文页签 v9.4 已有分帧范式：`_start_rune_load_timer` + `_process_rune_load_batch`
  （Timer 0.016s，每帧出 RUNE_PER_FRAME 个），直接复用该模式。

**修复步骤**：
1. `_ready()` 里把 `_setup_evolution_tab()` 与 `_refresh_lore()` 改为入队 + 分帧出队
   （复制 `_rune_load_queue`/`_start_rune_load_timer` 的写法，另起 `_lore_load_queue`
   或直接复用同一 timer 出多个队列）。
2. `refresh()` 里 `_refresh_lore()` 加脏标记：lore 未变化时跳过重建
   （可监听 lore 解锁信号置脏；首刷之后默认干净）。
3. `EvolutionAtlasView`（在 `_setup_evolution_tab` 实例化的那个类）内部若有"遍历全部卡逐卡建节点"
   的 refresh，同样按每帧 N 卡分帧；先读它的 refresh 确认单卡节点量再定批大小。
4. 面板打开的同步路径只保留：标题栏/样式/空容器骨架。

**验收**：首开同步耗时 < 200ms（掐秒或加临时打点），图谱/lore 逐帧填充可见。

---

## P2（可选，非本轮必做）

1. **启动卡顿段 ~1.5-2s**：main.tscn 实例化 + SaveManager 延迟管理器批次加载集中在少数帧。
   可把延迟批次进一步摊帧（`_process_deferred_manager_resets` 每帧 1 个而非批 N 个）。
   干净系统上体感可接受，优先级低。
2. **CostBadge 每帧字体测量**：`scripts/cost_badge.gd` `_compute_badge_global_position()`
   每帧 `get_string_size()`；文本只在 `energy_value` 变化时变，缓存测量结果即可。
   背包大列表时是小头，顺手改。
3. **面板隐藏不销毁**：`_close_overlay` 只 `visible=false`，节点常驻（空闲整树 2051 节点）。
   目前测量无感，列为观察项；若后续节点数随游玩持续增长再考虑关闭时 prune 列表内容。

---

## 环境注意事项（重要）

- **本机曾有僵尸进程污染**：机器 B 上发现一个挂死 20 小时的 `--headless --check-only`
  Godot 进程（烧一整核，累计 ~3h CPU），已手动结束。它曾让空闲实测掉到 26fps + 每秒
  2~4 次 80~150ms 尖峰。**任何机器上做性能测量/游玩前，先任务管理器确认没有多余的
  Godot 进程**。check-only 跑挂建议用 `timeout 360 godot ... --check-only` 兜底。
- **诊断工具在机器 B 未提交**：`tests/ui_spike_probe.{gd,tscn}`（尖峰示波器+对照实验）、
  `tests/ui_perf_probe.{gd,tscn}`（面板耗时+节点二分）、`tests/vp_mode_check{,2}.gd`
  （视口模式实验）。要跨机器用就提交；不用也不影响本计划执行。
- 修复涉及文件与当前工作区未提交改动（37 个文件）不重叠（bullet.gd / main.gd /
  intelligence_hub_panel.gd），注意 main.gd 本身不在未提交清单里，改动干净。

## 验证命令（机器 A/B 通用，Godot 路径见 AGENTS.md 探测脚本）

```bash
# 单文件语法（秒级）
"$GODOT" --headless --path . --script tests/vp_mode_check.gd   # 修后期望: 入树1秒后: 1
# 战斗冒烟（验 P0-1）：跑一局战斗，看日志无 "Preload file ... does not exist"
```
