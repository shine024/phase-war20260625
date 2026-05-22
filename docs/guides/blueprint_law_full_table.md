# 蓝图与法则全表

导出时间：当前工作区数据快照  
来源文件：
- `data/default_cards.gd`
- `data/enemy_blueprints.gd`
- `data/phase_laws.gd`

## 总计

- 平台：70
- 武器：110
- 法则：25
- 合计：205

## 字段说明

- `id`：唯一标识
- `name`：显示名
- `type`：`platform` / `weapon` / `law`
- `source`：`default` / `enemy_special` / `enemy_generated` / `phase_laws`

## A. 平台与武器（已命名固定条目）

| id | name | type | source |
|---|---|---|---|
| platform_ww1_light | 威克斯侦察车 | platform | default |
| platform_ww1_medium | 马克V型坦克 | platform | default |
| platform_ww1_fort | 要塞固定炮 | platform | default |
| platform_ww2_light | M8灰狗装甲车 | platform | default |
| platform_ww2_medium | 谢尔曼坦克 | platform | default |
| platform_ww2_heavy | 虎式坦克 | platform | default |
| platform_cold_light | 悍马侦察车 | platform | default |
| platform_cold_medium | T-72主战坦克 | platform | default |
| platform_cold_ifv | 布雷德利步战车 | platform | default |
| platform_modern_light | 北极星全地形车 | platform | default |
| platform_modern_medium | 艾布拉姆斯坦克 | platform | default |
| platform_modern_spg | 帕拉丁自行火炮 | platform | default |
| platform_future_light | 光学侦察车 | platform | default |
| platform_future_medium | 悬浮坦克 | platform | default |
| platform_future_heavy | 机甲步行者 | platform | default |
| omega_platform | 全装型机动舱 | platform | default |
| weapon_ww1_smg | MP18冲锋枪 | weapon | default |
| weapon_ww1_rifle | 李-恩菲尔德步枪 | weapon | default |
| weapon_ww1_mg | 马克沁机枪 | weapon | default |
| weapon_ww1_mortar | 斯托克斯迫击炮 | weapon | default |
| weapon_ww2_smg | 汤普森冲锋枪 | weapon | default |
| weapon_ww2_rifle | M1加兰德步枪 | weapon | default |
| weapon_ww2_mg | MG42机枪 | weapon | default |
| weapon_ww2_at | 巴祖卡火箭筒 | weapon | default |
| weapon_cold_assault | AK-47突击步枪 | weapon | default |
| weapon_cold_sniper | 德拉贡诺夫狙击枪 | weapon | default |
| weapon_cold_lmg | M60通用机枪 | weapon | default |
| weapon_cold_missile | 陶式反坦克导弹 | weapon | default |
| weapon_modern_carbine | M4卡宾枪 | weapon | default |
| weapon_modern_dmr | MK14射手步枪 | weapon | default |
| weapon_modern_minigun | M134加特林 | weapon | default |
| weapon_modern_grenade | 榴弹发射器 | weapon | default |
| weapon_future_laser | 光束步枪 | weapon | default |
| weapon_future_rail | 电磁炮 | weapon | default |
| weapon_future_plasma | 等离子枪 | weapon | default |
| weapon_future_pulse | 脉冲步枪 | weapon | default |
| omega_cannon | 米加粒子炮 | weapon | default |
| bulwark | 盾卫装甲车 | platform | enemy_special |
| titan_mk2 | 马克V型·改 | platform | enemy_special |
| storm_rider | 突击坦克·风暴型 | platform | enemy_special |
| heavy_carrier | 重型载机母舰 | platform | enemy_special |
| regen_frame | 野战维修车·改 | platform | enemy_special |
| abrams_mk2 | 艾布拉姆斯坦克·改 | platform | enemy_special |
| smg_mk2 | MP18冲锋枪·改 | weapon | enemy_special |
| phase_lance | 突击冲锋枪 | weapon | enemy_special |
| railgun | 长程反坦克步枪 | weapon | enemy_special |
| thunder_field | 高爆榴霰弹 | weapon | enemy_special |
| overclock_matrix | 超频模块 | weapon | enemy_special |
| mega_beam_cannon | 米加光束炮 | weapon | enemy_special |
| mega_particle_cannon | 米加粒子炮 | weapon | enemy_special |

## B. 平台与武器（生成条目，全量 ID 范围）

命名规则（来自 `enemy_blueprints.gd`）：
- 平台名：`{时代}·{NAME_PREFIX_PLATFORM[idx]}{NAME_SUFFIX_PLATFORM[idx]}`
- 武器名：`{时代}·{NAME_PREFIX_WEAPON[idx]}{NAME_SUFFIX_WEAPON[idx]}`

| era | platform_ids | platform_count | weapon_ids | weapon_count | source |
|---|---|---:|---|---:|---|
| 一战 | `bp_ww1_001..bp_ww1_010` | 10 | `bp_ww1_011..bp_ww1_026` | 16 | enemy_generated |
| 二战 | `bp_ww2_001..bp_ww2_010` | 10 | `bp_ww2_011..bp_ww2_026` | 16 | enemy_generated |
| 冷战 | `bp_cold_001..bp_cold_009` | 9 | `bp_cold_010..bp_cold_026` | 17 | enemy_generated |
| 现代 | `bp_modern_001..bp_modern_009` | 9 | `bp_modern_010..bp_modern_026` | 17 | enemy_generated |
| 近未来 | `bp_near_001..bp_near_010` | 10 | `bp_near_011..bp_near_026` | 16 | enemy_generated |

## C. 法则（25）

| id | name | type | source |
|---|---|---|---|
| steel_phase_armor | 钢铁·相位装甲 | law | phase_laws |
| flame_heat_overload | 烈焰·热能过载 | law | phase_laws |
| thunder_emp_storm | 雷霆·电磁风暴 | law | phase_laws |
| void_time_ripple | 虚空·时空涟漪 | law | phase_laws |
| steel_bastion_wall | 钢铁·堡垒之墙 | law | phase_laws |
| flame_front_bombard | 烈焰·前线火力压制 | law | phase_laws |
| thunder_chain_discharge | 雷霆·链式放电 | law | phase_laws |
| void_barrier_shift | 虚空·护盾转移 | law | phase_laws |
| steel_quick_repair | 钢铁·快速维修 | law | phase_laws |
| flame_mark | 烈焰·灼烧印记 | law | phase_laws |
| steel_aegis_link | 钢铁·护阵联结 | law | phase_laws |
| steel_anchor_field | 钢铁·锚定力场 | law | phase_laws |
| steel_fortify_protocol | 钢铁·固壁协议 | law | phase_laws |
| flame_scorch_wave | 烈焰·灼浪推进 | law | phase_laws |
| flame_ember_screen | 烈焰·灰烬幕障 | law | phase_laws |
| flame_core_rupture | 烈焰·核心破裂 | law | phase_laws |
| flame_afterburn | 烈焰·余烬加燃 | law | phase_laws |
| thunder_ion_net | 雷霆·离子网 | law | phase_laws |
| thunder_arc_beacon | 雷霆·弧光信标 | law | phase_laws |
| thunder_surge_drive | 雷霆·激涌驱动 | law | phase_laws |
| thunder_static_domain | 雷霆·静电域 | law | phase_laws |
| void_phase_cloak | 虚空·相位披幕 | law | phase_laws |
| void_entropy_lens | 虚空·熵镜 | law | phase_laws |
| void_gravity_well | 虚空·引力井 | law | phase_laws |
| steel_resonant_plate | 钢铁·共振装甲 | law | phase_laws |

