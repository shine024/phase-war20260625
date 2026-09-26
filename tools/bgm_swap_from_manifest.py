#!/usr/bin/env python3
"""BGM 换曲流水线：校验外部源 MP3 → 响度归一 → OGG 转码 → 落位 assets/sfx/。

用法：
    python tools/bgm_swap_from_manifest.py <manifest.json> [--dry-run]

manifest 条目（见 _steam_assets/licenses/incompetech_20260926/swap_manifest_20260926.json）：
    slot       目标文件名主干（=assets/sfx/<slot>.ogg，AudioManager BGM_MAP 键）
    mp3        源 MP3 绝对路径（incompetech 原始下载，项目外归档）
    want_sec   目录声明时长（秒），与实际差 >2s 即拒换（防截断文件入库）
    title/artist/isrc/src_url/license  写进输出 OGG 的元数据（发行包内文件自证来源）

响度策略：统一归一到 TARGET_LUFS（-14），采用静态增益（无动态处理，防抽吸）；
若增益后真峰值超 -1.5 dBTP 则按峰值回退增益。BGM 逐曲响度一致，切歌不跳音量。
"""
import json
import subprocess
import sys
import os

TARGET_LUFS = -14.0
PEAK_CEIL = -1.5
DURATION_TOL = 2.0
ASSETS = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")


def run(args):
    return subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")


def probe_duration(path):
    r = run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path])
    return float(r.stdout.strip())


def measure(path):
    """返回 (integrated_lufs, true_peak_dbtp)。"""
    r = run(["ffmpeg", "-nostats", "-i", path, "-af",
             "ebur128=peak=true:framelog=quiet", "-f", "null", "-"])
    lufs = tpeak = None
    for line in r.stderr.splitlines():
        line = line.strip()
        if line.startswith("I:") and "LUFS" in line:
            lufs = float(line.split()[1])
        if line.startswith("Peak:") and "dBFS" in line:
            tpeak = float(line.split()[1])
    return lufs, tpeak


def main():
    argv = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry-run" in sys.argv
    manifest = json.load(open(argv[0], encoding="utf-8"))
    if isinstance(manifest, dict):
        manifest = manifest["manifest"]
    failed = []
    for m in manifest:
        slot, mp3 = m["slot"], m["mp3"]
        dur = probe_duration(mp3)
        if dur < m["want_sec"] - DURATION_TOL:
            # 只拒「显著短于目录」= 截断；偏长合法（目录时长是取整值，MP3 有编码 padding）
            failed.append(f"{slot}: duration {dur:.1f}s < {m['want_sec']}s (source truncated?)")
            continue
        lufs, tpeak = measure(mp3)
        gain = TARGET_LUFS - lufs
        if tpeak + gain > PEAK_CEIL:
            gain = PEAK_CEIL - tpeak
        out = os.path.join(ASSETS, slot + ".ogg")
        print(f"{slot}: {dur:.1f}s  {lufs:.1f} LUFS / peak {tpeak:.1f} dBTP -> gain {gain:+.1f} dB")
        if dry:
            continue
        meta = ["-map_metadata", "-1",
                "-metadata", f"title={m['title']}",
                "-metadata", f"artist={m['artist']}",
                "-metadata", "album=Phase War Original Soundtrack",
                "-metadata", f"ISRC={m['isrc']}",
                "-metadata", f"comment={m['src_url']} | {m['license']}"]
        enc = run(["ffmpeg", "-y", "-i", mp3, "-af", f"volume={gain:.2f}dB",
                   "-ar", "44100", "-ac", "2", "-c:a", "libvorbis", "-q:a", "6",
                   *meta, out])
        if enc.returncode != 0:
            failed.append(f"{slot}: encode failed\n{enc.stderr[-800:]}")
            continue
        # 复核产物
        odur, (olufs, opeak) = probe_duration(out), measure(out)
        print(f"  -> {out}  {odur:.1f}s  {olufs:.1f} LUFS / peak {opeak:.1f} dBTP")
        if odur < m["want_sec"] - DURATION_TOL:
            failed.append(f"{slot}: output duration {odur:.1f}s off")
    if failed:
        print("\nFAILED:")
        print("\n".join(failed))
        sys.exit(1)
    print("\nALL_OK")


if __name__ == "__main__":
    main()
