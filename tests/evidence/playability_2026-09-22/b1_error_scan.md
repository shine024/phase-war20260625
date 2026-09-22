# B1.1e 日志扫描（2026-09-22）

范围：curve_L*_*.log 18 份 + tut_save/tut_probe_reload 2 份 + b1_task11_rerun 1 份（共 21 份进程日志）

## 结论
- SCRIPT ERROR：**0**（21 份日志合计）
- ERROR 级（剔除已知良性退出项 ObjectDB instances leaked / N resources still in use / Unreferenced static string 三类后）：**0**
- 教程回退证据：tut_save.log（内存 step=7→存档）+ tut_probe_reload.log（重载 step=1）+ tut_slot2_after_save_snapshot.json（落盘 current_step:1、completed_steps 重复 [1,2,3,1,2,3]）——**正常保存路径即回退，非强退专属**；复现批次已登记，修复归 M6-残/后续批次拍板
- 槽 2 已按 Task 1.1a 备份还原（见 slot2_backup_pre/ → 1.1e 还原步骤）

## ERROR 级行明细分类（2026-09-22 22:50 补记）

- `ERROR: Texture with GL ID of NNN: leaked 131072 bytes.` ×5 类 / `WARNING: 53 RIDs of type CanvasItem were leaked` ×18
  → **驱动器 quit_ok 强退期的 ANGLE 退出清理泄漏**（每轮恰好一组、18 份等量；进程非正常收尾的已知 artifact，
  历史可玩性报告基线同款），非游戏运行期错误。
- `WARNING: [SaveManager] 背包面板不可用，使用上次已知的额外卡ID` ×56 → 无头/驱动环境无 UI 的既知良性告警。
- `WARNING: ...switching to ANGLE` ×20 → 显老驱动自动切 ANGLE 的环境告警。
- 真正的游戏期 ERROR / SCRIPT ERROR：**0**。
