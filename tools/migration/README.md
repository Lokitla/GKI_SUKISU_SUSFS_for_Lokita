# 迁移脚本（一次性，不参与构建）

这个目录里放的是**把 `build.yml` 里的内联 shell 抽取成 `scripts/build_kernel.sh`、
并同步各内核工作流选项**时用过的一次性脚本。它们已经完成使命，正常构建流程
不会调用任何一个，也不建议在新的改动里复用。

保留下来的唯一理由是**过程留档**：如果之后要核对"某个选项是怎么从旧工作流
推导到新脚本的"，这里有据可查。

| 脚本 | 当时做了什么 |
|---|---|
| `extract_build_script.py` | 从旧 `build.yml` 的 run 步骤里抽出 shell，切成 `stage_*` / `run_*` 函数 |
| `gen_workflow.py` | 按阶段清单重新生成工作流骨架 |
| `propagate_options.py` | 把新增/改名的输入批量同步到 6 个 `kernel-*.yml` 入口 |

`build.yml.orig`（抽取前的原始文件）不入库，已被 `.gitignore` 的 `*.orig` 规则排除。

要改构建逻辑，请直接改 `scripts/build_kernel.sh`，不要动这里。
