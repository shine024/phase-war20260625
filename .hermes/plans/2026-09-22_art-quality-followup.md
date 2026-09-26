# 美术质检修复批收尾 + 遗留项计划（2026-09-22 第二份）

> 前置：`.hermes/plans/2026-09-22_art-quality-audit.md`（四块全量审计）已执行完毕；其修复批 v6.21.3 大部分已落地（详见 `docs/CHANGELOG.md` v6.21.3 两段 + `docs/美术资产质检报告_2026-09-22.md`）。
> 本文件只覆盖**未完成项**，按优先级排序，交接给其他执行软件可直接照跑。
> 执行约定（继承原计划）：测试全程只用槽 2 专用测试档；不主动 commit；证据落 `tests/evidence/art_audit_2026-09-22/`；改代码/数据后跑 gdunit 全量门禁（当前基线 **458 用例全绿**，含新增回归锁 `tests/unit/data/test_enemy_blueprint_era.gd` 3 用例）。

---

## 当前落盘状态（交接快照，2026-09-22）

**已改动的跟踪文件**（均未 commit）：`data/enemy_blueprints.gd`（era 修复）、`scripts/ui_asset_loader.gd`（override 4 条）、`export_presets.cfg`（gem_debug 排除）、`docs/CHANGELOG.md`（v6.21.3 两段）。
**新增未跟踪**：`tests/unit/data/test_enemy_blueprint_era.gd`、审计/生成脚本 6 个（tests/_tmp_art_audit_task11.gd、task21.gd、tools/_tmp_art_audit_task41*.py、_tmp_watermark_cleanup.py、_tmp_gen_six_card_icons.py、_tmp_orphan_disposition*.py）、报告与证据目录。
**资产侧已执行**：水印清理 15 张（bak 在 `.godot/art_backup_watermark_20260922/`）、6 张玩家卡专属图（`assets/card_icons/{card_id}.png` 根目录）、孤儿留档 **27 张**（`.godot/art_backup_orphan_20260922/`，清单在 `tests/evidence/art_audit_2026-09-22/orphan_disposition.json`）。
**在途中断点**：孤儿移动后的 gdunit 门禁复跑 + 编辑器重导入**被中断未执行**（即下方 Task A）。

---

## Task A（P0·阻塞收尾）：孤儿留档后的门禁与重导入

上轮执行到"27 张孤儿移入 `.godot/art_backup_orphan_20260922/` + 处置 JSON 落盘"后被中断。移动动作本身已完成，但两步收尾没跑：

1. `--headless --rendering-driver opengl3 --path . --script tests/gdunit4_runner.gd` → 预期 458/458（孤儿零引用，不应有任何波动；若挂，先查 world_map.gd:150 注释匹配外的漏网引用）。
2. `--headless --rendering-driver opengl3 --path . --editor --quit` → 清理被移文件的导入缓存（.import 已随 .png 一并移走，编辑器扫描会把 `.godot/` 里失效条目刷掉）。
3. 验收：gdunit 全绿 + 编辑器无 "res://...png not found" 级 ERROR + 随手开一次世界地图场景确认无缺图（bubble 系 7 张与 pi_drop 已移出，地图节点早已程序化绘制，理论无感知）。

## Task B（P1·文档收尾）

1. CHANGELOG v6.21.3 追加第三段：孤儿处置 27 张留档（清单指向 orphan_disposition.json）+ 3 张设计内保留（gate_near 注记保留 / black_sun、mountain_bunker_marker 接线候选）。
2. `docs/美术资产质检报告_2026-09-22.md` 第四节第 5 条标记 ✅（含"留档而非删除，物理删除待用户最终拍板"注记）。
3. 计划文件 `.hermes/plans/2026-09-22_art-quality-audit.md` 发现清单的孤儿相关行补"已留档"注记。

## Task C（P2·条件触发）：词条小图标层（5 重掷 + 3 底块修补）

**触发条件：词条图标 UI 接线时**（当前 `STANDARD_PROPERTY_POOL`/`RARE_PROPERTY_POOL` 26 张 128px 图标无 UI 消费方，不阻塞任何面板）。

- 重掷 5 张（<6 分）：pi_atk、pi_attack_speed、pi_r_dmg_reflect（空圆圈无语义）、pi_r_energy_fountain（底块未抠）、pi_r_free_deploy（与 first_deploy 同为"①"，零成本语义未表达）。
- **建议程序化 glyph 绘制而非 AI 生成**（极简黑白 glyph 风格 AI 出图不可控；PIL 画 128px 透明底 glyph 与既有词条族一致），旧图 bak 后替换。
- 顺带修补 3 张底块未抠（6 分留观）：pi_hp、pi_r_overload、pi_r_shield——清除图标外的实底方块 alpha。
- 质量红线沿用：重掷上限 3 次、审美终裁归用户。

## Task D（P2·条件触发）：era 修复实机抽验

**触发条件：下次实机试玩**。era 修复（`data/enemy_blueprints.gd`）已过 gdunit + boot smoke，但 era 影响掉落时代通道/制造门/克制建议链，需实机确认：

1. 冷战/现代/近未来关卡击杀敌人掉落蓝图，观察掉落物名称前缀与时代是否一致（bp_cold_* 不再出现在二战关）。
2. 图标显示：蓝图掉落弹窗/背包图纸格的图与名字兵种对得上（防空塔不再显示迫击炮图）。
3. 制造中心列表时代 chips 对蓝图配方的门控行为无异常。

异常回滚点：`data/enemy_blueprints.gd` 单文件，`git diff` 可见全量。

## Task E（P3·需用户设计方向，未拍板不执行）

1. **接线候选 2 张**：`assets/map/black_sun.png`（黑日徽记，8 分）、`assets/map/mountain_bunker_marker.png`（山体碉堡浮岩，9 分）——质量好但零消费方。接入需要设计方向（黑日→黑门无限模式标记？碉堡山→驻守关地图标记？），**待用户给落点再执行**，勿擅自接线。
2. **物理删除**：27 张留档图目前只在 `.godot/art_backup_orphan_20260922/`（.godot 若被整目录清理会丢）——是否转为正式删除或挪入 git 外的长期归档目录，待用户拍板。

---

## 质量红线（继承原计划，全程有效）

1. 目检不可跳过；2. 单张重掷上限 3 次；3. 替换前 bak 快照（先例 `.godot/art_backup_*_2026-09-*` 目录）；4. PNG 不入 git 政策下新增/删除需向用户确认入库路径；5. 生成图走 STRICT_PREFIX（本批 6 张卡图已按此执行，管线脚本 `tools/_tmp_gen_six_card_icons.py` 可复跑；Windows 下必须 curl 子进程 + 临时文件传体）。

## 执行顺序与预估

| 顺序 | 任务 | 量 | 备注 |
|------|------|----|------|
| 1 | Task A 门禁+重导入 | 2 条命令 | 上轮中断点，最先跑 |
| 2 | Task B 文档收尾 | 3 处编辑 | 纯文档 |
| 3 | Task C 词条图标 | 8 张 | 等接线时机，可长期挂起 |
| 4 | Task D 实机抽验 | 3 项观察 | 等下次试玩 |
| 5 | Task E 接线/删除 | 待拍板 | 阻塞在用户决策 |
