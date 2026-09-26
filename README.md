<div align="center">

# GKI KernelSU SUSFS

---

> [!WARNING]
> **⚠️ 个人衍生仓库 · 非官方发布 · AI 辅助二次开发 · 请勿打扰上游**
>
> - 本仓库是 [zzh20188/GKI_KernelSU_SUSFS](https://github.com/zzh20188/GKI_KernelSU_SUSFS) 的**个人自用衍生分支**。构建矩阵、脚本与补丁适配等**绝大多数核心工作由上游作者完成**，本仓库只是在此基础上做了自用整合，所有功劳归属上游。
> - 仓库内的工作流、构建脚本与文档经过 **AI 辅助修改与二次开发**，**未经任何上游作者审阅、认可或参与**，行为可能与上游不一致；上游作者对本仓库的内容、质量与后果不承担任何责任。
> - 产物仅供本人测试，**不是官方发布渠道**；想要官方版本请前往 [zzh20188 原仓库](https://github.com/zzh20188/GKI_KernelSU_SUSFS/releases)。
> - 刷入第三方内核存在变砖、丢失数据、触发应用风控等风险；请自行备份原厂 Boot 镜像，风险自负。
> - 文档站点（GitHub Pages）使用 [GoatCounter](https://www.goatcounter.com/) 做匿名访问统计，数据托管于 `zzh20188.goatcounter.com`，不收集可识别个人身份的信息；禁用 JavaScript 或拦截 `gc.zgo.at` 即可退出统计。
> - 遇到问题请在本仓库反馈，**不要以任何方式打扰上游作者**（包括 Issue、邮件、酷安私信等）。

---

**自动化构建 GKI 内核 | 集成 KernelSU + SUSFS**

本仓库**基于 [zzh20188 的 GKI 构建基架](https://github.com/zzh20188/GKI_KernelSU_SUSFS) 二次开发**（fork）：
以其为主体，移植了 [ShirkNeko](https://github.com/ShirkNeko/GKI_KernelSU_SUSFS) 的 KPM 镜像修补与本地 CLI 设计，
参考了 [coolzyd](https://github.com/coolzyd9107/GKI_SukiSU_Ultra_SUSFS) 的 Release 呈现方式，
并把构建流程收敛到同一份 [`scripts/build_kernel.sh`](scripts/build_kernel.sh)：
GitHub Actions 与本地 `build.py` 共用这一份 47 阶段脚本，不存在两套逻辑分叉。

覆盖 Android 12 / 13 / 14 / 15 / 16（内核 5.10 / 5.15 / 6.1 / 6.6 / 6.12），
每次构建产出 AnyKernel3 刷机包、三种压缩格式的 boot 镜像、KernelSU 管理器与 SUSFS 配套模块。

[![Release](https://img.shields.io/github/v/release/Lokitla/GKI_SUKISU_SUSFS_for_Lokita?label=Release&style=flat-square&logo=github&logoColor=white&color=2ea44f)](https://github.com/Lokitla/GKI_SUKISU_SUSFS_for_Lokita/releases)
[![上游原作者](https://img.shields.io/badge/%E2%9D%A4%EF%B8%8F%20%E4%B8%8A%E6%B8%B8%E5%8E%9F%E4%BD%9C%E8%80%85-zzh20188%40Coolapk-3DDC84?style=flat-square&logo=android&logoColor=white)](http://www.coolapk.com/u/11253396)
[![KernelSU](https://img.shields.io/badge/KernelSU-Supported-5AA300?style=flat-square)](https://kernelsu.org/)
[![SUSFS](https://img.shields.io/badge/SUSFS-Integrated-E67E22?style=flat-square)](https://gitlab.com/simonpunk/susfs4ksu)

> 🙏 上面这个 Coolapk 链接是**原作者 zzh20188 的酷安主页**，放在这里仅是为了表达敬意与感谢；
> **它与本仓库没有任何关系**——请勿因本仓库的任何问题（Issue、私信、评论）去打扰原作者。

[**English**](README-EN.md) | 简体中文

---

</div>

## 🚀 快速导航

- 📖 [文档](docs/advanced-features.md)
- 📥 [下载](https://github.com/Lokitla/GKI_SUKISU_SUSFS_for_Lokita/releases)
- 🔰 [教程](https://lokitla.github.io/GKI_SUKISU_SUSFS_for_Lokita/guide.html)
- 📊 [版本查询](https://lokitla.github.io/GKI_SUKISU_SUSFS_for_Lokita/)
- 📄 [上游来源与许可证](NOTICE)

---

## ✨ 功能特性

| 能力 | 说明 | 默认 |
|---|---|---|
| KernelSU 变体 | `SukiSU` / `SukiSU(40726)` / `SukiSU(40548)` / `ReSukiSU` / `Official` | `ReSukiSU` |
| SUSFS | 集成 SUSFS 补丁集，支持 inline hook | 开启 |
| KPM | 编译后修补 Image 使其可加载 KPM 模块（6.6 内核不支持） | `patched（开启并修补）`※ |
| Hook 类型 | SUSFS Inline Hooks，编译期手写 syscall 拦截，不留 kprobe 痕迹 | — |
| Magic Mount | SukiSU 默认挂载方式 | 开启 |
| ZRAM / LZ4KD | ZRAM 增强算法（LZ4KD / LZ4K_OPLUS）；6.12 无 lz4k 补丁栈，请求会被整段跳过并告警 | 开启（见下方注） |
| BBR | 设为默认拥塞算法（脚本会先开 `TCP_CONG_ADVANCED` 门控再写开关，见注 4） | 关闭 |
| BBG | Baseband-guard 防格机 | 关闭 |
| Re-Kernel | Re-Kernel 驱动 | 关闭 |
| NoMount | 挂载元模块：在 `fs/` 层集成 [maxsteeel/NoMount](https://github.com/maxsteeel/nomount)，与 SUSFS sus_mount 各走各的路径，可与任意 KSU 变体共存；需自行刷入配套 NoMount 模块 | 关闭 |
| Droidspaces | LXC 式容器支持（实验性） | 不启用 |
| NTSync | 需先启用 Droidspaces | 关闭 |
| CVE-2026-43499 | rtmutex 修复链 | 关闭 |
| 一加 8E 支持 | 非一加设备勿开 | 关闭 |
| Spoofed 管理器 | 一并拉取伪装包名的管理器 APK | 开启 |
| Telegram 通知 | 构建完成后推送通知 | 开启 |
| 自定义构建时间 | 固定内核 `UTS_VERSION` 时间戳 | 留空 |

> 除 ReSukiSU 变体、SUSFS、Spoofed 管理器、Telegram 通知和 ZRAM 外，其余开关默认关闭。
>
> 注 1 · **变体已换血：** 默认从 `SukiSU` 换成 `ReSukiSU`（不需要额外拉取上游
> 分支，构建更快），`.github/workflows/` 下 11 个入口的 `kernelsu_variant` /
> `ksu_variant` 默认值与 `scripts/build_kernel.sh` 的 `KSU_VARIANT` 均已同步。
>
> 注 2 · **KPM 在默认变体下不生效：** KPM 只有 SukiSU 变体提供，ReSukiSU / Official /
> Next 的内核 Kconfig 里没有 `config KPM`。默认变体下相关阶段会被自动跳过——构建不
> 中断，但内核加载不了 KPM 模块；需要 KPM 请手动把变体切回 `SukiSU`。
>
> 注 3 · **ZRAM 的默认值分三层：** 构建脚本内部兜底默认 `false`
> （`build_kernel.sh` 的 `USE_ZRAM:=false`，仅当无人传参时生效）；
> 本地 CLI（`build.py --zram`，`--no-zram` 关闭）与**所有** Actions 入口
> （各 `kernel-*.yml` 单版本入口、`kernel-custom.yml`、`main.yml` 全矩阵）默认 `true`。
> 默认开启即装配 LZ4KD / LZ4K_OPLUS；6.12 因无 lz4k 补丁栈，即使开了也会整段跳过
> （见下方「SukiSU 上游更新自动触发」一节的说明）。
>
> 注 4 · **BBR 的门控处理：** 5.10 / 5.15 / 6.1 / 6.12 的 gki_defconfig 基线里没有
> `CONFIG_TCP_CONG_ADVANCED`，而 Kconfig 里 `TCP_CONG_BBR` 与 `DEFAULT_BBR` 都被
> `if TCP_CONG_ADVANCED` 包住——门控不开，BBR 两行就是没人认的死行。脚本会先写
> `TCP_CONG_ADVANCED=y` 再写 BBR，并连带把 `TCP_CONG_BIC / WESTWOOD / HTCP` 置 `=y`
> （三者 Kconfig 默认 `m`，置 `y` 是为了避免在 bazel 路径产出未声明的 `.ko`）。
> 6.6 基线自带 ADVANCED，此处理幂等。

---

## 📦 构建产物说明

「上传全部」模式下，每个内核版本会拆成两个产物：

| 产物 | 内容 | 体积（以 5.10 为例） |
|---|---|---|
| `..._kernel-<版本>-AnyKernel3` | `AnyKernel3.zip` 刷机包 | 约 18 MB |
| `..._kernel-<版本>-Images` | `boot.img` / `boot-gz.img` / `boot-lz4.img` | 约 50 MB（压缩后） |

**刷机只需要 AnyKernel3 那个包**，里面的 `Image` 由 `anykernel.sh` 在设备上现场处理。

> 产物上传模式（`ARTIFACT_UPLOAD_MODE`）：除「上传全部」外，还可选「仅 AnyKernel3」——
> 只上传刷机包、不上传三个 boot 镜像，适合只需要刷机包的场景，更省 Release 体积。
> （`main.yml` 默认走「上传全部」全矩阵；`kernel-custom.yml` 默认走「仅 AnyKernel3」。）

三个 boot 镜像的区别在于内核部分的压缩方式，供 `fastboot flash boot` 直接刷入时使用：

| 文件 | 内核压缩 | 适用 |
|---|---|---|
| `boot.img` | 未压缩 | 兼容性最强，老 bootloader |
| `boot-gz.img` | gzip | 传统默认，几乎所有 bootloader 都支持 |
| `boot-lz4.img` | lz4 | 现代 GKI 常用，解压最快 |

现代设备优先 `boot-lz4.img`；卡第一屏换 `-gz`；仍不行用未压缩的 `boot.img`。

---

## 🔰 两种构建入口的区别

| 入口 | 一次会构建多少 |
|---|---|
| **内核构建 - Android 12 / 13 / 14 / 15 / 16** | 该内核版本的**全部**子版本（矩阵由 `.github/workflows/config/matrix.json` 的 `full` 模式生成，5.10 共 22 个；6.12 为 4 个） |
| **Android 内核构建-自定义** | 只构建你在「安全补丁级别」里指定的版本，**默认只出 1 个** |

> 注：从「构建内核」（`main.yml`）调用这些单版本入口时走 `auto` 精简矩阵
> （5.10=5 / 5.15=6 / 6.1=5 / 6.6=3，6.12 不在内），不是上表的 full 全量。

自定义入口用「构建范围」下拉控制出多少：

| 构建范围 | 效果 |
|---|---|
| 指定版本 | 只构建「构建目标」里填的版本（默认） |
| 全部版本 | 该内核全部版本（5.10 → 22 个，已含 LTS；**耗时很长**） |
| 仅 LTS | 只构建 LTS 版本（5.10 → 5.10.269） |

「构建目标」同时认**子版本代号**和**补丁级别日期**，两种可以混着填：

| 填法 | 效果 |
|---|---|
| `66` | 子版本代号 → 5.10.66 |
| `236` | 子版本代号 → 5.10.236 |
| `2022-01` | 补丁级别日期 → 5.10.66 |
| `lts` | LTS 版本 → 5.10.269 |
| `all` | 该内核全部版本（5.10 → 22 个，已含 LTS；**耗时很长**） |
| `66,236` | 逗号分隔，一次构建多个 |
| `66,2022-01,236` | 代号与日期可混填（重复目标会自动去重） |

> 选「全部版本」或「仅 LTS」时，「构建目标」里填什么都会被忽略。手填仍支持特殊值 `all` / `lts`。
> 填错时会把该内核所有可用子版本代号列出来。

---

## ⚠️ 兼容性提醒

> **注意：** 目前不支持一加 ColorOS 14、15，刷入后可能需要清除数据开机。
>
> **6.12：** 本仓库已为 6.10+ 的 `security_add_hooks` 新签名补上兼容补丁，
> 但自动构建矩阵不含 6.12（详见下方「SukiSU 上游更新自动触发」一节）；
> 要构建 6.12 请手动触发独立入口「内核构建 - Android 16 (6.12)」
> （6.12.23 / 30 / 38 / 58 四个子版本；6.12 上 KPM 与 ZRAM 会自动跳过）。
>
> **老版本 SukiSU：** 保留了老版本变体（`SukiSU(40726)` / `SukiSU(40548)`）的构建；
> 它们完全使用旧版 SUKISU 与 SUSFS 代码，不含最近的特性或 bug，
> 搭配老版本内核时最好用对应版本的管理器。
>
> **rekernel 特性（beta）：** rekernel 特性现已支持（目前处于 beta 阶段）
> 
> <img width="296" height="152" alt="image" src="https://github.com/user-attachments/assets/e60316c3-c760-4178-a4c8-b94d0ef0b5b2" />



---

## 📚 文档与指南

本仓库的文档都放在 [`docs/`](docs/) 里，与代码同一仓库、随提交一起评审和更新：

| 文档 | 内容 |
|---|---|
| 🧩 [**进阶功能**](docs/advanced-features.md) | GhostLock 安全修复、Droidspaces 容器支持、NoMount 挂载元模块、Re-Kernel、自定义提交配置、伪装 `/proc/config.gz` |
| 💻 [**本地 CLI 构建**](docs/local-build.md) | 不依赖 Actions、在本机直接构建的完整参数、断点续建与调试技巧 |

- 🔰 [**新手教程**](https://lokitla.github.io/GKI_SUKISU_SUSFS_for_Lokita/guide.html)：Fork 与自定义编译的逐步图文说明（GitHub Pages）
- 📊 [**内核版本查询**](https://lokitla.github.io/GKI_SUKISU_SUSFS_for_Lokita/)：安全补丁月份 → 内核子版本对照，点开即可复制构建参数
- [English](docs/advanced-features-en.md) / [English: local build](docs/local-build-en.md)

> [zzh20188/GKI_KernelSU_SUSFS](https://github.com/zzh20188/GKI_KernelSU_SUSFS) 的 Wiki 面向原仓库，
> 不含本分支的定制项（SukiSU 变体、KPM 镜像修补、Release 缓存、NoMount 等），请以本仓库 `docs/` 为准。

---

## 🆕 相对 zzh20188 的新增能力

在 [zzh20188/GKI_KernelSU_SUSFS](https://github.com/zzh20188/GKI_KernelSU_SUSFS) 的基础上，本仓库移植了 [ShirkNeko/GKI_KernelSU_SUSFS](https://github.com/ShirkNeko/GKI_KernelSU_SUSFS) 的以下能力，并做了适配整理：

| 能力 | 说明 | 开启方式 |
|---|---|---|
| **本地 CLI 构建** | 不依赖 Actions 即可构建，与云端共用同一脚本 | `python3 build.py ...` |
| **BBR 拥塞控制** | 将 BBR 设为默认 TCP 拥塞算法；含 `TCP_CONG_ADVANCED` 门控前置（见功能特性注 4） | Actions: `use_bbr`；CLI: `--bbr` |
| **Telegram 通知** | 构建完成后推送消息与产物校验值到 TG | Actions: `send_telegram` |
| **Release 缓存** | 用 GitHub Release 存 ccache，突破 `actions/cache` 的容量与过期限制 | Actions: `use_release_cache` |
| **Spoofed 管理器开关** | 可单独控制是否一并拉取伪装官方包名的 SukiSU 管理器 APK | Actions: `manager_spoofed` |
| **KPM 镜像修补** | 编译完成后对 `Image` 打 KPM 补丁（移植自 ShirkNeko 的 `patch_kpm_image`）；6.6 内核不支持会自动跳过，非 SukiSU 变体（`ReSukiSU` / `Official` / `Next`）同样整段跳过 | Actions: `use_kpm` 选 `enabled` / `patched` |
| **管理器拆分为两个产物** | 普通管理器与 Spoofed 管理器各自成为独立产物，不再混在一个压缩包里 | 默认生效 |
| **SUSFS 独立开关** | 原「KernelSU / SUSFS 模式」三态选择简化为「集成 SUSFS」勾选框（不再提供纯净 GKI） | Actions: `enable_susfs` |

### 默认值已对齐 ShirkNeko 推荐配置

默认值对齐 [ShirkNeko/GKI_KernelSU_SUSFS](https://github.com/ShirkNeko/GKI_KernelSU_SUSFS) 原仓库 main 分支
`build-kernels.yml` / `kernel-build.yml` 的实际配置（注意：**不是**任何私人 fork）：

| 选项 | 本分支默认 | ShirkNeko 原仓库 |
|---|---|---|
| KernelSU 变体 | **`ReSukiSU`** | `Stable(标准)`（无变体选项） |
| 集成 SUSFS | **开启** | 内置，无独立开关 |
| KPM | **`patched`（开启并修补镜像）** | `true` |
| ZRAM (LZ4KD) | **开启**（所有 Actions 入口与本地 CLI） | `false` |
| BBG 安全补丁 | **关闭** | `false` |
| CVE-2026-43499 修复 | **关闭** | 无此选项（本分支保留为可选） |
| BBR 拥塞控制 | 关闭 | `false` |
| 一加 8E 支持 | 关闭 | `false` |
| Telegram 通知 | **开启** | `true`（未配 secrets 则自动跳过） |
| Spoofed 管理器 | **开启** | `true` |
| 发布类型（构建内核） | **`Release`** | `make_release: true` |

> **关于 Release：** 原上游把「创建 Release」这一步硬编码成只在 `zzh20188/GKI_KernelSU_SUSFS` 仓库执行，
> fork 后永远发不出来。本分支已去掉该限制，并把默认改成发布：在 **构建内核** 里 `发布类型` 现在默认为 `Release`，
> 想只跑构建、不建 Release 时选 `Actions` 即可。

### 配置 Telegram 通知

在仓库 **Settings → Secrets and variables → Actions** 中添加：

| Secret | 说明 |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Bot 令牌（向 [@BotFather](https://t.me/BotFather) 申请） |
| `TELEGRAM_CHAT_ID` | 目标会话 ID |
| `TELEGRAM_MESSAGE_THREAD_ID` | 话题 ID（可选，仅论坛群组需要） |

未配置时通知会自动跳过，不会影响构建。

---

## 🔄 SukiSU 上游更新自动触发

`.github/workflows/Auto_Trigger.yml` 每三天检查一次 [SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra)
`main` 分支的最新提交号，与本仓库 `sha` 分支上记录的旧值比对：

1. 有新提交 → 回写 `sha` 分支，并触发 **构建内核** 工作流；
2. 无新提交 → 什么都不做，不消耗 Runner 时长；
3. 拿不到提交号（API 限流）→ 直接失败退出，不会带着空值去构建。

**默认跑「全部版本」**：走 `main.yml` 展开矩阵，但实际组合数由
`.github/workflows/config/matrix.json` 的 **`auto` 精简矩阵**决定：
**5.10=5 / 5.15=6 / 6.1=5 / 6.6=3，共 19 个内核版本**（每版取数个代表性子版本 + LTS）。
> 注：`data/` 目录下共 **127 条**版本定义（5.10=36 / 5.15=35 / 6.1=32 / 6.6=16 / 6.12=8），
> 这是「全部可用版本」的全集，本地 `build.py --all` 与各单版本入口的 full 矩阵
> （22/20/23/15/4，共 84 个）基于它；自动触发的 19 个是 auto 矩阵的子集。
构建配置固定为 **变体 `ReSukiSU`（KPM 随之被跳过）+ ZRAM (LZ4KD) 开启**，
其余增强项（BBG / Re-Kernel / BBR 等）关闭。想省时间时手动选「单版本冒烟」，只编 5.10.66 一个。

**6.12 默认不参与**（自动矩阵不含它，勾 `include_612` 也不会构建，见下）。它有三道坎，前两道已经翻过去：

`security_add_hooks` 的第三参数自 v6.10 起改成 `const struct lsm_id *`，而 KernelSU 各
变体仍按老签名传字符串（`hook/lsm_hook.c` 里的
`security_add_hooks(ksu_hooks, ARRAY_SIZE(ksu_hooks), "ksu")`）。打补丁阶段会按内核
版本补实参宏：**v6.10 起传 `&ksu_lsm_id`（`.name = "ksu"`），更早的内核照旧传字符串
字面量**。

第二道坎跟 KPM 有关：SukiSU 的 `drivers/kernelsu/kpm/super_access.c` 用了
`netlink_kernel_cfg.cb_mutex` 与 `DYNAMIC_STRUCT_END(netlink_kernel_cfg)`，在 6.10+ 上
编译不过（`no member named 'cb_mutex' in 'struct netlink_kernel_cfg'`）。
**脚本会自动关掉 KPM，不再硬跑那轮注定失败的编译**：`KERNEL_VERSION ≥ 6.10` 且请求了
KPM 时，早期闸门直接把 `KPM_SUPPORTED` 置 0，KPM 相关阶段与 `CONFIG_KPM=y` 全部跳过。
> 实测 run `36198392724` 硬跑的代价是：第一次构建 18 分钟后失败，再靠脚本自带的
> 「编译失败自动重试」丢弃 `ksu.fragment`（KPM 随之关闭）兜底才出包，一个版本多花
> 近 20 分钟。自动关闭与重试落点相同，只是不用先炸一次。
>
> 副作用：6.12 上 KPM 是被自动关掉的，想要 KPM 请改用 **≤ 6.6 的内核**。
> 默认变体 `ReSukiSU` 本身不带 KPM 代码，不受这条影响。
>
> 另注：`struct lsm_id` 的字段一直是 `name`，不是 `lsm` —— 照着新签名想当然写 `.lsm`
> 会在编译期报 `field designator 'lsm' does not refer to any field`。

第三道坎跟 ZRAM 有关：6.12 没有 lz4k 补丁栈（`SukiSU_patch` 只提供 5.10 / 5.15 /
6.1 / 6.6 四个目录）。**即使把 ZRAM 开关打开，6.12 上也会整段跳过**：构建早期闸门
发 `::warning::` 后，ZRAM 相关阶段与 `CONFIG_ZRAM` 系列的 defconfig 改写全部不执行，
产物只带内核自带的压缩算法。这是刻意设计——宁可明确跳过，也不要留下半套打了
一半的 ZRAM 补丁让 GKI defconfig 校验炸掉。

> 另外注意：**`include_612` 勾了也不会让自动构建跑 6.12**。自动触发走 `main.yml`，
> 各单版本入口被 `main.yml` 调用时一律用 `auto` 精简矩阵，而 6.12 不在 `auto`
> 矩阵里——`kernel-a16-6-12.yml` 会输出空矩阵并跳过构建。目前想构建 6.12，
> 只能**手动触发独立入口「内核构建 - Android 16 (6.12)」**（full 模式，
> 构建 6.12.23 / 30 / 38 / 58 四个子版本）。

手动运行时可改这几个输入：

| 输入 | 说明 | 默认 |
|---|---|---|
| `force` | 忽略「是否有新提交」，强制触发 | 否 |
| `build_scope` | `全部版本` / `单版本冒烟` / `不构建` | `全部版本` |
| `include_612` | 尝试把 6.12 纳入矩阵。**注意：6.12 不在 `auto` 矩阵内，勾选后自动构建仍会跳过 6.12**（见上）；本仓库已打 LSM 兼容补丁 | 否 |
| `ksu_branch_mode` | SukiSU 拉取分支：`auto`=跟随 SUSFS 开关自动选（开 SUSFS→builtin，关→main）/ `main`=纯管理器分支 / `builtin`=内核内置实现 | `auto` |
| `release_type` | `Release` / `Pre-Release` / `Actions` | `Release` |

> 选 `全部版本` 走 `main.yml` 展开矩阵；选 `单版本冒烟` 走 `kernel-custom.yml`，
> 一次只编 5.10.66 一个。
>
> 19 个版本（auto 矩阵）通常一波并发即可完成；若手动跑 full 全量 84 个，
> 并发上限 20 约分 4 波，属于正常现象。

> 需要仓库 **Settings → Actions → Workflow permissions** 为 `Read and write`，
> 否则回写 `sha` 分支会被 `github-actions[bot]` 的 403 拦下。

---

## 🧩 进阶功能

以下四项进阶用法默认均不启用，需要在触发构建时手动选择，或放置相应配置文件：

| 能力 | 说明 | 启用方式 |
|---|---|---|
| 🛡️ **GhostLock 安全修复** | 修复 `CVE-2026-43499` / `CVE-2026-53163` 两个 rtmutex 漏洞 | Actions 勾选 `cve_2026_43499_patch` |
| 🧪 **Droidspaces 容器支持** | 在 Android 上运行完整 Linux 环境（实验性） | Actions 选 `droidspaces` 槽位 |
| 🔧 **自定义提交配置** | 把 SUSFS / SukiSU 钉到指定 commit | 编辑 `config/config` |
| 🧪 **伪装 `/proc/config.gz`** | 让产物内核配置贴近官方 ROM | 放置 `config/stock_defconfig` 后自动生效 |

完整说明见 [**docs/advanced-features.md**](docs/advanced-features.md)。

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

除了 GitHub Actions，也支持在本机直接构建。**两者共用同一份构建逻辑**
（`scripts/build_kernel.sh`），因此本地构建与云端构建行为完全一致，不存在两套维护分叉。

```bash
# 构建单个版本
python3 build.py --android android14 --kernel 6.1 --sub-level 124 --os-patch 2025-02
```

完整参数（47 个构建阶段、断点续建 `--from` / 单步重跑 `--only`、全部功能开关）见
💻 [**本地 CLI 构建文档**](docs/local-build.md)。

---

## 🗂️ 仓库结构

| 路径 | 用途 |
|---|---|
| `scripts/build_kernel.sh` | **构建逻辑唯一来源**，47 个阶段；Actions 与本地 `build.py` 都调它 |
| `build.py` | 本地 CLI 入口，只负责参数解析与调用 `scripts/build_kernel.sh` |
| `.github/workflows/build.yml` | 可复用构建工作流，只保留缓存/产物/日志/通知等 Actions 专属能力 |
| `.github/workflows/main.yml` | 「构建内核」总入口，负责展开版本矩阵并调用 `build.yml` |
| `.github/workflows/kernel-*.yml` | 按 Android 版本拆分的独立入口 |
| `.github/workflows/Auto_Trigger.yml` | 检测 SukiSU 上游更新并自动触发构建 |
| `.github/workflows/get-manager.yml` | 抓取 KernelSU / SukiSU 管理器 APK |
| `.github/workflows/update-pages.yml` | 更新 `data/` 版本数据并部署 GitHub Pages |
| `config/` | 内核配置片段（如 `zram.config`）、`config/config` 提交锁定、SukiSU 变体配置 |
| `data/` | 各 Android 版本可用的内核子版本与补丁级别数据（驱动版本矩阵） |
| `security_patch/` | CVE-2026-43499（GhostLock）修复链与适配脚本 |
| `zram/` | LZ4 的 ARM64 NEON 加速实现（`apply_lz4_neon.sh`、`lz4/`、`include/linux/lz4.h`），与 ZRAM/LZ4KD 打在同一条补丁栈上 |
| `web/` | GitHub Pages 站点源码（构建版本查询） |
| `scripts/susfs_fixes/apply.sh` | SUSFS 补丁的适配与冲突修复 |
| `scripts/telegram_notify.py` | Telegram 通知推送 |
| `scripts/gki_fetch.py` 等 | 从 Google 拉取 GKI 版本数据，供 `update-pages.yml` 使用 |
| `tools/migration/` | 迁移时用过的一次性脚本，仅作过程留档，**不参与构建** |
| `FUSION.md` | 三个上游仓库的比对与迁移记录 |

> 改构建行为请改 `scripts/build_kernel.sh`，不要在 `build.yml` 里重写 shell ——
> 否则本地与云端会立刻分叉。

---

## 🔗 上游来源与许可证

本仓库是基于上游的**个人衍生项目**（fork + AI 辅助二次开发），核心工作来自以下上游作者，完整清单见 [NOTICE](NOTICE)。主要来源：

| 项目 | 上游贡献 | 许可证 |
|---|---|---|
| [WildKernels/GKI_KernelSU_SUSFS](https://github.com/WildKernels/GKI_KernelSU_SUSFS) | zzh20188 与 ShirkNeko 的共同原始上游 | **GPL-3.0-or-later**（自定义 LICENSE 声明头 + GPL-3.0 全文，GitHub 识别为 `Other`） |
| [zzh20188/GKI_KernelSU_SUSFS](https://github.com/zzh20188/GKI_KernelSU_SUSFS) | **构建基座与绝大部分代码**（矩阵、脚本、补丁适配） | GPL-2.0 |
| [ShirkNeko/GKI_KernelSU_SUSFS](https://github.com/ShirkNeko/GKI_KernelSU_SUSFS) | KPM 镜像修补、本地 CLI 设计 | 未声明 |
| [coolzyd9107/GKI_SukiSU_Ultra_SUSFS](https://github.com/coolzyd9107/GKI_SukiSU_Ultra_SUSFS) | Release 说明模板 | GPL-2.0 |
| [SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra) | KernelSU 变体本体 | GPL-3.0 |
| [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) | SUSFS 补丁集 | GPL-3.0 |
| [WildKernels/AnyKernel3](https://github.com/WildKernels/AnyKernel3) | 刷机包模板 | **BSD-3-Clause 风格**（osm0sis 的 AK3 脚本许可；其中 `magiskboot` / `magiskpolicy` 为 **GPL-3.0+**） |

**本仓库主体（自身新增的代码与文档）采用 GPL-2.0-or-later**，以便与仓库内含的 GPL-3.0
组件（SukiSU-Ultra、SUSFS、Droidspaces 等）兼容、合法整体分发；基座 zzh20188 标注 GPL-2.0，
本仓库作为其衍生作品在 GPL-2.0-or-later 条款下分发。

[LICENSE](LICENSE) 保留 GNU GPL v2 条款正文（不作删改），文件头部以 SPDX 标识声明
本仓库按 GPL-2.0-or-later 分发；归属与兼容性说明全部写在 [NOTICE](NOTICE) 里。

如果你是上游作者，认为归属描述有误，请在本仓库提 Issue，我会立即更正。

### GPL-2.0 与 GPL-3.0 的区别

本仓库同时涉及这两种许可证（基座 zzh20188 是 GPL-2.0，SukiSU / SUSFS 是 GPL-3.0），差异如下：

| 维度 | GPL-2.0 | GPL-3.0 / GPL-3.0-or-later |
|---|---|---|
| 反硬件锁定（Anti-Tivoization） | 无要求 | 禁止用签名或硬件锁死，消费设备必须能安装修改后的版本 |
| 专利授权 | 无显式条款 | 贡献者自动授予专利许可；起诉他人专利侵权则许可自动终止 |
| 违反后恢复 | 违反即终止，无恢复路径 | 首次违反后 60 天内纠正可恢复许可 |
| 与 AGPL 合并 | 不允许 | 允许与 AGPL-3.0 代码合并 |
| 附加条款 | 不允许额外限制 | 允许 7 类有限附加条款 |
| 与对方的兼容性 | GPL-2.0-only 代码**不能**并入 GPL-3.0 作品 | GPL-2.0-**or-later** 可升级到 GPL-3.0 |

**两者共同的核心限制**（copyleft 传染性）：

- 分发二进制（如本仓库发布的 boot 镜像与 AnyKernel3 刷机包）时，**必须同时提供对应的完整源代码**；
- 衍生作品必须以**同一许可证**分发，不能改成闭源或更宽松的协议；
- 必须保留原作者的版权声明、许可证全文与修改说明，且无担保（AS IS）。

**因此本仓库的实际约束**：本仓库是公开仓库，构建脚本、补丁与配置全部可查，上游 SukiSU / SUSFS / KernelSU 的源码也均可从其官方仓库获取，满足源码可得要求；任何二次分发本仓库产物的行为，同样需要遵守上述义务。

> **关于 `-or-later`**：本仓库新增部分采用 GPL-2.0-or-later，意味着使用者可以选择按 GPL-2.0 或任何更高版本的 GPL（如 GPL-3.0）来使用这部分代码，这正是它能与 GPL-3.0 组件共存的原因；而纯 GPL-2.0-only 的代码则不能这样升级。

---

## 🙏 致谢

本仓库能存在，完全站在上游作者们的肩膀上——内核构建矩阵、SUSFS 适配、KPM 修补、管理器分发，这些硬核工作没有一样是本仓库作者完成的，所有功劳与敬意归于他们：

- **[zzh20188](https://github.com/zzh20188)**（[酷安主页](http://www.coolapk.com/u/11253396)，仅作致敬）—— 本仓库的基座，构建矩阵与脚本的绝大部分工作出自他手；
- **[ShirkNeko](https://github.com/ShirkNeko)** —— KPM 镜像修补与本地 CLI 设计；
- **[coolzyd](https://github.com/coolzyd9107)** —— Release 呈现方式；
- 以及 [SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra)、[susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)、[KernelSU](https://kernelsu.org/)、[AnyKernel3](https://github.com/WildKernels/AnyKernel3) 等项目的所有贡献者。

本仓库作者（借助 AI）所做的只是把上述成果拼装成自己用着顺手的样子。

**遇到本仓库的任何问题，请在本仓库反馈，不要以任何方式打扰上游作者**——他们没有参与本仓库的修改，也不应为本仓库的问题买单。