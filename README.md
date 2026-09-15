<div align="center">

# GKI KernelSU SUSFS

---

> [!WARNING]
> **⚠️ 自用仓库 · 非官方发布 · 由 AI 辅助修改**
>
> - 本仓库是 [zzh20188/GKI_KernelSU_SUSFS](https://github.com/zzh20188/GKI_KernelSU_SUSFS) 的**个人自用分支**，产物仅供本人测试，**不是官方发布渠道**。
> - 仓库内的工作流、构建脚本与文档经过 **AI 辅助修改与二次开发**，未经上游作者审阅，行为可能与上游不一致。
> - 刷入第三方内核存在变砖、丢失数据、触发应用风控等风险；请自行备份原厂 Boot 镜像，风险自负。
> - 遇到问题请在本仓库反馈，不要去打扰上游作者。

---

### 🏮 2026 🐎 Happy New Year! 🏮

**自动化构建 GKI 内核 | 集成 KernelSU + SUSFS**

[![Release](https://img.shields.io/github/v/release/Lokitla/GKI_SUKISU_SUSFS_for_Lokita?label=Release&style=flat-square&logo=github&logoColor=white&color=2ea44f)](https://github.com/Lokitla/GKI_SUKISU_SUSFS_for_Lokita/releases)
[![Coolapk](https://img.shields.io/badge/Follow-Coolapk-3DDC84?style=flat-square&logo=android&logoColor=white)](http://www.coolapk.com/u/11253396)
[![KernelSU](https://img.shields.io/badge/KernelSU-Supported-5AA300?style=flat-square)](https://kernelsu.org/)
[![SUSFS](https://img.shields.io/badge/SUSFS-Integrated-E67E22?style=flat-square)](https://gitlab.com/simonpunk/susfs4ksu)

[**English**](README-EN.md) | 简体中文

---

</div>

## 🚀 快速导航

- 📖 [文档](https://github.com/zzh20188/GKI_KernelSU_SUSFS/wiki)
- 📥 [下载](https://github.com/Lokitla/GKI_SUKISU_SUSFS_for_Lokita/releases)
- 🔰 [教程](https://zzh20188.github.io/GKI_KernelSU_SUSFS/guide.html)

---

## 🔰 两种构建入口的区别

| 入口 | 一次会构建多少 |
|---|---|
| **内核构建 - Android 12 / 13 / 14 / 15 / 16** | 该内核版本的**全部**子版本（矩阵写死，5.10 共 22 个） |
| **Android 内核构建-自定义** | 只构建你在「安全补丁级别」里指定的版本，**默认只出 1 个** |

自定义入口的「构建目标」同时认**子版本代号**和**补丁级别日期**，两种可以混着填：

| 填法 | 效果 |
|---|---|
| `66` | 子版本代号 → 5.10.66 |
| `236` | 子版本代号 → 5.10.236 |
| `2022-01` | 补丁级别日期 → 5.10.66 |
| `lts` | LTS 版本 → 5.10.269 |
| `all` | 该内核全部版本（5.10 → 23 个，含 LTS；**耗时很长**） |
| `66,236` | 逗号分隔，一次构建多个 |
| `66,2022-01,236` | 代号与日期可混填（重复目标会自动去重） |

> 想让自定义入口也出全量，填 `all` 即可。填错时会把该内核所有可用子版本代号列出来。

---

## ⚠️ 兼容性提醒

> **注意：** 目前不支持一加 ColorOS 14、15，刷入后可能需要清除数据开机。
>
> **SUKISU最新版:** 已经恢复构建，但不兼容6.12
>
> 增加了了老版本SukiSU的构建，若使用老版本内核最好搭配同样版本的管理器，老版本完全使用以前的SUKISU和SUSFS代码，因此不包含最近的特性或bug
> 
> <img width="296" height="152" alt="image" src="https://github.com/user-attachments/assets/e60316c3-c760-4178-a4c8-b94d0ef0b5b2" />



---

## 📚 文档与指南

详细说明请查阅 [**GitHub Wiki（中英双语）**](https://github.com/zzh20188/GKI_KernelSU_SUSFS/wiki)

Wiki 涵盖内容：
- [**🔰 教程**](https://zzh20188.github.io/GKI_KernelSU_SUSFS/guide.html)
- 📥 下载/刷入内核
- 💡 使用技巧 Tips
- 🆘 救砖指南
- 📊 内核版本兼容性说明

---

## 🆕 融合新增能力

本仓库在原有基础上，合并了 [ShirkNeko/GKI_KernelSU_SUSFS](https://github.com/ShirkNeko/GKI_KernelSU_SUSFS) 的以下能力：

| 能力 | 说明 | 开启方式 |
|---|---|---|
| **本地 CLI 构建** | 不依赖 Actions 即可构建，与云端共用同一脚本 | `python3 build.py ...` |
| **BBR 拥塞控制** | 将 BBR 设为默认 TCP 拥塞算法 | Actions: `use_bbr`；CLI: `--bbr` |
| **Telegram 通知** | 构建完成后推送消息与产物校验值到 TG | Actions: `send_telegram` |
| **Release 缓存** | 用 GitHub Release 存 ccache，突破 `actions/cache` 的容量与过期限制 | Actions: `use_release_cache` |
| **Spoofed 管理器开关** | 可单独控制是否一并拉取伪装官方包名的 SukiSU 管理器 APK | Actions: `manager_spoofed` |

> **关于 Release：** 原上游把「创建 Release」这一步硬编码成只在 `zzh20188/GKI_KernelSU_SUSFS` 仓库执行，
> fork 后永远发不出来。本分支已去掉该限制，在 **构建内核** 里把 `发布类型` 选成 `Release` / `Pre-Release` 即可发布。

### 配置 Telegram 通知

在仓库 **Settings → Secrets and variables → Actions** 中添加：

| Secret | 说明 |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Bot 令牌（向 [@BotFather](https://t.me/BotFather) 申请） |
| `TELEGRAM_CHAT_ID` | 目标会话 ID |
| `TELEGRAM_MESSAGE_THREAD_ID` | 话题 ID（可选，仅论坛群组需要） |

未配置时通知会自动跳过，不会影响构建。

---

## 🛡️ GhostLock 安全修复

GhostLock 是影响 Linux 内核的一组高风险漏洞，包括 `CVE-2026-43499` 和 `CVE-2026-53163`。攻击者不需要 Root 权限，也不需要额外的内核模块，只要能够在设备上运行普通应用或本地代码，就可能利用该漏洞。

### 可能造成的危害

- **系统崩溃或强制重启：** 普通应用即可触发内核崩溃，导致设备无法正常使用，未保存的数据也可能丢失。
- **本地权限提升：** 更复杂的利用可以绕过 Android 权限边界，让普通应用获得内核级权限，进而控制整个设备。
- **现成利用已经公开：** 目前已有拒绝服务 PoC，以及针对 Android ARM64 平台的完整提权利用链，风险不再停留在理论阶段。
- **没有可靠的临时规避方法：** 常见的权限限制、应用隔离或系统加固只能增加利用难度，无法彻底阻止系统崩溃或其他利用方式。

该漏洞不能直接从网络远程触发，但恶意应用、共享运行环境中的不可信程序，或者已经通过其他漏洞取得代码执行能力的攻击者，都可以进一步利用它。因此，安装来源不明的应用、模块或脚本时尤其需要注意。

本项目支持在构建 5.10、5.15、6.1、6.6 和 6.12 内核时检查并应用完整修复。该选项默认关闭，如需加入 GhostLock 防护，请在触发构建时手动开启 `CVE-2026-43499 rtmutex 修复链`。两个漏洞的修复必须同时存在，工作流会自动处理这一点；已经包含完整修复的内核不会重复打补丁。

该修复已完成 [84 个内核版本的全量构建验证](https://github.com/zzh20188/GKI_KernelSU_SUSFS/actions/runs/29509099128)。如果想了解漏洞原理、受影响范围、公开利用和缓解措施，请阅读 CIQ 的详细文章：[GhostLock Mitigation](https://kb.ciq.com/article/rocky-linux/rl-ghostlock-mitigation)。

---

## 🧪 Droidspaces 容器支持（实验性）

> **实验性功能：** 不保证所有 GKI 版本均能成功构建或启动，刷入前请务必备份 Boot 镜像。
>
> **TIPS：** 工作流使用的是 [Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) 的 [官方补丁](https://github.com/ravindu644/Droidspaces-OSS/tree/main/Documentation/resources/kernel-patches/GKI) ，如有更好的补丁可以提个issues，此外由于存在三个补丁，或许需要反复试验以确保其中一个适配你的机型，请根据他人或实际经验来选择。

[Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) 是一个轻量级的 Linux 容器工具，可以在 Android 上运行完整的 Linux 环境（支持 systemd、OpenRC 等），用于搭建开发环境、运行服务器等场景。

**支持范围：** 5.10 / 5.15 / 6.1 / 6.6 / 6.12

**使用方式：** 在手动触发构建时，选择 `Droidspaces 容器支持` 选项：

| 选项 | 说明 |
|:---:|:---|
| `off` | 关闭（默认） |
| `678` | 使用 6_7_8 槽位补丁（推荐） |
| `123` | 使用 1_2_3 槽位补丁（备用） |
| `345` | 使用 3_4_5 槽位补丁（备用） |

> **提示：** 6.12 内核仅有一个补丁，选择任意非关闭选项即可。

**如果构建失败或刷入后 bootloop：** 可尝试切换到其他槽位补丁（如 678 → 123 或 345），不同内核子版本可能适用不同的补丁。

## 🔧 自定义提交配置
通过 [`config/config`](config/config) 文件可以指定 SUSFS 和 SukiSU 使用特定的 commit。

**什么是提交 (commit)？**

提交是一串哈希字符串，代表仓库在某个时间点的状态。例如将 sukisu 设为 `4b8644515fe6d87a109129e590ccd9d33a855dca`，即使用 1 月 30 日的 SukiSU 版本编译内核。

**为什么要指定提交？**

- 当上游仓库更新引入 bug 或兼容性问题时，可回退到稳定版本
- 当 SUSFS 与 SukiSU 版本不同步导致编译失败时，可手动指定兼容的版本

**如何获取提交哈希？**

- SUSFS: [susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)
- SukiSU: [SukiSU-Ultra commits/builtin](https://github.com/SukiSU-Ultra/SukiSU-Ultra/commits/builtin/)

以 SUSFS 为例，先选择分支，再复制对应提交的哈希值：

![选择分支](assets/susfs_branch.png)
![复制提交](assets/susfs_commit.png)

```ini
# 启用自定义提交
custom=true

# SUSFS 各分支的 commit hash
gki-android12-5.10=
gki-android13-5.15=
gki-android14-6.1=
gki-android15-6.6=

# SukiSU 的 commit hash
sukisu=
```

> 留空则使用该分支的最新提交。

---

## 🧪 伪装 `/proc/config.gz`（Stock Config）

这是一个进阶技巧，不需要在工作流里手动开关。  
构建时会自动检测 `config/stock_defconfig` 是否存在：存在则应用，不存在则跳过。

使用方法：
1. 确保设备当前是官方 ROM + 官方内核。
2. 获取设备上的 `/proc/config.gz`（可在手机端或电脑端操作）。
3. 解压后重命名为 `stock_defconfig`，上传到仓库 [`config/`](config/) 目录并提交（可直接在手机端完成）。

构建流程会自动：
- 复制到内核源码：`$KERNEL_ROOT/common/arch/arm64/configs/stock_defconfig`
- 在 `$KERNEL_ROOT/common/kernel/Makefile` 中将 `$(obj)/config_data` 规则从 `$(KCONFIG_CONFIG)` 切换为 `arch/arm64/configs/stock_defconfig`
- 使编译产物中的 `/proc/config.gz` 更贴近你的官方内核配置
---

## 🛠️ 安装后推荐

### 📦 模块推荐

<table>
<tr>
<th>模块名称</th>
<th>仓库</th>
<th>频道</th>
</tr>
<tr>
<td><b>LSPosed-Irena</b></td>
<td><a href="https://github.com/re-zero001/LSPosed-Irena">GitHub</a></td>
<td><a href="https://t.me/lsposed_irena">Telegram</a></td>
</tr>
<tr>
<td><b>Zygisk Next</b></td>
<td><a href="https://github.com/Dr-TSNG/ZygiskNext">GitHub</a></td>
<td rowspan="2"><a href="https://t.me/real5ec1cff">Telegram</a></td>
</tr>
<tr>
<td><b>TrickyStore</b></td>
<td><a href="https://github.com/5ec1cff/TrickyStore">GitHub</a></td>
</tr>
</table>

### 🔧 Xposed 模块

| 模块 | 说明 |
|:---:|:---|
| **FuseFixer** | [Unicode零宽修复模块](https://t.me/real5ec1cff/268) |

### App

| 名称 | 说明 |
|:---:|:---|
| **Scene** | [官网](https://omarea.com/#/) |
---

<div align="center">

**更多内容持续更新中...**

⭐ 如果这个项目对你有帮助，请点个 Star 支持一下！

</div>

---

## 💻 本地构建（CLI）

除了 GitHub Actions，现在也支持在本机直接构建。**两者共用同一份构建逻辑**
（`scripts/build_kernel.sh`），因此本地构建与云端构建行为完全一致，不存在两套维护分叉。

### 环境要求

- Linux（推荐 Ubuntu 22.04+），首次构建需 `sudo` 安装编译依赖
- 至少 **40GB** 可用磁盘空间
- Python 3.8+

### 快速开始

```bash
# 查看支持的版本组合（数据来自 data/）
python3 build.py --list-configs

# 构建单个版本
python3 build.py --android android14 --kernel 6.1 --sub-level 124 --os-patch 2025-02

# 构建某个组合的全部子版本
python3 build.py --matrix android14-6.1

# 构建全部版本（耗时极长，谨慎使用）
python3 build.py --all

# 只校验参数，不真正构建
python3 build.py --android android14 --kernel 6.1 --dry-run
```

### 常用选项

| 选项 | 说明 |
|---|---|
| `--ksu-variant` | KernelSU 变体：`ReSukiSU` / `SukiSU` / `SukiSU(40726)` / `SukiSU(40548)` / `Official` |
| `--zram` | 启用 ZRAM (LZ4KD) |
| `--bbr` | 设置 BBR 为默认 TCP 拥塞算法 |
| `--kpm` | 启用 KPM 内核模块支持 |
| `--bbg` | 启用 Baseband-guard |
| `--rekernel` | 启用 Re-Kernel |
| `--op8e` | 启用一加 8E 处理器支持 |
| `--cve-patch` | 应用 CVE-2026-43499 安全修复 |
| `--droidspaces` | Droidspaces 容器支持（`off` / `678` / `123` / `345`） |
| `--ntsync` | 启用 NTSync（需配合 `--droidspaces`） |
| `--only <阶段>` | 只运行指定阶段（调试用） |
| `--from <阶段>` | 从指定阶段开始（断点续建） |
| `--list-phases` | 列出全部构建阶段 |

> **调试技巧：** 用 `--only <阶段>` 可以单独重跑某一步，例如
> `python3 build.py --android android14 --kernel 6.1 --only compile_kernel`，
> 不必每次都从克隆源码重新开始。

> **注意：**「清理磁盘空间」这一步只在 GitHub Actions runner 上执行，本地构建会自动跳过，
> 以免误删你机器上的文件。
