#!/usr/bin/env python3
"""GitHub Actions workflow 静态校验。

用法：
    python3 scripts/tools/check_workflows.py            # 校验全部 workflow
    python3 scripts/tools/check_workflows.py --strict   # 警告也视为失败

检查项：
  1. YAML 语法与**重复键**（safe_load 默认静默取最后一个值，重复键极难肉眼发现。
     真实案例：插入输入时把 ksu_branch_mode 的 default: "auto" 挤进了
     kpm_patch_sha256 块，使其默认值变成 "auto"，导致 KPM 构建全量失败）
  2. 跨工作流调用（uses: ./xxx.yml）的 with: 键必须被调用方 workflow_call 声明
  3. run: 块内直接内插 ${{ inputs.* }} / ${{ secrets.* }} 的注入面
     （type: string 的自由文本可被 $(...) 命令替换，choice/boolean 不可）
  4. workflow_call 声明的输入若在调用方全部未透传，提示可能漏传

依赖：PyYAML
"""
from __future__ import annotations

import glob
import os
import re
import sys

try:
    import yaml
except ImportError:
    sys.exit("需要 PyYAML：pip3 install pyyaml")

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


class DupKeyLoader(yaml.SafeLoader):
    pass


def _no_dups(loader, node, deep=False):
    seen = set()
    for k, _ in node.value:
        key = loader.construct_object(k, deep=deep)
        if key in seen:
            raise yaml.constructor.ConstructorError(
                "重复键 %r（行 %d）" % (key, node.start_mark.line + 1)
            )
        seen.add(key)
    return yaml.constructor.SafeConstructor.construct_mapping(loader, node, deep)


DupKeyLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _no_dups
)


def _on(doc):
    return doc.get(True) if True in doc else doc.get("on")


def _call_inputs(doc):
    on = _on(doc)
    if not isinstance(on, dict):
        return {}
    return (on.get("workflow_call") or {}).get("inputs", {}) or {}


def _dispatch_inputs(doc):
    on = _on(doc)
    if not isinstance(on, dict):
        return {}
    return (on.get("workflow_dispatch") or {}).get("inputs", {}) or {}


def main() -> int:
    strict = "--strict" in sys.argv
    files = sorted(glob.glob(os.path.join(ROOT, ".github/workflows/*.yml")))
    errors: list[str] = []
    warnings: list[str] = []

    docs: dict[str, dict] = {}

    # 1) 语法 + 重复键
    for f in files:
        name = os.path.basename(f)
        try:
            with open(f, encoding="utf-8") as fh:
                docs[f] = yaml.load(fh, Loader=DupKeyLoader) or {}
        except yaml.YAMLError as e:
            errors.append(f"{name}: YAML 解析失败 -> {str(e).splitlines()[0]}")

    # 2) + 4) 跨工作流传参
    for f, doc in docs.items():
        name = os.path.basename(f)
        for jn, job in (doc.get("jobs") or {}).items():
            uses = job.get("uses", "") or ""
            if not uses.startswith("./"):
                continue
            # uses: 路径以仓库根为基准（./.github/workflows/x.yml），不是相对当前文件
            tgt = os.path.normpath(
                os.path.join(ROOT, uses[2:].split("@")[0])
            )
            if tgt not in docs:
                continue
            declared = _call_inputs(docs[tgt])
            passed = job.get("with") or {}
            for k in passed:
                if k == "secrets":
                    continue
                if k not in declared:
                    errors.append(
                        f"{name} [{jn}]: 传入 {k}，但 {os.path.basename(tgt)} 未声明该 workflow_call 输入"
                    )

    # 3) run: 块注入面
    interp = re.compile(r"\$\{\{\s*(inputs|secrets|github)\.[\w.\-]+\s*\}\}")
    for f, doc in docs.items():
        name = os.path.basename(f)
        free_text = {
            k
            for k, v in {**_dispatch_inputs(doc), **_call_inputs(doc)}.items()
            if (v or {}).get("type") == "string"
        }
        for jn, job in (doc.get("jobs") or {}).items():
            for step in job.get("steps") or []:
                run = step.get("run")
                if not run:
                    continue
                for m in interp.finditer(run):
                    kind, path = m.group(1), m.group(0)
                    var = path.split(".")[1] if "." in path else ""
                    if kind == "secrets":
                        warnings.append(
                            f"{name} [{jn}]: run 块内插 secret（{path}）会进入进程环境与 PS 输出，改用 job 级 env"
                        )
                    elif kind == "inputs" and var in free_text:
                        warnings.append(
                            f"{name} [{jn}]: run 块内插 string 型输入 {path}，自由文本可被命令替换，改用 job 级 env"
                        )

    print("=" * 72)
    print("工作流校验：%d 个文件" % len(files))
    print("=" * 72)
    for e in errors:
        print("  ❌ " + e)
    for w in warnings:
        print("  ⚠️  " + w)
    if not errors and not warnings:
        print("  ✅ 无问题")
    print()
    print("错误 %d / 警告 %d" % (len(errors), len(warnings)))

    if errors:
        return 1
    if strict and warnings:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
