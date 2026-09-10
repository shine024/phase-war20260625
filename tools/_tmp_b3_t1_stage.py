# 批次③ Task 1 外科暂存：truck_base.gd / world_map.gd / main.gd 只收批次③自己的行，
# 用户 v27.13 / v26.30 / v26.33 在途行留在工作区（台账规矩：commit 只收自己行）。
import difflib
import subprocess
import sys

REPO = r"F:\godot fair duet\create\phase-war"

# (path, anchor_fn(lines)->insert_index, task1_lines)
JOBS = [
    (
        "scenes/bunker/truck_base.gd",
        lambda ls: _after(ls, "\tEngine.set_meta(\"launch_from_bunker\", true)"),
        [
            "\t# 批次③ Task 1：出征过场拍点——main 侧 run_start_battle_sequence 头部消费（一次性）",
            "\tEngine.set_meta(SortieInterstitial.META_PENDING, true)",
        ],
    ),
    (
        "scenes/world_map.gd",
        lambda ls: _after_pair(
            ls,
            "\t_close_popup_safe(popup)",
            "\tif has_meta(\"embedded_mode\") and bool(get_meta(\"embedded_mode\")):",
        ),
        [
            "\t# 批次③ Task 1：出击确认 → 出征过场拍点（main 侧 run_start_battle_sequence 消费，一次性）",
            "\tEngine.set_meta(SortieInterstitial.META_PENDING, true)",
        ],
    ),
    (
        "scenes/main.gd",
        lambda ls: _before(ls, "\t# v21 余烬要塞：从基地经兵棋室进入战场时，返回按钮回基地而非标题"),
        [
            "\t# 批次③ Task 1：作废未消费的出征过场拍点（防下次开局首战误触发一次过场）",
            "\tEngine.remove_meta(SortieInterstitial.META_PENDING)",
        ],
    ),
]


def _git(*args: str) -> str:
    return subprocess.run(
        ["git", "-C", REPO] + list(args), capture_output=True, text=True, encoding="utf-8"
    ).stdout


def _after(lines: list, anchor: str) -> int:
    idx = [i for i, l in enumerate(lines) if l.rstrip("\n") == anchor]
    assert len(idx) == 1, "anchor not unique: %r hits=%d" % (anchor, len(idx))
    return idx[0] + 1


def _before(lines: list, anchor: str) -> int:
    idx = [i for i, l in enumerate(lines) if l.rstrip("\n") == anchor]
    assert len(idx) == 1, "anchor not unique: %r hits=%d" % (anchor, len(idx))
    return idx[0]


def _after_pair(lines: list, first: str, second: str) -> int:
    idx = [
        i
        for i in range(len(lines) - 1)
        if lines[i].rstrip("\n") == first and lines[i + 1].rstrip("\n") == second
    ]
    assert len(idx) == 1, "pair anchor not unique: hits=%d" % len(idx)
    return idx[0] + 1


def main() -> int:
    for path, anchor_fn, task1_lines in JOBS:
        head_txt = _git("show", "HEAD:%s" % path)
        head_lines = head_txt.splitlines()
        pos = anchor_fn(head_lines)
        new_lines = head_lines[:pos] + task1_lines + head_lines[pos:]
        blob_txt = "\n".join(new_lines) + ("\n" if head_txt.endswith("\n") else "")
        # 写临时文件 → hash-object -w → update-index --cacheinfo（绕开 git apply 的
        # 换行/补丁解析敏感；git show 经 text=True 已把 \r\n 归一为 \n，与 index 口径一致）
        tmp = REPO + r"\.git\tmp_stage_blob"
        with open(tmp, "w", encoding="utf-8", newline="\n") as f:
            f.write(blob_txt)
        sha = _git("hash-object", "-w", ".git/tmp_stage_blob").strip()
        r = subprocess.run(
            ["git", "-C", REPO, "update-index", "--cacheinfo", "100644,%s,%s" % (sha, path)],
            capture_output=True, text=True, encoding="utf-8",
        )
        if r.returncode != 0:
            print("[stage] UPDATE-INDEX FAILED %s:\n%s%s" % (path, r.stdout, r.stderr))
            return 1
        print("[stage] %s: +%d 行 @HEAD:%d（blob %s）" % (path, len(task1_lines), pos, sha[:12]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
