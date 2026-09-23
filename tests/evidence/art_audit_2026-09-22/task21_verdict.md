# Task 2.1 相位仪图标存在性核对结论（2026-09-22）

- 定义源：`data/phase_instruments.gd` 三张表——`get_all()` 68 台正式仪器 + `STANDARD_PROPERTY_POOL` 12 词条 + `RARE_PROPERTY_POOL` 13 词条。
- 主图 94 = 68 + 12 + 13 + 1（pi_drop）；缩略图 68 = 68 台正式仪器全覆盖。
- **零缺图**：68 台正式仪器主图+缩略图双向齐。
- **挂账 4 缺口全部核销**：pi_umbra_01/02/03（定义+主图+缩略图齐）；pi_r_free_deploy（定义在 RARE_PROPERTY_POOL + 主图在，缺缩略图由 `instrument_icon_small` 回退链覆盖，可选补齐）。
- **真孤儿 1 张**：`assets/ui/instruments/pi_drop.png`——无任何定义与引用（疑似旧掉落率词条遗留），候选删除/留档，只登记不删。
- 25 张词条同 id 主图无缩略图：当前 UI 无词条图标接线（词条池仅 manager 掷取用），属预留资产，非缺陷。
