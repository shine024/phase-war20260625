#!/usr/bin/env python
"""
批量生成相位仪型号图标（pi_aegis_02 ~ pi_umbra_03 + pi_r_free_deploy）
逐张生成，遇到上限自动等待重试
"""
import subprocess
import json
import time
import urllib.request
from PIL import Image
import io
import os

SKILL_SCRIPT = r"C:/Users/jianchang.tan/AppData/Local/Programs/WorkBuddy/resources/app.asar.unpacked/resources/builtin-skills/buddy-multimodal-generation/scripts/buddy-cloud.py"
TOKEN = "tk_taZgZ6o342xMQdbvSECT4UI2n5CZFuIl"
OUT_DIR = r"F:/godot fair duet/create/phase-war/assets/ui/instruments/"

IMAGES = [
    ("pi_aegis_02.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, square phalanx shield array framing dial, formation grid lines, defensive corporation emblem hint, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_aegis_03.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, domed shield canopy over dial, layered energy panels, fortress dome silhouette, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_aegis_04.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, massive citadel core shield with radiant barrier nodes, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_atlas_01.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, quantum logistics cargo drone silhouette, worker bee logistics glyph, teal supply lines, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_atlas_02.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, structural support beam frame, bridge pillar icons, logistics backbone dial, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_atlas_03.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, bridge core hub with radiating supply routes, heavy teal energy trunk lines, epic tier purple-blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_eon_01.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, frontier union gold clock hand second needle, minimal time dial ticks, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_eon_02.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, layered time-step rings, olive and gold chronometer stages, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_eon_03.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, ultimate chronology crown, multi-hand temporal dial, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_generic_01.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, compact entry phase instrument dial, bronze trim, one slow star point, rookie pilot starter kit aesthetic, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_generic_02.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, slightly larger dial with dual faint star orbits and soft cyan recovery glow ring, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_generic_03.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, dial with expanded outer deployment range tick marks and three star points, agile scout styling, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_generic_04.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, dial with forward-pointing phase blade motif on bezel, warm amber accent for attack tuning, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_generic_05.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, dual-layer dial rings, crossed phase strike glyphs, balanced assault module look, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_generic_06.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, heavy shield-shaped bezel around dial, reinforced rivet frame, defensive steel gray accents, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_generic_07.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, fortified dial with thick armored collar and steady gold stability glow, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_generic_08.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, dial surrounded by pulsing lightning arcs, high energy output capacitor nodes, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_generic_09.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, overcharged dial with red overload sector and crackling phase sparks at rim, epic tier purple-blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_generic_10.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, constellation-linked dial with six tiny node stars chained by light threads, resource focus, epic tier purple-blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_generic_11.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, seven-node star chain halo, balanced multi-stat enhancement look, silver-gold trim, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_generic_12.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, celestial crown bezel above dial, radiant sky-gold aura, ultimate generic flagship instrument, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_helix_01.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, helix recon green spiral spine across dial, hunter sight reticle, recon line motif, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_helix_02.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, interwoven helix mesh net around dial, data web nodes, scout network aesthetic, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_helix_03.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, dense neural helix bundle core, bright synapse flashes, advanced recon instrument, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_iron_01.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, iron wall corp anchor bolt frame, heavy steel chains, anchored tanker dial, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_iron_02.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, forged chain links encircling dial, molten steel seam highlights, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_iron_03.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, throne-backplate iron fortress mount, regal gunmetal and gold rivets, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_nova_01.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, nova arms orange circuit loop around dial, weapon circuit board traces, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_nova_02.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, flame-wreathed dial bezel, heat distortion waves, assault firepower styling, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_nova_03.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, hyperstring vibration lines and intense flame crown, legendary nova arms superweapon dial, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_nova_04.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, fission chamber ring with particle burst spokes, kill-energy feedback glow, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_r_free_deploy.png", "flat 2D stat ability icon, a combat unit materializing from thin air with phase energy particles converging into solid form, blueprints ghost pattern visible around the forming unit, a large zero symbol overlaid suggesting zero deployment cost, faint hyperspace void with floating island nodes in background, golden legendary glow aura, game UI attribute icon, centered on dark grey-blue background, 512x512"),
    ("pi_umbra_01.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, void research violet thin blade slash across dial, stealth edge highlight, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_umbra_02.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, refracted light prism shards, crit eye slit motif, shadow recon styling, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
    ("pi_umbra_03.png", "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, silent void dome suppressing light, dark purple haze, assassination field instrument, epic tier purple-blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi game UI, centered on dark grey-blue background, 512x512"),
]


def generate_image(prompt, out_path, max_retries=10):
    """生成图片，带自动等待重试"""
    for attempt in range(max_retries):
        try:
            result = subprocess.run(
                ["python", SKILL_SCRIPT, "image", prompt, "--resolution", "1024:1024", "--token-stdin"],
                input=TOKEN.encode(),
                capture_output=True,
                timeout=180
            )
            output = result.stdout.decode("utf-8", errors="replace")
            
            # 解析最后一段多行 JSON
            # 找到最后一个 { 开头的位置，读到末尾作为 JSON
            brace_start = output.rfind("\n{")
            if brace_start == -1:
                brace_start = output.find("{")
            else:
                brace_start += 1  # skip \n
            
            if brace_start == -1:
                print(f"  [警告] 无法找到 JSON，重试...")
                time.sleep(30)
                continue
            
            json_str = output[brace_start:].strip()
            
            try:
                data = json.loads(json_str)
            except Exception:
                print(f"  [警告] JSON 解析失败，重试... raw={json_str[:100]}")
                time.sleep(30)
                continue
            
            if "error" in data:
                err = data.get("message", "")
                if "上限" in err or "limit" in err.lower():
                    wait = 120 + attempt * 30
                    print(f"  [限制] 任务上限，等待 {wait}s 后重试...")
                    time.sleep(wait)
                    continue
                else:
                    print(f"  [错误] {err}，重试...")
                    time.sleep(30)
                    continue
            
            urls = data.get("result_url", [])
            if not urls or not urls[0]:
                print(f"  [警告] URL 为空（可能触发内容过滤），跳过此图")
                return False
            
            url = urls[0]
            img_data = urllib.request.urlopen(url).read()
            img = Image.open(io.BytesIO(img_data))
            img.save(out_path)
            return True
            
        except subprocess.TimeoutExpired:
            print(f"  [超时] 重试...")
            time.sleep(10)
        except Exception as e:
            print(f"  [异常] {e}，重试...")
            time.sleep(15)
    
    return False


def main():
    total = len(IMAGES)
    done = 0
    skipped = 0
    
    for i, (filename, prompt) in enumerate(IMAGES):
        out_path = os.path.join(OUT_DIR, filename)
        
        if os.path.exists(out_path):
            print(f"[{i+1}/{total}] {filename} 已存在，跳过")
            done += 1
            continue
        
        print(f"[{i+1}/{total}] 生成 {filename}...")
        
        success = generate_image(prompt, out_path)
        if success:
            print(f"  ✅ {filename} 保存成功")
            done += 1
        else:
            print(f"  ⚠️ {filename} 生成失败，跳过")
            skipped += 1
        
        # 每张之间稍微间隔，避免频率限制
        time.sleep(3)
    
    print(f"\n完成！成功: {done}/{total}，跳过/失败: {skipped}")


if __name__ == "__main__":
    main()
