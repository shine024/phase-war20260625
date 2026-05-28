# Platform V3 Stats Generator
# 为 default_cards.gd 中的所有平台卡片生成 v3 属性调用

platform_data = {
    # 一战 (era=0)
    "platform_ww1_light": {
        "era": 0, "pt": 0, "hp": 65.0, "speed": 115.0, "weapon": "冲锋枪", "wt": 0, "dmg": 14.0, "rng": 120.0, "int": 0.8, "deploy": 4,
        "atk_l": 14.0, "atk_a": 7.0, "atk_air": 0.0, "def_l": 2.0, "def_a": 3.0, "def_air": 0.0, "def_val": 2
    },
    "platform_ww1_medium": {
        "era": 0, "pt": 2, "hp": 200.0, "speed": 40.0, "weapon": "机枪", "wt": 0, "dmg": 28.0, "rng": 140.0, "int": 1.2, "deploy": 2,
        "atk_l": 28.0, "atk_a": 35.0, "atk_air": 0.0, "def_l": 4.0, "def_a": 8.0, "def_air": 0.0, "def_val": 6
    },
    "platform_ww1_fort": {
        "era": 0, "pt": 3, "hp": 260.0, "speed": 0.0, "weapon": "机枪", "wt": 0, "dmg": 25.0, "rng": 180.0, "int": 1.5, "deploy": 1,
        "atk_l": 25.0, "atk_a": 30.0, "atk_air": 0.0, "def_l": 6.0, "def_a": 10.0, "def_air": 0.0, "def_val": 8
    },
    "platform_ww1_medic": {
        "era": 0, "pt": 9, "hp": 80.0, "speed": 75.0, "weapon": "手枪", "wt": 0, "dmg": 8.0, "rng": 80.0, "int": 1.0, "deploy": 3,
        "atk_l": 8.0, "atk_a": 4.0, "atk_air": 0.0, "def_l": 2.0, "def_a": 2.0, "def_air": 0.0, "def_val": 2
    },
    "platform_ww1_radar": {
        "era": 0, "pt": 4, "hp": 180.0, "speed": 0.0, "weapon": "步枪", "wt": 0, "dmg": 12.0, "rng": 300.0, "int": 2.0, "deploy": 1,
        "atk_l": 12.0, "atk_a": 8.0, "atk_air": 0.0, "def_l": 3.0, "def_a": 4.0, "def_air": 0.0, "def_val": 4
    },

    # 二战 (era=1)
    "platform_ww2_light": {
        "era": 1, "pt": 5, "hp": 50.0, "speed": 135.0, "weapon": "冲锋枪", "wt": 0, "dmg": 16.0, "rng": 120.0, "int": 0.7, "deploy": 4,
        "atk_l": 16.0, "atk_a": 8.0, "atk_air": 0.0, "def_l": 2.0, "def_a": 3.0, "def_air": 0.0, "def_val": 2
    },
    "platform_ww2_medium": {
        "era": 1, "pt": 1, "hp": 110.0, "speed": 75.0, "weapon": "步枪", "wt": 0, "dmg": 20.0, "rng": 150.0, "int": 1.0, "deploy": 3,
        "atk_l": 20.0, "atk_a": 25.0, "atk_air": 0.0, "def_l": 3.0, "def_a": 6.0, "def_air": 0.0, "def_val": 5
    },
    "platform_ww2_heavy": {
        "era": 1, "pt": 2, "hp": 200.0, "speed": 40.0, "weapon": "火箭炮", "wt": 1, "dmg": 35.0, "rng": 200.0, "int": 2.5, "deploy": 2,
        "atk_l": 25.0, "atk_a": 45.0, "atk_air": 0.0, "def_l": 5.0, "def_a": 10.0, "def_air": 0.0, "def_val": 8
    },
    "platform_ww2_raider": {
        "era": 1, "pt": 6, "hp": 90.0, "speed": 100.0, "weapon": "机枪", "wt": 0, "dmg": 22.0, "rng": 130.0, "int": 0.9, "deploy": 4,
        "atk_l": 22.0, "atk_a": 15.0, "atk_air": 0.0, "def_l": 3.0, "def_a": 4.0, "def_air": 0.0, "def_val": 3
    },
    "platform_ww2_radar": {
        "era": 1, "pt": 4, "hp": 180.0, "speed": 0.0, "weapon": "步枪", "wt": 0, "dmg": 14.0, "rng": 320.0, "int": 1.8, "deploy": 1,
        "atk_l": 14.0, "atk_a": 10.0, "atk_air": 0.0, "def_l": 3.0, "def_a": 5.0, "def_air": 0.0, "def_val": 4
    },
    "platform_ww2_siege": {
        "era": 1, "pt": 7, "hp": 300.0, "speed": 0.0, "weapon": "火箭炮", "wt": 1, "dmg": 40.0, "rng": 250.0, "int": 3.0, "deploy": 1,
        "atk_l": 20.0, "atk_a": 50.0, "atk_air": 0.0, "def_l": 4.0, "def_a": 12.0, "def_air": 0.0, "def_val": 8
    },
    "platform_ww2_fortress": {
        "era": 1, "pt": 3, "hp": 260.0, "speed": 0.0, "weapon": "机枪", "wt": 0, "dmg": 24.0, "rng": 160.0, "int": 1.3, "deploy": 1,
        "atk_l": 24.0, "atk_a": 28.0, "atk_air": 0.0, "def_l": 6.0, "def_a": 10.0, "def_air": 0.0, "def_val": 8
    },

    # 冷战 (era=2)
    "platform_cold_light": {
        "era": 2, "pt": 0, "hp": 65.0, "speed": 115.0, "weapon": "冲锋枪", "wt": 0, "dmg": 18.0, "rng": 130.0, "int": 0.7, "deploy": 4,
        "atk_l": 18.0, "atk_a": 10.0, "atk_air": 0.0, "def_l": 2.0, "def_a": 4.0, "def_air": 0.0, "def_val": 3
    },
    "platform_cold_medium": {
        "era": 2, "pt": 2, "hp": 200.0, "speed": 40.0, "weapon": "火箭炮", "wt": 1, "dmg": 38.0, "rng": 220.0, "int": 2.2, "deploy": 2,
        "atk_l": 28.0, "atk_a": 48.0, "atk_air": 0.0, "def_l": 5.0, "def_a": 10.0, "def_air": 0.0, "def_val": 8
    },
    "platform_cold_ifv": {
        "era": 2, "pt": 8, "hp": 140.0, "speed": 50.0, "weapon": "机枪", "wt": 0, "dmg": 24.0, "rng": 150.0, "int": 1.0, "deploy": 3,
        "atk_l": 24.0, "atk_a": 18.0, "atk_air": 0.0, "def_l": 4.0, "def_a": 7.0, "def_air": 0.0, "def_val": 6
    },
    "platform_cold_scout": {
        "era": 2, "pt": 5, "hp": 50.0, "speed": 135.0, "weapon": "冲锋枪", "wt": 0, "dmg": 17.0, "rng": 125.0, "int": 0.7, "deploy": 4,
        "atk_l": 17.0, "atk_a": 9.0, "atk_air": 0.0, "def_l": 2.0, "def_a": 3.0, "def_air": 0.0, "def_val": 2
    },
    "platform_cold_radar": {
        "era": 2, "pt": 4, "hp": 180.0, "speed": 0.0, "weapon": "步枪", "wt": 0, "dmg": 15.0, "rng": 350.0, "int": 1.8, "deploy": 1,
        "atk_l": 15.0, "atk_a": 12.0, "atk_air": 0.0, "def_l": 3.0, "def_a": 6.0, "def_air": 0.0, "def_val": 5
    },
    "platform_cold_carrier": {
        "era": 2, "pt": 8, "hp": 140.0, "speed": 50.0, "weapon": "机枪", "wt": 0, "dmg": 23.0, "rng": 145.0, "int": 1.0, "deploy": 3,
        "atk_l": 23.0, "atk_a": 17.0, "atk_air": 0.0, "def_l": 4.0, "def_a": 7.0, "def_air": 0.0, "def_val": 6
    },

    # 现代 (era=3)
    "platform_modern_light": {
        "era": 3, "pt": 0, "hp": 65.0, "speed": 115.0, "weapon": "冲锋枪", "wt": 0, "dmg": 20.0, "rng": 140.0, "int": 0.6, "deploy": 4,
        "atk_l": 20.0, "atk_a": 12.0, "atk_air": 0.0, "def_l": 3.0, "def_a": 5.0, "def_air": 0.0, "def_val": 4
    },
    "platform_modern_medium": {
        "era": 3, "pt": 1, "hp": 110.0, "speed": 75.0, "weapon": "火箭炮", "wt": 1, "dmg": 42.0, "rng": 240.0, "int": 2.0, "deploy": 2,
        "atk_l": 32.0, "atk_a": 52.0, "atk_air": 0.0, "def_l": 5.0, "def_a": 11.0, "def_air": 0.0, "def_val": 9
    },
    "platform_modern_radar": {
        "era": 3, "pt": 4, "hp": 180.0, "speed": 0.0, "weapon": "步枪", "wt": 0, "dmg": 16.0, "rng": 380.0, "int": 1.6, "deploy": 1,
        "atk_l": 16.0, "atk_a": 14.0, "atk_air": 0.0, "def_l": 3.0, "def_a": 7.0, "def_air": 0.0, "def_val": 5
    },
    "platform_modern_spg": {
        "era": 3, "pt": 7, "hp": 300.0, "speed": 0.0, "weapon": "火箭炮", "wt": 1, "dmg": 45.0, "rng": 280.0, "int": 2.8, "deploy": 1,
        "atk_l": 22.0, "atk_a": 55.0, "atk_air": 0.0, "def_l": 4.0, "def_a": 13.0, "def_air": 0.0, "def_val": 9
    },
    "platform_modern_stealth": {
        "era": 3, "pt": 10, "hp": 50.0, "speed": 115.0, "weapon": "冲锋枪", "wt": 0, "dmg": 22.0, "rng": 135.0, "int": 0.6, "deploy": 5,
        "atk_l": 22.0, "atk_a": 13.0, "atk_air": 0.0, "def_l": 2.0, "def_a": 3.0, "def_air": 0.0, "def_val": 2
    },
    "platform_modern_guard_heavy": {
        "era": 3, "pt": 1, "hp": 110.0, "speed": 75.0, "weapon": "火箭炮", "wt": 1, "dmg": 48.0, "rng": 250.0, "int": 1.9, "deploy": 2,
        "atk_l": 38.0, "atk_a": 58.0, "atk_air": 0.0, "def_l": 6.0, "def_a": 14.0, "def_air": 0.0, "def_val": 10
    },

    # 近未来 (era=4)
    "platform_future_light": {
        "era": 4, "pt": 10, "hp": 50.0, "speed": 115.0, "weapon": "激光炮", "wt": 0, "dmg": 24.0, "rng": 150.0, "int": 0.5, "deploy": 5,
        "atk_l": 24.0, "atk_a": 15.0, "atk_air": 0.0, "def_l": 2.0, "def_a": 4.0, "def_air": 0.0, "def_val": 3
    },
    "platform_future_medium": {
        "era": 4, "pt": 6, "hp": 90.0, "speed": 100.0, "weapon": "激光炮", "wt": 0, "dmg": 38.0, "rng": 200.0, "int": 1.2, "deploy": 4,
        "atk_l": 38.0, "atk_a": 28.0, "atk_air": 0.0, "def_l": 4.0, "def_a": 8.0, "def_air": 0.0, "def_val": 6
    },
    "platform_future_radar": {
        "era": 4, "pt": 4, "hp": 180.0, "speed": 0.0, "weapon": "激光炮", "wt": 0, "dmg": 18.0, "rng": 400.0, "int": 1.5, "deploy": 1,
        "atk_l": 18.0, "atk_a": 16.0, "atk_air": 0.0, "def_l": 3.0, "def_a": 8.0, "def_air": 0.0, "def_val": 6
    },
    "platform_future_heavy": {
        "era": 4, "pt": 2, "hp": 200.0, "speed": 40.0, "weapon": "米加粒子炮", "wt": 0, "dmg": 60.0, "rng": 300.0, "int": 2.5, "deploy": 2,
        "atk_l": 45.0, "atk_a": 70.0, "atk_air": 0.0, "def_l": 6.0, "def_a": 15.0, "def_air": 0.0, "def_val": 11
    },

    # 终极
    "omega_platform": {
        "era": 4, "pt": 11, "hp": 240.0, "speed": 30.0, "weapon": "米加粒子炮", "wt": 0, "dmg": 70.0, "rng": 320.0, "int": 2.2, "deploy": 7,
        "atk_l": 55.0, "atk_a": 80.0, "atk_air": 0.0, "def_l": 8.0, "def_a": 18.0, "def_air": 0.0, "def_val": 13
    },
}

# 生成 GDScript 代码
output = []
for platform_id, data in platform_data.items():
    summary_def = data["def_val"]
    line = f'\t\t\t_apply_platform_v3_stats(c, {data["era"]}, {data["pt"]}, {data["hp"]}, {data["speed"]}, "{data["weapon"]}", {data["wt"]}, {data["dmg"]}, {data["rng"]}, {data["int"]}, {data["deploy"]}, {data["atk_l"]}, {data["atk_a"]}, {data["atk_air"]}, {data["def_l"]}, {data["def_a"]}, {data["def_air"]})'
    output.append(f'"{platform_id}":')
    output.append(f'\t\t\tc.summary_line = c.summary_line.replace("重量 \\d+", "防御 {summary_def}")  # 更新防御值')
    output.append(line)

print("\n".join(output[:20]))  # 显示前几个作为示例
