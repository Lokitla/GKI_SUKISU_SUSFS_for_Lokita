# 第三方许可合规锚点（许可未明 / 非标准许可组件）

本文件是 [NOTICE](./NOTICE) 的补充，专门记录**构建关键但许可状态不清晰**的依赖。

`NOTICE` 负责「全量归属声明」，本文件负责「风险可追溯 + 风险可退出」：
每个条目都给出三样东西 ——

1. **锚点**：该依赖在本仓库中被引入的**确切位置**（文件:行）与引入方式；
2. **可核实性**：你如何自己复核其许可状态（给出命令，不依赖本仓库的一面之词）；
3. **可退出性**：如何在构建中彻底剔除它（统一开关 `STRICT_LICENSE_MODE=true`）。

---

## 一、总览

| 组件 | 上游 | 用途 | 许可状态 | 是否进产物 | 严格模式下 |
|---|---|---|---|---|---|
| `min_kdp.c` + 三星符号 | `WildKernels/kernel_patches` | 6.6 WiFi/蓝牙兼容性（三星） | **未声明** | ✅ 编进内核（`drivers/min_kdp.c`） | ⛔ 跳过 |
| Unicode 绕过修复补丁 | `Numbersf/Action-Build` | SUSFS 的 Unicode 绕过修复 | **自定义许可（非 GPL）** | ✅ 打进内核源码 | ⛔ 跳过 |
| `patch_linux` | `SukiSU-Ultra/SukiSU_patch` | KPM 镜像修补工具 | **未声明** | ⚠ 构建工具，不进源码，但会改写产物 `Image` | ⛔ 跳过（保留原始 Image） |
| NoMount 子系统 | `maxsteeel/nomount` | 无需挂载点的模块挂载方案 | **GPL-3.0（与内核 GPL-2.0 冲突）** | ✅ 编进内核（`fs/nomount/`） | ⛔ 跳过（⚠ 开关待实现） |

四者都不是「不用就编不出来」的必需项，而是**功能增强项**：剔除后内核仍可正常构建与启动，
代价分别是三星兼容性修复失效、SUSFS Unicode 隐藏能力减弱、KPM 模块加载能力失效、
NoMount 模块挂载能力失效。

> ⚠ **NoMount 的退出开关尚未实现**：`STRICT_LICENSE_MODE=true` 目前只覆盖前三项，
> NoMount 仍会照常编入内核。这是当前已知的唯一「已识别风险但无法用开关剔除」的组件，
> 在开关实现前，如需产出不含该组件的内核，请保持 `use_nomount=false`（默认即为关闭）。

---

## 二、逐项锚点

### 2.1 `WildKernels/kernel_patches` — 三星 min_kdp

**引入位置**

| 环节 | 位置 |
|---|---|
| 拉取 | `scripts/build_kernel.sh:443` `git clone --depth 1 https://github.com/WildKernels/kernel_patches.git` |
| 源文件 | `scripts/build_kernel.sh:1655` `KERNEL_PATCHES/samsung/min_kdp/min_kdp.c` |
| 补丁 | `scripts/build_kernel.sh:1656` `KERNEL_PATCHES/samsung/min_kdp/add-min_kdp-symbols.patch` |
| 落地 | `scripts/build_kernel.sh:1684` 复制为内核源码 `drivers/min_kdp.c` 并加入 `drivers/Makefile` |
| 符号白名单 | `scripts/build_kernel.sh:1666-1668` 向 `android/abi_gki_aarch64_galaxy` 追加 3 个 `kdp_*` 符号 |

**许可状态**：上游仓库未附带许可证文件，GitHub 识别为「无许可」。

**自行核实**

```bash
git clone --depth 1 https://github.com/WildKernels/kernel_patches.git /tmp/kp
ls -la /tmp/kp | grep -iE 'license|copying|notice|readme'
# 也可查 GitHub API 的 license 字段（null 即未声明）
curl -s https://api.github.com/repos/WildKernels/kernel_patches | jq '.license'
```

**风险**：`min_kdp.c` 会被**编译进内核镜像**，是唯一「未声明许可代码直接进入分发产物」的组件。
内核镜像受 Linux 内核 GPL-2.0 约束，混入未声明许可代码时，严格来说无法对外宣称整体为纯 GPL 分发。

**缓解**：本仓库不使用默认分支快照以外的方式引入，也未对其做二次修改（原样复制）。
如上游后续补上许可证，请在本仓库提 Issue，本文件会同步更新。

**退出**：`STRICT_LICENSE_MODE=true` → 跳过三星符号白名单、`min_kdp` 补丁与源码复制；
小米侧 `device_find_any_child` 符号（不涉及未声明许可代码）保留。

---

### 2.2 `Numbersf/Action-Build` — Unicode 绕过修复

**引入位置**

| 环节 | 位置 |
|---|---|
| 拉取 | `scripts/build_kernel.sh:446` `git clone https://github.com/Numbersf/Action-Build.git --depth=1` |
| 应用 | `scripts/build_kernel.sh:1570`（≤6.1）`/ :1572`（>6.1）`patch -p1 --forward < "…/patches/unicode_bypass_fix_6.1±.patch"` |
| 触发条件 | 仅 `ENABLE_SUSFS=true` 时执行（`run_apply_unicode_fix`） |

**许可状态**：自定义许可，**非 GPL 体系**。要点（非原文）见 `NOTICE` 第 86-99 行。

**自行核实**

```bash
git clone --depth 1 https://github.com/Numbersf/Action-Build.git /tmp/ab
ls -la /tmp/ab | grep -iE 'license|copying|notice|readme'
```

**风险**：自定义许可含「禁止原样 fork 再分发或公开宣传」的限制，与 GPL 的再分发自由**存在冲突**。
同时该补丁**打进内核源码**，会进入产物。

**缓解**：本仓库仅以补丁形式引用其修复，不原样再分发该上游仓库本身；上游许可亦明确允许
分发由本软件生成的编译产物（二进制 / 内核镜像 / ZIP 包）。本仓库与原仓库存在明显区别（非镜像）。

**退出**：`STRICT_LICENSE_MODE=true` → 整个阶段跳过，产物中不含该来源代码。

---

### 2.3 `SukiSU-Ultra/SukiSU_patch` — `patch_linux`（KPM 镜像修补）

**引入位置**

| 环节 | 位置 |
|---|---|
| 仓库拉取 | `scripts/build_kernel.sh:444`（提供 ZRAM / LZ4KD 补丁） |
| 工具下载 | `scripts/build_kernel.sh:76` `KPM_PATCH_URL` 默认指向 `…/SukiSU_patch/refs/heads/main/kpm/patch_linux` |
| 使用 | `scripts/build_kernel.sh` 的 `stage_patch_kpm_image`，对 `Image` 执行修补 |

**许可状态**：上游仓库未附带许可证文件（与 2.1 同类问题）。

**自行核实**

```bash
curl -s https://api.github.com/repos/SukiSU-Ultra/SukiSU_patch | jq '.license'
```

**风险**：`patch_linux` 是**预编译二进制**，来源未声明许可，且被 `chmod 755` 后**直接执行**。
它不进源码，但会改写最终产物 `Image`。由于是二进制且仓库无许可声明，其可再分发性存在不确定性。

**缓解（本轮新增）**：

- 版本号锚点：可用 `scripts/tools/pin_kpm_patch.sh` 生成 `config/kpm_patch_sha256`，
  构建时做 **fail-closed** sha256 比对，上游一旦变更即中止构建（原为「跟随 main、零锚点」）。
- 产物完整性：修补后 `oImage` 体积若低于原始 `Image` 的 80%，判定为修补失败并保留原始 `Image`，
  避免打包出残缺的假内核。

**退出**：`STRICT_LICENSE_MODE=true` → 不下载、不执行该工具，保留未修补的原始 `Image`。

---

### 2.4 `maxsteeel/nomount` — NoMount 挂载元模块（**GPL-3.0，与内核许可冲突**）

**引入位置**

| 环节 | 位置 |
|---|---|
| 拉取 | `stage_integrate_nomount`：`curl` 下载 `…/maxsteeel/nomount/refs/heads/dev/kernel/setup.sh` 后 `bash` 执行 |
| 落地 | 该 setup.sh 克隆仓库并在内核源码树建立 `fs/nomount` 软链接，随内核一起编译 |
| defconfig | 追加 `CONFIG_NOMOUNT=y` |
| 触发条件 | 仅 `USE_NOMOUNT=true` 时执行（默认关闭） |

**许可状态**：**GPL-3.0**（仓库根 LICENSE）。已逐层核实：

- `kernel/` 目录下**没有** LICENSE 做分层（只有 `README.md` / `setup.sh` / `src/`）；
- `kernel/src/nomount.c`（61 KB）文件头**没有** SPDX-License-Identifier、
  没有版权声明、没有 `MODULE_LICENSE`。

即：其内核部分的实际授权就是仓库根的 **GPL-3.0**。

**自行核实**

```bash
curl -s https://api.github.com/repos/maxsteeel/nomount | jq '.license.spdx_id'
curl -s https://api.github.com/repos/maxsteeel/nomount/contents/kernel | jq '.[].name'
curl -sL https://raw.githubusercontent.com/maxsteeel/nomount/master/kernel/src/nomount.c | head -20
```

**风险**：GPL-3.0 代码被编入 GPL-2.0（含 syscall 例外）的内核镜像。
GPL-2.0-only 与 GPL-3.0 不能合并，且内核无法升级到 v3，
因此该组合的对外再分发存在许可瑕疵。

这是本仓库当前**唯一**「已识别为许可冲突、且代码进入产物」的组件——
前三项属于「许可未明」，性质不同，严重程度也低于本项。

**缓解**：

- 默认关闭（`use_nomount` 默认 `false`），用户不主动开启则完全不涉及；
- setup.sh 支持可选的 sha256 锚点（`NOMOUNT_SETUP_SHA256`），留空则不校验；
- 已如实披露于 `NOTICE` 与本节。

**退出**：⚠ **尚未纳入 `STRICT_LICENSE_MODE`**（待实现）。在开关落地前，
保持 `use_nomount=false` 即可完全不涉及该组件。

**建议**：向上游询问能否为 `kernel/` 单独提供 GPL-2.0 授权 ——
SukiSU-Ultra 与 ReSukiSU 均采用「根 GPL-3.0 / `kernel/` GPL-2.0」的分层做法。
若上游补上分层，本节风险即可解除。

---

## 三、严格许可模式（统一退出开关）

```bash
# 本地
STRICT_LICENSE_MODE=true ./scripts/build_kernel.sh …

# CI：在 build.yml 的环境变量中加一行
#   STRICT_LICENSE_MODE: true
```

开启后第 2.1–2.3 节的三个组件**全部不参与构建**。

⚠ 第 2.4 节的 NoMount **暂不受本开关控制**，需另行保持 `use_nomount=false`。

构建日志会为每个被跳过的组件打印 `::warning::`，说明功能代价，不会静默降级。

默认 `false`，即保持既有构建行为 —— 这是**可用性优先**的选择，风险已在上面逐项披露。

---

## 四、维护约定

1. 上游补上许可证或提出异议 → 更新本文件与 `NOTICE`，并在 commit message 中注明。
2. 新增「许可未明」依赖 → 必须先在此登记，并在 `STRICT_LICENSE_MODE` 下可退出，否则不予合入。
3. `patch_linux` 的 sha256 锚点随上游更新需重新生成：
   `./scripts/tools/pin_kpm_patch.sh`（CI 巡检漂移：`--check`）。