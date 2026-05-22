# 候选卡面美术归档

非正式入库的势力底图 / 卡框候选，已从 `backgrounds_choice/`、`frames_choice/`、`frames_v2/` 及 `frames/Game_card_frame_border_*` 移入此目录。

- 文件名：`原ID_中文名.png`
- 对照表：`_index.csv`
- 与正式资源重复、已从归档删除的记录：`_removed_duplicates_of_formal.csv`（共 13 张，正式版保留在 `backgrounds/` 与 `frames/`）
- 正式资源仍在：
  - `assets/cards/backgrounds/`（8 张势力底，来自 v3 纹章套）
  - `assets/cards/frames/`（5 张稀有度框，来自 C 华丽套）

重新生成候选图时，对应脚本会重建 `backgrounds_choice/` 等目录；满意后再 Copy-Item 到正式目录。
