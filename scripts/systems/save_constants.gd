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
const SK_STATISTICS: String = "statistics"
const SK_CARD_ENHANCEMENT: String = "card_enhancement"
# v7.x 数据一致性核对：SK_LAW_SHARDS（"law_shards"）已删除——全项目零引用，疑似旧"法则碎片"系统残留。
const SK_TUTORIAL_PROGRESS: String = "tutorial_progress"
const SK_STORY_PROGRESS: String = "story_progress"
const SK_CHARACTERS: String = "characters"
const SK_CHALLENGE_RECORDS: String = "challenge_records"
const SK_CARD_COLLECTION: String = "card_collection"
const SK_LEADERBOARD: String = "leaderboard"
const SK_LEGACY_COMPANY_REP: String = "_legacy_company_rep"
# v7.x 数据一致性核对：SK_SYNTHESIS（"synthesis_state"）已删除——全项目零引用常量；
# FactionSystemManager 用硬编码字面量 "synthesis_state"（faction_system_manager.gd:676/723），与 SynthesisManager 父子内嵌存档路径一致。
# v6.6: 情报系统存档键
const SK_INTEL_MANUAL: String = "intel_manual"
const SK_INTEL_DISCOVERY: String = "intel_discovery"
const SK_INTEL_EVOLUTION: String = "intel_evolution"
const SK_EOM_MANAGER: String = "eom_manager"
# v7.x: SK_INTEL_ITEM_BAG 从 save_manager.gd:131 迁移至此集中（与其余4个情报键并列；SAV-1 常量提取初衷）
const SK_INTEL_ITEM_BAG: String = "intel_item_bag"
# v6.6: 挂机系统存档键（slots/mode/push_level/accumulated_rewards）
const SK_AFK: String = "afk"
