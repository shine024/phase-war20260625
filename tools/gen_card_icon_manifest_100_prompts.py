#!/usr/bin/env python3
"""Generate docs/card_icon_manifest_100_agent_prompts.md from manifest-aligned entries."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs" / "card_icon_manifest_100_zh.md"
OUT = ROOT / "docs" / "card_icon_manifest_100_agent_prompts.md"

ERA_LABEL = {0: "一战", 1: "二战", 2: "冷战", 3: "现代", 4: "近未来"}

NEG_VEHICLE = (
    "three-quarter view, perspective, isometric, top-down, rear three-quarter, facing right, "
    "gradient background, sky, clouds, battlefield, trench, ground plane, cast shadow, pedestal, "
    "text, watermark, logo, letters, numbers, blurry, low quality, deformed, duplicate hull"
)
NEG_INFANTRY = (
    "three-quarter view, perspective, isometric, top-down, facing right, group photo, "
    "gradient background, battlefield scenery, ground shadow, text, watermark, logo, "
    "blurry, extra limbs, deformed rifle"
)
NEG_AIRCRAFT = (
    "front view, top-down, three-quarter, facing right, runway scenery, clouds background, "
    "text, watermark, logo, blurry, deformed rotor"
)

TAIL = (
    " Strict true profile side view, orthographic projection, entire unit facing LEFT "
    "(nose/barrel/front toward left edge). Semi-realistic hard-surface military game unit concept art, "
    "rivets panel lines weathering scratches. Solid flat chroma green #00FF00 background only, "
    "no ground shadow no floor no scenery. Centered composition 10% margin, 512x512. "
    "No text, no watermark, no logo."
)

# Each entry: num, visual_id, display_name, archetype_id, era, role, note_zh, subject, neg_kind
# subject = unique visual description (English); neg_kind = vehicle|infantry|aircraft|naval|boss

ENTRIES: list[tuple] = [
    # A 1-29 platforms
    (1, "vis_player_001", "威克斯侦察车", "foe_platform_ww1_light", 0, "猎犬",
     "一战轻型装甲侦察车，四轮",
     "WW1 British Vickers-Wickes pattern armored scout car, riveted khaki steel hull, canvas roof over rear cabin, twin machine gun pintle, four spoked wheels with mud-splashed rubber, dented front radiator grille and round headlamp, oil stains and paint chips.",
     "vehicle"),
    (2, "vis_player_002", "马克V型坦克", "foe_platform_ww1_medium", 0, "泰坦",
     "菱形一战重型坦克",
     "WW1 British Mark V male rhomboid heavy tank, continuous caterpillar tracks wrapping diamond hull, long naval gun barrel in side sponson pointing left, riveted olive plates, command cabin slot, heavy mud on lower track skirts.",
     "vehicle"),
    (3, "vis_player_003", "150mm岸防火炮阵地", "foe_platform_ww1_fort", 0, "要塞",
     "混凝土炮堡与岸防火炮",
     "WW1 coastal fortress emplacement, 150mm naval gun on curved shield mount, concrete casemate with firing slit, stacked burlap sandbags, rusted traverse wheel and spent shell rack silhouette.",
     "vehicle"),
    (4, "vis_player_004", "系留气球观测队", "foe_platform_ww1_radar", 0, "雷达",
     "系留观测气球",
     "WW1 tethered observation barrage balloon, fabric envelope with panel seams and rigging net, wicker gondola basket with map case, steel winch frame on truck chassis optional minimal base.",
     "vehicle"),
    (5, "vis_player_005", "福特T型救护改装车", "foe_platform_ww1_medic", 0, "医疗",
     "T型车救护改装",
     "WW1 Ford Model T ambulance conversion, white-over-khaki box body, large red cross on side panel, open cab, wooden spoke wheels, stretcher rack visible through rear door gap.",
     "vehicle"),
    (6, "vis_player_006", "M8灰狗装甲车", "foe_platform_ww2_light", 1, "侦察",
     "六轮装甲侦察",
     "WW2 US M8 Greyhound six-wheeled armored car, sloped welded hull olive drab, open-topped turret with 37mm gun pointing left, antenna whip, canvas equipment bins, worn white star faded on glacis.",
     "vehicle"),
    (7, "vis_player_007", "谢尔曼坦克", "foe_platform_ww2_medium", 1, "哨兵",
     "M4谢尔曼侧视",
     "WW2 US M4 Sherman medium tank, vertical volute suspension bogies, three-piece welded hull, medium turret with 75mm gun left, applique armor patches, tool clamps on hull side.",
     "vehicle"),
    (8, "vis_player_008", "虎式坦克", "foe_platform_ww2_heavy", 1, "泰坦",
     "虎I重型坦克",
     "WW2 German Tiger I heavy tank, interleaved road wheels, long 88mm L/56 barrel with muzzle brake left, zimmerit texture patches, commander's cupola, dark yellow-olive camo chips.",
     "vehicle"),
    (9, "vis_player_009", "BA-64轻型突击车", "foe_platform_ww2_raider", 1, "突袭",
     "苏制轻型装甲车",
     "WW2 Soviet BA-64 light armored car, compact angled armor, turret machine gun left, four wheels with bullet strikes on fenders, dark green with white tactical number stencil.",
     "vehicle"),
    (10, "vis_player_010", "SCR-584雷达指挥车", "foe_platform_ww2_radar", 1, "雷达",
     "雷达天线指挥车",
     "WW2 US SCR-584 microwave radar truck, GMC 6x6 cargo bed, parabolic dish antenna folded for travel profile, generator crate, olive drab with signal corps markings.",
     "vehicle"),
    (11, "vis_player_011", "203毫米迫击炮", "foe_platform_ww2_siege", 1, "攻城",
     "重型迫击炮阵地",
     "WW2 203mm heavy mortar battery, enormous smoothbore tube on twin-leg base plate, elevating screw and spade, stacked ammo crates and ramrod crew steps implied by hardware only.",
     "vehicle"),
    (12, "vis_player_012", "海岸混凝土炮堡", "foe_platform_ww2_fortress", 1, "要塞",
     "永备混凝土碉堡",
     "WW2 Atlantic Wall concrete casemate, embrasure with coastal gun barrel left, rebar stains, camouflage net drape, anti-landing obstacles cast into roof edge.",
     "vehicle"),
    (13, "vis_player_013", "悍马侦察车", "foe_platform_cold_light", 2, "猎犬",
     "悍马武装侦察",
     "Cold War era HMMWV armed scout, armored doors, roof ring mount with M2 machine gun left, antenna cluster, sand tan paint, IR driving light and jerry cans on tailgate.",
     "vehicle"),
    (14, "vis_player_014", "T-72主战坦克", "foe_platform_cold_medium", 2, "泰坦",
     "T-72侧视",
     "Cold War Soviet T-72 MBT, low silhouette cast turret, autoloader bustle, rubber side skirts, 125mm smoothbore gun left, reactive armor blocks on cheeks, Russian green with mud splatter.",
     "vehicle"),
    (15, "vis_player_015", "布雷德利步战车", "foe_platform_cold_ifv", 2, "运输",
     "M2布雷德利IFV",
     "Cold War US M2 Bradley IFV, aluminum hull angular, TOW launcher box on turret left, six road wheels, infantry firing ports along flank, MERDC woodland faded camo.",
     "vehicle"),
    (16, "vis_player_016", "BRDM-2侦察车", "foe_platform_cold_scout", 2, "侦察",
     "BRDM两栖侦察",
     "Cold War BRDM-2 scout car, boat hull belly, four wheels with central tire inflation lines, turret KPVT gun left, periscope fairings, white recognition stripe on bow.",
     "vehicle"),
    (17, "vis_player_017", "R-330电子干扰车", "foe_platform_cold_radar", 2, "雷达",
     "电子战卡车",
     "Cold War R-330Zh EW truck on ZIL chassis, tall mast telescoped, jammer dish arrays on sides, cable reels, matte green with lightning bolt stencil.",
     "vehicle"),
    (18, "vis_player_018", "BMP步战车", "foe_platform_cold_carrier", 2, "运输",
     "BMP-1步兵战车",
     "Cold War BMP-1 infantry fighting vehicle, low angled glacis, 73mm low-pressure gun and ATGM rail left, rear troop door outline, spaced armor texture.",
     "vehicle"),
    (19, "vis_player_019", "L-ATV全地形侦察车", "foe_platform_modern_light", 3, "猎犬",
     "联合轻型战术车",
     "Modern US Oshkosh L-ATV MRAP scout, modular armor panels, CROWS remote weapon station pointing left, blast-resistant windows, digital tan-gray camo.",
     "vehicle"),
    (20, "vis_player_020", "艾布拉姆斯坦克", "foe_platform_modern_medium", 3, "哨兵",
     "M1A2艾布拉姆斯",
     "Modern US M1A2 Abrams MBT, depleted uranium skirt tiles, large bustle rack, 120mm gun with thermal sleeve left, commander CITV, desert tan with unit chalk marks.",
     "vehicle"),
    (21, "vis_player_021", "相控阵雷达车", "foe_platform_modern_radar", 3, "雷达",
     "机动相控阵雷达",
     "Modern phased-array air-defense radar truck, folding AESA panel lattice on hydraulic mast, support outriggers stowed, FMTV cab, slate gray with IFF transponder blister.",
     "vehicle"),
    (22, "vis_player_022", "帕拉丁自行火炮", "foe_platform_modern_spg", 3, "攻城",
     "M109帕拉丁",
     "Modern M109 Paladin self-propelled howitzer, closed turret with long 155mm barrel left, spade deployed at rear, automated fire control boxes on hull.",
     "vehicle"),
    (23, "vis_player_023", "Fennek侦察车", "foe_platform_modern_stealth", 3, "隐匿",
     "芬内克侦察",
     "Modern Dutch-German Fennek recon vehicle, low radar signature hull, surveillance mast folded, MG3 remote mount left, matte sand with IR suppressing paint.",
     "vehicle"),
    (24, "vis_player_024", "豹2A7主战坦克", "foe_platform_modern_guard_heavy", 3, "哨兵",
     "豹2A7",
     "Modern Leopard 2A7 MBT, wedge turret cheeks, 120mm L55 gun left, auxiliary power unit grilles, urban gray-green camo with rubber chain grousers.",
     "vehicle"),
    (25, "vis_player_025", "RQ-45无人侦察车", "foe_platform_future_light", 4, "隐匿",
     "无人侦察平台",
     "Near-future RQ-45 unmanned ground recon sled, flat carbon chassis, gimbal EO pod on articulated arm left, LIDAR puck, subtle enemy blue phase sensor glow on lens ring.",
     "vehicle"),
    (26, "vis_player_026", "L-220悬浮突击车", "foe_platform_future_medium", 4, "突袭",
     "悬浮突击平台",
     "Near-future L-220 hover assault skimmer, magneto-plasma lift skirts under angular hull, dual plasma cannons on chin turret left, heat discoloration on cowlings.",
     "vehicle"),
    (27, "vis_player_027", "AEW-12感知阵列车", "foe_platform_future_radar", 4, "雷达",
     "感知阵列指挥车",
     "Near-future AEW-12 sensor array carrier, articulated phased-sensor wings stowed along hull, quantum dome radome, matte gunmetal with blue phase lattice seams.",
     "vehicle"),
    (28, "vis_player_028", "HK-09重型机兵", "foe_platform_future_heavy", 4, "泰坦",
     "双足重型机兵",
     "Near-future HK-09 heavy bipedal war-walker, thick leg actuators, shoulder missile pods, rotary cannon arm pointing left, battle-scarred armor plates with blue energy core slit.",
     "vehicle"),
    (29, "vis_player_029", "全装型机动舱", "foe_omega_platform", 4, "终极",
     "Ω级全装机动舱",
     "Near-future omega-class mobile combat capsule, modular weapon spines, spherical phase reactor visible through armored viewport, golden-trim black hull, intimidating oversized silhouette.",
     "vehicle"),
    # B 30-35 elites
    (30, "vis_player_030", "兰开夏 FV603 装甲车", "foe_bulwark", 0, "哨兵",
     "一战末装甲输送",
     "Interwar Lancashire FV603 pattern armored personnel carrier stylized WW1-era, riveted box hull, side firing loopholes, roof hatches, sandbag rack on glacis.",
     "vehicle"),
    (31, "vis_player_031", "马克V型·改", "foe_titan_mk2", 0, "泰坦",
     "强化菱形坦克",
     "Up-armored WW1 Mark V variant mk2, extra boilerplate on sponsons, twin searchlights, reinforced track links, additional trench crossing tail skid, heavier camouflage nets bundled.",
     "vehicle"),
    (32, "vis_player_032", "M10狼獾歼击车", "foe_storm_rider", 1, "突袭",
     "敞篷坦克歼击车",
     "WW2 US M10 Wolverine tank destroyer, open-top turret with 3-inch gun left, counterweight on turret rear, tall side fenders, white invasion star.",
     "vehicle"),
    (33, "vis_player_033", "LST-1两栖指挥舰", "foe_heavy_carrier", 1, "运输",
     "坦克登陆舰侧视",
     "WW2 LST-1 tank landing ship side silhouette, bow ramp door seams, bridge superstructure aft, deck tie-down cleats, camouflage gray with wake paint stripe only on hull waterline hint minimal.",
     "naval"),
    (34, "vis_player_034", "M88A1抢救牵引车", "foe_regen_frame", 2, "医疗",
     "装甲抢救车",
     "Cold War M88A1 recovery vehicle, crane boom stowed along hull, winch cable drum, dozer blade on glacis, lifting A-frame, olive drab with recovery triangle.",
     "vehicle"),
    (35, "vis_player_035", "艾布拉姆斯坦克·改", "foe_abrams_mk2", 3, "哨兵",
     "升级型艾布拉姆斯",
     "Modern Abrams mk2 upgrade package, trophy APS sensor clusters on turret cheeks, heavier side skirts, commander's low-profile cupola, urban kit storage boxes.",
     "vehicle"),
    # C 36-71 fixed archetypes
    (36, "vis_enemy_036", "步兵班·MP18", "enemy_ww1_infantry_basic", 0, "步兵",
     "MP18冲锋枪班",
     "WW1 German stormtrooper squad represented as single soldier profile, MP18 submachine gun with drum magazine, Stahlhelm, gas mask canister on belt, puttee leggings, mud-spattered greatcoat.",
     "infantry"),
    (37, "vis_enemy_037", "李-恩菲尔德步枪班", "enemy_ww1_infantry_rifle", 0, "步兵",
     "英军步枪手",
     "WW1 British rifleman profile, Lee-Enfield SMLE with bayonet, Brodie helmet, khaki wool tunic, bandolier across chest, trench mud on boots.",
     "infantry"),
    (38, "vis_enemy_038", "马克沁机枪阵地", "enemy_ww1_mg_nest", 0, "阵地",
     "水冷重机枪阵地",
     "WW1 Vickers-Maxim machine gun nest emplacement, water-jacketed heavy machine gun on tripod with brass feed block, sandbag parapet two layers high, ammo belt box.",
     "vehicle"),
    (39, "vis_enemy_039", "81mm斯托克斯迫击炮组", "enemy_ww1_mortar", 0, "阵地",
     "斯托克斯迫击炮",
     "WW1 Stokes 81mm trench mortar on base plate, short smoothbore tube elevated, bipod legs, stacked mortar bombs in wicker cage, range dial plate on tube.",
     "vehicle"),
    (40, "vis_enemy_040", "暴风突击队", "elite_ww1_storm", 0, "精英步兵",
     "德军暴风兵",
     "WW1 elite stormtrooper profile, reinforced brow plate on helmet, MP18 plus stick grenades on belt, flame-resistant cloak, aggressive forward-leaning stance, extra ammo pouches.",
     "infantry"),
    (41, "vis_enemy_041", "劳斯莱斯 Mk.I 装甲车", "elite_ww1_armored", 0, "载具",
     "精英装甲车",
     "WW1 Rolls-Royce Armoured Car Mk I, turret with Vickers gun left, spoked wheels, polished rivet lines, royal navy gray-green with unit pennant stub only no readable text.",
     "vehicle"),
    (42, "vis_enemy_042", "圣沙蒙坦克", "boss_ww1_av7", 0, "Boss",
     "超重型一战坦克",
     "WW1 French Saint-Chamond heavy assault tank boss scale, long hull overhang front, multiple casemate guns, tall rear cabin, extreme rivet count, battle damage gashes, oversized presence filling frame.",
     "vehicle"),
    (43, "vis_enemy_043", "步兵班·汤普森", "enemy_ww2_infantry", 1, "步兵",
     "汤普森冲锋枪班",
     "WW2 US infantry soldier profile, Thompson M1928A1 with drum, M1 helmet netted, suspenders, grenade pouches, oil on cheek of wooden stock.",
     "infantry"),
    (44, "vis_enemy_044", "步枪班·加兰德", "enemy_ww2_rifleman", 1, "步兵",
     "加兰德步枪手",
     "WW2 US rifleman profile, M1 Garand rifle at high port, canvas gaiters, ammo clips on belt, helmet chin strap, subdued olive uniform.",
     "infantry"),
    (45, "vis_enemy_045", "MG42机枪组", "enemy_ww2_mg42", 1, "阵地",
     "MG42机枪阵地",
     "WW2 MG42 machine gun on Lafette tripod, perforated barrel shroud, belt drum feed, low sandbag wall, spare barrel case beside mount.",
     "vehicle"),
    (46, "vis_enemy_046", "铁拳88mm反坦克组", "enemy_ww2_panzerschreck", 1, "阵地",
     "铁拳反坦克组",
     "WW2 Panzerschreck 88mm recoilless anti-tank team gear still life profile: launcher tube on shoulder rest stand, shield plate, rocket warhead crate, no visible face.",
     "vehicle"),
    (47, "vis_enemy_047", "FG42伞兵班", "elite_ww2_paratrooper", 1, "精英步兵",
     "德军伞兵",
     "WW2 German Fallschirmjäger profile, FG42 rifle with bipod folded, jump smock, side-holster, helmet with chin pad, elite eagle insignia shape only no readable insignia text.",
     "infantry"),
    (48, "vis_enemy_048", "黑豹坦克", "elite_ww2_panther", 1, "精英载具",
     "黑豹中型坦克",
     "WW2 Panther Ausf G medium tank, sloped glacis, long 75mm KwK42 L/70 left, wide tracks, zimmerit bands, commander's periscope guard.",
     "vehicle"),
    (49, "vis_enemy_049", "虎王坦克", "boss_ww2_kingtiger", 1, "Boss",
     "虎王重型坦克",
     "WW2 King Tiger boss silhouette, massive Königstiger hull, long 88mm L/71, thick frontal armor slab, double road wheel interleave, imposing scale with chipped ambush camo.",
     "vehicle"),
    (50, "vis_enemy_050", "AKM摩托化步兵班", "enemy_cold_ak", 2, "步兵",
     "AKM步兵",
     "Cold War motor rifle soldier profile, AKM rifle with slab magazine, load-bearing harness, SSH68 helmet, wool greatcoat, NBC cape rolled on back.",
     "infantry"),
    (51, "vis_enemy_051", "M60机枪步兵班", "enemy_cold_m60", 2, "步兵",
     "M60通用机枪手",
     "Cold War US machine gunner profile, M60 GPMG with bipod folded, ammo belt over shoulder, PASGT helmet, flak vest, woodland ERDL pattern.",
     "infantry"),
    (52, "vis_enemy_052", "BTR-60PB装甲输送车", "enemy_cold_btr", 2, "载具",
     "BTR-60八轮",
     "Cold War BTR-60PB eight-wheeled APC, boat hull, turret KPVT left, troop vision blocks row, white Russian naval stripe optional.",
     "vehicle"),
    (53, "vis_enemy_053", "M113A1装甲输送车", "enemy_cold_m113", 2, "载具",
     "M113履带输送",
     "Cold War M113A1 APC, aluminum angled hull, cupola M2 mount left, trim vane on bow, rubber track, MERDC camo scuffs.",
     "vehicle"),
    (54, "vis_enemy_054", "Spetsnaz侦察小组", "elite_cold_spetsnaz", 2, "精英步兵",
     "苏军特种部队",
     "Cold War Spetsnaz recon operator profile, AS Val suppressed rifle, night vision goggle mount on helmet, suppressor wrap cloth, black coveralls with subdued patches no text.",
     "infantry"),
    (55, "vis_enemy_055", "T-72A主战坦克", "elite_cold_t72", 2, "精英载具",
     "T-72A精英涂装",
     "Cold War T-72A elite variant, IR searchlight box, smoke grenade launchers on turret, extended fuel drums on rear fender, aggressive angular turret cheeks.",
     "vehicle"),
    (56, "vis_enemy_056", "米格-29", "boss_cold_mig", 2, "Boss",
     "米格-29战斗机侧视",
     "Cold War MiG-29 Fulcrum fighter aircraft strict side profile, swept wings, twin vertical tails, intake under fuselage, boss scale fills height, bare metal and green camo, no runway.",
     "aircraft"),
    (57, "vis_enemy_057", "M27海军陆战队班", "enemy_modern_marine", 3, "步兵",
     "M27步枪海军陆战队",
     "Modern USMC rifleman profile, M27 IAR rifle with optic, ILBE pack straps, MARPAT desert, knee pads, bayonet frog empty.",
     "infantry"),
    (58, "vis_enemy_058", "丰田Hilux重机枪车", "enemy_modern_technical", 3, "步兵",
     "技术皮卡机枪车",
     "Modern Toyota Hilux technical truck profile, DShK heavy machine gun on bed mount pointing left, welded armor plates on doors, dust-coated white paint, spare tire on tailgate.",
     "vehicle"),
    (59, "vis_enemy_059", "M1126斯特赖克ICV", "enemy_modern_stryker", 3, "载具",
     "斯特赖克八轮",
     "Modern Stryker ICV M1126, eight-wheel configuration, remote CROWS on roof left, slat armor cage panels, digital camo, antenna farm.",
     "vehicle"),
    (60, "vis_enemy_060", "M270 MLRS火箭炮", "enemy_modern_mlrs", 3, "阵地",
     "MLRS多管火箭",
     "Modern M270 MLRS launcher vehicle, two six-pack rocket pods elevated slightly, armored cab forward, hydraulic outriggers down, desert tan.",
     "vehicle"),
    (61, "vis_enemy_061", "CAG三角洲小队", "elite_modern_delta", 3, "精英步兵",
     "三角洲特战",
     "Modern CAG operator profile, suppressed HK416, NVG shroud up, plate carrier with pouches no readable patches, fast helmet and comms wires.",
     "infantry"),
    (62, "vis_enemy_062", "M1A2 SEP v3", "elite_modern_abrams", 3, "精英载具",
     "SEP v3艾布拉姆斯",
     "Modern M1A2 SEP v3 with TUSK kit, depleted uranium skirts, CROWS-LP, commander's independent thermal viewer, urban gray.",
     "vehicle"),
    (63, "vis_enemy_063", "AH-64D阿帕奇", "elite_modern_apache", 3, "精英航空",
     "阿帕奇武装直升机",
     "Modern AH-64D Apache helicopter side profile, tandem cockpit, nose sensor ball, stub wings with rocket pods, tail rotor guard, gun turret left.",
     "aircraft"),
    (64, "vis_enemy_064", "联合星区指挥所", "boss_modern_command", 3, "Boss",
     "机动指挥所",
     "Modern joint sector command post boss vehicle, expanded TOC truck with satellite dishes, ECM domes, generator trailers, camouflage net draped massive silhouette.",
     "vehicle"),
    (65, "vis_enemy_065", "蜂群微型无人机", "enemy_future_drone", 4, "步兵",
     "蜂群无人机",
     "Near-future micro drone swarm carrier rack on tripod mast, dozens of insect-scale quadrotors clipped in hex cells, blue phase glow on charging ports, no human figures.",
     "vehicle"),
    (66, "vis_enemy_066", "外骨骼突击兵", "enemy_future_cyborg", 4, "步兵",
     "动力外骨骼步兵",
     "Near-future powered exoskeleton assault soldier profile, hydraulic leg frames, sealed helmet visor, coil rifle left, blue enemy phase nodes on joints.",
     "infantry"),
    (67, "vis_enemy_067", "XM-3机步突击车", "enemy_future_mech", 4, "载具",
     "六轮机步突击车",
     "Near-future XM-3 mechanized assault vehicle six-wheel, angular ceramic armor, railgun turret left, drone launch tubes on roof.",
     "vehicle"),
    (68, "vis_enemy_068", "L-220悬浮主战平台", "enemy_future_hovertank", 4, "载具",
     "悬浮主战平台另一构型",
     "Near-future L-220 hover main battle platform alternate configuration, wider skirt, dual phase thrusters, heavy chin railgun, heat haze on cowling unlike assault car variant.",
     "vehicle"),
    (69, "vis_enemy_069", "光学迷彩渗透组", "elite_future_spectre", 4, "精英步兵",
     "光学迷彩特战",
     "Near-future spectre infiltrator profile, active camouflage cloak with pixel shimmer, suppressed bullpup rifle, faint blue outline glitch on edges.",
     "infantry"),
    (70, "vis_enemy_070", "GK-1重型步行机", "elite_future_colossus", 4, "精英载具",
     "重型双足机甲",
     "Near-future GK-1 heavy walker elite, thicker legs than HK-09, missile racks on shoulders, blue reactor core, battle damage exposing wiring.",
     "vehicle"),
    (71, "vis_enemy_071", "风暴核心指挥塔", "boss_future_nexus", 4, "Boss",
     "近未来Boss指挥塔",
     "Near-future Storm Nexus command spire boss structure, vertical phased array tower on armored crawler base, lightning-blue phase arcs along spine, dominating height.",
     "vehicle"),
    # D 72-100 pool
    (72, "vis_pool_001", "李-恩菲尔德志愿兵排", "foe_pool_001", 0, "步兵",
     "志愿步枪排",
     "WW1 British volunteer rifleman profile alternate kit, SMLE with cloth wrap on stock, scarf, enamel mug on belt, lighter mud tone than standard rifleman.",
     "infantry"),
    (73, "vis_pool_002", "劳斯莱斯 Mk.II 装甲车", "foe_pool_002", 0, "载具",
     "Mk.II装甲车",
     "WW1 Rolls-Royce Armoured Car Mk II evolution, revised turret bustle, additional headlight guard, heavier sand shields on wheel arches, darker olive drab.",
     "vehicle"),
    (74, "vis_pool_003", "维克斯.303机枪阵地", "foe_pool_003", 0, "阵地",
     "维克斯机枪",
     "WW1 Vickers .303 water-cooled gun on high tripod, ammunition cloth belt feed, sandbagged firing step, condenser can hose loop.",
     "vehicle"),
    (75, "vis_pool_004", "福特T型战地救护车", "foe_pool_004", 0, "支援",
     "战地救护T型车",
     "WW1 field ambulance Ford T variant with stretcher rack on running boards, additional canvas awning poles stowed, dual red cross panels, lantern on fender.",
     "vehicle"),
    (76, "vis_pool_005", "MP18突击队", "foe_pool_005", 0, "步兵",
     "突击队MP18",
     "WW1 assault detachment soldier profile, MP18 with snail drum, trench club on belt, blackened helmet, stick grenade bandolier.",
     "infantry"),
    (77, "vis_pool_006", "M1加兰德伞兵班", "foe_pool_006", 1, "步兵",
     "加兰德伞兵",
     "WW2 US paratrooper profile, M1 Garand with folding stock variant, M1942 jump uniform, leg bag straps, Corcoran boots.",
     "infantry"),
    (78, "vis_pool_007", "黄蜂Hummel自行火炮", "foe_pool_007", 1, "载具",
     "胡蜂自行火炮",
     "WW2 Hummel 150mm self-propelled gun on Panzer IV chassis, open fighting compartment, long howitzer left, spare track links on hull.",
     "vehicle"),
    (79, "vis_pool_008", "PaK 40反坦克炮组", "foe_pool_008", 1, "阵地",
     "PaK40反坦克炮",
     "WW2 PaK 40 75mm anti-tank gun on cruciform mount, splinter shield, wheels raised for firing, stacked AP rounds in crates.",
     "vehicle"),
    (80, "vis_pool_009", "GMC 2.5t补给卡车", "foe_pool_009", 1, "支援",
     "补给卡车",
     "WW2 GMC CCKW 2.5 ton cargo truck profile, canvas canopy over bed, fuel drums strapped, winch bumper, olive drab star hood.",
     "vehicle"),
    (81, "vis_pool_010", "毛瑟Kar98k狙击组", "foe_pool_010", 1, "步兵",
     "Kar98k狙击",
     "WW2 German sniper profile, Kar98k with ZF39 scope, ghillie strips on shoulders, fingerless gloves, bolt handle polished.",
     "infantry"),
    (82, "vis_pool_011", "BMD-1空降战车", "foe_pool_011", 2, "步兵",
     "BMD空降战车",
     "Cold War BMD-1 airborne IFV, very low hull, 73mm gun left, hydropneumatic suspension pods, paratrooper door outline on flank.",
     "vehicle"),
    (83, "vis_pool_012", "BMP-1步兵战车", "foe_pool_012", 2, "载具",
     "BMP-1池化",
     "Cold War BMP-1 alternate camo, rubber side skirts torn, AT-3 Sagger rail empty, infantry periscope row, fuel barrel on rear.",
     "vehicle"),
    (84, "vis_pool_013", "9K111法特导弹组", "foe_pool_013", 2, "阵地",
     "法特反坦克导弹",
     "Cold War 9K111 Fagot ATGM team equipment profile: launcher tube on tripod, thermal sight box, missile canister upright, no soldier face.",
     "vehicle"),
    (85, "vis_pool_014", "P-18雷达警戒车", "foe_pool_014", 2, "支援",
     "P-18雷达车",
     "Cold War P-18 Spoon Rest radar on Ural truck, folding parabolic mesh antenna, cabin map light glow implied off, green camouflage nets folded on roof.",
     "vehicle"),
    (86, "vis_pool_015", "BREM-1装甲抢修车", "foe_pool_015", 2, "支援",
     "BREM抢修车",
     "Cold War BREM-1 armored recovery on T-72 hull, crane jib, welding cables, spare track sections on deck.",
     "vehicle"),
    (87, "vis_pool_016", "M4卡宾特遣班", "foe_pool_016", 3, "步兵",
     "M4卡宾特遣",
     "Modern special forces operator profile, M4 carbine with PEQ and holographic sight, plate carrier slick, IR flag patch shape only.",
     "infantry"),
    (88, "vis_pool_017", "爱国者PAC-3发射车", "foe_pool_017", 3, "载具",
     "爱国者发射车",
     "Modern Patriot PAC-3 launcher erector on semi-trailer, four canister cells angled, radar cable drum, desert tan with dust.",
     "vehicle"),
    (89, "vis_pool_018", "HIMARS火箭炮组", "foe_pool_018", 3, "阵地",
     "HIMARS",
     "Modern HIMARS truck launcher, single six-pack pod, FMTV cab, hydraulic stabilizers, chalk serial blocks illegible.",
     "vehicle"),
    (90, "vis_pool_019", "RQ-7影子无人机班", "foe_pool_019", 3, "支援",
     "影子无人机",
     "Modern RQ-7 Shadow UAV on rail launcher trailer, high aspect ratio wing, pusher propeller, ground control antenna mast folded.",
     "vehicle"),
    (91, "vis_pool_020", "EA-18G电子战小组", "foe_pool_020", 3, "支援",
     "咆哮者电子战机",
     "Modern EA-18G Growler aircraft side profile on deck trolley silhouette simplified, ALQ wing pods, jamming pods under wings, no carrier background.",
     "aircraft"),
    (92, "vis_pool_021", "神经接口突击兵", "foe_pool_021", 4, "步兵",
     "神经接口步兵",
     "Near-future neural-interface assault trooper profile, skull port cable, reflex booster braces on calves, bullpup coil carbine left.",
     "infantry"),
    (93, "vis_pool_022", "HK-07量产机兵", "foe_pool_022", 4, "载具",
     "HK-07机兵",
     "Near-future HK-07 mass-production bipedal mech soldier chassis, lighter than HK-09, stamped serial plates blank, production line weld marks.",
     "vehicle"),
    (94, "vis_pool_023", "HEL-30激光炮阵列", "foe_pool_023", 4, "阵地",
     "激光防空阵列",
     "Near-future HEL-30 laser defense array on trailer, gimbal turret with sapphire lens barrel, capacitor boxes, warning hazard stripes no readable text.",
     "vehicle"),
    (95, "vis_pool_024", "N-Repair纳米工程车", "foe_pool_024", 4, "支援",
     "纳米工程车",
     "Near-future N-Repair nano-fabrication repair truck, articulated printer arm, material hopper silo, blue phase feed lines along hull.",
     "vehicle"),
    (96, "vis_pool_025", "X-9猎杀者渗透组", "foe_pool_025", 4, "步兵",
     "X-9渗透者",
     "Near-future X-9 hunter infiltrator profile, monoblade carbine, cloak with adaptive pixels, visor slits glowing dim blue.",
     "infantry"),
    (97, "vis_pool_026", "毛瑟C96征召兵排", "foe_pool_026", 4, "步兵",
     "C96征召兵（近未来混搭）",
     "Near-future conscript soldier profile anachronistic Mauser C96 holster shape as ceremonial sidearm plus modern phase armor vest, satirical hybrid kit, weary stance.",
     "infantry"),
    (98, "vis_pool_027", "Sd.Kfz.251/1半履带车", "foe_pool_027", 4, "载具",
     "251半履带（近未来改装）",
     "Near-future retro-fitted Sd.Kfz 251 half-track with phase-coated armor plates over classic hull, MG42 shield left, hybrid diesel-electric exhaust shroud.",
     "vehicle"),
    (99, "vis_pool_028", "SS-C-1岸防导弹组", "foe_pool_028", 4, "阵地",
     "岸防导弹",
     "Near-future SS-C-1 coastal missile launcher truck, twin vertical launch tubes, acquisition radar dish folded, naval gray with blue phase trim.",
     "vehicle"),
    (100, "vis_pool_029", "PS-9相位中继站", "foe_pool_029", 4, "支援",
     "相位中继站",
     "Near-future PS-9 phase relay station on tracked carrier, tall resonator coil, capacitor ring, blue energy arc between twin masts, support guy wires.",
     "vehicle"),
]

NEG_MAP = {
    "vehicle": NEG_VEHICLE,
    "infantry": NEG_INFANTRY,
    "aircraft": NEG_AIRCRAFT,
    "naval": NEG_VEHICLE + ", aircraft wings",
    "boss": NEG_VEHICLE,
}


def parse_manifest_rows() -> list[dict]:
    text = MANIFEST.read_text(encoding="utf-8")
    rows = []
    for line in text.splitlines():
        m = re.match(
            r"^\|\s*(\d+)\s*\|\s*(\S+)\s*\|\s*([^|]+?)\s*\|\s*(\d+)\s*\|\s*([^|]+?)\s*\|\s*(\S+)\s*\|",
            line,
        )
        if m:
            rows.append(
                {
                    "num": int(m.group(1)),
                    "visual_id": m.group(2).strip(),
                    "display_name": m.group(3).strip(),
                    "era": int(m.group(4)),
                    "role": m.group(5).strip(),
                    "archetype_id": m.group(6).strip(),
                }
            )
    return rows


def render_entry(e: tuple, manifest_row: dict | None) -> str:
    num, vid, name, aid, era, role, note_zh, subject, neg_kind = e
    era_zh = ERA_LABEL[era]
    full_prompt = f"Game enemy unit card icon art, {subject}{TAIL}"
    neg = NEG_MAP.get(neg_kind, NEG_VEHICLE)
    block = "A" if num <= 29 else "B" if num <= 35 else "C" if num <= 71 else "D"
    lines = [
        f"### {num}) {vid}（{name}）",
        "",
        f"**区块：** {block} | **era：** {era}（{era_zh}） | **兵种：** {role}  ",
        f"**archetype_id：** `{aid}` | **输出：** `assets/card_icons/units/{vid}.png`",
        "",
        f"**说明：** {note_zh}。与清单 `display_name` 一致；生图后绿幕抠图部署，见 `tools/deploy_agent_unit_icons_1_5.py` 同类流程。",
        "",
        "#### English prompt（Cursor Agent / 绿幕 #00FF00）",
        "",
        "```text",
        full_prompt,
        "",
        f"Negative prompt: {neg}",
        "```",
        "",
        "#### 负面提示词（中文备忘）",
        "",
        "三分之四视角、透视、等距、俯视、朝右、背景场景、地面投影、文字水印、模糊变形。",
        "",
        "---",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    manifest_rows = {r["num"]: r for r in parse_manifest_rows()}
    if len(manifest_rows) < 100:
        print(f"WARN: parsed {len(manifest_rows)} manifest rows")
    by_num = {e[0]: e for e in ENTRIES}
    if len(by_num) != 100:
        raise SystemExit(f"Expected 100 entries, got {len(by_num)}")

    header = """# 敌方单位卡图 Agent 生图提示词（100）

**版本：** v1.0 | 2026-05-20  
**对齐：** `docs/card_icon_manifest_100_zh.md`（100 敌人，`visual_id` 一行一提示词）  
**规格：** 与已成功落地的 #1–5 相同 — 半写实硬表面、**严格正侧视**、**朝左**、**#00FF00 绿幕** → 抠图后 512×512 透明 PNG。

## 使用方式

1. 在 Cursor Agent 对话中复制对应条目的 **English prompt**（含 Negative prompt 约束）。  
2. 生图输出保存后，用 `tools/deploy_agent_unit_icons_1_5.py` 的逻辑批量抠绿（或扩展脚本按 `visual_id` 部署）。  
3. 每条提示词的 **主体描述互不重复**；仅末尾技术约束（侧视/朝左/绿幕）统一。

## 统一技术约束（已写入每条 prompt 正文）

- 正侧视 `true profile side view`，正交投影  
- **朝左**（车头/炮口/正面在画面左侧）  
- 半写实军事硬表面，铆钉/磨损/分件  
- 纯色绿幕 `#00FF00`，无地面无场景  
- 512×512，无文字无水印  

---

"""

    body = []
    for n in range(1, 101):
        if n not in by_num:
            raise SystemExit(f"Missing entry #{n}")
        body.append(render_entry(by_num[n], manifest_rows.get(n)))

    OUT.write_text(header + "\n".join(body), encoding="utf-8")
    print(f"Wrote {OUT} ({len(ENTRIES)} prompts, {OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
