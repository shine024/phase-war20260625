extends RefCounted
class_name StoryFlags
## v6.6(剧情): 剧情标记常量定义 — docs/补剧情.txt 分支剧情的统一标记 key
##
## 所有 story_flag 字符串集中管理，避免拼写不一致。
## 值存储在 StoryManager._story_flags 中（save_state/load_state 已接入）。
## 调用方式：
##   StoryManager.set_story_flag(StoryFlags.REALIST_CONTACTED)
##   if StoryManager.is_story_flag_true(StoryFlags.PASSED_83): ...

# ═══════════════════════════════════════════════════════════════════
# 真实者（Realist）支线
# ═══════════════════════════════════════════════════════════════════
const REALIST_FIRST_CONTACT: String = "realist_first_contact"        ## 第25天真实者初次接触
const REALIST_CONTACTED: String = "realist_contacted"                ## 玩家已与真实者对话
const REALIST_THREATENED: String = "realist_threatened"              ## 第150天真实者第二次威胁
const REALIST_CHOICE_JOIN: String = "realist_choice_join"            ## 分支：加入真实者
const REALIST_CHOICE_REJECT: String = "realist_choice_reject"        ## 分支：拒绝真实者
const REALIST_CHOICE_DELAY: String = "realist_choice_delay"          ## 分支：拖延真实者
const E_2301_VANISHED: String = "e_2301_vanished"                    ## E-2301 消失（海伦后台处理）

# ═══════════════════════════════════════════════════════════════════
# 林薇（Linwei）支线
# ═══════════════════════════════════════════════════════════════════
const LINWEI_RETURN: String = "linwei_return"                        ## 第40天林薇归来（能量球有裂纹）
const LINWEI_MENTION_10946: String = "linwei_mention_10946"          ## E-10946 伏笔
const LINWEI_HELP_OFFER: String = "linwei_help_offer"               ## 玩家承诺"下次需要帮忙叫我"

# ═══════════════════════════════════════════════════════════════════
# 扎克（Zack）支线
# ═══════════════════════════════════════════════════════════════════
const ZACK_ENGINEER_MEMORY: String = "zack_engineer_memory"          ## 扎克工程师记忆碎片
const ZACK_PROMISE_48: String = "zack_promise_48"                    ## 玩家承诺"到48关时替你看看后面"

# ═══════════════════════════════════════════════════════════════════
# 洛克（Locke）支线
# ═══════════════════════════════════════════════════════════════════
const LOCKE_MISSING_DAY100: String = "locke_missing_day100"          ## 第100天洛克失踪2天
const LOCKE_PROTECTION_SEQ: String = "locke_protection_seq"          ## 洛克申请量子体保护序列

# ═══════════════════════════════════════════════════════════════════
# 关卡守护者节点
# ═══════════════════════════════════════════════════════════════════
const GUARDIAN_20_ATTEMPT_1: String = "guardian_20_attempt_1"        ## 第20关第一次失败（撑7分钟）
const GUARDIAN_20_ATTEMPT_2: String = "guardian_20_attempt_2"        ## 第20关第二次失败（撑12分钟）
const GUARDIAN_20_CLEARED: String = "guardian_20_cleared"            ## 第20关通过
const GUARDIAN_60_SPEAKS: String = "guardian_60_speaks"              ## 第60关守护者开始说话
const PASSED_83: String = "passed_83"                                ## 83关通过（回答"我愿意付出所有"）

# ═══════════════════════════════════════════════════════════════════
# 终局
# ═══════════════════════════════════════════════════════════════════
const HELEN_COUNTDOWN_ANNOUNCED: String = "helen_countdown_announced"  ## 海伦宣告倒计时25天
const TRUTH_REVEALED: String = "truth_revealed"                      ## 海伦坦白真相：入侵是真的，她是传奇指挥官+AI融合体
const PASSED_99: String = "passed_99"                                ## 99关镜像战通过
const PASSED_100: String = "passed_100"                              ## 100关最终试炼通过
const ENDING_CHOICE_GOOD: String = "ending_choice_good"              ## 好结局：接受双重跳跃
const ENDING_CHOICE_BAD: String = "ending_choice_bad"                ## 坏结局：拒绝/失败

# ═══════════════════════════════════════════════════════════════════
# 序章
# ═══════════════════════════════════════════════════════════════════
const PROLOGUE_COMPLETED: String = "prologue_completed"              ## 序章噩梦必败战完成
const FIRST_CARD_RECEIVED: String = "first_card_received"            ## 收到第一张卡"铁壁护盾"

# ═══════════════════════════════════════════════════════════════════
# 元数据查询（用于调试/存档导出）
# ═══════════════════════════════════════════════════════════════════

const FLAG_META: Dictionary = {
	REALIST_FIRST_CONTACT: {"category": "realist", "desc": "真实者初次接触"},
	REALIST_CONTACTED: {"category": "realist", "desc": "已与真实者对话"},
	REALIST_THREATENED: {"category": "realist", "desc": "真实者第二次威胁"},
	REALIST_CHOICE_JOIN: {"category": "realist_choice", "desc": "分支：加入真实者"},
	REALIST_CHOICE_REJECT: {"category": "realist_choice", "desc": "分支：拒绝真实者"},
	REALIST_CHOICE_DELAY: {"category": "realist_choice", "desc": "分支：拖延真实者"},
	E_2301_VANISHED: {"category": "realist", "desc": "E-2301消失"},

	LINWEI_RETURN: {"category": "linwei", "desc": "林薇归来"},
	LINWEI_MENTION_10946: {"category": "linwei", "desc": "E-10946伏笔"},
	LINWEI_HELP_OFFER: {"category": "linwei", "desc": "承诺帮助林薇"},

	ZACK_ENGINEER_MEMORY: {"category": "zack", "desc": "扎克工程师记忆"},
	ZACK_PROMISE_48: {"category": "zack", "desc": "承诺替扎克看48关后面"},

	LOCKE_MISSING_DAY100: {"category": "locke", "desc": "洛克失踪"},
	LOCKE_PROTECTION_SEQ: {"category": "locke", "desc": "洛克进入保护序列"},

	GUARDIAN_20_ATTEMPT_1: {"category": "guardian", "desc": "第20关第1次失败"},
	GUARDIAN_20_ATTEMPT_2: {"category": "guardian", "desc": "第20关第2次失败"},
	GUARDIAN_20_CLEARED: {"category": "guardian", "desc": "第20关通过"},
	GUARDIAN_60_SPEAKS: {"category": "guardian", "desc": "第60关守护者说话"},
	PASSED_83: {"category": "guardian", "desc": "83关通过"},

	HELEN_COUNTDOWN_ANNOUNCED: {"category": "finale", "desc": "海伦宣告倒计时"},
	TRUTH_REVEALED: {"category": "finale", "desc": "真相揭露"},
	PASSED_99: {"category": "finale", "desc": "99关通过"},
	PASSED_100: {"category": "finale", "desc": "100关通过"},
	ENDING_CHOICE_GOOD: {"category": "ending", "desc": "好结局"},
	ENDING_CHOICE_BAD: {"category": "ending", "desc": "坏结局"},

	PROLOGUE_COMPLETED: {"category": "prologue", "desc": "序章完成"},
	FIRST_CARD_RECEIVED: {"category": "prologue", "desc": "收到第一张卡"},
}

## 获取标记的元数据（category/desc）
static func get_flag_meta(flag_key: String) -> Dictionary:
	return FLAG_META.get(flag_key, {"category": "unknown", "desc": ""})

## 获取某分类下的所有标记 key
static func get_flags_by_category(category: String) -> Array[String]:
	var result: Array[String] = []
	for key in FLAG_META:
		if FLAG_META[key].get("category", "") == category:
			result.append(key)
	return result
