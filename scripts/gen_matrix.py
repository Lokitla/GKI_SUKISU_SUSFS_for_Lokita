#!/usr/bin/env python3
"""从 .github/workflows/config/matrix.json 生成构建矩阵。

对齐 ShirkNeko/GKI_KernelSU_SUSFS 的裁剪策略：只保留仍在维护、
实际有人刷机的版本组合，剔掉过于早期已被弃用的子版本。
共 19 个组合：5.10(5) + 5.15(6) + 6.1(5) + 6.6(3)。

用法：
    python3 scripts/gen_matrix.py                     # 输出全部矩阵到 stdout（JSON）
    python3 scripts/gen_matrix.py --android android12 # 只看某个安卓版本
    python3 scripts/gen_matrix.py --github-output     # 写入 $GITHUB_OUTPUT
"""
import argparse
import json
import os
import sys
from pathlib import Path

MATRIX_PATH = Path(__file__).resolve().parent.parent / ".github" / "workflows" / "config" / "matrix.json"

# androidN -> (内核版本, 用于给 job 排序)
_SUB_ORDER = lambda s: (9999 if s == "X" else int(s), s)  # noqa: E731  X(LTS) 排最后


def load_matrix() -> dict:
    if not MATRIX_PATH.is_file():
        print(f"::error::矩阵文件不存在: {MATRIX_PATH}", file=sys.stderr)
        sys.exit(1)
    with MATRIX_PATH.open(encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict) or not data:
        print("::error::矩阵文件为空或格式错误", file=sys.stderr)
        sys.exit(1)
    return data


def build_entries(data: dict) -> list:
    """展开成扁平清单，每项含 android / kernel / sub_level / os_patch / revision。"""
    out = []
    for key, configs in data.items():
        try:
            android, kernel = key.split("-", 1)
        except ValueError:
            print(f"::error::矩阵键名不合法（应为 androidN-kernel）: {key}", file=sys.stderr)
            sys.exit(1)
        for cfg in configs:
            entry = {
                "android": android,
                "kernel": kernel,
                "sub_level": str(cfg["sub_level"]),
                "os_patch_level": str(cfg["os_patch_level"]),
            }
            if cfg.get("revision"):
                entry["revision"] = str(cfg["revision"])
            out.append(entry)

    out.sort(key=lambda e: (
        int(e["android"].replace("android", "")),
        float(e["kernel"]),
        _SUB_ORDER(e["sub_level"]),
    ))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--android", help="只输出指定安卓版本，如 android12")
    ap.add_argument("--github-output", action="store_true", help="写入 $GITHUB_OUTPUT")
    args = ap.parse_args()

    entries = build_entries(load_matrix())
    if args.android:
        entries = [e for e in entries if e["android"] == args.android]
        if not entries:
            print(f"::error::矩阵中没有安卓版本 {args.android}", file=sys.stderr)
            sys.exit(1)

    payload = json.dumps(entries, ensure_ascii=False, separators=(",", ":"))

    if args.github_output:
        out_file = os.environ.get("GITHUB_OUTPUT")
        if not out_file:
            print("::error::$GITHUB_OUTPUT 未设置", file=sys.stderr)
            sys.exit(1)
        with open(out_file, "a", encoding="utf-8") as f:
            f.write(f"matrix={payload}\n")
            f.write(f"count={len(entries)}\n")
        print(f"矩阵已写入: {len(entries)} 个组合")
    else:
        print(payload)

    # 汇总打印，便于 CI 日志核对
    per_android = {}
    for e in entries:
        per_android.setdefault(f"{e['android']}-{e['kernel']}", []).append(e["sub_level"])
    for k in sorted(per_android):
        print(f"  {k}: {', '.join(per_android[k])}", file=sys.stderr)


if __name__ == "__main__":
    main()
