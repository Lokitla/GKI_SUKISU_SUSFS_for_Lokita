<div align="center">

# GKI KernelSU SUSFS

---

> [!WARNING]
> **⚠️ Personal fork · Not an official release · Modified with AI assistance**
>
> - This repository is a **personal fork** of [zzh20188/GKI_KernelSU_SUSFS](https://github.com/zzh20188/GKI_KernelSU_SUSFS). Builds here are for the owner's own testing and are **not an official distribution channel**.
> - Workflows, build scripts and docs in this repo were **modified with AI assistance** and have not been reviewed by the upstream author; behaviour may differ from upstream.
> - Flashing third-party kernels risks bricking, data loss and app integrity-check failures. Back up your stock boot image and proceed at your own risk.
> - Please report issues here rather than to the upstream author.

---

**Automated GKI Kernel Builds | KernelSU + SUSFS Integrated**

This repository is built on top of [zzh20188's GKI scaffolding](https://github.com/zzh20188/GKI_KernelSU_SUSFS),
absorbing [ShirkNeko](https://github.com/ShirkNeko/GKI_KernelSU_SUSFS)'s KPM image patching and local-CLI design,
plus [coolzyd](https://github.com/coolzyd9107/GKI_SukiSU_Ultra_SUSFS)'s Release presentation style.
All three pipelines are converged into a single
[`scripts/build_kernel.sh`](scripts/build_kernel.sh): GitHub Actions and the local
`build.py` share that same 45-phase script, so there is no second implementation to drift.

Covers Android 12 / 13 / 14 / 15 / 16 (kernels 5.10 / 5.15 / 6.1 / 6.6 / 6.12).
Every build produces an AnyKernel3 flashable zip, boot images in three compression
formats, the KernelSU manager and the companion SUSFS module.

[![Release](https://img.shields.io/github/v/release/Lokitla/GKI_SUKISU_SUSFS_for_Lokita?label=Release&style=flat-square&logo=github&logoColor=white&color=2ea44f)](https://github.com/Lokitla/GKI_SUKISU_SUSFS_for_Lokita/releases)
[![Coolapk](https://img.shields.io/badge/Follow-Coolapk-3DDC84?style=flat-square&logo=android&logoColor=white)](http://www.coolapk.com/u/11253396)
[![KernelSU](https://img.shields.io/badge/KernelSU-Supported-5AA300?style=flat-square)](https://kernelsu.org/)
[![SUSFS](https://img.shields.io/badge/SUSFS-Integrated-E67E22?style=flat-square)](https://gitlab.com/simonpunk/susfs4ksu)

English | [**简体中文**](README.md)

---

</div>

## 🚀 Quick Navigation

- 📖 [Documentation](https://github.com/zzh20188/GKI_KernelSU_SUSFS/wiki)
- 📥 [Downloads](https://github.com/Lokitla/GKI_SUKISU_SUSFS_for_Lokita/releases)
- 🔰 [Tutorial](https://zzh20188.github.io/GKI_KernelSU_SUSFS/guide.html)
- 📄 [Upstream sources & licences](NOTICE)

---

## ✨ Features

| Capability | Description | Default |
|---|---|---|
| KernelSU variant | `SukiSU` / `SukiSU(40726)` / `SukiSU(40548)` / `ReSukiSU` / `Official` | `SukiSU` |
| SUSFS | SUSFS patch set with inline hook support | On |
| KPM | Patch `Image` after compilation so KPM modules can load (unsupported on 6.6) | `enabled` |
| Hook type | SUSFS Inline Hooks — hand-written syscall interception at compile time, no kprobe traces | — |
| Magic Mount | SukiSU default mount mode | On |
| ZRAM / LZ4KD | Enhanced ZRAM algorithm | Off |
| BBR | Set as the default congestion algorithm | Off |
| BBG | Baseband-guard anti-wipe protection | Off |
| Re-Kernel | Re-Kernel driver | Off |
| Droidspaces | LXC-style container support (experimental) | Disabled |
| NTSync | Requires Droidspaces | Off |
| CVE-2026-43499 | rtmutex fix chain | Off |
| OnePlus 8E support | Do not enable on non-OnePlus devices | Off |
| Spoofed manager | Also fetch the manager APK disguised as the official package name | On |
| Telegram notification | Push a notification when the build finishes | On |
| Custom build time | Pin the kernel `UTS_VERSION` timestamp | Empty |

> Apart from SukiSU, SUSFS, KPM, the spoofed manager and Telegram notifications, every
> other toggle defaults to off, matching the defaults of ShirkNeko's **original repository**.

---

## 📦 Build artifacts

In `上传全部` (upload everything) mode, each kernel version is split into two artifacts:

| Artifact | Contents | Size (5.10 example) |
|---|---|---|
| `..._kernel-<version>-AnyKernel3` | `AnyKernel3.zip` flashable package | ~18 MB |
| `..._kernel-<version>-Images` | `boot.img` / `boot-gz.img` / `boot-lz4.img` | ~50 MB (compressed) |

**Flashing only needs the AnyKernel3 package** — its `Image` is handled on-device by `anykernel.sh`.

The three boot images differ only in how the kernel payload is compressed; they are meant
for `fastboot flash boot`:

| File | Kernel compression | Use when |
|---|---|---|
| `boot.img` | uncompressed | Widest compatibility, older bootloaders |
| `boot-gz.img` | gzip | Traditional default, supported by nearly all bootloaders |
| `boot-lz4.img` | lz4 | Common on modern GKI, fastest decompression |

Try `boot-lz4.img` first on modern devices; if it hangs on the first screen, switch to
`-gz`; if that still fails, use the uncompressed `boot.img`.

---

## ⚠️ Compatibility Notice

> **Note:** OnePlus ColorOS 14/15 is currently not supported. A data wipe may be required after flashing.

> **rekernel feature (beta): rekernel feature is now supported (currently in beta)**


---

## 📚 Documentation & Guides

For detailed instructions, please refer to the [**GitHub Wiki (bilingual CN/EN)**](https://github.com/zzh20188/GKI_KernelSU_SUSFS/wiki)

Wiki covers:
- [**🔰 Tutorial**](https://zzh20188.github.io/GKI_KernelSU_SUSFS/guide.html)
- 📥 Download / Flash kernel
- 💡 Tips & Tricks
- 🆘 Brick Recovery Guide
- 📊 Kernel Version Compatibility

---

## 🆕 Merged Capabilities

The following features were merged from
[ShirkNeko/GKI_KernelSU_SUSFS](https://github.com/ShirkNeko/GKI_KernelSU_SUSFS):

| Capability | Description | How to enable |
|---|---|---|
| **Local CLI build** | Build without Actions, sharing the same script as CI | `python3 build.py ...` |
| **BBR congestion control** | Set BBR as the default TCP congestion algorithm | Actions: `use_bbr`; CLI: `--bbr` |
| **Telegram notification** | Push build results and checksums to Telegram | Actions: `send_telegram` |
| **Release cache** | Store ccache in GitHub Releases, bypassing `actions/cache` size and expiry limits | Actions: `use_release_cache` |
| **Spoofed manager toggle** | Choose whether to also fetch the SukiSU manager APK disguised as the official KernelSU package name | Actions: `manager_spoofed` |
| **KPM image patching** | Patch `Image` after compilation so KPM modules can load (ported from ShirkNeko's `patch_kpm_image`); 5.x only, skipped on 6.6 | Actions: `use_kpm` → `enabled` / `patched` |
| **Split manager artifacts** | The normal and Spoofed managers are uploaded as two separate artifacts instead of one combined archive | Always on |
| **Standalone SUSFS switch** | The three-state "KernelSU / SUSFS mode" picker is now a simple "Integrate SUSFS" checkbox (plain GKI is no longer offered) | Actions: `enable_susfs` |

Defaults below are aligned with the actual values in `build-kernels.yml` / `kernel-build.yml`
on the **main branch of [ShirkNeko/GKI_KernelSU_SUSFS](https://github.com/ShirkNeko/GKI_KernelSU_SUSFS)**
(note: not any private fork):

| Option | This fork | ShirkNeko upstream |
|---|---|---|
| KernelSU variant | **`SukiSU`** | `Stable` (no variant picker) |
| Integrate SUSFS | **On** | built in, no separate switch |
| KPM | **`enabled`** (with image patching) | `true` |
| ZRAM (LZ4KD) | **Off** | `false` |
| BBG security patch | **Off** | `false` |
| CVE-2026-43499 fix | **Off** | not offered upstream (kept here as an option) |
| BBR congestion control | Off | `false` |
| OnePlus 8E support | Off | `false` |
| Telegram notification | **On** | `true` (skipped when secrets are missing) |
| Spoofed manager | **On** | `true` |
| Release type (Build kernel) | **`Release`** | `make_release: true` |

> **About releases:** upstream hard-coded the "create release" job to run only in `zzh20188/GKI_KernelSU_SUSFS`, so a fork could never publish one. That restriction has been removed here, and publishing is now the default: `Release type` in the **Build kernel** workflow defaults to `Release`. Pick `Actions` if you only want artifacts without creating a release.

### Configuring Telegram notifications

Add these under **Settings → Secrets and variables → Actions**:

| Secret | Description |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Bot token from [@BotFather](https://t.me/BotFather) |
| `TELEGRAM_CHAT_ID` | Target chat ID |
| `TELEGRAM_MESSAGE_THREAD_ID` | Topic ID (optional, forum groups only) |

If they are not configured, notifications are skipped silently and never break a build.

---

## 🔄 Automatic trigger on SukiSU updates

`.github/workflows/Auto_Trigger.yml` checks the latest commit on
[SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra) `main` every three days and
compares it against the value recorded on this repository's `sha` branch:

1. New commit found → write it back to the `sha` branch and trigger the **构建内核** workflow;
2. No new commit → do nothing, no runner minutes burned;
3. Commit SHA unavailable (API rate limit) → fail fast instead of building with an empty value.

**By default only Android 16 (6.12) is built as a smoke test**, not all 80 versions at once.
The reason is practical: a full run means 80 jobs pulling kernel source from
`android.googlesource.com` simultaneously — real load on upstream, and a good way to burn
runner minutes on a commit that may not even compile. Once a new commit looks healthy, run
**构建内核** manually with the full matrix.

Manual runs accept three inputs:

| Input | Description | Default |
|---|---|---|
| `force` | Trigger even when no new commit was detected | false |
| `build_scope` | `单版本验证` (single) / `全部版本` (all) / `不构建` (none) | `单版本验证` |
| `release_type` | `Release` / `Pre-Release` / `Actions` | `Release` |

> Requires **Settings → Actions → Workflow permissions** to be `Read and write`,
> otherwise the push back to the `sha` branch is rejected with a 403 for `github-actions[bot]`.

---

## 🛡️ GhostLock Security Fix

GhostLock is a pair of high-risk Linux kernel vulnerabilities tracked as `CVE-2026-43499` and `CVE-2026-53163`. An attacker does not need Root access or an additional kernel module. The vulnerability may be exploited by any application or local process that can run code on the device.

### Potential impact

- **System crash or forced reboot:** An ordinary application can crash the kernel, making the device unavailable and potentially causing the loss of unsaved data.
- **Local privilege escalation:** A more advanced exploit can cross Android security boundaries and give an ordinary application kernel-level control of the device.
- **Public exploits are available:** Both a denial-of-service proof of concept and a complete privilege-escalation chain targeting Android ARM64 have been published. This is no longer a theoretical risk.
- **No reliable temporary workaround exists:** Permission restrictions, application isolation, and hardening options may make exploitation harder, but they cannot fully prevent crashes or alternative exploit methods.

The vulnerability cannot be triggered directly over the network. However, a malicious application, untrusted code in a shared environment, or an attacker who already gained code execution through another vulnerability can use GhostLock as the next step. Extra care should therefore be taken with applications, modules, and scripts from unknown sources.

This project can check and apply the complete fix when building kernels 5.10, 5.15, 6.1, 6.6, and 6.12. The option is **disabled by default** (ShirkNeko upstream does not carry this fix). Enable `CVE-2026-43499 rtmutex fix chain` when starting a build to include GhostLock protection. Both vulnerability fixes must be present together, and the workflow handles this automatically. Kernels that already contain the complete fix are not patched again.

The fix has passed a [full build validation covering 84 kernel versions](https://github.com/zzh20188/GKI_KernelSU_SUSFS/actions/runs/29509099128). For vulnerability details, affected systems, public exploits, and mitigation guidance, read CIQ's article: [GhostLock Mitigation](https://kb.ciq.com/article/rocky-linux/rl-ghostlock-mitigation).

---

## 🧪 Droidspaces Container Support (Experimental)

> **Experimental feature:** Successful build and boot is not guaranteed across all GKI versions. Always back up your boot image before flashing.
>
> **TIPS:** The workflow uses the [official Droidspaces patches](https://github.com/ravindu644/Droidspaces-OSS/tree/main/Documentation/resources/kernel-patches/GKI) from [Droidspaces](https://github.com/ravindu644/Droidspaces-OSS). If you have better patches, feel free to open an issue. Since there are three patch variants, you may need to test them repeatedly to find one that fits your device. Choose based on other users' feedback or your own experience.

[Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) is a lightweight Linux containerization tool that lets you run full Linux environments (with systemd, OpenRC, etc.) on Android — useful for development, running servers, and more.

**Supported versions:** 5.10 / 5.15 / 6.1 / 6.6 / 6.12

**Usage:** When triggering a build manually, select the `Droidspaces` option:

| Option | Description |
|:---:|:---|
| `不启用` (disabled) | Disabled (default) |
| `678` | Use 6_7_8 slot patch (recommended) |
| `123` | Use 1_2_3 slot patch (fallback) |
| `345` | Use 3_4_5 slot patch (fallback) |

> **Note:** Kernel 6.12 has only two options — `不启用` (disabled) and `启用` (enabled). There are no slots there.

**If the build fails or bootloops after flashing:** Try switching to a different slot patch (e.g. 678 → 123 or 345). Different kernel sub-levels may require different patches.

## 🔧 Custom Commit Pinning
Use the [`config/config`](config/config) file to pin SUSFS and SukiSU to specific commits.

**What is a commit?**

A commit is a hash string representing the state of a repository at a specific point in time. For example, setting sukisu to `4b8644515fe6d87a109129e590ccd9d33a855dca` means using the January 30th version of SukiSU to build the kernel.

**Why pin a commit?**

- When upstream updates introduce bugs or compatibility issues, you can roll back to a stable version
- When SUSFS and SukiSU versions are out of sync causing build failures, you can manually specify compatible versions

**How to get a commit hash?**

- SUSFS: [susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)
- SukiSU: [SukiSU-Ultra commits/builtin](https://github.com/SukiSU-Ultra/SukiSU-Ultra/commits/builtin/)

Taking SUSFS as an example, first select the branch, then copy the commit hash:

![Select branch](assets/susfs_branch.png)
![Copy commit](assets/susfs_commit.png)

```ini
# Enable custom commits
custom=true

# SUSFS commit hash per branch
gki-android12-5.10=
gki-android13-5.15=
gki-android14-6.1=
gki-android15-6.6=

# SukiSU commit hash
sukisu=
```

> Empty value = use the latest commit of that branch.

---

## 🧪 Spoof `/proc/config.gz` (Stock Config)

This is an advanced trick and requires no workflow toggle.  
The build process auto-detects whether `config/stock_defconfig` exists: if present, it is applied; if absent, it is skipped.

How to use:
1. Make sure your device is running stock ROM + stock kernel.
2. Obtain `/proc/config.gz` from your device (phone-side or PC-side workflow both work).
3. Decompress it, rename it to `stock_defconfig`, upload it to the [`config/`](config/) directory in your repo, and commit (can be done directly on phone).

During the build, the workflow will automatically:
- Copy it to `$KERNEL_ROOT/common/arch/arm64/configs/stock_defconfig`
- In `$KERNEL_ROOT/common/kernel/Makefile`, switch the `$(obj)/config_data` rule from `$(KCONFIG_CONFIG)` to `arch/arm64/configs/stock_defconfig`
- Make `/proc/config.gz` in the built kernel closer to your stock kernel config
---

## 🛠️ Post-Install Recommendations

### 📦 Recommended Modules

<table>
<tr>
<th>Module</th>
<th>Repository</th>
<th>Channel</th>
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

### 🔧 Xposed Modules

| Module | Description |
|:---:|:---|
| **FuseFixer** | [Unicode zero-width fix module](https://t.me/real5ec1cff/268) |

### App

| Name | Description |
|:---:|:---|
| **Scene** | [Official Site](https://omarea.com/#/) |
---

<div align="center">

**More content coming soon...**

⭐ If this project helps you, please give it a Star!

</div>

---

## 💻 Local Build (CLI)

Besides GitHub Actions, kernels can now be built locally. **Both paths share the same
build logic** (`scripts/build_kernel.sh`), so local and cloud builds behave identically —
there is no second implementation to keep in sync.

### Requirements

- Linux (Ubuntu 22.04+ recommended), `sudo` needed to install build dependencies
- At least **40 GB** of free disk space
- Python 3.8+

### Quick start

```bash
# List supported version combinations (data comes from data/)
python3 build.py --list-configs

# Build a single version
python3 build.py --android android14 --kernel 6.1 --sub-level 124 --os-patch 2025-02

# Build every sub-level of a combination
python3 build.py --matrix android14-6.1

# Build everything (very long, use with care)
python3 build.py --all

# Validate parameters without building
python3 build.py --android android14 --kernel 6.1 --dry-run
```

### Common options

| Option | Description |
|---|---|
| `--ksu-variant` | KernelSU variant, defaults to `SukiSU`: `SukiSU` / `SukiSU(40726)` / `SukiSU(40548)` / `ReSukiSU` / `Official` |
| `--zram` | Enable ZRAM (LZ4KD) |
| `--bbr` | Set BBR as the default congestion algorithm |
| `--kpm` | Enable KPM kernel module support; optional value `enabled` (default) / `patched` (also patches `Image`) |
| `--bbg` | Enable Baseband-guard |
| `--rekernel` | Enable Re-Kernel |
| `--no-susfs` | Skip SUSFS integration (integrated by default) |
| `--op8e` | Enable OnePlus 8E support (OnePlus only) |
| `--cve-patch` | Apply the CVE-2026-43499 fix |
| `--droidspaces` | Droidspaces container support (`不启用` / `678` / `123` / `345`) |
| `--ntsync` | Enable NTSync (requires `--droidspaces`) |
| `--only <phase>` | Run a single phase (for debugging) |
| `--from <phase>` | Resume from a given phase |
| `--list-phases` | List all build phases |

> **Tip:** use `--only <phase>` to re-run a single step, e.g.
> `python3 build.py --android android14 --kernel 6.1 --only compile_kernel`,
> instead of restarting from a full source clone.

> **Note:** the "free disk space" step only runs on GitHub Actions runners.
> Local builds skip it so your own files are never deleted.

---

## 🔗 Upstream sources & licences

This repository is a fusion. The full list lives in [NOTICE](NOTICE); the main sources are:

| Project | What was absorbed | Licence |
|---|---|---|
| [WildKernels/GKI_KernelSU_SUSFS](https://github.com/WildKernels/GKI_KernelSU_SUSFS) | Common root of both zzh and ShirkNeko | bundled in repo |
| [zzh20188/GKI_KernelSU_SUSFS](https://github.com/zzh20188/GKI_KernelSU_SUSFS) | Main build scaffolding | GPL-2.0 |
| [ShirkNeko/GKI_KernelSU_SUSFS](https://github.com/ShirkNeko/GKI_KernelSU_SUSFS) | KPM image patching, local CLI design | not declared |
| [coolzyd9107/GKI_SukiSU_Ultra_SUSFS](https://github.com/coolzyd9107/GKI_SukiSU_Ultra_SUSFS) | Release notes template | GPL-2.0 |
| [SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra) | The KernelSU variant itself | GPL-3.0 |
| [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) | SUSFS patch set | GPL-3.0 |
| [WildKernels/AnyKernel3](https://github.com/WildKernels/AnyKernel3) | Flashable package template | bundled in repo |

**This repository is GPL-2.0 as a whole**, matching its primary upstreams. The scripts and
docs newly added here are distributed under GPL-2.0-or-later so they can coexist with the
GPL-3.0 components. Full text: [LICENSE](LICENSE).

If you are an upstream author and believe any attribution is wrong, please open an issue
here and it will be corrected immediately.

---

## 🙏 Acknowledgements

Thanks to every upstream author for their open-source work — this repository merely
reassembles their results into a shape that is convenient for personal use.
Please report issues here and **do not disturb the upstream authors**.
