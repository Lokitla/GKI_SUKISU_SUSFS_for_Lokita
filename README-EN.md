<div align="center">

# GKI KernelSU SUSFS

---

> [!WARNING]
> **⚠️ Personal derivative · Not an official release · AI-assisted rework · Do not disturb upstream**
>
> - This repository is a **personal derivative (fork)** of [zzh20188/GKI_KernelSU_SUSFS](https://github.com/zzh20188/GKI_KernelSU_SUSFS). The vast majority of the core work — build matrix, scripts, patch adaptation — **was done by the upstream author**; this repo only integrates it for personal use. All credit belongs upstream.
> - Workflows, build scripts and docs here were **modified with AI assistance** and have **not been reviewed, endorsed or contributed to by any upstream author**; behaviour may differ from upstream. The upstream authors take no responsibility for anything in this repository.
> - Builds are for the owner's own testing and are **not an official distribution channel**; for official releases go to [zzh's original repo](https://github.com/zzh20188/GKI_KernelSU_SUSFS/releases).
> - Flashing third-party kernels risks bricking, data loss and app integrity-check failures. Back up your stock boot image and proceed at your own risk.
> - The docs site (GitHub Pages) uses [GoatCounter](https://www.goatcounter.com/) for anonymous visit stats, hosted at `zzh20188.goatcounter.com`; it collects no personally identifiable information. Disable JavaScript or block `gc.zgo.at` to opt out.
> - Please report issues **here** and never contact the upstream authors about them (no issues, emails or Coolapk DMs).

---

**Automated GKI Kernel Builds | KernelSU + SUSFS Integrated**

This repository is **based on [zzh20188's GKI scaffolding](https://github.com/zzh20188/GKI_KernelSU_SUSFS)** (a fork
with AI-assisted rework): using it as the main body, it ports [ShirkNeko](https://github.com/ShirkNeko/GKI_KernelSU_SUSFS)'s
KPM image patching and local-CLI design, and takes inspiration from
[coolzyd](https://github.com/coolzyd9107/GKI_SukiSU_Ultra_SUSFS)'s Release presentation style.
The build pipeline is converged into a single
[`scripts/build_kernel.sh`](scripts/build_kernel.sh): GitHub Actions and the local
`build.py` share that same 45-phase script, so there is no second implementation to drift.

Covers Android 12 / 13 / 14 / 15 / 16 (kernels 5.10 / 5.15 / 6.1 / 6.6 / 6.12).
Every build produces an AnyKernel3 flashable zip, boot images in three compression
formats, the KernelSU manager and the companion SUSFS module.

[![Release](https://img.shields.io/github/v/release/Lokitla/GKI_SUKISU_SUSFS_for_Lokita?label=Release&style=flat-square&logo=github&logoColor=white&color=2ea44f)](https://github.com/Lokitla/GKI_SUKISU_SUSFS_for_Lokita/releases)
[![Upstream Author](https://img.shields.io/badge/%E2%9D%A4%EF%B8%8F%20Upstream%20Author-zzh20188%40Coolapk-3DDC84?style=flat-square&logo=android&logoColor=white)](http://www.coolapk.com/u/11253396)
[![KernelSU](https://img.shields.io/badge/KernelSU-Supported-5AA300?style=flat-square)](https://kernelsu.org/)
[![SUSFS](https://img.shields.io/badge/SUSFS-Integrated-E67E22?style=flat-square)](https://gitlab.com/simonpunk/susfs4ksu)

> 🙏 The Coolapk link above is **the personal Coolapk page of zzh20188, the original upstream
> author** — it is placed here solely as a token of respect and gratitude.
> **It is not affiliated with this repository in any way**; please do not contact the author
> about anything related to this repo (no issues, DMs or comments).

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
| KPM | Patch `Image` after compilation so KPM modules can load (unsupported on 6.6) | `patched` (on + patched) |
| Hook type | SUSFS Inline Hooks — hand-written syscall interception at compile time, no kprobe traces | — |
| Magic Mount | SukiSU default mount mode | On |
| ZRAM / LZ4KD | Enhanced ZRAM algorithm | **On** |
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

> Artifact upload mode (`ARTIFACT_UPLOAD_MODE`): besides `上传全部` (upload everything), you can pick `仅 AnyKernel3` (AnyKernel3 only) —
> it uploads just the flashable zip and skips the three boot images, which saves Release space when only the flashable package is needed.
> (`main.yml` defaults to upload-everything for the full matrix; `kernel-custom.yml` defaults to AnyKernel3 only.)

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

## 🆕 Capabilities Added on Top of Upstream zzh

On top of [zzh20188/GKI_KernelSU_SUSFS](https://github.com/zzh20188/GKI_KernelSU_SUSFS), this repository ports
the following features from
[ShirkNeko/GKI_KernelSU_SUSFS](https://github.com/ShirkNeko/GKI_KernelSU_SUSFS), with additional adaptation:

| Capability | Description | How to enable |
|---|---|---|
| **Local CLI build** | Build without Actions, sharing the same script as CI | `python3 build.py ...` |
| **BBR congestion control** | Set BBR as the default TCP congestion algorithm | Actions: `use_bbr`; CLI: `--bbr` |
| **Telegram notification** | Push build results and checksums to Telegram | Actions: `send_telegram` |
| **Release cache** | Store ccache in GitHub Releases, bypassing `actions/cache` size and expiry limits | Actions: `use_release_cache` |
| **Spoofed manager toggle** | Choose whether to also fetch the SukiSU manager APK disguised as the official KernelSU package name | Actions: `manager_spoofed` |
| **KPM image patching** | Patch `Image` after compilation so KPM modules can load (ported from ShirkNeko's `patch_kpm_image`); 5.x and 6.1, skipped on 6.6 | Actions: `use_kpm` → `enabled` / `patched` |
| **Split manager artifacts** | The normal and Spoofed managers are uploaded as two separate artifacts instead of one combined archive | Always on |
| **Standalone SUSFS switch** | The three-state "KernelSU / SUSFS mode" picker is now a simple "Integrate SUSFS" checkbox (plain GKI is no longer offered) | Actions: `enable_susfs` |

Defaults below are aligned with the actual values in `build-kernels.yml` / `kernel-build.yml`
on the **main branch of [ShirkNeko/GKI_KernelSU_SUSFS](https://github.com/ShirkNeko/GKI_KernelSU_SUSFS)**
(note: not any private fork):

| Option | This fork | ShirkNeko upstream |
|---|---|---|
| KernelSU variant | **`SukiSU`** | `Stable` (no variant picker) |
| Integrate SUSFS | **On** | built in, no separate switch |
| KPM | **`patched`** (enabled + image patching) | `true` |
| ZRAM (LZ4KD) | **On** | `false` |
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

**By default the full matrix runs**: 5.10 + 5.15 + 6.1 + 6.6 —
**22 + 20 + 23 + 15 = 80 kernel versions**, matching what upstream zzh publishes per Release.
> Note: the above covers only the default-enabled 5.10–6.6 matrix; ticking `include_612` adds 6.12's 4 versions.
> The `data/` directory holds **126** version definitions in total (5.10=36 / 5.15=35 / 6.1=32 / 6.6=16 / 6.12=7);
> a local `build.py --all` builds from this full set.
The build config is fixed at **KPM `patched` (on + patched) + ZRAM (LZ4KD) on**, with the other
enhancements (BBG / Re-Kernel / BBR, etc.) off.
Pick `单版本冒烟` for a quick run that builds just 5.10.66.

**6.12 is excluded by default**: current SukiSU mainline does not compile on 6.12 —
`security_add_hooks` takes a `const struct lsm_id *` on 6.12 while SukiSU still passes a
string (`hook/lsm_hook.c:191`), and disabling KPM does not help either. This is an upstream
issue; enable it again by ticking `include_612` once SukiSU fixes it or if you switch to the
legacy variants (40726 / 40548) — no code change needed.

Manual runs accept these inputs:

| Input | Description | Default |
|---|---|---|
| `force` | Trigger even when no new commit was detected | false |
| `build_scope` | `全部版本` (all) / `单版本冒烟` (single) / `不构建` (none) | `全部版本` |
| `include_612` | Include the 4 Android 16 (6.12) versions too (incompatible with current SukiSU) | false |
| `release_type` | `Release` / `Pre-Release` / `Actions` | `Release` |

> `全部版本` dispatches `main.yml` with the full matrix; `单版本冒烟` dispatches
> `kernel-custom.yml` and builds only 5.10.66.
>
> A full 80-version run takes a while (20 concurrent jobs → roughly 4 waves). That is normal.

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
| `--zram` / `--no-zram` | ZRAM (LZ4KD) enhancement (on by default) |
| `--bbr` | Set BBR as the default congestion algorithm |
| `--kpm` | KPM module support, defaults to `patched` (on + patched); optional value `disabled` / `enabled` / `patched` |
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

This repository is a **personal derivative** of its upstreams (a fork with AI-assisted rework);
the core work comes from the upstream authors below. The full list lives in [NOTICE](NOTICE); the main sources are:

| Project | Upstream contribution | Licence |
|---|---|---|
| [WildKernels/GKI_KernelSU_SUSFS](https://github.com/WildKernels/GKI_KernelSU_SUSFS) | Common root of both zzh and ShirkNeko | **GPL-3.0-or-later** (custom LICENSE header + full GPL-3.0 text; GitHub reports `Other`) |
| [zzh20188/GKI_KernelSU_SUSFS](https://github.com/zzh20188/GKI_KernelSU_SUSFS) | **Build scaffolding and the bulk of the code** (matrix, scripts, patch adaptation) | GPL-2.0 |
| [ShirkNeko/GKI_KernelSU_SUSFS](https://github.com/ShirkNeko/GKI_KernelSU_SUSFS) | KPM image patching, local CLI design | not declared |
| [coolzyd9107/GKI_SukiSU_Ultra_SUSFS](https://github.com/coolzyd9107/GKI_SukiSU_Ultra_SUSFS) | Release notes template | GPL-2.0 |
| [SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra) | The KernelSU variant itself | GPL-3.0 |
| [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) | SUSFS patch set | GPL-3.0 |
| [WildKernels/AnyKernel3](https://github.com/WildKernels/AnyKernel3) | Flashable package template | **BSD-3-Clause style** (osm0sis' AK3 script licence; bundled `magiskboot` / `magiskpolicy` are **GPL-3.0+**) |

**This repository's own newly added code and docs are GPL-2.0-or-later**, so they can coexist
with and be lawfully distributed alongside the in-repo GPL-3.0 components (SukiSU-Ultra, SUSFS,
Droidspaces, etc.); the zzh20188 base is labelled GPL-2.0 and this repo distributes as a
derivative under GPL-2.0-or-later.

[LICENSE](LICENSE) keeps the verbatim GNU GPL v2 terms (unmodified), with a header
SPDX-License-Identifier declaring this repo distributes under GPL-2.0-or-later; attribution
and compatibility notes all live in [NOTICE](NOTICE).

If you are an upstream author and believe any attribution is wrong, please open an issue
here and it will be corrected immediately.

### GPL-2.0 vs GPL-3.0

This repository touches both licences (the zzh base is GPL-2.0; SukiSU / SUSFS are GPL-3.0). The differences:

| Aspect | GPL-2.0 | GPL-3.0 / GPL-3.0-or-later |
|---|---|---|
| Anti-Tivoization | no requirement | forbids signature/hardware locks — consumer devices must allow installing modified builds |
| Patent grant | no explicit clause | contributors grant a patent licence; suing over patents terminates your licence |
| Reinstatement after violation | terminated, no way back | first violation can be cured within 60 days |
| Combination with AGPL | not allowed | AGPL-3.0 code may be combined |
| Additional terms | not allowed | seven limited categories allowed |
| Compatibility with the other | GPL-2.0-only code **cannot** be folded into a GPL-3.0 work | GPL-2.0-**or-later** code can be upgraded to GPL-3.0 |

**Core obligations shared by both (copyleft):**

- When distributing binaries (the boot images and AnyKernel3 zips published here), the **complete corresponding source code** must be made available as well;
- Derivative works must be released under the **same licence** — you cannot relicense to closed or more permissive terms;
- Copyright notices, the licence text and modification notes must be kept, and everything is provided **AS IS** without warranty.

**What this means here:** this repo is public, so all build scripts, patches and configs are inspectable, and the SukiSU / SUSFS / KernelSU sources are available from their own upstreams — the source-availability requirement is met. Anyone redistributing artifacts built here inherits the same obligations.

> **On `-or-later`:** the parts newly added here use GPL-2.0-or-later, meaning users may take them under GPL-2.0 or any later GPL version (e.g. GPL-3.0). That is exactly why they can coexist with the GPL-3.0 components; code that is GPL-2.0-*only* cannot be upgraded this way.

---

## 🙏 Acknowledgements

This repository exists entirely on the shoulders of the upstream authors — the build matrix, SUSFS
adaptation, KPM patching and manager distribution are all their work, none of it was done by this
repo's owner. All credit and respect belong to them:

- **[zzh20188](https://github.com/zzh20188)** ([Coolapk page](http://www.coolapk.com/u/11253396), as a token of respect) — the foundation of this repo; the bulk of the build matrix and scripts is his work;
- **[ShirkNeko](https://github.com/ShirkNeko)** — KPM image patching and local-CLI design;
- **[coolzyd](https://github.com/coolzyd9107)** — Release presentation style;
- and all contributors to [SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra), [susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu), [KernelSU](https://kernelsu.org/) and [AnyKernel3](https://github.com/WildKernels/AnyKernel3).

What this repo's owner did (with AI assistance) was merely reassemble their results into a
personally convenient shape.

**For any issue with this repository, report it here — do not contact the upstream authors in any
way.** They did not participate in this repo's modifications and should not be bothered by its problems.
