# 全面性能检查报告（静态审计）

> 日期：2026-09-11 ｜ 分支：feat/v6.14-system-integration ｜ 方法：5 路并行只读扫描 + 引擎配置/资产自查
> 范围：战斗热路径 / 单位视觉层 / 30 autoload / VFX 弹道 / UI 基地层
> ⚠️ 编辑器未运行，无实机 profile——全部结论为静态分析，修复后应开编辑器用 Performance 监视器实测复验。

---

# 〇、修复状态台账（v27.12，2026-09-11 回写）

> 修复批次：两批主刀 + 编译自检（临时 tscn headless load 全部改动脚本 fail=0）+ GdUnit4 全套 268/268 通过。
> 改动统一带 `v27.12:` / `v27.12 perf:` 注释前缀。

## ✅ 已修（按分报告编号）

**正确性 bug（最优先）**
- ③-P2-2 AuraManager `clear_all()` 后 `_global_tick_timer` 永久停摆 → 已修（aura_manager.gd:409，恢复启动点）
- ③-P2-1 伤害数字双份管线 → battle_hud 侧 `show_damage_popup` 下线，统一走 BattleManager→CombatFeedback（80ms 节流合并）

**分报告① 战斗热路径**
- P1-1/P1-2 module_effect_handler 守卫顺序（`_tick_aegis_pulse`/`_tick_gravity_pulse`/`_check_last_stand`/`_tick_dot_damage` 零成本门禁前置）
- P1-3/4/5 phase_instrument_abilities：`_pkey` 键名查表缓存、`_process_barrage_queue` 就地压缩（免 filter lambda）、`_check_rage_expire` 核查原已达标免改
- P1-6 construct_unit_ai `get_attack_delta_scale` 时间戳惰性读取
- P2-7/8 module_effect_handler `_get_battle_manager` 静态缓存 + `_mech_active` 走引擎零拷贝 `is_mechanism_active`
- P2-9 pair_synergy_engine root 链缓存
- P2-10/11 indirect batch：格子战判定提函数头一次、BM 成员缓存、fire 时预计算 tint/apex 存弹道字典
- P2-12 player/enemy batch 曳光色按 sk 静态缓存（width/len 纯 match 免缓存）
- P2-14 enemy_master_skill_engine 走 `get_cached_nodes_in_group`
- P2-19 nano_swarm hit 特效：gradient 复用 + hit_fx 上限 6
- P2-20 combo_field_state `to_erase` 分配消除
- P2-21 vfx_impact_factory decal 池（48 上限）+ `_spawn_pellet_mark` 接入
- P3-24 unit_shared_helpers `HIT_SHAKE_KEYS` const + sprite meta 缓存 + `Callable.bind` 替代 lambda
- P3-31 endless_rift_ambience TwinkleLayer 20fps 重绘节流、faction_skill_effect_handler autoload 静态缓存

**分报告② 单位视觉层**
- P1-1 unit_outline.refresh：uniform 值挂 ShaderMaterial meta 缓存，换帧 tick 恒定值零写入（同时覆盖 ②-P3-16 boss no-op refresh 与 ①-P3-23 部分）
- P1-2 unit_hp_bar 低血脉动 20fps 节流（相位走绝对时钟不跳相）
- P2-3 浓度场 VFX 更新式复用（Polygon 重建守卫 + 材质复用）
- P2-6 attack_pose_anim：timer 代次门禁（修 SceneTreeTimer 不可取消的纹理二次复位视觉瑕疵）+ `_find_sprite` meta 缓存
- P2-7 base_aura `_draw` 20fps 节流
- P3-9 unit_frame_anim：anim.json 路径级缓存 + `_resolve_key` 探测缓存 + 帧序列 AtlasTexture 跨单位共享
- P3-10 construct/enemy_unit hit_boost meta 写守卫 + `_get_hpbar_cached` 接入（P3-12 同）
- P3-11 deploy_progress_bar bg 恒定几何一次性构建
- P3-14 card_grid_unit_visuals `_buff_label_sig_cache` 512 上限自愈
- P3-15 advance_idle_motion StringName 键 + AirUnitShadow 类型化直调（免反射）

**分报告③ autoload**
- ③-P3-6 object_pool `clear()` 重置 `total_created` + `_prewarmed`（潜伏雷防御性修复）

**分报告④ VFX/弹道**
- P1 曲射 mid/apex/tint fire 时预计算（batch + bullet.gd 单发路径 `_indirect_apex_point`）
- P1 MultiMesh `set_instance_color` 增量补写（`_prev_counts` 记前帧）
- P1 screen_shake 无震动 `set_process(false)`
- P1 batch 尾烟 0.09s 节流核查原已有
- P2 `_spawn_impact_decal`/`_spawn_pellet_mark` decal 池化、battle_spectacle `_make_label_settings` 静态缓存、bullet.gd `_shape_flavor` 复用（classify 5 处→1 处）

**分报告⑤ UI 层**
- modification_panel / store_panel / achievement_panel（可见守卫）/ backpack_card_item（归还清缓存）/ ui_asset_loader（LRU）/ world_map / buff_fold_card（脏标记）均已修（各文件 `v27.12` 标记）

## ⏭️ 明确延期（2 项，需实机验证/架构级重构）

1. **CPUParticles→GPUParticles2D 迁移评估**（④-P1）：改动面大，先满载实测帧时间再定
2. **单位本体整树池化**（②-P2-8）：ConstructUnit/EnemyUnit 场景级 churn，架构级重构

## 🚫 免修（核查后判定不修 + 理由）

- ①-P2-13 `aim_pos_for` 每弹每帧重算——瞄准位依赖目标**当前位置**，弹与目标都在动，不可缓存（audit 误判）
- ①-P2-15 battle_manager 反馈路径——`has_meta` 门禁已在最前 + `show_damage` 内部 80ms 节流
- ①-P2-16 battle_damage_system 每击杀 `get_children()`——每击杀一次，低频
- ①-P3-22 target_selection——主路径已是空间网格单遍扫描，残余小项不成热点
- ①-P3-25/26 battle_spectacle await timer / battle_manager 结束 timer——每杀/每战一次，低频；核爆 `load()` 有引擎资源缓存仅首次真 IO
- ①-P3-27 combo_engine 已修（3 处 v27.12）；①-P3-28 attack_calculator 调用方已缓存仅 fallback
- ①-P3-29 unit_status_collector 已被 unit_hp_bar 0.3s 节流覆盖
- ①-P3-30 dot_vfx_manager 有 48 上限，分配量有界
- ①-P3-31 mod_aura_handler lambda 每单位部署一次；fort_shield_aura 残余 audit 自注可忽略
- ③-P3-3/4 save_manager 15-33KB ~1ms 级 + 1.2s 间隔，留观测点
- ③-P3-5 vfx_impact_factory 30+ SceneTreeTimer——RefCounted 轻量，改动回归风险大于收益
- ③-P3-7 object_pool 启动 load 两 PackedScene——实例化已延迟，仅注册期小项
- ③-P3-8 aura_manager `_get_aura_data` 3s 一次，分配噪音级
- ③-P3-9/10 save toast（UI churn 非性能）/ game_bridge 10Hz 轮询（仅 debug 构建）
- ②-P2-5 battle_slot_grid 已修；battlefield.gd :146-149 调用侧 0.4s 一次低频（重建成本已在 vfx factory 侧消除）

---

# 一、总结论

**架构底子好，无灾难性问题。** 空间网格、MultiMesh 批处理、六层对象池、全局节流纪律、UI 缩略图管线全部真实生效（逐一核实过消费方）。残余帧开销集中在三个系统性模式：

1. **on_tick 门禁顺序错误** —— 廉价检查放在昂贵调用之后，无模块单位每帧白付堆分配。
2. **未缓存 `root.get_node_or_null("BattleManager"/"GameManager")`** —— ≥8 处按命中/按 tick 重复全树字符串查找（`bullet.gd:1140` 已有直引先例可照抄）。
3. **恒定量每帧重算** —— 曲射弹道 mid/apex、tint 字符串分类、曳光样式、描边 uniform。

另发现 **1 个正确性 bug**（光环 Timer 永久停摆）与 **1 个疑似视觉 bug**（伤害数字双份）。

## 做对了的（抽查核实）

| 项 | 证据 |
|---|---|
| SpatialGrid 真用上 | 索敌（construct_unit_ai.gd:87-110）/溅射/AOE（simple_indirect_projectile_batch.gd:520-548）主路径全走网格查询，零 O(n²) 全对全 |
| MultiMesh 真批处理 | 1440+ 弹同屏仅 ~18 渲染节点，弹道 dict 池 + 桶数组成员复用零每帧分配 |
| autoload 自律 | 30 个仅 2 个有 `_process`（均带战斗门控）；常驻 Timer 仅 2 个 |
| 对象池 | 子弹 450 / 伤害数字 80 / spark 320 / debris 140 / ring 80 / beam 60 / impact_sprite 160，均有防泄漏兜底 |
| 节流纪律 | 组缓存 0.28s / 命中特效 40ms / 开火音 110ms / HUD 0.25-1s / DOT 0.25s |
| UI 缩略图 | 384/256/128 三档 + 视口懒加载；backpack_panel.gd:1018-1081 是全项目标杆 |
| 启动/存档 | ModificationRegistry 延迟到首查询、DefaultCards 懒构建、JSON 八表懒加载；存档 15-33KB 单次 ~1ms + 原子写 + 15s 节流备份 |

## 引擎配置 / 资产层

- `gl_compatibility` + 1280×720 + `canvas_items` 拉伸：2D 项目正确姿势，无异常。
- 贴图导入 lossless、无 mipmap：2D 正确；每张 512² 卡图解码占 1MB 显存，战斗同屏十几个单位无压力。
- 最大单图 = `assets/map/大地图.png` 6.6MB（解码 ~16-32MB 显存级），可接受。
- 体量：409 gd / 16.7 万行 / 47 个 `_process` / 6 个 `_physics_process` / 4 个全屏 shader。
- 磁盘：assets 619MB（ui 141 + 卡图 118），`.godot/imported` 788MB——仅磁盘，非运行时问题。
- `file_logging` 开启：IO 极小，无需动。

## 建议修复顺序

1. **AuraManager timer bug**（正确性，影响战斗数值，一行级）
2. **P1 守卫顺序 6 处 + 双伤害数字管线去重**（机械改，消除绝大部分残余每帧开销）
3. **root 引用缓存统一收口**（≥8 处同一模式，一次治理）
4. **描边 refresh 预缓存 + 低血血条分档降载**（收益随单位数线性放大）
5. **indirect batch 恒定量预计算 + decal/爆炸入池 + field 重建守卫**
6. **CPUParticles→GPUParticles2D 评估**（改动大，先实测满载帧时间再定）
7. UI 三面板向 backpack 池化标杆对齐 + achievement 可见守卫
8. 修完开编辑器实机复测（Performance 监视器对比帧时间）

---

# 二、分报告①：战斗热路径（managers/battle + scripts/battle + energy_manager）

**真实每帧主干**：`construct_unit/enemy_unit._physics_process` → `ConstructUnitAI.process_attack` + `ModuleEffectHandler.on_tick`（每单位每物理帧）→ 三个弹道 batch `_physics_process`（每弹每帧）→ `BattleManager._process`（5 引擎）。

## P1

1. `scripts/battle/module_effect_handler.gd:1803` `:1831`（`_tick_aegis_pulse`/`_tick_gravity_pulse`）：`_get_attacker_special_flags(unit)` 在任何廉价门禁之前调用，无该模块的单位每帧也分配新 `{}`——每单位每帧一次堆分配；`:1778`（`_check_last_stand`）同模式。对照 `_tick_radar_lock`（L1412-1415）已有正确的零成本门禁写法。
2. `module_effect_handler.gd:1472-1489`（`_tick_dot_damage`）：`Time.get_ticks_msec()`（L1475）在节流判断之前，且 `set_meta("_dot_acc")`（L1489）对无 DOT 单位也每帧写入。
3. `managers/battle/phase_instrument_abilities.gd:274` `:432` `:768`：引擎循环内每帧字符串拼接键名（"%s_xxx" % …）。
4. `phase_instrument_abilities.gd:292-306`（`_process_barrage_queue`）：`queue.filter(func(...))` 每帧新 lambda + 新数组。
5. `phase_instrument_abilities.gd:869-876`（`_check_rage_expire`）：每帧 `Time.get_ticks_msec()`，可改累计 delta。
6. `scripts/battle/construct_unit_ai.gd:845-879`（`get_attack_delta_scale`）：每单位每物理帧（L978），内含 `Time.get_ticks_msec()` + 4 段 has_meta/get_meta 链。

## P2

7. `module_effect_handler.gd:539-545`（`_get_battle_manager`）：`Engine.get_main_loop()` + `root.get_node_or_null("BattleManager")` 完全未缓存，被每次溅射/连锁/光环 tick、`_mech_active`、`_get_combo_engine` 反复调用——全项目同一反模式的核心（≥5 处复现）。
8. `module_effect_handler.gd:1626-1630`（`_mech_active`）：每次调用触发引擎 `get_active_mechanisms()` 返回的 `.duplicate()` 数组拷贝；频率 = 每命中/每受击/每 tick；L1539-1541 每 0.25s DOT tick 再来一次。
9. `scripts/battle/pair_synergy_engine.gd:226-239`（`query_pair_active`）：未缓存 root 查找，经 `is_artillery_mark_crit`（L278-290）变成**每发子弹命中一次**；`get_artillery_mark_splash_mult` 每次溅射再一次。
10. `simple_indirect_projectile_batch.gd:431-435` `:492-496`（`_apply_hit`）：`"GameManager"` root 字符串查找位于**溅射目标循环内部**；L417-419 每次爆炸 `get_active_mechanisms()` duplicate；L457-463 `shooter.get_script().on_bullet_hit_post` 反射调用。
11. `simple_indirect_projectile_batch.gd:328-331`（`_sync_multimesh_layers`）：星冥开关开启时 `XenoWeaponFlavor.classify(String(...))` 每弹每帧字符串分类（应 fire 时分档一次存 dict）。
12. `simple_player_projectile_batch.gd:53-84` / `simple_enemy_projectile_batch.gd:48-77`（`_update_tracers`）：每帧对 ≤48 条曳光线 `clear_points()` + 2×`add_point()` + 每条 3 次 `tracer_*_for()` 静态参数查找——宽度/颜色只有换档时才变。
13. 三个弹道 batch 的 `CardGridUnitVisuals.aim_pos_for(tgt)`：每弹每帧重算瞄准位，无结果缓存。
14. `enemy_master_skill_engine.gd:365-369` `:1177-1181`：0.5s tick 内未缓存 `get_nodes_in_group`；每帧 `get_boss_active/passive_spells()`（若返回副本则每帧数组分配）。
15. `battle_manager.gd:1394-1427`（`_on_unit_damaged_combat_feedback`）：每次 damage 信号全量反馈逻辑（密集交火 = 每秒数十次）。
16. `battle_damage_system.gd:155-170`（`_get_recon_fragment_bonus_multiplier`）：每次击杀 `get_children()` 全量子节点扫描。
17. `construct_unit_ai.gd:365-387`（`_scan_slot_targets`）：一次 retarget 3 个 `valid.filter(func...)` 新 lambda + 新数组；`:224-233` `:270-276` 每次 retarget 再分配候选数组。
18. `construct_unit_ai.gd:1192-1253`（`_play_muzzle_feedback`）与 `:547-586`（`_get_direct_fire_spawn_pos`）：每次开火 `get_node_or_null("Sprite"/"Anchor…")` 未缓存。
19. `phase_instrument_abilities.gd:1058-1094`（`_create_nano_swarm_hit`）：每目标每 0.25s tick `new` Node2D + CPUParticles2D + Gradient 并 add_child（有 VFX 上限但节点不复用）。
20. `scripts/battle/combo_field_state.gd:97-116`（`update`，每帧）：每帧 `to_erase` 数组分配 + 每活跃 tag 每帧 `field_changed.emit`。
21. `vfx_impact_factory.gd:3361-3380`（`_spawn_impact_decal`）：无池无上限 `Sprite2D.new()` + tween + free，每次动能命中一次（batch 路径 40ms 节流，其余调用方无）。

## P3

22. `target_selection.gd:241-251` `:271-282` `:226-237`：主路径已是空间网格单遍扫描（良好）；残余 `_filter_attackable` 数组分配、`_prioritize_crit_marked` 每调用 msec + 数组分配、`select_target` 多趟遍历；每敌 `CardAbilityManager.is_unit_targetable` 反射式判断。
23. `attack_pose_anim.gd:214-230`：每次攻击 2 SceneTreeTimer + 2 lambda + 2 WeakRef；`:272-282` 每次攻击最多 3 次字符串 get_node。
24. `unit_shared_helpers.gd:93`：受击窗口内每帧分配 `keys` 数组（应 const）；`:186/:198` 每次开火字符串 get_node + 新 lambda。
25. `battle_spectacle.gd:127`：每杀（已节流）`await create_timer`；`:933-957` 核爆贴图未缓存重复 load（有资源缓存仅首次真 IO）。`phase_instrument_abilities.gd:503/629-653` 同类。
26. `battle_manager.gd:708-713` 战斗结束 timer+lambda；battle_spawn_system 递归槽位扫描 O(槽×单位)/波 + `_build_stats_cached` 每部署字符串键；card_periodic_skill_engine 每 0.5s 数组分配；enemy_master_skill_engine 每次施法 27 tween 突发（有告警标记）。
27. `combo_engine.gd:239`（`try_chem_spread`）：半径 100000.0 全场最近敌扫描（应直接取缓存组）；`:411-435` `_get_nearby_enemies` 每次调用 root 查找 + 数组分配。
28. `attack_calculator.gd:367-379`：`get_weapon_attack_timing` 每次新 Dictionary（调用方已缓存，仅 fallback）。
29. `unit_status_collector.gd:108-193`：`collect()` 约 20 次 has_meta + entry dict 分配、`signature()` 格式化——已由 unit_hp_bar 0.3s 节流。
30. `dot_vfx_manager.gd:245-274`：每 0.25s tick 分配 4-dict `states` 数组；每次挂载 Sprite + 2-3 Polygon + 无限 tween（有 ~48 上限）。
31. `endless_rift_ambience.gd:411-415`：TwinkleLayer 每帧 `queue_redraw()` → 44 星 × 5 次 dict 取值（仅无尽模式）；`mod_aura_handler.gd:56-73` 每单位 setup 一个 lambda；`faction_skill_effect_handler.gd:623-627` 每事件 root 查找；`fort_shield_aura.gd:108-116` 每次 redraw `PackedVector2Array` + `duplicate()`（已降到 1/4 帧，残余可忽略）。
32. 三个 batch `_apply_hit`：每命中 `_opts` 新 dict、tier≥2 时 root 查找 shake。

## 已验证的良好实践

- SpatialGrid 真用上（索敌/溅射/光环/AOE），无 O(n²) 全对全。
- ObjectPoolManager 真用上（子弹两处、伤害数字 battle_spawn_system:951-956、VFX 环/光束/碎片池 + 活跃上限），弹道 dict 池 + MultiMesh 批渲染。
- 节流纪律普遍良好：0.28s 组缓存 / 0.5s 技能 / 1.0s 战术连招 / 0.3s 光环 / 0.25s DOT / 40ms 命中特效 / 110ms 开火音。
- `energy_manager.gd` 干净：整数门控 energy_changed 发射，无发现。

---

# 三、分报告②：单位视觉层（scenes/units + scenes/battlefield + visuals/aura 相关）

## P1

1. **`scripts/battle/unit_frame_anim.gd:200`（同 150、223）** — FrameDriver 每次换帧（idle ~8Hz，attack 动态 6-24Hz）无条件调 `UnitOutline.refresh()`，全军每单位每动画帧 2 次 `set_shader_parameter` + AtlasTexture 宽高查询；`edge_texels` 尺寸补偿后恒定却每次重算，`region_uv` 可按帧预缓存。单位多时是最热 uniform 写入路径。
2. **`scenes/units/unit_hp_bar.gd:221-222` `:343-352`** — `_target_ratio <= 0.3` 使 `_needs_active_process()` 恒真，低血单位 `_process` 永不休眠（每帧 sin() + `_glow.color` 写）。消耗战下半场单位长期 <30% HP = 全军每帧血条脉动（注释自知未分档降载）。

## P2

3. `scenes/battlefield/battlefield.gd:146-149` + `scripts/battle/vfx_impact_factory.gd:3919-3974` — 浓度场 VFX 每 0.4s 无条件重建 nano/chem 两个 Polygon2D（浓度不变也重建）；`_cleanup_field_vfx`（:3982）每周期两次全子节点线性扫描；常态 ~5 节点/秒 churn。
4. `scripts/battle/pair_synergy_engine.gd:226-239` — `query_pair_active` 每次调用走 `Engine.get_main_loop()→root.get_node_or_null("BattleManager")→get_combo_engine()` 链；调用点在命中热路径（bullet.gd:1327、module_effect_handler.gd:437、simple_indirect_projectile_batch.gd:484）。
5. `scenes/battlefield/battle_slot_grid.gd:181` — SlotHighlight._process 每帧 `get_node_or_null("/root/BattleInputState")` 绝对路径查找且在 `visible` 早退之前；`:198` 挂起部署期间每帧 `queue_redraw()`（悬停/占用未变也重绘）。
6. `scripts/battle/attack_pose_anim.gd:146-151` `:170-174`（前摇版 79-87 `:105-112`）— 每次开火每单位 2 个 Tween（位移+倾斜），带前摇武器再各加 2（有 kill 旧 tween，无泄漏）。
7. `scenes/units/base_aura.gd:57` — `_process` 末尾无条件 `queue_redraw()`，`_draw` 每帧重新分配 4-5 个 20-28 段椭圆 PackedVector2Array；仅 2 实例影响有界，模式上就是"每帧 queue_redraw"。
8. `scenes/units/enemy_phase_field_driver.gd:1062` `:1140` + `unit_shared_helpers.gd:116-127` — 单位生成走整场景 `instantiate()`、死亡淡出后 `queue_free`，**单位本体无对象池**（子弹/VFX/蜂群均已池化，唯独 ConstructUnit/EnemyUnit 整树 churn：每个体 ~10 子节点）；补兵队列高频模式下 P2。

## P3

9. `unit_frame_anim.gd:61-66` `:83` — `attach` 每单位每次 FileAccess 读 anim.json + JSON.parse，同 key 无跨单位缓存；`_resolve_key`（37-57）最多 6 次 `ResourceLoader.exists` 磁盘探测——出生瞬间 hitch。
10. `construct_unit.gd:1319` / `enemy_unit.gd:785` — `_update_fort_shield_aura` 每物理帧 `set_meta("hit_boost", ...)` 即使值为 0 且未变（redraw 已 4 帧节流，meta 写漏节流）。
11. `scenes/units/deploy_progress_bar.gd:24-56`（调用点 construct_unit_deploy.gd:98）— 部署虚影期每物理帧全量重建 bg+fill 两个 PackedVector2Array（bg 几何恒定）。
12. `enemy_unit.gd:1575` `:1591` / `construct_unit.gd:1779` — `_update_hp_bar` 用未缓存 `get_node_or_null("HpBar")`，而两文件均已有 `_get_hpbar_cached()`（147/249）未在此处使用。
13. `module_effect_handler.gd:151-182` `:1483-1488` — `on_tick` 每单位每物理帧扇出 14 个子系统调用；DOT/光环计时累加器在机制不存在时也每帧 has_meta/get_meta/set_meta 三连。
14. `scripts/card_grid_unit_visuals.gd:30` `:764-767` — 静态 `_buff_label_sig_cache` 按 instance_id 只增不清（长会话内存缓慢增长）。
15. `card_grid_unit_visuals.gd:293-319` — `advance_idle_motion` 每单位每物理帧 get_meta 取 Dictionary 装箱回写 + 可能的投影 set_bob 反射调用。
16. `scripts/battle/boss_idle_anim.gd:91` — boss 帧为同分辨率整图，换帧 `UnitOutline.refresh` 实为 no-op（region_uv 恒 0,0,1,1 仍重算）。

## 专项核查结论

- **描边刷新频率**：`refresh` 触发点 = 换帧 tick（8-24Hz/单位）+ attach/首帧/play_attack，非每帧；但换帧必刷两个 uniform 属过度（见 #1）；无任何纹理重建。
- **帧动画 texture 切换**：AtlasTexture 在 attach 时一次性预构建（unit_frame_anim.gd:102-117），换帧只做预建对象赋值——设计正确。
- **未发现问题**：物理查询滥用（scope 内零 intersect_shape/ray）；Label.text 每帧风暴（HP 文本 1% 变化门控 construct_unit.gd:1797-1800、enemy_unit.gd:1586-1589；状态图标签去重 unit_hp_bar.gd:460-477；buff 标签签名+节点池复用 card_grid_unit_visuals.gd:759-806）；Tween 泄漏（循环 tween 存 meta 显式 kill；唯一瑕疵 attack_pose_anim.gd:214-230 SceneTreeTimer 不可取消，快速连发可能纹理二次复位——视觉瑕疵非泄漏）。

---

# 四、分报告③：30 个 autoload

## 每帧活跃清单

| Autoload | 每帧做什么 | 门控质量 |
|---|---|---|
| `BattleManager`（battle_manager.gd:229） | 战斗中每帧：群组缓存 0.28s 刷新 → 5 子引擎（后两者内部有间隔节流）→ 波次计时 → 限时判负 → `_check_win_lose()` → 性能采样转发 | 优：`battle_active` 早退 |
| `EnergyManager`（energy_manager.gd:32） | 战斗中每帧能量回复累加；`energy_changed` 只在整数部分变化时 emit（:119-127） | 优：`_ready` 即 `set_process(false)` |
| `AuraManager` | 无 `_process`，0.5s Timer 批处理 | 优（但有发现 #2 生命周期 bug） |
| `PerformanceMetricsManager` | 由 BattleManager 转发采样；15s flush，release 短路（:122） | 优 |
| `_MCPGameBridge` | 10Hz Timer 轮询 | 仅 debug 构建初始化，release 零开销 |

常驻 Timer 全项目 autoload 仅 2 个 + 懒加载 DebugLog 1 个。

## 发现

### P2
1. **`scenes/ui/battle_hud.gd:172-174` + `battle_manager.gd:172` `:1421-1427` — 同一次 `unit_damaged` 触发两套伤害数字管线**。BattleManager 侧走 CombatFeedback（80ms/单位节流合并），battle_hud 侧 `show_damage_popup` 无任何节流、每次命中从池取一个 damage_number_display 并拼样式字符串；密集战斗下最高频信号扇出路径（该信号 6 个订阅者），且视觉上疑似双份数字。
2. **`managers/aura_manager.gd:410` — `clear_all()` 里 `_global_tick_timer.stop()` 后全项目无任何 `.start()` 重启点**（battle_manager.gd:561-563 每次 `end_battle` 都调 `clear_all`）。首场战斗结束后 0.5s 全局 tick 永久停摆 → **MEDIC/CARRIER 周期光环第二场起静默失效**。正确性 bug。

### P3
3. `save_manager.gd:766-813` — 整档同步 JSON.stringify + 临时文件写 + 双 rename 全在主线程。实测 15-33KB ~1ms 级，有 1.2s 最小间隔 + 原子写 + 战斗中置脏延迟冲刷——现在没问题；序列化体积随 InstanceRegistry 实例数线性涨，实例涨 10 倍会成结算帧可感尖峰，留观测点。
4. `save_manager.gd:407-441` — `get_slot_info` 读一个 int 最多 parse 3 个整档（有缓存，仅标题屏触发）。
5. `vfx_impact_factory.gd` 30+ 处（:453/:498/:700/:2033 等）— 每颗粒子每生命周期一个 SceneTreeTimer 延迟归池；密集战斗每秒数百短命 Timer 分配，可换单个共享清扫器。
6. `object_pool.gd:96` `:164-173` — `clear()` 不重置 `total_created`：一旦有人调 clear_pool/clear_all，池永久拒绝新建、全部走兜底实例化（"有池等于没池"）。当前全项目零调用方，潜伏雷。
7. `object_pool.gd:43` `:184-201` — autoload 启动时同步 `load()` 两个 PackedScene（注册即加载，实例化已延迟），启动关键路径小项。
8. `aura_manager.gd:36-39` `:294-297` — `_get_aura_data()` 每次调用 new RefCounted，CARRIER 修复 tick 内每盟友 2 次；`get_unit_star(unit)` 可外提。3s 一次，分配噪音。
9. `save_manager.gd:856-858` — 每次自动存档成功弹 "游戏已保存" toast（UI churn 而非性能）。
10. `game_bridge.gd:19/:40` — debug 构建 10Hz `FileAccess.file_exists` 轮询，开发期可接受。

## 专项核查结论

- **SignalBus（实测 82 个 signal，比 AGENTS 记载 79 漂移 +3）**：高频信号订阅方几乎都自带节流或脏标记（audio 120ms / spectacle 1s / info_display dirty-flag / log 早退）；energy_changed 源头节流。唯一例外 = P2-1。
- **每帧/每秒全量大字典扫描：未发现**。combo_engine 1s 节流（combo_engine.gd:79-82）、tactic_detector 间隔、aura tick 只扫持有者、InstanceRegistry O(1) 反向索引（instance_registry.gd:40）。
- **启动开销整体轻**：ModificationRegistry._ready defer 到首查询（:194-199）、DefaultCards 131 卡懒构建、JSON 八表懒加载、多数 manager `_ready` 为 pass。重项仅 #7 两场景加载与 DropManager 的 DropTables.new（drop_manager.gd:29）。

---

# 五、分报告④：VFX / 弹道 / 特效层

## P1（每帧）

- `simple_indirect_projectile_batch.gd:252-253` — 曲射贝塞尔 `mid`/`apex_point` 每帧每弹重算，发射后恒定（180 弹满载 = 每物理帧 360 次多余 Vector2 运算）。
- `simple_indirect_projectile_batch.gd:325-331` — `WeaponProjectileVfx.indirect_tint()` + `XenoWeaponFlavor.classify()`（字符串关键词扫描）每实例每帧调用，结果恒定，应 fire 时算一次存弹道字典。
- `simple_enemy_projectile_batch.gd:300` / `simple_player_projectile_batch.gd:301` — `set_instance_color(idx, tint)` 每实例每帧写 MultiMesh 颜色缓冲，tint 对整层恒定（每层首帧写一次或 layer 级 uniform 化即可）。
- 两 batch `:73-84` — 曳光每帧对最多 48×2 条 Line2D `clear_points()`+2×`add_point`+重写 width/color（样式恒定），96 条独立 Line2D 未批处理。
- `vfx_impact_factory.gd:3732-3784` `:3788-3857` — **全项目粒子池 100% CPUParticles2D**（GPUParticles2D 零使用），gl_compatibility 下 CPU 逐粒模拟：spark 320 + debris 140 满载 = 460 并发发射器（各再模拟 2-30 粒），大场面帧时间主风险。
- `simple_indirect_projectile_batch.gd:263-266` — 每弹每 0.09s `spawn_projectile_trail_puff` 抢占 140 上限 debris 池（vfx_impact_factory.gd:3249），齐射 12+ 门炮持续击穿上限，尾烟与命中碎片互相顶替。
- `scenes/effects/screen_shake.gd:43` — 无震动时每帧仍 `offset = original_offset`（应加 active 守卫）。
- `scenes/units/bullet.gd:952-953` — 单发曲射兜底路径同病根（频率低于 batch）。

## P2（高频命中路径）

- `vfx_impact_factory.gd:3366-3380` `_spawn_impact_decal` — 每次轻动能命中 `Sprite2D.new()`+tween+free，非池化（轻武器 40ms 限流下峰值仍 ~16 并存）。
- `:2276-2296` `spawn_animated_nuclear` — 每次曲射/火箭/高炮/导弹命中 `AnimatedSprite2D.new()`+tween+free（注释 :2257 自认），无限流，密集炮战峰值 ~20 并存。
- `:371-387` `_spawn_pellet_mark` — 每霰弹弹丸 `Sprite2D.new()`，一次齐射 6-8 个新节点。
- `:3939` `:3969` `spawn_nano_field`/`spawn_chem_field` — 每 0.5s 重建 Polygon2D 且每次 `CanvasItemMaterial.new()` 新材质实例。
- `:213-311` `spawn_layered_impact` — 单次重型命中产 6-8 个池节点，每节点各配一个 Tween + SceneTreeTimer + 释放 lambda（`_connect_deferred_release`），每秒数十命中时分配 churn 显著。
- `simple_indirect_projectile_batch.gd:377` `:416` `:524` — 每命中 `get_node_or_null("BattleManager")` 从 root 全树查找（autoload 可直引；对比 bullet.gd:1140 已改直引）。
- `simple_enemy_projectile_batch.gd:237` / `simple_player_projectile_batch.gd:238` — 目标死亡补播命中特效路径无 40ms 限流（限流只在 `_apply_hit`），团灭波次瞬间数十发无节流特效。
- `battle_spectacle.gd:629` `_make_label_settings` — 每次 banner/标题/combo `LabelSettings.new()`（调用点 :249/:411/:492/:530/:561/:589/:803），可静态缓存。
- `bullet.gd:1221` `:1085` `:540` `:603` — `_on_hit` 单次命中内对同一 `_weapon_name` 重复 `DirectWeaponFlavor.classify()` 最多 3-4 次（setup 已解析存 `_shape_flavor` 未复用）。

## P3（低频大场面）

- `battle_spectacle.gd:746-860` `_on_mechanism_nuclear_launched` — 一次核武编排瞬时 10+ VFX 节点链；`:886` 每发 `Sprite2D.new()` 核弹；`:933-957` 每次 `load()` 贴图/帧（有资源缓存）。
- `:342` `:363-364` — 纳米雨层 `CPUParticles2D.new()`（amount=120 持续 30s 全屏 CPU 模拟）+ 每次 `CanvasItemMaterial.new()`。
- `vfx_impact_factory.gd:2051-2094` `spawn_ground_burn` — 地面焦痕永驻至战斗结束，多次大招线性堆积。
- `:1999-2045` `:2423-2560` `:4192-4227` — 均为每次 `new` 节点，低频可接受。
- `:4235-4256` `_get_tint_add_mat` — 首次调用运行时 `Shader.new()` + 内联 GLSL 编译（一帧卡顿），按 tint 色无限增长 ShaderMaterial 缓存。
- `battle_spectacle.gd:261-282` `_play_nuclear_impact` — 两条重叠 tween 链同时写 `_overlay.color`，互相覆盖的冗余写。
- `scenes/effects/phase_law_cast_effect.gd:18-86` — 每次施法全新建 8 Line2D + CPUParticles2D + Gradient + Curve + Polygon2D + 3 tween，无一复用。
- `scenes/effects/aura_range_indicator.gd:67` — 每次部署 `load()` 脚本 + `scr.new()`（0.85s 自毁，量小）。

## 做对了的

- 弹道 batch 是**真 MultiMesh 批处理**（TRANSFORM_2D + use_colors，dict 池 + buckets 成员复用零每帧分配），满载 720+720 直射弹仅 ~18 渲染节点。
- 伤害数字走 ObjectPoolManager 池（damage_number_display.gd:293-327），LabelSettings 静态缓存（:143）、Label 子节点跨池复用。
- 缓存健全：add/normal 材质（:3582-3596）、渐变（:3600-3622）、配方（:3434）、SpriteFrames（:2262）、贴图名查表（weapon_projectile_vfx.gd:623-624）、ring 共享顶点数组（:3673）；无 AtlasTexture 重建。
- 池化覆盖：ring 80 / debris 140 / spark 320 / beam 60 / impact_sprite 160 / indicator 40 / trace 48 环形缓冲；bullet 池 450 上限 + 4 消费方均有兜底与归还守卫（bullet.gd:776-792 无泄漏）。

## 峰值同屏估算

常驻池节点 848 + 曳光 96 + 未池化瞬态（弹痕 ~16 + 帧动画爆炸 ~20+）+ 伤害数字 80 + bullet 池 ≤450 + 核武演出瞬时 +15-25 ≈ **1500-1600 特效相关节点**；主力弹道 MultiMesh 仅 ~18 节点扛 1400+ 弹——节点数可控，**真瓶颈是 ~460 个满载 CPUParticles2D 发射器的 CPU 模拟量与每命中 6-8 节点的 Tween/Timer 分配 churn**。

---

# 六、分报告⑤：UI / 地图 / 基地层

## P1 — 未发现

重点排查的"打开面板同步加载 131 张 512×512 原图"未发生：已有缩略图管线（列表 `_thumb384` / 战斗 `_thumb256` / 饰品符文 `_thumb128`）+ 视口懒加载，最坏路径已切断。

## P2

- `scenes/ui/modification_panel.gd:411-516`（触发点 :225-228）— 每次打开面板且每次点击筛选 chip 同步"遍历 133 卡 × N 实例"全量 `queue_free` + 重建整个名册（注释自认重操作），无池化无签名跳过。
- `modification_panel.gd:686-746` — 每次选中一张卡全量清空重建改造条目列表，与上一条叠加 = 点一下重建两片。
- `scenes/ui/store_panel.gd:221-319`（触发点 :105-115）— 面板可见期间每次 `resources_changed` 全量 `queue_free` + 逐行 `instantiate()` 重建全部商品行及分节。
- `scenes/ui/achievement_panel.gd:330-336`（重建体 :143-155）— 成就解锁/进度信号直接 `refresh()` 全量重建，无 `is_visible_in_tree()` 守卫；面板经 UILazyLoader 常驻后，战斗中每次进度推送隐形全量重建。
- `scenes/ui/backpack_card_item.gd:47` `:317-322` `:850-855` — 池化 item 的 `_icon_cache` 在 `set_card(null)` 归还池时不清空；视口外"卸载"只置 `texture=null` 但仍持有 Texture2D 引用（注释宣称的"释放 VRAM"未达成），且绕过 UiAssetLoader LRU 直连 `ResourceLoader.load`。
- `scripts/ui_asset_loader.gd:38` `:53-67` — 静态 LRU 上限 80 < 背包 131+ 卡，整列表滚动必然反复逐出/重载；且 `CACHE_MODE_REUSE` 下引擎全局 ResourceCache 持引用，手动驱逐（含一处先赋 null 再 erase 的死存储）实际释放不了 VRAM。
- `scenes/world_map.gd:931-935` — `occupation_changed` 在地图可见期间每次过关全量重建 100 个关卡节点（按钮+标签+遮罩，注释自认），与已做好的静态模板缓存形成短板。
- `scenes/ui/buff_fold_card.gd:105-178` — `_process` 有 1 秒节流，但每秒无条件重建 buff/名册/资源三段——含 `get_all_instance_ids()` 全注册表扫描 + 逐实例 `get_card_level()`——无脏标记、不看折叠态。

## P3

- `world_map.gd:1083-1100` — `_process` 每帧字符串 `get_node_or_null` + 每帧更新下一关标记/行军徽标/跟随点（文本 set 已有变更守卫、路径重绘已节流至每 20 帧，剩余为常驻查找与变换）。
- `scenes/title_screen.gd:191-204` `:435-455` — 每帧标题自脉冲 + 每 ~2 帧 `queue_redraw()` 全量重绘 120 星 + ~19 条扫描线（~30Hz 全画布重绘，标题页常驻）。
- `ui_asset_loader.gd:308-319` — 缓存未命中路径 FileAccess 逐行读 `.import` 判断有效性——UI 滚动路径同步磁盘 IO。
- `buff_fold_card.gd:163-165` — 每秒对全部实例逐个 `get_card_level()`（注册表全迭代进 UI 刷新路径）。
- `scenes/bunker/truck_base.gd:473` `:1858-1862` — 内饰已入 `_textures` 缓存，内背景/外景刷新仍每次直调 `_load_era_texture()`（引擎 ResourceCache 缓解，未走自管缓存）。
- `backpack_card_item.gd:272-276`（调用点 :313）— 每次 `set_card` 递归 `find_child("Icon", true, false)`，131 格重建 = 131 次递归搜索。
- `scenes/ui/growth_panel.gd:279-319` `:346-350` — 每次打开/换筛选全量重建成长卡列表（已延迟一帧 + 缩略图，无池化）。
- `scenes/ui/evolution_panel.gd:440-543` — 每次刷新全量重建进化配方列表（缩略图路径正确，无池化）。
- `scenes/ui/bottom_instrument_bar.gd:586-614` — 每帧对每个可部署槽位呼吸 modulate + `EnergyManager.can_afford` 查询（有 motion_reduce 守卫与变更守卫，剩余常驻小开销）。
- `scenes/intro/comic_intro.gd:226-228` `:279-288` — 每次翻格同步 `load()` 原图并重建 11 个进度 ColorRect（一次性场景，影响极小）。

## 确认干净的类别

- **每帧 _process 刷 UI**：card_info_panel.gd:1066-1078（0.4s + 可见守卫）、top_hud_bar.gd:227-234（1s 累加器）、battle_hud/ultimate_cast_bar/resource_bar 全部节流或信号驱动；例外仅 title_screen 与 bottom_instrument_bar（P3）。
- **字体**：design_tokens.gd:276-349 静态缓存三套字体，无每-Label Font 泄漏。
- **信号连接泄漏**：backpack_panel（_ready 守卫连接 + _exit_tree 断连 + 池化时断连）、achievement_panel 等均有守卫；UILazyLoader 实例缓存使重复打开不重复 _ready——无连接数膨胀。
- **基地层**：truck_base.gd 无 `_process`；bunker_room_overlay.gd 状态变迁 + tween 驱动（`_prev_state`/`_prev_level` 守卫）；bunker_ambient 仅 ~20 圆重绘。
- **标杆**：backpack_panel.gd:1018-1081 主网格"按类型池化 + 视口懒加载 + 缩略图"是全项目最佳实践，modification/store/achievement 应向其对齐。
