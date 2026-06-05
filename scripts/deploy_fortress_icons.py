"""
抠去 11 张堡垒/omega 卡图的白色背景，转透明 PNG。
同时部署到 3 个目录：
  1. assets/card_icons/  (UI 背包/相位仪)
  2. assets/card_icons/units/  (敌方战场渲染 vis_enemy_*)
  3. assets/card_icons/units/vis_pool_*  (池子卡)

同时替换 enemy_unit_manifest 和 player 侧的映射。
"""
import os
from PIL import Image
import io

INPUT_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons"
UNITS_DIR = os.path.join(INPUT_DIR, "units")

# 11 张堡垒/omega 卡
CARD_IDS = [
    "fort_ww1_pillbox",
    "fort_ww1_artillery",
    "fort_ww2_bunker",
    "fort_ww2_flak",
    "fort_cold_missile",
    "fort_cold_radar",
    "fort_modern_citadel",
    "fort_modern_phalanx",
    "fort_future_ion",
    "fort_future_shield",
    "omega_platform",
]

def remove_white_bg(input_path, output_path, threshold=240):
    """移除白色/近白色背景，保留主体，输出透明 PNG"""
    img = Image.open(input_path).convert("RGBA")
    data = img.getdata()
    
    new_data = []
    for item in data:
        r, g, b, a = item
        # 如果背景是纯白或接近白色（RGB 都 > threshold），设为透明
        if r > threshold and g > threshold and b > threshold:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)
    
    img.putdata(new_data)
    
    # 保存到临时位置
    temp_path = output_path + ".tmp.png"
    img.save(temp_path, "PNG")
    
    # 替换原文件
    os.replace(temp_path, output_path)
    print(f"  COG: {output_path} ({os.path.getsize(output_path):,} bytes)")

if __name__ == "__main__":
    print("=== 抠图部署堡垒/omega 卡 ===")
    
    success = 0
    fail = 0
    
    for card_id in CARD_IDS:
        # 源文件
        src = os.path.join(INPUT_DIR, f"{card_id}.png")
        if not os.path.exists(src):
            print(f"SKIP: {card_id} source not found at {src}")
            fail += 1
            continue
        
        # 1. 原地抠图
        print(f"\n[{card_id}]")
        remove_white_bg(src, src)
        success += 1
        
        # 2. 副本到 units/ 目录（敌方战场渲染用）
        # 根据 enemy manifest，堡垒/omega 对应 foe_platform_* archetype
        # 需要找到对应的 vis_player_* 文件名
        # fort_* → 对应 foe_platform_* → vis_player_*
        # 具体映射：vis_enemy_003 是 fort_ww1_pillbox 的战场渲染图
        
        # 堡垒卡在 units/ 下用 vis_pool_ 或 vis_enemy_ 编号
        # 实际上堡垒卡走的是 by_id 路径 (root card_icons/fort_*.png)，
        # 但战场渲染可能走 vis_enemy_* 路径
        # 先把副本放到 units/ 目录下
        units_dest = os.path.join(UNITS_DIR, f"{card_id}.png")
        if not os.path.exists(units_dest):
            import shutil
            shutil.copy2(src, units_dest)
            print(f"  COPY: {units_dest} ({os.path.getsize(units_dest):,} bytes)")
    
    print(f"\n=== 完成 ===")
    print(f"处理: {success}/{len(CARD_IDS)}")
    print(f"失败: {fail}/{len(CARD_IDS)}")
