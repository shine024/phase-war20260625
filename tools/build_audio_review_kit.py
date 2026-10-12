# -*- coding: utf-8 -*-
"""
build_audio_review_kit.py — 音效/音乐资产审核套件的构建器（可重跑）

用途：把项目全部音频资产 + 授权凭据 + 生成/换曲管线脚本 + 一张离线审核网页
打包到独立文件夹 audio_review_kit/，供「换机审核与重新生成」。

产出结构（audio_review_kit/）：
  index.html                 离线审核网页（单文件，内嵌 <audio> 播放器，相对路径引音）
  使用说明_README.md          换机审核与重新生成步骤
  audio_manifest.json        机器可读资产台账（序号/文件/类别/用途/来源）
  assets/sfx/                全部 .ogg/.wav 副本 + CREDITS.md + README.md
  licenses/                 授权凭据（incompetech/kenney LICENSE_EVIDENCE 与 manifest）
  source_scripts/            合成/换曲管线脚本（sound_generator.gd + tools/*.py）

⚠️ 红线（与 assets/sfx/CREDITS.md 一致）：
  *.ogg 在 .gitignore，git 不保护音频资产。本脚本把音源 + 凭据 + 管线一次性搬走，
  换机即可独立审核/重生成，无需再回读项目 .git。
"""

import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # 项目根
KITSRC_SFX = os.path.join(ROOT, "assets", "sfx")
KIT = os.path.join(ROOT, "audio_review_kit")

KITSRC_SFX_FILES = ["*.ogg", "*.wav"]
KITSRC_SFX_DOCS = ["CREDITS.md", "README.md"]

# 授权凭据：从 _steam_assets/licenses 挑选与音频直接相关的证据文件
LICENSE_SRC = [
    "_steam_assets/licenses/README.md",
    "_steam_assets/licenses/incompetech_20260926/LICENSE_EVIDENCE.md",
    "_steam_assets/licenses/incompetech_20260926/swap_manifest_20260926.json",
    "_steam_assets/licenses/incompetech_20260926/intake_hashes_20260926.json",
    "_steam_assets/licenses/incompetech_20260926/cc-by-4.0_legalcode.txt",
    "_steam_assets/licenses/incompetech_20261008/swap_manifest_20261008.json",
    "_steam_assets/licenses/incompetech_20261010/LICENSE_EVIDENCE.md",
    "_steam_assets/licenses/incompetech_20261010/swap_manifest_20261010.json",
    "_steam_assets/licenses/incompetech_20261010/intake_hashes_20261010.json",
    "_steam_assets/licenses/kenney_20261010/sci-fi-sounds.zip",  # missile_hum 源包（CC0，含 sci-fi thruster）
]

# 生成/换曲管线脚本（重新生成音频所需的真身代码）
SCRIPT_SRC = [
    "managers/sound_generator.gd",           # SFX 运行期合成兜底（方波+噪声→枪械/爆炸/能量武器）
    "tools/_tmp_gen_combat_sfx.py",          # v6.38 战斗程序合成 SFX
    "tools/_tmp_gen_sfx_v642.py",            # v6.42 新配方 button/win/cannon/impact/wakeup_wind
    "tools/_tmp_sfx_swap_v656.py",           # v6.56 RMS 匹配换槽（CC0 真枪换血）
    "tools/_tmp_gen_sfx_v657.py",           # v6.57 story_page 翻格音
    "tools/bgm_swap_from_manifest.py",       # BGM 换曲管线（响度归一+元数据内嵌）
]


def _cp(src, dst_dir):
    """Copy file src (abs or proj-relative) into dst_dir; return dest path or None."""
    s = src if os.path.isabs(src) else os.path.join(ROOT, src)
    if not os.path.exists(s):
        return None
    dst = os.path.join(dst_dir, os.path.basename(s))
    shutil.copy2(s, dst)
    return dst


# ── 资产台账（序号在生成时按分组自动编号）────────────────────────────────────
# 每条目字段：
#   file    文件名（对应 assets/sfx/ 下实体）
#   cat     分组 key（决定颜色与页面顺序）
#   comp    曲目名（BGM）或 中文功能描述
#   where   使用位置（场景/系统 + file:line，尽量具体）
#   trigger 触发条件
#   src     来源/许可
#   note    附加说明（可选）
CAT_ORDER = ["bgm", "ambient", "ui", "combat", "weapon", "event", "progression"]
CAT_LABEL = {
    "bgm": "BGM 背景音乐",
    "ambient": "环境音",
    "ui": "SFX · UI / 系统",
    "combat": "SFX · 战斗通用",
    "weapon": "SFX · 武器类型",
    "event": "SFX · 战斗节奏 / 事件",
    "progression": "SFX · 养成 / 结算",
}

ASSETS = [
    # ── BGM（13）：全部 Kevin MacLeod / incompetech，CC BY 4.0 ──
    dict(file="bgm_title.ogg", cat="bgm", comp="At Launch",
         where="启动首屏：AudioManager._play_initial_bgm（managers/audio_manager.gd:700）；"
               "L100 胜利后结局独白段：_on_battle_ended_bgm（audio_manager.gd:488）",
         trigger="游戏启动即播；战斗结束且 current_level>=100 且胜利时切本曲",
         src="Kevin MacLeod (incompetech.com) · CC BY 4.0 · ISRC USUAN1100539"),
    dict(file="bgm_hub.ogg", cat="bgm", comp="Peaceful Desolation",
         where="基地/大地图时代曲缺失时的回退；其余战斗结束回基地："
               "world_map.gd:297 · truck_base.gd:2794 · world_map_panel.gd:58（经 music_key_for_current_era）；"
               "audio_manager._on_battle_ended_bgm else 分支（audio_manager.gd:490）",
         trigger="music_key_for_current_era 时代曲文件不存在时回落 'hub'；战斗结束非黑门非 L100 时",
         src="Kevin MacLeod · CC BY 4.0 · ISRC USUAN1200017"),
    dict(file="bgm_hub_ww1.ogg", cat="bgm", comp="Man Down",
         where="基地/大地图·一战线：music_key_for_current_era→'hub_ww1'（audio_manager.gd:386）"
               "由 world_map.gd:297 / truck_base.gd:2794 / world_map_panel.gd:58 消费",
         trigger="当前关卡时代=WW1 时大地图/基地 BGM",
         src="Kevin MacLeod · CC BY 4.0 · ISRC USUAN1700086（v6.52.2 新增；8 把大提琴哀伤弦乐）"),
    dict(file="bgm_hub_ww2.ogg", cat="bgm", comp="Take the Lead",
         where="基地/大地图·二战线：music_key_for_current_era→'hub_ww2'（audio_manager.gd:387）",
         trigger="当前关卡时代=WW2 时大地图/基地 BGM",
         src="Kevin MacLeod · CC BY 4.0 · ISRC b62f1a8b-907c-4ba2-922b-49f69cca1be1（v6.52.2 新增）"),
    dict(file="bgm_hub_cold.ogg", cat="bgm", comp="Spy Glass",
         where="基地/大地图·冷战线：music_key_for_current_era→'hub_cold'（audio_manager.gd:388）",
         trigger="当前关卡时代=COLD_WAR 时大地图/基地 BGM",
         src="Kevin MacLeod · CC BY 4.0 · ISRC USUAN1500058（v6.52.2 新增；50 年代侦探爵士）"),
    dict(file="bgm_hub_modern.ogg", cat="bgm", comp="Bass Walker",
         where="基地/大地图·现代线：music_key_for_current_era→'hub_modern'（audio_manager.gd:389）",
         trigger="当前关卡时代=MODERN 时大地图/基地 BGM",
         src="Kevin MacLeod · CC BY 4.0 · ISRC 6053b5b8-cfbd-4277-9370-bfd7c9e52a22（v6.52.2 新增）"),
    dict(file="bgm_hub_future.ogg", cat="bgm", comp="Space Fighter Loop",
         where="基地/大地图·近未来线：music_key_for_current_era→'hub_future'（audio_manager.gd:390）；"
               "另 comic_intro.gd:54 序章直调 'hub_ww1'",
         trigger="当前关卡时代=NEAR_FUTURE 时大地图/基地 BGM",
         src="Kevin MacLeod · CC BY 4.0 · ISRC USUAN1100672（v6.52.2 自 battle_future 挪档，授权同曲沿用）"),
    dict(file="bgm_battle_ww1.ogg", cat="bgm", comp="Devastation and Revenge",
         where="一战战斗 BGM：AudioManager._on_battle_started_bgm era=WW1（audio_manager.gd:369）",
         trigger="进战斗且关卡时代=WW1（battle_started 信号）",
         src="Kevin MacLeod · CC BY 4.0 · ISRC USUAN1100694"),
    dict(file="bgm_battle_ww2.ogg", cat="bgm", comp="Five Armies",
         where="二战战斗 BGM：AudioManager._on_battle_started_bgm era=WW2（audio_manager.gd:370）",
         trigger="进战斗且关卡时代=WW2",
         src="Kevin MacLeod · CC BY 4.0 · ISRC USUAN1100875"),
    dict(file="bgm_battle_cold.ogg", cat="bgm", comp="Crypto",
         where="冷战战斗 BGM：AudioManager._on_battle_started_bgm era=COLD_WAR（audio_manager.gd:371）",
         trigger="进战斗且关卡时代=COLD_WAR",
         src="Kevin MacLeod · CC BY 4.0 · ISRC USUAN1600013"),
    dict(file="bgm_battle_modern.ogg", cat="bgm", comp="Rock Hybrid",
         where="现代战斗 BGM：AudioManager._on_battle_started_bgm era=MODERN（audio_manager.gd:372）",
         trigger="进战斗且关卡时代=MODERN",
         src="Kevin MacLeod · CC BY 4.0 · ISRC USUAN1100094"),
    dict(file="bgm_battle_future.ogg", cat="bgm", comp="Hiding Your Reality",
         where="近未来战斗 BGM：AudioManager._on_battle_started_bgm era=NEAR_FUTURE（audio_manager.gd:373）；"
               "序章梦战 dream_battle.gd:77 直调 'battle_future'",
         trigger="进战斗且关卡时代=NEAR_FUTURE",
         src="Kevin MacLeod · CC BY 4.0 · ISRC USUAN1700081（v6.52.2 换曲，原 Space Fighter Loop 挪 hub_future）"),
    dict(file="bgm_boss.ogg", cat="bgm", comp="Final Battle of the Dark Wizards",
         where="Boss 战 BGM：AudioManager._on_phase_master_appeared_bgm（audio_manager.gd:399）；"
               "黑门无限 run 驻留：_on_battle_ended_bgm run_active→'boss'（audio_manager.gd:486）",
         trigger="相位师/头目登场；黑门无尽 run 中战斗结束不切 hub 而驻留本曲",
         src="Kevin MacLeod · CC BY 4.0 · ISRC USUAN1500085"),

    # ── 环境音（2）：项目内自合成，无第三方素材 ──
    dict(file="ambient_battle_wind.wav", cat="ambient", comp="战场环境风声（含远炮闷响）",
         where="AudioManager._on_battle_started_bgm 尾部 play_ambient('battle_wind')（audio_manager.gd:376）；"
               "battle_ended 时 stop_ambient(1.5)（audio_manager.gd:492）；AMBIENT_MAP audio_manager.gd:499",
         trigger="进战斗起风声底噪循环（独立于 BGM 层）；战斗结束淡出；极速推演期间不停",
         src="项目内程序合成（tools/_tmp_gen_sfx_v642.py 可重跑），无外部授权义务"),
    dict(file="ambient_wakeup_wind.wav", cat="ambient", comp="苏醒演出专用柔化雪原风声",
         where="truck_base.gd:2617 play_ambient('wakeup_wind', 0.45)；演出收场 truck_base.gd:2792 stop_ambient(1.5)；"
               "AMBIENT_MAP audio_manager.gd:501",
         trigger="开场苏醒演出起风声（与战斗 battle_wind 分离，v6.42 专用键）",
         src="项目内程序合成（tools/_tmp_gen_sfx_v642.py 可重跑），无外部授权义务"),

    # ── SFX UI / 系统（8）──
    dict(file="button.ogg", cat="ui", comp="按钮点击音",
         where="全局钩子 AudioManager._on_button_clicked_sfx（node_added→BaseButton.pressed，audio_manager.gd:645）；"
               "TabBar 切标签 _on_tabbar_tab_changed（audio_manager.gd:662）；title_screen.gd:5 / main.gd:7 / "
               "truck_base.gd:1907 / bottom_function_bar.gd 手写 _play_sfx('button')（共约 65 处）",
         trigger="任意按钮按下；极速推演白名单（_FF_SFX_ALLOWLIST）；50ms 去重窗口",
         src="项目内程序合成（方波脉冲）"),
    dict(file="button_hover.ogg", cat="ui", comp="按钮悬停音",
         where="全局钩子 AudioManager._on_button_hovered（node_added→BaseButton.mouse_entered，audio_manager.gd:668）",
         trigger="鼠标悬停到按钮（60ms 节流，音量 0.35）",
         src="项目内程序合成"),
    dict(file="panel_open.ogg", cat="ui", comp="面板打开音",
         where="title_screen.gd / truck_base.gd 面板开（PanelAnim.open 收尾）",
         trigger="打开 overlay 面板；极速推演白名单",
         src="项目内程序合成"),
    dict(file="panel_close.ogg", cat="ui", comp="面板关闭音",
         where="title_screen.gd 面板关（PanelAnim.close）",
         trigger="关闭 overlay 面板；极速推演白名单",
         src="项目内程序合成"),
    dict(file="card_pickup.ogg", cat="ui", comp="卡牌拾取音",
         where="ground_loot_layer.gd（拾取战场遗落卡）；dream_battle.gd 序章拾卡",
         trigger="拾取到卡牌实例",
         src="项目内程序合成"),
    dict(file="card_place.ogg", cat="ui", comp="卡牌放置 / 部署音",
         where="battle_spawn_system.gd:1071（部署单位 play_sound）；main.gd:1292；backpack_card_item_drag.gd:384"
               "（拖入槽位）；backpack_panel.gd:2545（符文放置 _play_rune_sound）；evolution_panel.gd:1271",
         trigger="把卡放进相位仪槽 / 符文槽 / 部署到战场",
         src="项目内程序合成"),
    dict(file="error.ogg", cat="ui", comp="错误 / 失败提示音",
         where="AudioManager._on_player_deploy_failed（audio_manager.gd:624）· _on_energy_insufficient（:627）；"
               "main.gd / truck_base.gd / bottom_function_bar.gd 多处 _play_sfx('error')",
         trigger="部署失败 / 能量不足 / 操作错误；极速推演白名单",
         src="项目内程序合成"),
    dict(file="cancel.ogg", cat="ui", comp="取消 / 回退音",
         where="battle_click_overlay.gd:343（SignalBus.play_sound.emit('cancel')）；"
               "AudioManager._on_enhancement_completed 强化失败分支（audio_manager.gd:588）",
         trigger="取消操作 / 强化合成失败",
         src="项目内程序合成"),
    dict(file="story_page.ogg", cat="ui", comp="剧情漫画翻格音",
         where="comic_intro.gd:54（剧情逐格推进翻页音）；黑门在 intro_comic_panels 第 3 格登场",
         trigger="序章漫画/黑门剧情逐格推进",
         src="项目内程序合成（tools/_tmp_gen_sfx_v657.py 可重跑，seed=20261011）；旧档为 Kenney CC0 划擦声",
         note="v6.57 记录3#1 重制：扫频带通噪声挥扫 + 36Hz 纸颤 + 高频碎纸粒"),

    # ── SFX 战斗通用（10）──
    dict(file="hit.ogg", cat="combat", comp="单位受击（中档）",
         where="AudioManager._on_unit_damaged 伤害 60~150 档（audio_manager.gd:559）；batch 主力命中默认音",
         trigger="单位受击且单发伤害 ∈ [60,150)",
         src="项目内程序合成"),
    dict(file="impact_light.ogg", cat="combat", comp="命中（轻档）",
         where="bullet.gd._play_impact_sfx tier0/1（scenes/units/bullet.gd:1180）；"
               "AudioManager._on_unit_damaged 伤害 <60 档（audio_manager.gd:563）",
         trigger="轻动能命中（手枪弹等直射轻武器）",
         src="项目内程序合成（v6.52 力度分级三档之一）"),
    dict(file="impact_generic.ogg", cat="combat", comp="命中（中档 tier2）",
         where="bullet.gd._play_impact_sfx tier2（scenes/units/bullet.gd:1177）",
         trigger="中等动能命中（直射中档火力）",
         src="项目内程序合成"),
    dict(file="impact_heavy.ogg", cat="combat", comp="命中（重档 tier3）",
         where="bullet.gd._play_impact_sfx tier3（scenes/units/bullet.gd:1176）；"
               "AudioManager._on_unit_damaged 伤害 ≥150 档（audio_manager.gd:559）",
         trigger="重炮/爆炸级命中（单发伤害 ≥150）",
         src="项目内程序合成"),
    dict(file="shoot.ogg", cat="combat", comp="通用射击音",
         where="sound_generator.gd:47 合成兜底（_gen_gunfire 900Hz）；缺文件时运行期合成",
         trigger="通用开火兜底（无武器专属音时用）",
         src="项目内程序合成（运行期 sound_generator 兜底）"),
    dict(file="explosion.ogg", cat="combat", comp="爆炸音",
         where="simple_indirect_projectile_batch.gd（间接/曲射弹爆炸落地）",
         trigger="火箭/曲射弹着地爆炸",
         src="项目内程序合成"),
    dict(file="explosion_big.ogg", cat="combat", comp="大爆炸 / 核爆级",
         where="simple_indirect_projectile_batch.gd（大半径爆炸/终极武器核爆级）",
         trigger="大半径 AOE / 核爆齐射（同名 3 池轮转防截断）",
         src="项目内程序合成（v6.42）"),
    dict(file="cast.ogg", cat="combat", comp="施法 / 相位法则",
         where="dream_battle.gd（序章梦战施法特效）",
         trigger="施放相位法则/技能",
         src="项目内程序合成（正弦扫频）"),
    dict(file="hurt.ogg", cat="combat", comp="玩家受伤提示音",
         where="sound_generator.gd:44 合成兜底（_gen_beep_tone 200Hz）",
         trigger="玩家单位受伤兜底",
         src="项目内程序合成"),
    dict(file="unit_death.ogg", cat="combat", comp="单位阵亡音",
         where="AudioManager._on_unit_died（SignalBus.unit_died，audio_manager.gd:571）",
         trigger="任意单位阵亡（120ms 节流防团灭糊音）",
         src="项目内程序合成（v26.6 接线，此前零消费）"),

    # ── SFX 武器类型（12 + 1 火炮开火）：weapon_type 0~11 ──
    dict(file="gun_smg.ogg", cat="weapon", comp="冲锋枪（weapon_type 0）",
         where="bullet.gd._play_attack_sfx wt0（scenes/units/bullet.gd:1141）；"
               "simple_player/enemy_projectile_batch.gd._play_fire_sfx tier0 兜底",
         trigger="冲锋枪单位开火（敌我分流：敌方 pitch×0.92）",
         src="The Free Firearm Sound Library by bart (opengameart) · CC0 · 单发剪裁 + RMS 匹配"),
    dict(file="gun_rifle.ogg", cat="weapon", comp="步枪（weapon_type 1）",
         where="bullet.gd._play_attack_sfx wt1（bullet.gd:1142）；batch tier1 兜底",
         trigger="步枪单位开火",
         src="The Free Firearm Sound Library by bart · CC0"),
    dict(file="gun_mg.ogg", cat="weapon", comp="机枪（weapon_type 2）",
         where="bullet.gd._play_attack_sfx wt2（bullet.gd:1143）；batch tier≥1 走 gun_mg",
         trigger="机枪单位开火（连发 110ms 节流）",
         src="The Free Firearm Sound Library by bart · CC0"),
    dict(file="rocket_launch.ogg", cat="weapon", comp="火箭弹（weapon_type 3）",
         where="bullet.gd._play_attack_sfx wt3（bullet.gd:1144）；simple_indirect_projectile_batch.gd",
         trigger="火箭弹发射（爆炸最响 vol×1.0）",
         src="项目内程序合成（低频扫降）"),
    dict(file="gun_pistol.ogg", cat="weapon", comp="手枪（weapon_type 4）",
         where="bullet.gd._play_attack_sfx wt4（bullet.gd:1145）；batch wt4 专属",
         trigger="手枪单位开火（音高 +1.1 清脆）",
         src="The Free Firearm Sound Library by bart · CC0"),
    dict(file="gun_shotgun.ogg", cat="weapon", comp="霰弹枪（weapon_type 5）",
         where="bullet.gd._play_attack_sfx wt5（bullet.gd:1146）",
         trigger="霰弹枪单位开火（碎屑命中 vol×0.7）",
         src="The Free Firearm Sound Library by bart · CC0"),
    dict(file="gun_sniper.ogg", cat="weapon", comp="狙击枪（weapon_type 6）",
         where="bullet.gd._play_attack_sfx wt6（bullet.gd:1147）",
         trigger="狙击枪单位开火（音高 +1.2 清脆）",
         src="The Free Firearm Sound Library by bart · CC0"),
    dict(file="flak_fire.ogg", cat="weapon", comp="高射炮（weapon_type 7）",
         where="bullet.gd._play_attack_sfx wt7（bullet.gd:1148）；simple_indirect_projectile_batch.gd",
         trigger="高射炮开火（空爆命中 vol×0.8）",
         src="The Free Firearm Sound Library by bart · CC0"),
    dict(file="laser_fire.ogg", cat="weapon", comp="激光（weapon_type 8）",
         where="bullet.gd._play_attack_sfx wt8（bullet.gd:1149，音高 +2.0 高频）",
         trigger="激光单位开火（高频命中 pitch 3~5）",
         src="项目内程序合成（正弦扫频）"),
    dict(file="missile_hum.ogg", cat="weapon", comp="导弹（weapon_type 9）",
         where="bullet.gd._play_attack_sfx wt9（bullet.gd:1150）；simple_indirect_projectile_batch.gd",
         trigger="导弹发射（爆炸最响 vol×1.0）",
         src="Kenney Sci-Fi Sounds (kenney.nl) · CC0 · 定长剪裁"),
    dict(file="omega_cannon.ogg", cat="weapon", comp="欧米加炮（weapon_type 10）",
         where="bullet.gd._play_attack_sfx wt10（bullet.gd:1151，音高 ×0.5 低沉）",
         trigger="终极能量武器开火",
         src="项目内程序合成（低频扫降）"),
    dict(file="rail_cannon.ogg", cat="weapon", comp="电磁炮（weapon_type 11）",
         where="bullet.gd._play_attack_sfx wt11（bullet.gd:1152，音高 ×1.5 尖锐）",
         trigger="电磁炮开火",
         src="项目内程序合成（高频扫频）"),
    dict(file="cannon_fire.ogg", cat="weapon", comp="火炮开火（力度分级 tier2/3）",
         where="simple_player/enemy_projectile_batch.gd._play_fire_sfx（wt 非 1/2/4 且 tier≥2 走 cannon_fire）",
         trigger="重火力直射开火（力度分级 tier2/3 专属音，比 gun 系更有分量）",
         src="项目内程序合成（tools/_tmp_gen_sfx_v642.py）"),

    # ── SFX 战斗节奏 / 事件（7）──
    dict(file="wave_start.ogg", cat="event", comp="新波次开始",
         where="AudioManager._on_wave_spawned（SignalBus.wave_spawned，audio_manager.gd:614）",
         trigger="每一波敌兵刷新时",
         src="项目内程序合成"),
    dict(file="boss_warn.ogg", cat="event", comp="Boss / 本体波警报",
         where="AudioManager._on_boss_wave_started（非 elite 才响，audio_manager.gd:616）；dream_battle.gd",
         trigger="首领/本体波刷新（精英波不吹警笛，防 5 波一响过频）",
         src="项目内程序合成"),
    dict(file="master_appear.ogg", cat="event", comp="相位师登场",
         where="AudioManager._on_phase_master_appeared（SignalBus.phase_master_appeared，audio_manager.gd:621）",
         trigger="相位师（PM）单位登场",
         src="项目内程序合成"),
    dict(file="base_destroy.ogg", cat="event", comp="基地（相位场驱动器）被摧毁",
         where="AudioManager._on_phase_driver_destroyed（SignalBus.phase_driver_destroyed，audio_manager.gd:622）",
         trigger="我方相位场驱动器被击毁",
         src="项目内程序合成"),
    dict(file="base_alarm.ogg", cat="event", comp="基地低血量告警",
         where="AudioManager._on_phase_driver_hp_changed_alarm（≤30% 触发，10s 重提醒，audio_manager.gd:683）",
         trigger="相位场驱动器完整度 ≤30%（10s 重提醒，战斗开始复位）",
         src="项目内程序合成（sound_generator 兜底；无 .ogg 文件，纯运行期合成）",
         note="无对应 .ogg 资源，SFX_NAMES 在册但走合成兜底——如需独立文件需另生成"),
    dict(file="ultimate_ready.ogg", cat="event", comp="大招就绪提示音",
         where="ultimate_cast_bar.gd:233 AudioManager.play_sfx('ultimate_ready', 0.5)",
         trigger="手动模式大招按钮亮起时轻提示（音量 0.5）",
         src="项目内程序合成（明亮短升调）"),
    dict(file="return_base.ogg", cat="event", comp="回基地转场音",
         where="world_map.gd:1795 / :1814 SignalBus.play_sound.emit('return_base')",
         trigger="世界地图 → 移动基地 转场",
         src="项目内程序合成（v6.38 记录5#5）"),

    # ── SFX 养成 / 结算（6）──
    dict(file="blueprint_unlock.ogg", cat="progression", comp="蓝图 / 符文 / 技能树解锁音",
         where="feature_unlock_popup.gd；ground_loot_layer.gd；AudioManager._on_rune_acquired（audio_manager.gd:630）；"
               "技能树加点 _pick_unlock_sfx（普通分支）",
         trigger="解锁新蓝图 / 获得符文 / 技能树普通节点加点",
         src="项目内程序合成"),
    dict(file="enhance.ogg", cat="progression", comp="强化 / 合成成功音",
         where="AudioManager._on_enhancement_completed 成功分支（audio_manager.gd:588）；"
               "_on_phase_field_level_up（:634）；dream_battle.gd",
         trigger="卡牌强化/升级成功；相位场升级",
         src="项目内程序合成"),
    dict(file="achievement.ogg", cat="progression", comp="成就解锁 / 势力升级音",
         where="AudioManager._on_achievement_unlocked（audio_manager.gd:600）；"
               "_on_faction_level_up（:632）；truck_base.gd；dream_battle.gd",
         trigger="成就解锁；势力声望升级；技能树 capstone（顶点）加点",
         src="项目内程序合成"),
    dict(file="quest_complete.ogg", cat="progression", comp="任务 / 日常任务完成音",
         where="AudioManager._on_quest_completed（audio_manager.gd:604）；"
               "_on_task_completed（:610，复用同一音色）",
         trigger="委托任务 / 日常任务完成",
         src="项目内程序合成"),
    dict(file="win.ogg", cat="progression", comp="胜利音",
         where="AudioManager._on_battle_ended player_won=true（audio_manager.gd:579）",
         trigger="战斗胜利（BGM 切换延迟 0.5s 让胜负音先出）",
         src="项目内程序合成（v6.42）"),
    dict(file="lose.ogg", cat="progression", comp="失败音",
         where="AudioManager._on_battle_ended player_won=false（audio_manager.gd:579）",
         trigger="战斗失败",
         src="项目内程序合成"),
]


def build():
    if os.path.exists(KIT):
        print("[clean] 移除旧 kit：", KIT)
        shutil.rmtree(KIT)
    for sub in ["assets/sfx", "licenses", "source_scripts"]:
        os.makedirs(os.path.join(KIT, sub.replace("/", os.sep)), exist_ok=True)

    # 1. 音频资产
    copied, missing = [], []
    for pat in KITSRC_SFX_FILES:
        for fn in sorted(os.listdir(KITSRC_SFX)):
            import fnmatch
            if fnmatch.fnmatch(fn, pat) and os.path.isfile(os.path.join(KITSRC_SFX, fn)):
                shutil.copy2(os.path.join(KITSRC_SFX, fn),
                             os.path.join(KIT, "assets", "sfx", fn))
                copied.append(fn)
    for doc in KITSRC_SFX_DOCS:
        _cp(os.path.join(KITSRC_SFX, doc), os.path.join(KIT, "assets", "sfx"))
    print("[audio] 复制 %d 个音频文件" % len(copied))

    # 2. 授权凭据
    lic_ok, lic_miss = [], []
    for rel in LICENSE_SRC:
        r = _cp(rel, os.path.join(KIT, "licenses"))
        (lic_ok if r else lic_miss).append(rel)
    print("[licenses] 复制 %d，缺 %d" % (len(lic_ok), len(lic_miss)))
    for m in lic_miss:
        print("  [warn] 缺：%s" % m)

    # 3. 管线脚本
    sc_ok, sc_miss = [], []
    for rel in SCRIPT_SRC:
        r = _cp(rel, os.path.join(KIT, "source_scripts"))
        (sc_ok if r else sc_miss).append(rel)
    print("[scripts] 复制 %d，缺 %d" % (len(sc_ok), len(sc_miss)))

    # 4. 台账 + 网页
    manifest, html = _render(copied)
    with open(os.path.join(KIT, "audio_manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    with open(os.path.join(KIT, "index.html"), "w", encoding="utf-8") as f:
        f.write(html)
    with open(os.path.join(KIT, "使用说明_README.md"), "w", encoding="utf-8") as f:
        f.write(_readme(manifest))
    print("[out] index.html + audio_manifest.json + 使用说明_README.md 生成于", KIT)
    return manifest


def _render(copied_files):
    present = set(copied_files)
    # 编号：按 CAT_ORDER 分组顺序
    serial, entries = 0, []
    for cat in CAT_ORDER:
        for a in ASSETS:
            if a["cat"] != cat:
                continue
            serial += 1
            e = dict(a)
            e["serial"] = serial
            e["has_file"] = a["file"] in present
            e["note"] = a.get("note", "")
            entries.append(e)
    missing = [e["file"] for e in entries if not e["has_file"] and e["file"] != "base_alarm.ogg"]
    if missing:
        print("[warn] 台账中有但目录缺失的文件：", missing)
    manifest = dict(
        title="Phase War 音效与音乐资产审核台账",
        root_rel="assets/sfx/",
        generated_by="tools/build_audio_review_kit.py",
        categories=[dict(key=k, label=CAT_LABEL[k]) for k in CAT_ORDER],
        total=serial,
        entries=entries,
    )

    # ── HTML ──
    cat_color = {"bgm": "#5b8def", "ambient": "#4fbf9f", "ui": "#c9a030",
                 "combat": "#e07850", "weapon": "#d05a5a", "event": "#9a7bd6",
                 "progression": "#4fbfd6"}
    body_rows = []
    for e in entries:
        c = cat_color.get(e["cat"], "#888")
        src_html = _esc(e["src"])
        filebadge = "有资源文件" if e["has_file"] else "无文件（纯合成兜底）"
        audio = ('<audio controls preload="none" src="assets/sfx/%s"></audio>' % e["file"]
                 if e["has_file"] and not e["file"].endswith("base_alarm.ogg") else "")
        note = ('<div class="note">⚠️ %s</div>' % _esc(e["note"])) if e["note"] else ""
        body_rows.append(
            '<div class="row" data-cat="%s" data-file="%s" style="border-left:4px solid %s">'
            '<div class="head"><span class="serial">#%d</span> '
            '<span class="fname">%s</span> '
            '<span class="comp">%s</span> '
            '<span class="badge" style="background:%s">%s</span> '
            '<span class="fstate">%s</span></div>'
            '<div class="comp-sub"></div>'
            '<div class="grid">'
            '<div class="cell"><span class="k">📍 使用位置</span>%s</div>'
            '<div class="cell"><span class="k">⚡ 触发条件</span>%s</div>'
            '<div class="cell"><span class="k">📄 来源 / 许可</span>%s</div>'
            '<div class="cell play">%s</div>'
            '</div>%s'
            '</div>' % (
                e["cat"], _esc(e["file"]), c, e["serial"], _esc(e["file"]), _esc(e["comp"]),
                c, _esc(CAT_LABEL[e["cat"]]), _esc(filebadge),
                _esc(e["where"]), _esc(e["trigger"]), src_html, audio, note,
            ))

    cat_filters = ['<button class="fbtn active" data-cat="all">全部 (%d)</button>' % serial]
    for cat in CAT_ORDER:
        n = sum(1 for e in entries if e["cat"] == cat)
        cat_filters.append('<button class="fbtn" data-cat="%s" style="--c:%s">%s (%d)</button>'
                          % (cat, cat_color[cat], _esc(CAT_LABEL[cat]), n))

    bgm = sum(1 for e in entries if e["cat"] == "bgm")
    sfx = sum(1 for e in entries if e["cat"] in ("ui", "combat", "weapon", "event", "progression"))
    amb = sum(1 for e in entries if e["cat"] == "ambient")

    html = (HTML_TEMPLATE
            .replace("__TOTAL__", str(serial))
            .replace("__BGM__", str(bgm))
            .replace("__SFX__", str(sfx))
            .replace("__AMB__", str(amb))
            .replace("__FILTERS__", "".join(cat_filters))
            .replace("__ROWS__", "".join(body_rows)))
    return manifest, html


def _esc(s):
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
             .replace("\n", "<br>"))


def _readme(man):
    lines = []
    lines.append("# Phase War 音效与音乐资产审核套件（audio_review_kit）\n")
    lines.append("本目录由 `tools/build_audio_review_kit.py` 一键生成，可整体拷到另一台机器离线审核/重生成。\n")
    lines.append("## 目录结构\n")
    lines.append("- `index.html` — 离线审核网页（双击打开；内嵌播放器用相对路径引 `assets/sfx/` 音源）")
    lines.append("- `audio_manifest.json` — 机器可读台账（%d 条目，含序号/文件/类别/用途/来源）" % man["total"])
    lines.append("- `assets/sfx/` — 全部音源副本（.ogg/.wav）+ `CREDITS.md`（授权凭据）+ `README.md`（目录说明）")
    lines.append("- `licenses/` — 授权证据（incompetech CC BY 4.0 / kenney CC0 的 LICENSE_EVIDENCE 与 manifest）")
    lines.append("- `source_scripts/` — 生成/换曲管线脚本（重新生成音源的真身代码）\n")
    lines.append("## 资产统计\n")
    lines.append("- BGM %d 首（Kevin MacLeod / incompetech · CC BY 4.0，逐曲 ISRC 见 licenses/）"
                 % sum(1 for e in man["entries"] if e["cat"] == "bgm"))
    lines.append("- 环境音 %d 个（自合成）" % sum(1 for e in man["entries"] if e["cat"] == "ambient"))
    lines.append("- SFX %d 个（自合成 + 部分 CC0 真枪/导弹剪裁）"
                 % sum(1 for e in man["entries"] if e["cat"] in ("ui", "combat", "weapon", "event", "progression")))
    lines.append("\n## 换机审核步骤\n")
    lines.append("1. 把整个 `audio_review_kit/` 拷到新机器（音源 + 网页 + 凭据 + 脚本一次搬走，不依赖项目 .git）。")
    lines.append("2. 双击 `index.html`：浏览器离线打开即可逐条试听、看使用位置与授权。")
    lines.append("3. 核对授权：BGM 13 首逐曲 ISRC/SHA256 见 `licenses/incompetech_*/`；SFX 多为自合成（无外部义务），")
    lines.append("   武器九槽 + missile_hum 为 CC0（The Free Firearm Sound Library / Kenney，无署名义务）；")
    lines.append("   Kenney 源包 `licenses/sci-fi-sounds.zip`（missile_hum 出处）已随附。")
    lines.append("\n## 重新生成音源步骤（在新机器，需 Python）\n")
    lines.append("- **BGM 换曲/重归一**：改 `licenses/incompetech_*/swap_manifest_*.json` 后跑")
    lines.append("  `python source_scripts/bgm_swap_from_manifest.py <manifest>`（自动拒截断+响度归一+内嵌元数据+同名落位）。")
    lines.append("- **SFX 程序合成**：`python source_scripts/_tmp_gen_sfx_v642.py` / `_tmp_gen_sfx_v657.py` 等可重跑；")
    lines.append("  运行期兜底合成器=`source_scripts/sound_generator.gd`（随游戏运行加载）。")
    lines.append("- **CC0 真枪换血**：`python source_scripts/_tmp_sfx_swap_v656.py`（换槽必走 RMS 匹配，防响度失衡）。")
    lines.append("\n## 红线（与 assets/sfx/CREDITS.md 一致）\n")
    lines.append("- `*.ogg` 在 .gitignore，git 不保护音频资产——任何换曲/删曲前先外部备份。")
    lines.append("- BGM 商店提交前，凭据表不得留 UNVERIFIED（现 13 首已闭环）。")
    lines.append("- SFX 若被替换为外部素材，必须回写 CREDITS.md（来源/许可/凭证）并检查商店 AI 披露范围。")
    return "\n".join(lines)


HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Phase War · 音效与音乐资产审核</title>
<style>
  :root { --bg:#0f1220; --panel:#1a1f34; --panel2:#20263f; --tx:#e8ecf7; --mut:#9aa3c0;
          --line:#2b3352; --accent:#5b8def; }
  * { box-sizing:border-box; }
  body { margin:0; background:var(--bg); color:var(--tx);
         font-family:"Segoe UI","Microsoft YaHei",system-ui,sans-serif; line-height:1.55; }
  .wrap { max-width:1080px; margin:0 auto; padding:24px 20px 80px; }
  header.hero { background:linear-gradient(135deg,#1b2444,#241a3f); border:1px solid var(--line);
                border-radius:14px; padding:26px 28px; margin-bottom:22px; }
  header.hero h1 { margin:0 0 6px; font-size:24px; }
  header.hero .sub { color:var(--mut); font-size:14px; }
  .stats { display:flex; gap:12px; flex-wrap:wrap; margin-top:16px; }
  .stat { background:var(--panel2); border:1px solid var(--line); border-radius:10px;
          padding:12px 16px; min-width:120px; }
  .stat .n { font-size:26px; font-weight:700; }
  .stat .l { color:var(--mut); font-size:12px; }
  .controls { position:sticky; top:0; z-index:5; background:rgba(15,18,32,.95);
              backdrop-filter:blur(6px); padding:12px 0; margin-bottom:18px;
              border-bottom:1px solid var(--line); }
  .fbtn { background:var(--panel); color:var(--tx); border:1px solid var(--line);
          border-radius:20px; padding:7px 14px; margin:4px 6px 4px 0; cursor:pointer;
          font-size:13px; border-left:4px solid var(--c,#888); }
  .fbtn.active { background:#33406e; border-color:var(--accent); }
  .fbtn.all { border-left:4px solid #888; }
  #search { width:100%; padding:10px 12px; margin-top:8px; background:var(--panel);
            color:var(--tx); border:1px solid var(--line); border-radius:8px; font-size:14px; }
  .row { background:var(--panel); border:1px solid var(--line); border-radius:10px;
         padding:14px 16px; margin-bottom:12px; }
  .row.hidden { display:none; }
  .head { display:flex; align-items:center; flex-wrap:wrap; gap:8px; }
  .serial { font-weight:800; color:#fff; background:var(--accent); border-radius:6px;
            padding:2px 8px; font-size:13px; }
  .fname { font-family:Consolas,monospace; font-weight:700; font-size:15px; }
  .comp { color:var(--mut); font-size:13px; }
  .badge { color:#0f1220; border-radius:6px; padding:2px 9px; font-size:12px; font-weight:600; }
  .fstate { margin-left:auto; color:var(--mut); font-size:12px; }
  .grid { display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-top:12px; }
  @media (max-width:720px){ .grid { grid-template-columns:1fr; } }
  .cell { background:var(--panel2); border:1px solid var(--line); border-radius:8px; padding:10px 12px; font-size:13px; }
  .cell .k { display:block; color:var(--accent); font-weight:600; margin-bottom:4px; font-size:12px; }
  .cell.play { display:flex; flex-direction:column; gap:6px; justify-content:center; }
  .cell audio { width:100%; }
  .note { color:#f0a868; font-size:12px; margin-top:8px; }
  footer { color:var(--mut); font-size:12px; text-align:center; margin-top:30px; }
  .legend { margin-top:10px; color:var(--mut); font-size:12px; }
</style>
</head>
<body>
<div class="wrap">
  <header class="hero">
    <h1>Phase War · 音效与音乐资产审核</h1>
    <div class="sub">共 __TOTAL__ 项（BGM __BGM__ 首 · SFX __SFX__ 项 · 环境音 __AMB__ 个）——
      每项标注「使用位置 / 触发条件 / 来源许可」并内嵌播放器，可直接离线试听。</div>
    <div class="stats">
      <div class="stat"><div class="n">__TOTAL__</div><div class="l">资产总数</div></div>
      <div class="stat"><div class="n">__BGM__</div><div class="l">BGM（CC BY 4.0）</div></div>
      <div class="stat"><div class="n">__SFX__</div><div class="l">SFX（自合成/CC0）</div></div>
      <div class="stat"><div class="n">__AMB__</div><div class="l">环境音</div></div>
    </div>
    <div class="legend">📄 许可：<b>BGM</b>=Kevin MacLeod / incompetech · CC BY 4.0（逐曲 ISRC 见 licenses/）；
      <b>武器九槽 + missile_hum</b>=CC0（Free Firearm Sound Library / Kenney）；
      <b>其余 SFX + 环境音</b>=项目内自合成（无外部授权义务）。</div>
  </header>

  <div class="controls">
    __FILTERS__
    <input id="search" type="search" placeholder="🔍 按文件名 / 曲目 / 使用位置 / 触发条件 过滤…">
  </div>

  <div id="list">
    __ROWS__
  </div>

  <footer>Phase War 音频资产审核套件 · 由 tools/build_audio_review_kit.py 生成 ·
    音源副本位于 <code>assets/sfx/</code>（相对本页）· 授权凭据见 <code>licenses/</code> 与 <code>assets/sfx/CREDITS.md</code></footer>
</div>

<script>
(function(){
  var btns = document.querySelectorAll('.fbtn');
  var rows = Array.prototype.slice.call(document.querySelectorAll('.row'));
  function apply(){
    var cat = document.querySelector('.fbtn.active').dataset.cat;
    var q = document.getElementById('search').value.trim().toLowerCase();
    rows.forEach(function(r){
      var okCat = (cat==='all' || r.dataset.cat===cat);
      var okQ = !q || (r.dataset.file.indexOf(q)>-1 || r.textContent.toLowerCase().indexOf(q)>-1);
      r.classList.toggle('hidden', !(okCat && okQ));
    });
  }
  btns.forEach(function(b){ b.addEventListener('click', function(){
    document.querySelectorAll('.fbtn').forEach(function(x){x.classList.remove('active');});
    b.classList.add('active'); apply();
  });});
  document.getElementById('search').addEventListener('input', apply);
  apply();
})();
</script>
</body>
</html>
"""


if __name__ == "__main__":
    build()
