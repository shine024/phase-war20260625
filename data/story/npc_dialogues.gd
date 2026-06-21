extends RefCounted
class_name NPCDialogues
## v6.6(剧情): NPC 对话数据 — docs/补剧情.txt 补充角色（洛克/林薇/扎克/海伦/真实者）的支线对话
##
## 设计：与现有 main_story_nodes.gd 的"参谋长/情报官"通用旁白并存。
## 通用旁白承载功能性引导，本文件承载角色情感弧线和分支剧情。
##
## 每条对话结构：
##   {
##     "id": "linwei_return",                # 对话唯一ID（也是触发幂等标记）
##     "day_min": 40, "day_max": 40,         # 触发天数区间（含两端，<=0 表示不限）
##     "relationship_req": 0,                # 最低好感度要求（<0 表示要求上限，此处只用>=0）
##     "flags_required": {key: true},        # 必须已设置的标记（值需匹配）
##     "flags_blocked": [key, ...],          # 任一存在则不触发
##     "lines": [ {"speaker":"林薇","text":"..."} ],  # 对话内容
##     "grant_flags": {key: value},          # 播完后设置标记
##     "relationship_change": {"locke": 5},  # 播完后调整好感度
##     "reveal_quest": "quest_id",           # 播完后揭示任务（本轮仅记录标记，不接QuestManager）
##     "force_location": "market"            # 强制在指定地点触发（空=任意地点）
##   }
##
## 查询接口：
##   get_dialogue(npc_id, day, relationship, story_flags, used_ids) -> Dictionary

const StoryFlags := preload("res://data/story/story_flags.gd")

# ═══════════════════════════════════════════════════════════════════
# NPC ID 常量（与 CharacterManager 注册的 character_id 一致）
# ═══════════════════════════════════════════════════════════════════
const NPC_LOCKE: String = "locke"        # 洛克 — 引导者，止步83关
const NPC_LINWEI: String = "linwei"      # 林薇 — 四叶草商店店主
const NPC_ZACK: String = "zack"          # 扎克 — 训练场教官，停在48关
const NPC_HELEN: String = "helen"        # 海伦 — 每日播报者/城市管理者
const NPC_REALIST: String = "realist"    # 真实者 — 反派/亦敌亦友
const NPC_CHENMO: String = "chenmo"      # 陈末留言（未来自己，非交互NPC）

# ═══════════════════════════════════════════════════════════════════
# 对话数据库
# ═══════════════════════════════════════════════════════════════════

const DIALOGUES: Dictionary = {
	# ─────────────────────────────────────────────────────────────
	# 洛克（Locke）— 引导者
	# ─────────────────────────────────────────────────────────────
	NPC_LOCKE: [
		{
			"id": "locke_intro",
			"day_min": 1, "day_max": 3,
			"relationship_req": 0,
			"flags_required": {}, "flags_blocked": ["locke_intro_done"],
			"lines": [
				{"speaker": "洛克", "text": "嘿，新面孔。欢迎来到无限城——E-10947，这是你的编号。"},
				{"speaker": "洛克", "text": "我是洛克，比你早来一些日子。这座城市看起来很大，但能救命的只有几样东西：声望、战力，和你在传送门里拿到的卡。"},
				{"speaker": "洛克", "text": "听好——别相信真实者。不管他们说什么。还有，别在能量罩的数字归零前死掉。"},
				{"speaker": "陈末", "text": "……我知道了。"},
			],
			"grant_flags": {"locke_intro_done": true},
			"relationship_change": {"locke": 5},
			"force_location": "command_center",
		},
		{
			"id": "locke_warning_realist",
			"day_min": 25, "day_max": 27,
			"relationship_req": 10,
			"flags_required": {StoryFlags.REALIST_FIRST_CONTACT: true},
			"flags_blocked": ["locke_warning_realist_done"],
			"lines": [
				{"speaker": "洛克", "text": "听说真实者找上你了。听我的，他们那张嘴能把死的说成活的。"},
				{"speaker": "洛克", "text": "他们说你看到的5742次重启是假的？呵。真假有那么重要吗？你今天还在这里，就够了。"},
				{"speaker": "陈末", "text": "可如果他们说的是真的呢？"},
				{"speaker": "洛克", "text": "那就当我没说。但记住——无论真假，死在这里就是真的死。"},
			],
			"grant_flags": {"locke_warning_realist_done": true},
			"relationship_change": {"locke": 3},
			"force_location": "",
		},
		{
			"id": "locke_missing",
			"day_min": 100, "day_max": 102,
			"relationship_req": 30,
			"flags_required": {}, "flags_blocked": [StoryFlags.LOCKE_MISSING_DAY100],
			"lines": [
				{"speaker": "林薇", "text": "洛克……不见了。已经两天了。他平时从不会这样。"},
				{"speaker": "海伦", "text": "洛克向系统申请了量子体保护序列，这是高阶相位师才能用的应急措施。他暂时无法被任何人联系。"},
				{"speaker": "陈末", "text": "他到底遇到了什么？"},
				{"speaker": "海伦", "text": "这是居民自己要解决的事。我只能告诉你：他还活着。"},
			],
			"grant_flags": {StoryFlags.LOCKE_MISSING_DAY100: true, StoryFlags.LOCKE_PROTECTION_SEQ: true},
			"relationship_change": {},
			"force_location": "command_center",
		},
		{
			"id": "locke_return_83",
			"day_min": 280, "day_max": 282,
			"relationship_req": 50,
			"flags_required": {StoryFlags.PASSED_83: true},
			"flags_blocked": ["locke_return_83_done"],
			"lines": [
				{"speaker": "洛克", "text": "你做到了。83关——那道门，我站在它前面整整三天，最终没能走进去。"},
				{"speaker": "洛克", "text": "你做得比我好。不只是战力，是那份……你说的'我愿意付出所有'。我当年说不出这句话。"},
				{"speaker": "陈末", "text": "也没什么特别的。我只是已经没什么可失去的了。"},
				{"speaker": "洛克", "text": "呵……也许这才是最强的相位。谢谢。"},
			],
			"grant_flags": {"locke_return_83_done": true},
			"relationship_change": {"locke": 30},
			"force_location": "void_rift",
		},
		{
			"id": "locke_sendoff_100",
			"day_min": 364, "day_max": 364,
			"relationship_req": 40,
			"flags_required": {}, "flags_blocked": ["locke_sendoff_100_done"],
			"lines": [
				{"speaker": "洛克", "text": "100关门前，我送你到这里。"},
				{"speaker": "洛克", "text": "这一路你替我走完了48关之后的所有路，替我过了83关……剩下的，是你自己的了。"},
				{"speaker": "陈末", "text": "洛克，谢了。从一开始到现在。"},
			],
			"grant_flags": {"locke_sendoff_100_done": true},
			"relationship_change": {"locke": 10},
			"force_location": "void_rift",
		},
	],

	# ─────────────────────────────────────────────────────────────
	# 林薇（Linwei）— 四叶草商店店主
	# ─────────────────────────────────────────────────────────────
	NPC_LINWEI: [
		{
			"id": "linwei_intro",
			"day_min": 5, "day_max": 12,
			"relationship_req": 0,
			"flags_required": {}, "flags_blocked": ["linwei_intro_done"],
			"lines": [
				{"speaker": "林薇", "text": "欢迎光临四叶草。东西都在架子上，看中什么直接说。"},
				{"speaker": "林薇", "text": "你是新来的E-10947？洛克跟我提过你。新手第一张卡，我给你打个折。"},
				{"speaker": "陈末", "text": "为什么叫四叶草？"},
				{"speaker": "林薇", "text": "……一个老朋友起的。她总说运气比实力重要。后来我才明白，能遇到运气本身就是实力。"},
			],
			"grant_flags": {"linwei_intro_done": true},
			"relationship_change": {"linwei": 5},
			"force_location": "market",
		},
		{
			"id": "linwei_return",
			"day_min": 40, "day_max": 42,
			"relationship_req": 20,
			"flags_required": {}, "flags_blocked": [StoryFlags.LINWEI_RETURN],
			"lines": [
				{"speaker": "陈末", "text": "林薇？店……关了一天。我以为你出事了。"},
				{"speaker": "林薇", "text": "……抱歉。我去办了点私事。"},
				{"speaker": "陈末", "text": "你的能量球……有裂纹。怎么回事？"},
				{"speaker": "林薇", "text": "（沉默良久）……你听说过E-10946吗？只差一个编号的那个。"},
				{"speaker": "陈末", "text": "没有。"},
				{"speaker": "林薇", "text": "……下次需要帮忙，叫我。"},
			],
			"grant_flags": {StoryFlags.LINWEI_RETURN: true, StoryFlags.LINWEI_MENTION_10946: true, StoryFlags.LINWEI_HELP_OFFER: true},
			"relationship_change": {"linwei": 15},
			"reveal_quest": "q_linwei_secret",
			"force_location": "market",
		},
		{
			"id": "linwei_gift_crystal",
			"day_min": 62, "day_max": 65,
			"relationship_req": 30,
			"flags_required": {StoryFlags.GUARDIAN_20_ATTEMPT_1: true},
			"flags_blocked": ["linwei_gift_crystal_done"],
			"lines": [
				{"speaker": "林薇", "text": "听说你在第20关吃了亏？那面能量巨墙……不是靠蛮力能破的。"},
				{"speaker": "林薇", "text": "这个修复晶核给你。不是卖，是借。等你过了20关，再还我一颗更好的。"},
				{"speaker": "陈末", "text": "林薇……为什么对我这么好？"},
				{"speaker": "林薇", "text": "因为你让我想起一个人。一个我也没来得及帮上的人。"},
			],
			"grant_flags": {"linwei_gift_crystal_done": true},
			"relationship_change": {"linwei": 10},
			"force_location": "market",
		},
	],

	# ─────────────────────────────────────────────────────────────
	# 扎克（Zack）— 训练场教官，停在48关
	# ─────────────────────────────────────────────────────────────
	NPC_ZACK: [
		{
			"id": "zack_intro",
			"day_min": 8, "day_max": 14,
			"relationship_req": 0,
			"flags_required": {}, "flags_blocked": ["zack_intro_done"],
			"lines": [
				{"speaker": "扎克", "text": "你就是洛克带来的那个新手？来，先在这个靶场跑两圈。"},
				{"speaker": "扎克", "text": "记住一句话——卡只是工具。真正决定胜负的是你怎么用它，以及你愿不愿意为了赢付出代价。"},
				{"speaker": "陈末", "text": "听起来你经历得不少。"},
				{"speaker": "扎克", "text": "（笑）……够了。开练。"},
			],
			"grant_flags": {"zack_intro_done": true},
			"relationship_change": {"zack": 5},
			"force_location": "training_ground",
		},
		{
			"id": "zack_48_truth",
			"day_min": 100, "day_max": 105,
			"relationship_req": 20,
			"flags_required": {}, "flags_blocked": [StoryFlags.ZACK_ENGINEER_MEMORY],
			"lines": [
				{"speaker": "陈末", "text": "扎克？你怎么一个人坐在这里……"},
				{"speaker": "扎克", "text": "我停在48关。三年了。每次走到那扇门前，脑子里就会涌出一堆不属于我的记忆——齿轮、图纸、一个工厂……"},
				{"speaker": "扎克", "text": "我以前……好像是个工程师。不是相位师。但在进入无限城那一刻，那些记忆就被锁住了。"},
				{"speaker": "陈末", "text": "……我明白了。"},
				{"speaker": "扎克", "text": "如果你哪天能走到48关，替我看看——门后面到底是什么。这就是我唯一的请求。"},
			],
			"grant_flags": {StoryFlags.ZACK_ENGINEER_MEMORY: true, StoryFlags.ZACK_PROMISE_48: true},
			"relationship_change": {"zack": 20},
			"reveal_quest": "q_zack_beyond_48",
			"force_location": "training_ground",
		},
	],

	# ─────────────────────────────────────────────────────────────
	# 海伦（Helen）— 每日播报者/城市管理者
	# ─────────────────────────────────────────────────────────────
	NPC_HELEN: [
		{
			"id": "helen_first_broadcast",
			"day_min": 1, "day_max": 1,
			"relationship_req": 0,
			"flags_required": {}, "flags_blocked": ["helen_first_broadcast_done"],
			"lines": [
				{"speaker": "海伦", "text": "早安，无限城的居民们。我是海伦。今日是第1天，能量罩剩余天数：365。"},
				{"speaker": "海伦", "text": "新编号E-10947已激活。请各位居民遵守城市公约：传送门每日开放时段请勿越界；声望低于阈值的居民将被限制进入高阶关卡。"},
				{"speaker": "海伦", "text": "祝各位今日平安。"},
			],
			"grant_flags": {"helen_first_broadcast_done": true},
			"relationship_change": {},
			"force_location": "command_center",
		},
		{
			"id": "helen_guidance_east7",
			"day_min": 18, "day_max": 20,
			"relationship_req": 0,
			"flags_required": {}, "flags_blocked": ["helen_guidance_east7_done"],
			"lines": [
				{"speaker": "海伦", "text": "E-10947，请留意：东区7号传送门近期刷新了一张适合你当前战力的卡。"},
				{"speaker": "海伦", "text": "这并非特殊优待，只是城市系统的例行提示。是否前往，由你自行决定。"},
			],
			"grant_flags": {"helen_guidance_east7_done": true},
			"relationship_change": {},
			"force_location": "command_center",
		},
		{
			"id": "helen_e2301",
			"day_min": 150, "day_max": 152,
			"relationship_req": 0,
			"flags_required": {StoryFlags.REALIST_THREATENED: true},
			"flags_blocked": [StoryFlags.E_2301_VANISHED],
			"lines": [
				{"speaker": "陈末", "text": "海伦！真实者又出现了，这次是威胁。E-2301他们说要'处理'我……"},
				{"speaker": "海伦", "text": "我知道了。无限城的矛盾，由居民自己解决——这是原则。"},
				{"speaker": "海伦", "text": "（片刻后）……但E-2301刚才已经从城市居民名单中移除了。系统判定其行为越界。"},
				{"speaker": "陈末", "text": "是你做的？"},
				{"speaker": "海伦", "text": "我只是执行了系统既有的规则。请继续你的旅程。"},
			],
			"grant_flags": {StoryFlags.E_2301_VANISHED: true},
			"relationship_change": {},
			"force_location": "command_center",
		},
		{
			"id": "helen_countdown",
			"day_min": 340, "day_max": 340,
			"relationship_req": 0,
			"flags_required": {}, "flags_blocked": [StoryFlags.HELEN_COUNTDOWN_ANNOUNCED],
			"lines": [
				{"speaker": "海伦", "text": "全城广播。距离能量罩归零，还有25天。"},
				{"speaker": "海伦", "text": "自即刻起，所有传送门全天开放；战斗奖励提升至3倍。这是最后的冲刺，请各位倾尽所有。"},
				{"speaker": "海伦", "text": "……以及，洛克已申请量子体保护序列。在他归来前，请不要打扰。"},
			],
			"grant_flags": {StoryFlags.HELEN_COUNTDOWN_ANNOUNCED: true, StoryFlags.LOCKE_PROTECTION_SEQ: true},
			"relationship_change": {},
			"force_location": "command_center",
		},
		{
			"id": "helen_truth_revealed",
			"day_min": 365, "day_max": 365,
			"relationship_req": 0,
			"flags_required": {StoryFlags.PASSED_100: true},
			"flags_blocked": [StoryFlags.TRUTH_REVEALED],
			"lines": [
				{"speaker": "海伦", "text": "E-10947。在你做最终选择前，有一件事我必须告诉你。"},
				{"speaker": "海伦", "text": "能量罩上的数字5742:0——5742次重启，是假的。"},
				{"speaker": "海伦", "text": "真实情况是：你已经是第5743次。前5742次，全部失败。"},
				{"speaker": "陈末", "text": "……那现在的我，是第5743次的陈末。"},
				{"speaker": "海伦", "text": "是的。也是唯一一个走到这一步的陈末。双重跳跃协议已就绪——选择权在你。"},
			],
			"grant_flags": {StoryFlags.TRUTH_REVEALED: true},
			"relationship_change": {},
			"force_location": "void_rift",
		},
	],

	# ─────────────────────────────────────────────────────────────
	# 真实者（Realist）— 反派/亦敌亦友
	# ─────────────────────────────────────────────────────────────
	NPC_REALIST: [
		{
			"id": "realist_first_contact",
			"day_min": 25, "day_max": 25,
			"relationship_req": 0,
			"flags_required": {}, "flags_blocked": [StoryFlags.REALIST_CONTACTED],
			"lines": [
				{"speaker": "真实者", "text": "E-10947。我叫真实者。我们观察你很久了。"},
				{"speaker": "真实者", "text": "你有没有想过——海伦每天播报的那个5742，是真的吗？"},
				{"speaker": "陈末", "text": "你是谁？怎么进来的？"},
				{"speaker": "真实者", "text": "我们是清醒的人。我们看到了这座城市的真相：一切都在循环，而你被设计成永远走不到尽头。"},
				# v6.6(剧情): 分支选择节点（补剧情.txt 第四幕 加入/拒绝/拖延）
				{"speaker": "真实者", "text": "那么，你的回答是？", "choices": [
					{
						"text": "我加入你们。",
						"branch_key": "join",
						"response": [
							{"speaker": "真实者", "text": "明智的选择。从今天起，你是我们的一员。我会指引你找到海伦隐瞒的真相。"},
							{"speaker": "陈末", "text": "（……我已经没什么可失去的了。）"},
						],
					},
					{
						"text": "我拒绝。海伦相信我，我不会背叛她。",
						"branch_key": "reject",
						"response": [
							{"speaker": "真实者", "text": "……遗憾。但我尊重你的选择。记住，你今天拒绝的，或许正是你明天需要的。"},
							{"speaker": "陈末", "text": "……我不会后悔。"},
						],
					},
					{
						"text": "我再想想。现在还做不了决定。",
						"branch_key": "delay",
						"response": [
							{"speaker": "真实者", "text": "谨慎。这很好。那证明给我看——在你想清楚之前，先证明你有资格站在任何一边。"},
							{"speaker": "陈末", "text": "……我会的。"},
						],
					},
				]},
			],
			"grant_flags": {StoryFlags.REALIST_FIRST_CONTACT: true, StoryFlags.REALIST_CONTACTED: true},
			"relationship_change": {"realist": 0},
			"reveal_quest": "q_realist_invite",
			"quest_id_for_choice": "q_realist_invite",
			"force_location": "aether_tower",
		},
		{
			"id": "realist_second_threat",
			"day_min": 150, "day_max": 150,
			"relationship_req": 0,
			"flags_required": {StoryFlags.REALIST_CONTACTED: true},
			"flags_blocked": [StoryFlags.REALIST_THREATENED],
			"lines": [
				{"speaker": "真实者", "text": "你拒绝了我们的邀请。我尊重你的选择，但耐心是有限的。"},
				{"speaker": "真实者", "text": "E-2301会去'拜访'你。这只是个开始。如果你继续替海伦卖命，下一次来的就不是E-2301了。"},
				{"speaker": "陈末", "text": "……你们到底想要什么？"},
				{"speaker": "真实者", "text": "我们想要的，和你一样——一个不在循环里重来的未来。"},
			],
			"grant_flags": {StoryFlags.REALIST_THREATENED: true},
			"relationship_change": {"realist": -10},
			"force_location": "aether_tower",
		},
	],

	# ─────────────────────────────────────────────────────────────
	# 陈末（Chenmo）— 主角内心独白 / 二周目专属（补剧情.txt 第十二幕）
	# 非交互NPC，承载剧情旁白和二周目开局演出
	# ng_plus_required=true 确保只有二周目才触发
	# ─────────────────────────────────────────────────────────────
	NPC_CHENMO: [
		{
			"id": "chenmo_ngplus_awaken",
			"day_min": 1, "day_max": 1,
			"relationship_req": 0,
			"flags_required": {StoryFlags.PASSED_100: true},
			"flags_blocked": ["chenmo_ngplus_awaken_done"],
			"ng_plus_required": true,
			"lines": [
				{"speaker": "旁白", "text": "虚空。无尽的、深蓝色的虚空。没有上下，没有远近，只有时间线流淌的微光。"},
				{"speaker": "陈末", "text": "……我醒着。但我不在任何地方。"},
				{"speaker": "陈末", "text": "那个相位仪——它还在。但表盘变成了深蓝色，里面浮现着我认识又不认识的图案。是记忆。"},
				{"speaker": "旁白", "text": "远处，一个微弱的光点正在靠近。不是洛克，不是林薇，不是这座无限城里的任何一个人。"},
				{"speaker": "陈末", "text": "新的……相位师？还是另一条时间线的我？"},
				{"speaker": "旁白", "text": "光点越来越近。新的无限城，新的365天，新的故事。但你携带的符文——那份穿越轮回的力量——与你同在。"},
			],
			"grant_flags": {"chenmo_ngplus_awaken_done": true},
			"relationship_change": {},
			"force_location": "command_center",
		},
		{
			"id": "chenmo_ngplus_core_glow",
			"day_min": 3, "day_max": 5,
			"relationship_req": 0,
			"flags_required": {"chenmo_ngplus_awaken_done": true},
			"flags_blocked": ["chenmo_ngplus_core_glow_done"],
			"ng_plus_required": true,
			"lines": [
				{"speaker": "陈末", "text": "时间核上的图案越来越清晰了。是一座城市——不，是无数座城市的叠影。"},
				{"speaker": "陈末", "text": "每一座都是一条时间线的无限城。每一座都死了5742次，直到我。"},
				{"speaker": "陈末", "text": "……这一次，我不会让新无限城重蹈覆辙。"},
			],
			"grant_flags": {"chenmo_ngplus_core_glow_done": true},
			"relationship_change": {},
			"force_location": "aether_tower",
		},
	],
}

# ═══════════════════════════════════════════════════════════════════
# 查询接口
# ═══════════════════════════════════════════════════════════════════

## 获取某 NPC 在指定条件下应触发的对话（返回第一条匹配的，空字典表示无）
## 参数：
##   npc_id        - NPC标识
##   day           - 当前天数
##   relationship  - 与该NPC的当前好感度
##   story_flags   - StoryManager.get_all_story_flags() 的副本
##   used_ids      - 已播放过的对话id集合（用 story_flag "dialog_used_"+id 记录）
static func get_dialogue(npc_id: String, day: int, relationship: int, story_flags: Dictionary, used_ids: Array) -> Dictionary:
	if not DIALOGUES.has(npc_id):
		return {}
	for entry in DIALOGUES[npc_id]:
		var eid: String = entry.get("id", "")
		# 幂等：已播放过的对话不重复触发
		if used_ids.has(eid):
			continue
		# 天数区间检查
		var dmin: int = int(entry.get("day_min", 0))
		var dmax: int = int(entry.get("day_max", 0))
		if dmin > 0 and day < dmin:
			continue
		if dmax > 0 and day > dmax:
			continue
		# 好感度要求
		var req_rel: int = int(entry.get("relationship_req", 0))
		if relationship < req_rel:
			continue
		# 必须已设置的标记
		var flags_required: Dictionary = entry.get("flags_required", {})
		var req_ok: bool = true
		for fk in flags_required:
			var want: Variant = flags_required[fk]
			var have: Variant = story_flags.get(fk, null)
			if have == null or (want is bool and not bool(have)) or (not (want is bool) and have != want):
				req_ok = false
				break
		if not req_ok:
			continue
		# 阻断标记（任一存在则跳过）
		var flags_blocked: Array = entry.get("flags_blocked", [])
		var blocked: bool = false
		for fk in flags_blocked:
			if story_flags.has(fk):
				blocked = true
				break
		if blocked:
			continue
		# v6.6(剧情): 二周目专属对话（补剧情.txt 第十二幕）
		# ng_plus_required=true 时只有二周目才触发；ng_plus_required=false（默认）时只有一周目
		# 未设置该字段的对话两轮都可触发
		if entry.has("ng_plus_required"):
			var want_ng: bool = bool(entry.get("ng_plus_required", false))
			if want_ng != _is_ng_plus_active():
				continue
		# 全部条件满足
		return entry
	return {}

## 获取某 NPC 的全部对话条目（调试/UI展示用）
static func get_all_dialogues_for(npc_id: String) -> Array:
	return DIALOGUES.get(npc_id, [])

## 获取所有 NPC ID
static func get_all_npc_ids() -> Array:
	return DIALOGUES.keys()

## 应用对话播完后的副作用：返回应设置的 flags + relationship change
## 由调用方（NPCDialogSystem）负责实际写入 StoryManager/CharacterManager
static func apply_post_effects(entry: Dictionary) -> Dictionary:
	return {
		"grant_flags": entry.get("grant_flags", {}),
		"relationship_change": entry.get("relationship_change", {}),
		"reveal_quest": entry.get("reveal_quest", ""),
		"dialog_id": entry.get("id", ""),
	}

## v6.6(剧情): 查询当前是否处于二周目（RefCounted 静态方法需通过 SceneTree 访问 GameManager）
static func _is_ng_plus_active() -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var gm: Node = tree.root.get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("is_ng_plus_active"):
		return gm.is_ng_plus_active()
	return false
