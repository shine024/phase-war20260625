# 美术资源出库清单（2026-09-07）

本目录收录所有**生产过程产物**——项目运行时不会加载的美术/影像资源，从项目内移出至此，供整体复制到项目外备份。

## 移入内容

| 来源 | 本目录位置 | 内容 | 规模 |
|------|-----------|------|------|
| `资料/` | `资料/` | 单位分帧动画全量源（每单位 idle/attack 帧 PNG + source.mp4 原始视频 + meta/_task.json + .gdignore） | 9399 文件 / 1.77 GB |
| `docs/` 图片 | `docs/`（保持原目录结构） | 设计稿、AI 生成底图/待生成队列、基地重设计 caps、VFX 审计截图（vfx_audit_shots / vfx_audit_sheets / vfx_realism_shots / boss_spell_shots）、enemy_fire_icons、重修背景图/重修改卡图、出击面板参考、3x3_vs_3x3、美术资源预览（无扩展名 PNG）等 | ~802 MB |
| `tools/bg_rework/` 图片 | `tools/bg_rework/` | 背景重加工的检查图/绿幕遮罩 | ~5.6 MB |
| `ui/portraits/` | `ui_portraits/` | 旧人物立绘（aria/helen 等，全项目零引用） | ~2.2 MB |
| 根目录 `_probe4k.png` | `_probe4k.png` | 4K 探针截图 | 3.1 MB |
| （原有） | 根目录散件 + `对比图/` | 此前动画审查截图 | — |

## 判定依据（运行时引用核查）

- 全项目 12093 张图逐一归类；`assets/`（卡面/特效/UI/背景/符文/基地/开场/地图等全部子目录）在代码/场景中有直接或动态路径引用，**全部保留在项目内未动**。
- `资料/`、`docs/`、`tools/`、`ui/portraits` 中的图片经 grep 核对 `*.gd/*.tscn/*.tres/*.json` 均无 `res://` 引用（docs 下的引用全部是审计工具的**写入目标**，运行后目录会自动重建）。
- 已知例外保留：`addons/gdunit4`（编辑器插件图）、根 `icon.svg`（项目图标）、`_steam_assets/`（Steam 发行工作区 479MB，被 make_steam_capsules.py / _tmp_steam_cap.gd 等脚本引用，未移）。

## 还原须知

- docs 生成链依赖：基地房间升级图重烘焙需 `docs/基地重设计/generated5/` 的 caps 源图（现已在此处备份，需要重跑烘焙时复制回项目）。
- 动画分帧再加工需 `资料/单位分帧动画/`（工具链产出 sprite sheet 的输入）。
- 审计工具（vfx_audit_matrix / boss_spell_audit）的输出目录 `docs/vfx_audit_shots/`、`docs/boss_spell_shots/` 已随图片移出，目录会在下次运行时自动重建，历史截图在此处 `docs/` 下。
