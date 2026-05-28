#!/usr/bin/env python3
"""
将 enemy_unit_manifest.gd 的旧数据格式转换为新格式
旧格式: { "kind": int, "hp": float, "dmg": float, "rng": float, "ivl": float, "spd": float, "def": float, "weapon": str }
新格式: 需要添加 weapon_type, deploy_speed, attack_light/armor/air, defense_light/armor/air
"""

# 根据设计文档的100个单位数据
UNIT_DATA = {
    # 一战 WW1 (20个单位)
    "ww1_mp18": {"name": "MP18突击班", "kind": 0, "hp": 65.0, "atk_light": 35.0, "atk_armor": 0.0, "atk_air": 0.0,
                 "def_light": 8.0, "def_armor": 5.0, "def_air": 3.0, "rng": 95.0, "ivl": 0.67, "spd": 115.0,
                 "weapon_type": 0, "deploy_speed": 4, "weapon": "冲锋枪", "era": 0},
    "ww1_mauser": {"name": "毛瑟步枪班", "kind": 0, "hp": 70.0, "atk_light": 30.0, "atk_armor": 0.0, "atk_air": 0.0,
                   "def_light": 8.0, "def_armor": 5.0, "def_air": 3.0, "rng": 135.0, "ivl": 1.5, "spd": 105.0,
                   "weapon_type": 0, "deploy_speed": 3, "weapon": "步枪", "era": 0},
    "ww1_enfield": {"name": "李恩菲尔德班", "kind": 0, "hp": 70.0, "atk_light": 30.0, "atk_armor": 0.0, "atk_air": 0.0,
                    "def_light": 8.0, "def_armor": 5.0, "def_air": 3.0, "rng": 135.0, "ivl": 1.2, "spd": 105.0,
                    "weapon_type": 0, "deploy_speed": 3, "weapon": "步枪", "era": 0},
    "ww1_mg08": {"name": "MG08机枪巢", "kind": 2, "hp": 180.0, "atk_light": 45.0, "atk_armor": 0.0, "atk_air": 25.0,
                 "def_light": 12.0, "def_armor": 8.0, "def_air": 10.0, "rng": 160.0, "ivl": 0.5, "spd": 0.0,
                 "weapon_type": 0, "deploy_speed": 0, "weapon": "机枪", "era": 0},
    "ww1_vickers": {"name": "维克斯机枪巢", "kind": 2, "hp": 180.0, "atk_light": 40.0, "atk_armor": 0.0, "atk_air": 22.0,
                    "def_light": 12.0, "def_armor": 8.0, "def_air": 10.0, "rng": 160.0, "ivl": 0.56, "spd": 0.0,
                    "weapon_type": 0, "deploy_speed": 0, "weapon": "机枪", "era": 0},
    "ww1_m81": {"name": "81mm迫击炮组", "kind": 2, "hp": 80.0, "atk_light": 40.0, "atk_armor": 20.0, "atk_air": 0.0,
                "def_light": 6.0, "def_armor": 5.0, "def_air": 3.0, "rng": 99.0, "ivl": 2.0, "spd": 60.0,
                "weapon_type": 1, "deploy_speed": 1, "weapon": "迫击炮", "era": 0},
    "ww1_m76": {"name": "76mm迫击炮组", "kind": 2, "hp": 80.0, "atk_light": 38.0, "atk_armor": 18.0, "atk_air": 0.0,
                "def_light": 6.0, "def_armor": 5.0, "def_air": 3.0, "rng": 99.0, "ivl": 2.0, "spd": 60.0,
                "weapon_type": 1, "deploy_speed": 1, "weapon": "迫击炮", "era": 0},
    "ww1_storm": {"name": "暴风突击队", "kind": 0, "hp": 90.0, "atk_light": 40.0, "atk_armor": 5.0, "atk_air": 0.0,
                  "def_light": 10.0, "def_armor": 6.0, "def_air": 4.0, "rng": 95.0, "ivl": 0.67, "spd": 125.0,
                  "weapon_type": 0, "deploy_speed": 5, "weapon": "冲锋枪", "era": 0},
    "ww1_rolls": {"name": "罗尔斯装甲车", "kind": 1, "hp": 150.0, "atk_light": 25.0, "atk_armor": 35.0, "atk_air": 5.0,
                  "def_light": 18.0, "def_armor": 22.0, "def_air": 10.0, "rng": 135.0, "ivl": 1.0, "spd": 120.0,
                  "weapon_type": 0, "deploy_speed": 5, "weapon": "机枪", "era": 0},
    "ww1_lanchest": {"name": "兰彻斯特装甲车", "kind": 1, "hp": 150.0, "atk_light": 22.0, "atk_armor": 32.0, "atk_air": 8.0,
                     "def_light": 18.0, "def_armor": 22.0, "def_air": 10.0, "rng": 135.0, "ivl": 1.0, "spd": 120.0,
                     "weapon_type": 0, "deploy_speed": 5, "weapon": "机枪", "era": 0},
    "ww1_ft17": {"name": "FT-17轻型坦克", "kind": 1, "hp": 140.0, "atk_light": 28.0, "atk_armor": 40.0, "atk_air": 0.0,
                 "def_light": 20.0, "def_armor": 25.0, "def_air": 8.0, "rng": 135.0, "ivl": 1.2, "spd": 75.0,
                 "weapon_type": 0, "deploy_speed": 3, "weapon": "火炮", "era": 0},
    "ww1_saint": {"name": "圣沙蒙坦克", "kind": 1, "hp": 200.0, "atk_light": 20.0, "atk_armor": 50.0, "atk_air": 0.0,
                  "def_light": 25.0, "def_armor": 35.0, "def_air": 8.0, "rng": 160.0, "ivl": 1.5, "spd": 50.0,
                  "weapon_type": 0, "deploy_speed": 2, "weapon": "火炮", "era": 0},
    "ww1_a7v": {"name": "A7V重型坦克", "kind": 1, "hp": 220.0, "atk_light": 18.0, "atk_armor": 48.0, "atk_air": 0.0,
                "def_light": 28.0, "def_armor": 38.0, "def_air": 8.0, "rng": 160.0, "ivl": 2.0, "spd": 40.0,
                "weapon_type": 0, "deploy_speed": 2, "weapon": "火炮", "era": 0},
    "ww1_mark4": {"name": "马克IV型坦克", "kind": 1, "hp": 210.0, "atk_light": 22.0, "atk_armor": 45.0, "atk_air": 0.0,
                  "def_light": 22.0, "def_armor": 30.0, "def_air": 8.0, "rng": 135.0, "ivl": 1.5, "spd": 50.0,
                  "weapon_type": 0, "deploy_speed": 2, "weapon": "机枪", "era": 0},
    "ww1_77mm": {"name": "77mm野战炮", "kind": 2, "hp": 100.0, "atk_light": 45.0, "atk_armor": 30.0, "atk_air": 0.0,
                 "def_light": 6.0, "def_armor": 8.0, "def_air": 4.0, "rng": 99.0, "ivl": 3.0, "spd": 0.0,
                 "weapon_type": 1, "deploy_speed": 0, "weapon": "火炮", "era": 0},
    "ww1_105mm": {"name": "105mm榴弹炮", "kind": 2, "hp": 120.0, "atk_light": 50.0, "atk_armor": 35.0, "atk_air": 0.0,
                  "def_light": 6.0, "def_armor": 8.0, "def_air": 4.0, "rng": 99.0, "ivl": 4.0, "spd": 0.0,
                  "weapon_type": 1, "deploy_speed": 0, "weapon": "火炮", "era": 0},
    "ww1_37mm": {"name": "37mm高射炮", "kind": 2, "hp": 100.0, "atk_light": 10.0, "atk_armor": 8.0, "atk_air": 50.0,
                 "def_light": 8.0, "def_armor": 8.0, "def_air": 18.0, "rng": 175.0, "ivl": 0.67, "spd": 0.0,
                 "weapon_type": 0, "deploy_speed": 0, "weapon": "高射炮", "era": 0},
    "ww1_cavalry": {"name": "骑兵斥候", "kind": 0, "hp": 60.0, "atk_light": 20.0, "atk_armor": 0.0, "atk_air": 0.0,
                    "def_light": 6.0, "def_armor": 4.0, "def_air": 2.0, "rng": 65.0, "ivl": 1.0, "spd": 150.0,
                    "weapon_type": 0, "deploy_speed": 6, "weapon": "步枪", "era": 0},
    "ww1_flame": {"name": "火焰喷射兵", "kind": 0, "hp": 70.0, "atk_light": 45.0, "atk_armor": 15.0, "atk_air": 0.0,
                  "def_light": 8.0, "def_armor": 5.0, "def_air": 3.0, "rng": 65.0, "ivl": 1.0, "spd": 75.0,
                  "weapon_type": 0, "deploy_speed": 3, "weapon": "火焰", "era": 0},
    "ww1_engineer": {"name": "工兵班", "kind": 2, "hp": 90.0, "atk_light": 30.0, "atk_armor": 25.0, "atk_air": 0.0,
                     "def_light": 10.0, "def_armor": 8.0, "def_air": 5.0, "rng": 85.0, "ivl": 1.0, "spd": 80.0,
                     "weapon_type": 0, "deploy_speed": 3, "weapon": "步枪", "era": 0},
}

def convert_to_new_format(old_data):
    """转换旧数据格式为新格式"""
    return {
        "kind": old_data["kind"],
        "hp": old_data["hp"],
        "weapon_type": old_data["weapon_type"],
        "deploy_speed": old_data["deploy_speed"],
        "attack_light": old_data["atk_light"],
        "attack_armor": old_data["atk_armor"],
        "attack_air": old_data["atk_air"],
        "defense_light": old_data["def_light"],
        "defense_armor": old_data["def_armor"],
        "defense_air": old_data["def_air"],
        "rng": old_data["rng"],
        "ivl": old_data["ivl"],
        "spd": old_data["spd"],
        "weapon": old_data["weapon"],
        "era": old_data.get("era", 0)
    }

if __name__ == "__main__":
    print("数据转换脚本已准备")
    print(f"共有 {len(UNIT_DATA)} 个单位")
    for unit_id, data in UNIT_DATA.items():
        new_data = convert_to_new_format(data)
        print(f"{unit_id}: {data['name']}")
        print(f"  轻装: {new_data['attack_light']:.0f}, 装甲: {new_data['attack_armor']:.0f}, 空中: {new_data['attack_air']:.0f}")
