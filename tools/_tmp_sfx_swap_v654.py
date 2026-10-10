#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v6.54 记录6三轮：SFX 六项换血——Kenney CC0 真实录音替换自合成音。

实机主诉（2026-10-09 记录6 三轮）：胜利音不好(#4)/攻击音效不好按武器类型区分(#5)/
按钮音不好(#6)/技能树解锁音不好(#8)/剧情按钮提示音不匹配(#2)。
背景：v6.42 已用 numpy 合成重制过 button/win——用户仍不满意；本轮改用
Kenney 真实录音乐包（CC0，无署名义务）打破"合成感"瓶颈：
  - Interface Sounds 1.0   → button / button_hover / blueprint_unlock / story_page(新)
  - Impact Sounds 1.0      → hit / impact_light / impact_heavy
  - Music Jingles 1.0      → win（Hit 系管乐重击 stinger）
  - Sci-Fi Sounds 1.0      → laser_fire / rail_cannon / omega_cannon / rocket_launch /
                             explosion / explosion_big
响度策略：RMS 匹配被替换旧文件（实测旧文件 astats RMS_level），混合配比不变；
rocket_launch 源 5s 循环剪 0.95s + 尾部 0.25s 渐隐。
统一转码 OGG Vorbis q6 / 44.1kHz。

证据链：zip 原包 + License.txt 存档 _steam_assets/licenses/kenney_20261010/（SHA256 见
CREDITS.md 增补表）。旧素材已备份 D:/godotplay/_art_backup/sfx_pre_v654_20261010/。
铁律：*.ogg 不入 git。

用法：python tools/_tmp_sfx_swap_v654.py [--extract-dir <解包目录>] [--dry-run]
"""
import argparse
import os
import subprocess
import sys

FFMPEG_CANDIDATES = [
    r"D:/360安全浏览器下载/铁血联盟3/Godot/ffmpeg-8.0-essentials_build/ffmpeg-8.0-essentials_build/bin/ffmpeg.exe",
    "ffmpeg",
]
FFPROBE_CANDIDATES = [
    r"D:/360安全浏览器下载/铁血联盟3/Godot/ffmpeg-8.0-essentials_build/ffmpeg-8.0-essentials_build/bin/ffprobe.exe",
    "ffprobe",
]

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SFX_DIR = os.path.join(REPO, "assets", "sfx")

## slot → (新源文件名, 处理尾巴)。尾巴: None=原样; ("trim", dur, fade)=剪 dur 秒+尾部 fade 秒渐隐
MAPPING = {
    "button":           ("interface__click_001.ogg", None),
    "button_hover":     ("interface__tick_001.ogg", None),
    "blueprint_unlock": ("interface__confirmation_002.ogg", None),
    "story_page":       ("interface__scratch_002.ogg", None),
    "hit":              ("impact-sounds__impactMetal_medium_000.ogg", None),
    "impact_light":     ("impact-sounds__impactMetal_light_000.ogg", None),
    "impact_heavy":     ("impact-sounds__impactMetal_heavy_001.ogg", None),
    "win":              ("music-jingles__jingles_HIT01.ogg", None),
    "laser_fire":       ("sci-fi-sounds__laserSmall_000.ogg", None),
    "rail_cannon":      ("sci-fi-sounds__laserLarge_002.ogg", None),
    "omega_cannon":     ("sci-fi-sounds__laserLarge_000.ogg", None),
    "rocket_launch":    ("sci-fi-sounds__thrusterFire_001.ogg", ("trim", 0.95, 0.25)),
    "explosion":        ("sci-fi-sounds__explosionCrunch_003.ogg", None),
    "explosion_big":    ("sci-fi-sounds__lowFrequency_explosion_000.ogg", None),
}


def ffmpeg_bin():
    for c in FFMPEG_CANDIDATES:
        try:
            subprocess.run([c, "-version"], capture_output=True, timeout=10)
            return c
        except Exception:
            continue
    raise SystemExit("ffmpeg not found")


def ffprobe_bin():
    for c in FFPROBE_CANDIDATES:
        try:
            subprocess.run([c, "-version"], capture_output=True, timeout=10)
            return c
        except Exception:
            continue
    raise SystemExit("ffprobe not found")


def run(args):
    return subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")


def rms_level(ffmpeg, path):
    """astats 末尾 Overall 的 RMS level dB。文件名走 -i 普通参数（无 filtergraph 转义坑）。"""
    r = run([ffmpeg, "-hide_banner", "-nostats", "-i", path, "-af", "astats", "-f", "null", "-"])
    hits = [ln for ln in r.stderr.splitlines() if "RMS level dB" in ln]
    if not hits:
        return None
    try:
        return float(hits[-1].split(":")[-1].strip())
    except ValueError:
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--extract-dir", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "sfxdl", "extract"))
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    extract = os.path.abspath(args.extract_dir)

    ff = ffmpeg_bin()
    plan = []
    for slot, (src_name, tail) in MAPPING.items():
        src = os.path.join(extract, src_name)
        dst = os.path.join(SFX_DIR, slot + ".ogg")
        if not os.path.isfile(src):
            print("[MISS] 源不存在: %s" % src)
            continue
        if not os.path.isfile(dst) and slot != "story_page":
            print("[MISS] 目标不在现役库（跳过，避免新增名未接线）: %s" % dst)
            continue
        old_rms = rms_level(ff, dst) if os.path.isfile(dst) else None
        new_rms = rms_level(ff, src)
        if new_rms is None:
            print("[WARN] 新源 RMS 量测失败 %s — 用 -12dB 基准" % slot)
            new_rms = -12.0
        # 新文件无旧文件可比（story_page）：以 -12dB 为基准，接近池内平均响度
        gain = ((old_rms if old_rms is not None else -12.0) - new_rms)
        plan.append((slot, src, dst, gain, tail))

    print("=== 换血计划 %d 项 ===" % len(plan))
    for slot, src, dst, gain, tail in plan:
        print("  %-15s gain=%+.1f dB  tail=%s" % (slot, gain, tail or "-"))
    if args.dry_run:
        return 0

    for slot, src, dst, gain, tail in plan:
        af = ["volume=%.1fdB" % gain]
        trim_t = None
        if tail is not None and tail[0] == "trim":
            _, dur, fade = tail
            trim_t = dur
            af.append("afade=t=out:st=%.2f:d=%.2f" % (dur - fade, fade))
        tmp = dst + ".tmp.ogg"
        cmd = [ff, "-y", "-i", src]
        if trim_t is not None:
            cmd += ["-t", "%.2f" % trim_t]
        cmd += ["-af", ",".join(af), "-ar", "44100", "-c:a", "libvorbis", "-q:a", "6", tmp]
        r = run(cmd)
        if r.returncode != 0 or not os.path.isfile(tmp):
            print("[FAIL] %s: %s" % (slot, (r.stderr or "")[-300:]))
            continue
        os.replace(tmp, dst)
        print("[OK] %s ← %s" % (slot, os.path.basename(src)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
