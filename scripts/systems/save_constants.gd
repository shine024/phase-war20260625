class_name SaveConstants
extends RefCounted
## 存档数据键名常量（SAV-1 提取自 save_manager.gd）

## ─── 存档数据键名常量 ───
const SK_SCHEMA_VERSION: String = "__schema_version"
# v7.0: 卡牌实例表（必须最先加载，背包/相位仪/养成消费者依赖它）
const SK_INSTANCES: String = "instances"
const SK_BLUEPRINT: String = "blueprint"
const SK_BASIC_RESOURCES: String = "basic_resources"
const SK_PHASE_LAW: String = "phase_law"
const SK_QUEST: String = "quest"
const SK_FACTION_SYSTEM: String = "faction_system"
const SK_AFFIX_DATA: String = "affix_data"
const SK_LEVEL_PROGRESS: String = "level_progress"
const SK_DROP_MANAGER: String = "drop_manager"
const SK_GAME: String = "game"
const SK_CURRENT_LEVEL: String = "current_level"
const SK_PHASE_SLOTS: String = "phase_slots"
const SK_PHASE_SLOTS_ORDER: String = "phase_slots_order"
const SK_PHASE_INSTRUMENT: String = "phase_instrument"
const SK_BACKPACK_EXTRA_IDS: String = "backpack_extra_ids"
const SK_LORE: String = "lore"
const SK_STAT_BOOST: String = "stat_boost"
const SK_ACHIEVEMENT: String = "achievement"
const SK_DAILY_TASK: String = "daily_task"
const SK_DAY_CLOCK: String = "day_clock"
# v7.x 数据一致性核对：SK_STATISTICS（"statistics"）已删除——StatisticsManager 全项目
# 无 record_* 调用者（数据恒为 0），整个统计系统为死代码已移除。save_manager.gd 保留
# 字面量 "statistics" 仅用于兼容旧存档读取（load_state 忽略缺失键）。
const SK_CARD_ENHANCEMENT: String = "card_enhancement"
# v7.x 数据一致性核对：SK_LAW_SHARDS（"law_shards"）已删除——全项目零引用，疑似旧"法则碎片"系统残留。
const SK_TUTORIAL_PROGRESS: String = "tutorial_progress"
const SK_CHARACTERS: String = "characters"
const SK_CHALLENGE_RECORDS: String = "challenge_records"
const SK_CARD_COLLECTION: String = "card_collection"
const SK_LEADERBOARD: String = "leaderboard"
const SK_LEGACY_COMPANY_REP: String = "_legacy_company_rep"
# v9.x（P2-7范围C）：合成系统整体删除——旧档 "synthesis_state" key 由 FactionSystemManager
# 读档路径 key 级静默跳过（不再有消费方）。
# v6.6: 情报系统存档键
const SK_INTEL_MANUAL: String = "intel_manual"
const SK_INTEL_DISCOVERY: String = "intel_discovery"
const SK_INTEL_EVOLUTION: String = "intel_evolution"
# v7.x: SK_INTEL_ITEM_BAG 从 save_manager.gd:131 迁移至此集中（与其余4个情报键并列；SAV-1 常量提取初衷）
const SK_INTEL_ITEM_BAG: String = "intel_item_bag"
# v8.x: 相位师技能树（unlocked_nodes / spent_points / bonus_points / phase_field_level）
# BUG 修复：原 PhaseMasterSkillManager 有 save_state/load_state 但从未接入存档系统，
# 导致技能点（含测试模式 add_bonus_points 发放的）重启/读档后全部丢失。
const SK_PHASE_MASTER_SKILL: String = "phase_master_skill"
# v6.6: 挂机系统存档键（slots/mode/push_level/accumulated_rewards）
const SK_AFK: String = "afk"
