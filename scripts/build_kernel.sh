#!/usr/bin/env bash
# =============================================================================
# GKI 内核构建核心脚本 —— YAML 工作流与 Python CLI 共用的单一真相源
#
# 本脚本由 .github/workflows/build.yml 自动提取生成，逻辑与原工作流等价。
# 请勿直接手工编辑本文件的阶段函数：修改请改 build.yml 后重新生成，
# 或同步修改 build.py 与工作流，避免两套逻辑分叉。
#
# 用法:
#   ./scripts/build_kernel.sh --all                 运行完整构建
#   ./scripts/build_kernel.sh --from clone_deps     从指定阶段开始
#   ./scripts/build_kernel.sh --only compile_kernel 只跑单个阶段
#   ./scripts/build_kernel.sh --list                列出全部阶段
#
# 所有参数通过环境变量注入（见下方默认值），也可由 build.py 传入。
# =============================================================================
set -eo pipefail

# ---------------------------- 参数与默认值 ----------------------------
: "${ANDROID_VERSION:=android14}"
: "${KERNEL_VERSION:=6.1}"
: "${SUB_LEVEL:=124}"
: "${OS_PATCH_LEVEL:=2025-02}"
: "${KSU_VARIANT:=SukiSU}"
: "${KSU_MODE:=关闭}"
: "${VERSION:=}"
: "${REVISION:=}"
: "${BUILD_TIME:=}"
: "${USE_ZRAM:=false}"
: "${USE_BBR:=false}"
: "${USE_BBG:=false}"
: "${USE_KPM:=false}"
: "${USE_REKERNEL:=false}"
: "${CVE_2026_43499_PATCH:=false}"
: "${EXPORT_SUSFS_PATCHES:=false}"
: "${ENABLE_SUSFS:=true}"
: "${SUPP_OP:=false}"
: "${DROIDSPACES:=不启用}"
: "${DROIDSPACES_NTSYNC:=false}"
: "${ARTIFACT_UPLOAD_MODE:=上传全部}"

# [融合] KPM 镜像修补工具，移植自 ShirkNeko/GKI_KernelSU_SUSFS (scripts/config.py)
: "${KPM_PATCH_URL:=https://raw.githubusercontent.com/ShirkNeko/SukiSU_patch/refs/heads/main/kpm/patch_linux}"
: "${WORKSPACE:=$(pwd)}"
: "${COMPILE_TIMEOUT_MINUTES:=30}"
: "${COMPILE_MAX_ATTEMPTS:=3}"
: "${GITHUB_SHA:=$(git -C "$WORKSPACE" rev-parse HEAD 2>/dev/null || echo unknown)}"
: "${GITHUB_RUN_ID:=local}"
: "${GITHUB_SERVER_URL:=}"
: "${GITHUB_REPOSITORY:=}"
: "${MANAGER_STR:=}"
export WORKSPACE GITHUB_SHA GITHUB_RUN_ID GITHUB_SERVER_URL GITHUB_REPOSITORY MANAGER_STR
export ANDROID_VERSION
export KERNEL_VERSION
export SUB_LEVEL
export OS_PATCH_LEVEL
export KSU_VARIANT
export KSU_MODE
export VERSION
export REVISION
export BUILD_TIME
export USE_ZRAM
export USE_BBR
export USE_BBG
export USE_KPM
export USE_REKERNEL
export CVE_2026_43499_PATCH
export EXPORT_SUSFS_PATCHES
export ENABLE_SUSFS
export SUPP_OP
export DROIDSPACES
export DROIDSPACES_NTSYNC
export ARTIFACT_UPLOAD_MODE

# ---------------------------- 运行时状态 ----------------------------
export COMPILE_FAILED=0
export SUSFS_PATCH_EXPORT=false
export REJ_COUNT=0
export TOOLCHAIN_CACHE_HIT="${TOOLCHAIN_CACHE_HIT:-false}"
# 注意：切勿在全局导出 OUT_DIR —— GKI 的 build/build.sh 会把它当作内核输出目录继承，
# 导致产物从 out/<branch>/dist 跑到别处。SUSFS 补丁导出目录请在阶段内局部定义。

log_stage() {
  echo ""
  echo "================================================================"
  echo "  [$1] $2"
  echo "================================================================"
}

# ---------------------------- 阶段函数 ----------------------------
stage_summary() {
  log_stage "summary" "构建信息摘要"
  local _pwd="$PWD"
  echo "========================================"
  echo "       内核构建配置摘要"
  echo "========================================"
  echo "Android 版本  : ${ANDROID_VERSION}"
  echo "内核版本      : ${KERNEL_VERSION}"
  echo "子版本号      : ${SUB_LEVEL}"
  echo "补丁级别      : ${OS_PATCH_LEVEL}"
  echo "KSU 变体      : ${KSU_VARIANT}"
  echo "构建时间      : ${BUILD_TIME}"
  echo "SUSFS 状态    : ${ENABLE_SUSFS}"
  echo "ZRAM 增强     : ${USE_ZRAM}"
  echo "BBG 补丁      : ${USE_BBG}"
  echo "KPM 功能      : ${USE_KPM}"
  echo "Re-Kernel     : ${USE_REKERNEL}"
  echo "CVE-2026-43499: ${CVE_2026_43499_PATCH}"
  echo "SUSFS 集成补丁导出: ${EXPORT_SUSFS_PATCHES}"
  echo "Droidspaces   : ${DROIDSPACES}"
  echo "NTSync        : ${DROIDSPACES_NTSYNC}"
  echo "产物上传模式  : ${ARTIFACT_UPLOAD_MODE}"
  echo "Stock Config  : 自动检测 config/stock_defconfig"
  echo "========================================"


  # [融合] BBR 开关展示（zzh 原摘要没有该项）
  echo "BBR 拥塞控制: ${USE_BBR}"

  cd "$_pwd"
}

run_summary() { stage_summary "$@"; }

stage_cleanup_disk() {
  log_stage "cleanup_disk" "清理磁盘空间"
  local _pwd="$PWD"
  # 先并行 mv 到临时目录（瞬时完成），再在后台低优先级删除，不阻塞后续步骤
  # 临时目录必须放在工作区之外：checkout 会以 runner 用户清空工作区，
  # 遇到 sudo mv 进来的 root 属主文件会 EACCES 失败
  TRASH_DIR=/tmp/.background_trash
  sudo rm -rf "$TRASH_DIR"
  mkdir -p "$TRASH_DIR"/{1..17}

  safe_mv() {
    [ -e "$1" ] && sudo mv "$1" "$2" || true
  }
  export -f safe_mv

  safe_mv /usr/share/dotnet         "$TRASH_DIR"/1  &
  safe_mv /usr/local/lib/android    "$TRASH_DIR"/2  &
  safe_mv /opt/ghc                  "$TRASH_DIR"/3  &
  safe_mv /opt/hostedtoolcache/CodeQL "$TRASH_DIR"/4 &
  safe_mv /usr/local/aws-sam-cli    "$TRASH_DIR"/5  &
  safe_mv /usr/local/share/chromium "$TRASH_DIR"/6  &
  safe_mv /usr/local/share/powershell "$TRASH_DIR"/7 &
  safe_mv /usr/local/lib/heroku     "$TRASH_DIR"/8  &
  safe_mv /usr/local/lib/node_modules "$TRASH_DIR"/9 &
  safe_mv /opt/az                   "$TRASH_DIR"/10 &
  safe_mv /opt/microsoft/powershell "$TRASH_DIR"/11 &
  safe_mv /opt/hostedtoolcache/go   "$TRASH_DIR"/12 &
  safe_mv /opt/hostedtoolcache/PyPy "$TRASH_DIR"/13 &
  safe_mv /opt/hostedtoolcache/node "$TRASH_DIR"/14 &
  sudo bash -c "mv /usr/local/bin/aliyun /usr/local/bin/azcopy /usr/local/bin/bicep \
    /usr/local/bin/cmake-gui /usr/local/bin/cpack /usr/local/bin/helm \
    /usr/local/bin/hub /usr/local/bin/kubectl /usr/local/bin/minikube \
    /usr/local/bin/node /usr/local/bin/packer /usr/local/bin/sam \
    /usr/local/bin/stack /usr/local/bin/terraform /usr/local/bin/oc \
    $TRASH_DIR/15 2>/dev/null || true" &
  sudo bash -c "mv /usr/local/julia* $TRASH_DIR/16 2>/dev/null || true" &
  sudo bash -c "mv /usr/local/bin/pulumi* $TRASH_DIR/17 2>/dev/null || true" &
  wait

  # 后台低优先级删除，顺带清理浏览器包和 apt 缓存
  (
    sudo nice -n 19 ionice -c 3 rm -rf "$TRASH_DIR"
    sudo apt-get purge -y firefox google-chrome-stable microsoft-edge-stable \
      >/dev/null 2>&1 || true
    sudo apt-get autoremove -y >/dev/null 2>&1 || true
    sudo apt-get clean >/dev/null 2>&1 || true
    command -v docker >/dev/null 2>&1 && \
      docker rmi $(docker images -q) 2>/dev/null || true
  ) >/dev/null 2>&1 &
  disown

  cd "$_pwd"
}

# 安全门：仅 GitHub Actions runner 执行，本地构建跳过以免破坏系统
run_cleanup_disk() {
  if [ "${GITHUB_ACTIONS:-false}" = "true" ]; then
    stage_cleanup_disk "$@"
  else
    echo "跳过阶段: cleanup_disk（仅 GitHub Actions runner 执行）"
  fi
}

stage_init_env() {
  log_stage "init_env" "初始化构建环境"
  local _pwd="$PWD"
  CONFIG="${ANDROID_VERSION}-${KERNEL_VERSION}-${SUB_LEVEL}"
  KERNEL_ROOT="$WORKSPACE/$CONFIG"
  mkdir -p "$KERNEL_ROOT"

  LEGACY_SUKISU_CONFIG=""
  case "${KSU_VARIANT}" in
    SukiSU\(*\)) LEGACY_SUKISU_CONFIG="$WORKSPACE/config/${KSU_VARIANT}.config" ;;
  esac

  if [ -n "$LEGACY_SUKISU_CONFIG" ] && [ ! -f "$LEGACY_SUKISU_CONFIG" ]; then
    echo "未找到 ${KSU_VARIANT} 固定提交配置: $LEGACY_SUKISU_CONFIG" >&2
    exit 1
  fi

  export CONFIG="$CONFIG"
  export KERNEL_ROOT="$KERNEL_ROOT"
  export LEGACY_SUKISU_CONFIG="$LEGACY_SUKISU_CONFIG"
  export DEFCONFIG="$KERNEL_ROOT/common/arch/arm64/configs/gki_defconfig"
  export SUSFS4KSU="$WORKSPACE/susfs4ksu"
  export KERNEL_PATCHES="$WORKSPACE/kernel_patches"
  export SUKISU_PATCHES="$WORKSPACE/SukiSU_patch"
  export ZZH_PATCHES="$WORKSPACE"
  export ANYKERNEL3="$WORKSPACE/AnyKernel3"
  export ACTION_BUILD="$WORKSPACE/Action-Build"
  export AVBTOOL="$WORKSPACE/kernel-build-tools/linux-x86/bin/avbtool"
  export MKBOOTIMG="$WORKSPACE/mkbootimg/mkbootimg.py"
  export UNPACK_BOOTIMG="$WORKSPACE/mkbootimg/unpack_bootimg.py"
  export BOOT_SIGN_KEY_PATH="$WORKSPACE/kernel-build-tools/linux-x86/share/avb/testkey_rsa2048.pem"

  mkdir -p "$WORKSPACE/git-repo"
  # storage.googleapis.com 偶发 TLS 握手失败（curl 退出码 35），全量构建 80+ 个
  # job 各跑一次，累积下来命中概率不低。--retry-all-errors 才会重试握手类错误，
  # -f 保证 HTTP 错误页不会被当成成功写进 repo 文件。
  curl -fsSL --retry 5 --retry-delay 3 --retry-all-errors --connect-timeout 30 \
    https://storage.googleapis.com/git-repo-downloads/repo \
    -o "$WORKSPACE/git-repo/repo"
  chmod 0755 "$WORKSPACE/git-repo/repo"
  export PATH="$WORKSPACE/git-repo:$PATH"
  export REPO="$WORKSPACE/git-repo/repo"

  cd "$_pwd"
}

run_init_env() { stage_init_env "$@"; }

stage_show_config() {
  log_stage "show_config" "显示配置信息"
  local _pwd="$PWD"
  CONFIG_FILE="$WORKSPACE/config/config"
  if [ -f "$CONFIG_FILE" ]; then
    echo "加载配置文件: $CONFIG_FILE"
    cat "$CONFIG_FILE"
  fi
  if [ -n "$LEGACY_SUKISU_CONFIG" ]; then
    echo "加载老版 SukiSU 固定提交配置: $LEGACY_SUKISU_CONFIG"
    cat "$LEGACY_SUKISU_CONFIG"
  fi

  cd "$_pwd"
}

run_show_config() { stage_show_config "$@"; }

stage_install_deps() {
  log_stage "install_deps" "安装编译依赖"
  local _pwd="$PWD"
  sudo apt-get update
  sudo apt-get install -y ccache python3 git curl build-essential libssl-dev bison flex libelf-dev dwarves

  cd "$_pwd"
}

run_install_deps() { stage_install_deps "$@"; }

stage_setup_ccache() {
  log_stage "setup_ccache" "配置 ccache"
  local _pwd="$PWD"
  mkdir -p ~/.cache/bazel
  ccache --version
  ccache --max-size=2G
  ccache --set-config=compression=true
  export CCACHE_DIR="$HOME/.ccache"

  cd "$_pwd"
}

run_setup_ccache() { stage_setup_ccache "$@"; }

stage_download_toolchain() {
  log_stage "download_toolchain" "下载工具链"
  local _pwd="$PWD"
  AOSP_MIRROR=https://android.googlesource.com
  BRANCH=main-kernel-build-2024
  git clone $AOSP_MIRROR/kernel/prebuilts/build-tools -b $BRANCH --depth 1 kernel-build-tools
  git clone $AOSP_MIRROR/platform/system/tools/mkbootimg -b $BRANCH --depth 1 mkbootimg

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_download_toolchain() {
  if [ "${TOOLCHAIN_CACHE_HIT:-false}" != "true" ]; then
    stage_download_toolchain "$@"
  else
    echo "跳过阶段: download_toolchain（条件不满足）"
  fi
}

stage_gen_sign_key() {
  log_stage "gen_sign_key" "生成签名密钥"
  local _pwd="$PWD"
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 > $BOOT_SIGN_KEY_PATH

  cd "$_pwd"
}

run_gen_sign_key() { stage_gen_sign_key "$@"; }

stage_setup_git() {
  log_stage "setup_git" "配置 Git"
  local _pwd="$PWD"
  git config --global user.name "BuildBot"
  git config --global user.email "BuildGkiKernel@gmail.com"

  cd "$_pwd"
}

run_setup_git() { stage_setup_git "$@"; }

stage_clone_deps() {
  log_stage "clone_deps" "克隆依赖仓库"
  local _pwd="$PWD"
  ANYKERNEL_BRANCH="gki-2.0"
  SUSFS_BRANCH="gki-${ANDROID_VERSION}-${KERNEL_VERSION}"

  echo "克隆 AnyKernel3..."
  git clone https://github.com/WildKernels/AnyKernel3.git -b "$ANYKERNEL_BRANCH"
  rm -rf AnyKernel3/.git

  echo "克隆 SUSFS (分支: $SUSFS_BRANCH)..."
  if [ -n "$LEGACY_SUKISU_CONFIG" ]; then
    git clone https://gitlab.com/simonpunk/susfs4ksu.git -b "$SUSFS_BRANCH"
  elif [ "${KSU_VARIANT}" == "SukiSU" ]; then
    if ! git clone https://github.com/ShirkNeko/susfs4ksu.git -b "$SUSFS_BRANCH" 2>/dev/null; then
      echo "ShirkNeko 仓库未找到分支 $SUSFS_BRANCH，回退到 simonpunk 原版..."
      git clone https://gitlab.com/simonpunk/susfs4ksu.git -b "$SUSFS_BRANCH"
    fi
  else
    git clone https://gitlab.com/simonpunk/susfs4ksu.git -b "$SUSFS_BRANCH"
  fi

  if [ -n "$LEGACY_SUKISU_CONFIG" ]; then
    SUSFS_FIXED_COMMIT=$(grep "^${SUSFS_BRANCH}=" "$LEGACY_SUKISU_CONFIG" | cut -d'=' -f2-)
    if [ -z "$SUSFS_FIXED_COMMIT" ]; then
      echo "未在 $LEGACY_SUKISU_CONFIG 配置 $SUSFS_BRANCH 的固定 SUSFS 提交" >&2
      exit 1
    fi
    echo "${KSU_VARIANT} 固定 SUSFS 提交: $SUSFS_FIXED_COMMIT"
    git -C susfs4ksu checkout "$SUSFS_FIXED_COMMIT"
  fi

  CONFIG_FILE="config/config"
  if [ -z "$LEGACY_SUKISU_CONFIG" ] && [ -f "$CONFIG_FILE" ]; then
    CUSTOM_ENABLED=$(grep "^custom=" "$CONFIG_FILE" | cut -d'=' -f2)
    if [ "$CUSTOM_ENABLED" == "true" ]; then
      CUSTOM_COMMIT=$(grep "^${SUSFS_BRANCH}=" "$CONFIG_FILE" | cut -d'=' -f2)
      if [ -n "$CUSTOM_COMMIT" ]; then
        echo "切换 SUSFS 到自定义提交: $CUSTOM_COMMIT"
        cd susfs4ksu
        git checkout "$CUSTOM_COMMIT"
        cd ..
      fi
    fi
  fi

  SUSFS_LATEST_COMMIT_DATE=$(git -C susfs4ksu log -1 --date=format:'%Y-%m-%d %H:%M:%S %z' --format='%cd')
  export SUSFS_LATEST_COMMIT_DATE="$SUSFS_LATEST_COMMIT_DATE"
  echo "SUSFS 仓库最新提交日期: $SUSFS_LATEST_COMMIT_DATE"

  echo "准备补丁资源..."
  git clone https://github.com/WildKernels/kernel_patches.git
  git clone https://github.com/ShirkNeko/SukiSU_patch.git
  echo "使用当前仓库补丁目录: $ZZH_PATCHES"
  git clone https://github.com/Numbersf/Action-Build.git --depth=1

  cd "$_pwd"
}

run_clone_deps() { stage_clone_deps "$@"; }

stage_sync_kernel_source() {
  log_stage "sync_kernel_source" "初始化并同步内核源码"
  local _pwd="$PWD"
  cd ${KERNEL_ROOT}
  FORMATTED_BRANCH="${ANDROID_VERSION}-${KERNEL_VERSION}-${OS_PATCH_LEVEL}"
  MAX_ATTEMPTS=3
  RETRY_DELAY=15
  SYNC_TIMEOUT=15m

  # android.googlesource.com 偶发限流、连接重置或单个 project 拉取卡死，
  # 单次失败不代表分支有问题，整轮重来通常就能成功。
  init_repo() {
    $REPO init --depth=1 -u https://android.googlesource.com/kernel/manifest \
      -b common-${FORMATTED_BRANCH} --repo-rev=v2.16 || return 1

    # ls-remote 同样可能瞬时失败；失败时返回空会让弃用分支判定出错，
    # 因此按退出码重试，全部失败就让本轮重来而不是白跑一次 sync。
    local ok=false
    for _ in 1 2 3; do
      if REMOTE_BRANCH=$(git ls-remote https://android.googlesource.com/kernel/common ${FORMATTED_BRANCH}); then
        ok=true
        break
      fi
      sleep 5
    done
    if [ "$ok" != true ]; then
      echo "git ls-remote 查询 ${FORMATTED_BRANCH} 失败"
      return 1
    fi

    DEFAULT_MANIFEST_PATH=.repo/manifests/default.xml
    TAG_FALLBACK=""
    if grep -q deprecated <<< "$REMOTE_BRANCH"; then
      echo "检测到已弃用的分支: $FORMATTED_BRANCH"
      sed -i "s/\"${FORMATTED_BRANCH}\"/\"deprecated\/${FORMATTED_BRANCH}\"/g" $DEFAULT_MANIFEST_PATH
    elif [ -z "$REMOTE_BRANCH" ]; then
      # Google 会把过期的月度分支整个删掉（既不在活跃也不在 deprecated/ 下），
      # 但 manifest 仍指向该分支。发布 tag 不会被删，回退到编号最大的 _rN tag。
      # 必须写成 refs/tags/ 全路径，裸 tag 名会被 repo 当成分支去 refs/heads/ 下找。
      local latest_tag
      latest_tag=$(git ls-remote https://android.googlesource.com/kernel/common "refs/tags/${FORMATTED_BRANCH}_r*" 2>/dev/null \
        | awk '{print $2}' | grep -v '\^{}$' | sed 's|refs/tags/||' \
        | awk -F'_r' '{print $NF+0, $0}' | sort -n | tail -n 1 | cut -d' ' -f2- || true)
      if [ -z "$latest_tag" ]; then
        echo "::error::分支 ${FORMATTED_BRANCH} 在上游既无分支也无发布 tag"
        return 1
      fi
      echo "分支 ${FORMATTED_BRANCH} 已被上游删除，回退到发布 tag: $latest_tag"
      sed -i "/path=\"common\"/ s|revision=\"${FORMATTED_BRANCH}\"|revision=\"refs/tags/${latest_tag}\"|" $DEFAULT_MANIFEST_PATH
      TAG_FALLBACK="$latest_tag"
    fi
  }

  attempt=1
  while :; do
    echo "第 $attempt/$MAX_ATTEMPTS 次初始化并同步，分支: common-${FORMATTED_BRANCH}（单次超时 $SYNC_TIMEOUT）"
    df -h "$PWD" | tail -n +2 || true

    rc=0
    if init_repo; then
      # 不加 --fail-fast：单个 project 出错时让其余 project 继续拉完，
      # 重试只需要补齐缺失部分。-j4 与 --no-clone-bundle 是为了避免
      # 高并发触发限流、以及跳过经常超时的 clone.bundle。
      SYNC_FLAGS="-c -j4 --jobs-checkout=4 --no-tags --no-clone-bundle --retry-fetches=3"
      # 第二次在原地续传（repo sync 可断点续传），第三次才整目录重来
      [ "$attempt" -gt 1 ] && SYNC_FLAGS="$SYNC_FLAGS --force-sync"
      timeout -k 60 "$SYNC_TIMEOUT" $REPO sync $SYNC_FLAGS || rc=$?
      if [ "$rc" -eq 0 ]; then
        echo "内核源码同步成功（第 $attempt 次）"
        break
      fi
      if [ "$rc" -eq 124 ]; then
        echo "repo sync 超时（$SYNC_TIMEOUT）"
      else
        echo "repo sync 失败，退出码 $rc"
      fi
    else
      rc=1
      echo "repo init 或分支预检失败"
    fi

    if [ "$attempt" -ge "$MAX_ATTEMPTS" ]; then
      echo "::error::内核源码同步连续 $MAX_ATTEMPTS 次失败"
      exit "$rc"
    fi

    # 最后一次重试前彻底清空：只删 .repo 会残留半检出的 project 目录，
    # 之后每次 sync 都会以 "Checking out local projects failed" 收场。
    if [ "$attempt" -eq $((MAX_ATTEMPTS - 1)) ]; then
      echo "清空工作目录后重来"
      find "$PWD" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    fi

    echo "${RETRY_DELAY}s 后重试..."
    sleep "$RETRY_DELAY"
    attempt=$((attempt + 1))
  done

  export REMOTE_BRANCH="$REMOTE_BRANCH"
  export TAG_FALLBACK="$TAG_FALLBACK"

  cd "$_pwd"
}

run_sync_kernel_source() { stage_sync_kernel_source "$@"; }

stage_apply_stock_config() {
  log_stage "apply_stock_config" "应用 Stock Config 伪装"
  local _pwd="$PWD"
  STOCK_SRC="$WORKSPACE/config/stock_defconfig"
  STOCK_DST="$KERNEL_ROOT/common/arch/arm64/configs/stock_defconfig"

  if [ ! -f "$STOCK_SRC" ]; then
    echo "未检测到 $STOCK_SRC，跳过 Stock Config 伪装。"
    return 0
  fi

  mkdir -p "$(dirname "$STOCK_DST")"
  if ! cp "$STOCK_SRC" "$STOCK_DST"; then
    echo "::error::复制 stock_defconfig 失败: $STOCK_SRC -> $STOCK_DST"
    exit 1
  fi
  echo "已复制 stock_defconfig -> $STOCK_DST"

  NEW_RULE='$(obj)/config_data: arch/arm64/configs/stock_defconfig FORCE'
  OLD_RULE='$(obj)/config_data: $(KCONFIG_CONFIG) FORCE'
  TARGET_MAKEFILE="$KERNEL_ROOT/common/kernel/Makefile"

  if [ ! -f "$TARGET_MAKEFILE" ]; then
    echo "::error::未找到 $TARGET_MAKEFILE"
    exit 1
  fi

  if grep -qF "$NEW_RULE" "$TARGET_MAKEFILE"; then
    echo "config_data 规则已是 stock_defconfig，跳过。"
  elif grep -qF "$OLD_RULE" "$TARGET_MAKEFILE"; then
    sed -i 's|$(obj)/config_data: $(KCONFIG_CONFIG) FORCE|$(obj)/config_data: arch/arm64/configs/stock_defconfig FORCE|' "$TARGET_MAKEFILE"
    echo "已替换 config_data 规则: $TARGET_MAKEFILE"
  else
    echo "::error::未在 $TARGET_MAKEFILE 找到规则: $OLD_RULE"
    exit 1
  fi

  cd "$_pwd"
}

run_apply_stock_config() { stage_apply_stock_config "$@"; }

stage_extract_sublevel() {
  log_stage "extract_sublevel" "提取实际子版本号"
  local _pwd="$PWD"
  ACTUAL_SUBLEVEL="${SUB_LEVEL}"
  if [[ -f "$KERNEL_ROOT/common/Makefile" ]]; then
    EXTRACTED=$(grep '^SUBLEVEL = ' "$KERNEL_ROOT/common/Makefile" | awk '{print $3}')
    [[ -n "$EXTRACTED" ]] && ACTUAL_SUBLEVEL="$EXTRACTED"
  fi
  export ACTUAL_SUBLEVEL="$ACTUAL_SUBLEVEL"
  echo "实际子版本号: $ACTUAL_SUBLEVEL"

  cd "$_pwd"
}

run_extract_sublevel() { stage_extract_sublevel "$@"; }

stage_apply_cve_patch() {
  log_stage "apply_cve_patch" "自动应用 CVE-2026-43499 rtmutex 修复链"
  local _pwd="$PWD"
  cd ${KERNEL_ROOT}/common
  bash "$WORKSPACE/security_patch/apply_cve_2026_43499.sh" \
    "${KERNEL_VERSION}" \
    "$ACTUAL_SUBLEVEL" \
    "$WORKSPACE/security_patch"

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_apply_cve_patch() {
  if [ "$CVE_2026_43499_PATCH" = "true" ]; then
    stage_apply_cve_patch "$@"
  else
    echo "跳过阶段: apply_cve_patch（条件不满足）"
  fi
}

stage_fix_glibc() {
  log_stage "fix_glibc" "修复 glibc 2.38 兼容性"
  local _pwd="$PWD"
  cd ${KERNEL_ROOT}/common
  RAW_SUB="${SUB_LEVEL}"
  [[ ! "$RAW_SUB" =~ ^[0-9]+$ ]] && CURRENT_SUB=99999 || CURRENT_SUB=$RAW_SUB

  NEEDS_FIX=false
  if [[ "${ANDROID_VERSION}" == "android13" && "${KERNEL_VERSION}" == "5.10" && $CURRENT_SUB -le 186 ]] ||
     [[ "${ANDROID_VERSION}" == "android13" && "${KERNEL_VERSION}" == "5.15" && $CURRENT_SUB -le 119 ]] ||
     [[ "${ANDROID_VERSION}" == "android14" && "${KERNEL_VERSION}" == "6.1" && $CURRENT_SUB -le 43 ]]; then
    NEEDS_FIX=true
  fi

  if [ "$NEEDS_FIX" = true ]; then
    GLIBC_VERSION=$(ldd --version 2>/dev/null | head -n 1 | awk '{print $NF}')
    if [ "$(printf '%s\n' "2.38" "$GLIBC_VERSION" | sort -V | head -n1)" = "2.38" ]; then
      echo "应用 glibc 2.38 兼容性修复..."
      sed -i '/\$(Q)\$(MAKE) -C \$(SUBCMD_SRC) OUTPUT=\$(abspath \$(dir \$@))\/ \$(abspath \$@)/s//$(Q)$(MAKE) -C $(SUBCMD_SRC) EXTRA_CFLAGS="$(CFLAGS)" OUTPUT=$(abspath $(dir $@))\/ $(abspath $@)/' tools/bpf/resolve_btfids/Makefile 2>/dev/null || true

      if [[ "${KERNEL_VERSION}" == "5.10" || "${KERNEL_VERSION}" == "5.15" ]]; then
        sed -i '/char \*buf = NULL;/a int i;' tools/lib/subcmd/parse-options.c 2>/dev/null || true
        sed -i 's/for (int i = 0; subcommands\[i\]; i++) {/for (i = 0; subcommands[i]; i++) {/' tools/lib/subcmd/parse-options.c 2>/dev/null || true
        sed -i '/if (subcommands) {/a int i;' tools/lib/subcmd/parse-options.c 2>/dev/null || true
        sed -i 's/for (int i = 0; subcommands\[i\]; i++)/for (i = 0; subcommands[i]; i++)/' tools/lib/subcmd/parse-options.c 2>/dev/null || true
      fi
    fi
  fi

  cd "$_pwd"
}

run_fix_glibc() { stage_fix_glibc "$@"; }

stage_add_oneplus8e() {
  log_stage "add_oneplus8e" "添加一加 8E 处理器支持"
  local _pwd="$PWD"
  cd ${KERNEL_ROOT}/common/drivers
  echo "下载一加 8E 支持补丁..."
  curl -LSs "https://github.com/zzh20188/GKI_KernelSU_SUSFS/raw/refs/heads/dev/hmbird_patch.c" -o hmbird_patch.c
  echo "obj-y += hmbird_patch.o" >> Makefile

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_add_oneplus8e() {
  if [ "$SUPP_OP" = "true" ]; then
    stage_add_oneplus8e "$@"
  else
    echo "跳过阶段: add_oneplus8e（条件不满足）"
  fi
}

stage_resolve_ksu_branch() {
  log_stage "resolve_ksu_branch" "确定 KernelSU 分支"
  local _pwd="$PWD"
  variant_input="${KSU_VARIANT}"

  case "$variant_input" in
    "Official"|"ReSukiSU")
      BRANCH="-s main"
      ;;
    "SukiSU")
      if [ "${ENABLE_SUSFS}" = "false" ]; then
        BRANCH="-s main"
      else
        BRANCH="-s builtin"
      fi
      ;;
    "Next")
      BRANCH=""
      ;;
    *)
      if [ -z "$LEGACY_SUKISU_CONFIG" ] || [ ! -f "$LEGACY_SUKISU_CONFIG" ]; then
        echo "未知变体: $variant_input" >&2
        exit 1
      fi
      SUKISU_FIXED_COMMIT=$(grep "^sukisu=" "$LEGACY_SUKISU_CONFIG" | cut -d'=' -f2-)
      if [ -z "$SUKISU_FIXED_COMMIT" ]; then
        echo "未在 $LEGACY_SUKISU_CONFIG 配置 SukiSU 固定提交" >&2
        exit 1
      fi
      BRANCH="-s $SUKISU_FIXED_COMMIT"
      ;;
  esac

  # 检查自定义提交 (仅对 SukiSU 生效)
  CONFIG_FILE="config/config"
  if [ -f "$CONFIG_FILE" ]; then
    CUSTOM_ENABLED=$(grep "^custom=" "$CONFIG_FILE" | cut -d'=' -f2)
    if [ "$CUSTOM_ENABLED" == "true" ] && [ "$variant_input" == "SukiSU" ]; then
      SUKISU_COMMIT=$(grep "^sukisu=" "$CONFIG_FILE" | cut -d'=' -f2)
      if [ -n "$SUKISU_COMMIT" ]; then
        BRANCH="-s $SUKISU_COMMIT"
        echo "SukiSU 使用自定义提交: $SUKISU_COMMIT"
      fi
    fi
  fi

  export BRANCH="$BRANCH"
  echo "KSU 分支: $BRANCH"

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_resolve_ksu_branch() {
  if [ "$KSU_MODE" != "禁用KSU" ]; then
    stage_resolve_ksu_branch "$@"
  else
    echo "跳过阶段: resolve_ksu_branch（条件不满足）"
  fi
}

stage_add_kernelsu() {
  log_stage "add_kernelsu" "添加 KernelSU"
  local _pwd="$PWD"
  cd ${KERNEL_ROOT}
  case "${KSU_VARIANT}" in
    "Official")
      echo "添加 KernelSU 官方版..."
      curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash $BRANCH

      cd KernelSU
      KSU_GIT_VERSION=$(git rev-list --count HEAD)
      KSU_VERSION=$((20000 + KSU_GIT_VERSION))
      export KSU_VERSION="$KSU_VERSION"

      if [ -f "kernel/Kbuild" ]; then
        sed -i "s/DKSU_VERSION=16/DKSU_VERSION=${KSU_VERSION}/" kernel/Kbuild
      fi
      cd ..
      ;;
    "Next")
      echo "添加 KernelSU-Next..."
      curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/refs/heads/dev/kernel/setup.sh" | bash -s dev_susfs
      ;;
    "SukiSU")
      echo "添加 ${KSU_VARIANT}..."
      curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash $BRANCH
      ;;
    "ReSukiSU")
      echo "添加 ReSukiSU..."
      curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash $BRANCH
      ;;
    *)
      if [ -z "$LEGACY_SUKISU_CONFIG" ]; then
        echo "未知变体: ${KSU_VARIANT}" >&2
        exit 1
      fi
      echo "添加 ${KSU_VARIANT}..."
      curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash $BRANCH
      ;;
  esac

  if [ -d "KernelSU/.git" ]; then
    KSU_LATEST_COMMIT_DATE=$(git -C KernelSU log -1 --date=format:'%Y-%m-%d %H:%M:%S %z' --format='%cd')
    export KSU_LATEST_COMMIT_DATE="$KSU_LATEST_COMMIT_DATE"
  else
    export KSU_LATEST_COMMIT_DATE="未知"
  fi

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_add_kernelsu() {
  if [ "$KSU_MODE" != "禁用KSU" ]; then
    stage_add_kernelsu "$@"
  else
    echo "跳过阶段: add_kernelsu（条件不满足）"
  fi
}

stage_config_sukisu_manager() {
  log_stage "config_sukisu_manager" "配置 SukiSU 管理器信息"
  local _pwd="$PWD"
  cd ${KERNEL_ROOT}/KernelSU
  KBUILD_FILE="./kernel/Kbuild"
  CUSTOM_TAG="${MANAGER_STR:-}"

  if [ ! -f "$KBUILD_FILE" ]; then
    echo "未找到 $KBUILD_FILE，跳过 SukiSU 版本标识定制"
    cd "$_pwd"
    return 0
  fi

  GIT_HASH=$(git rev-parse --short=8 HEAD)
  BRANCH_NAME="${BRANCH#-s }"
  if [ -z "$BRANCH_NAME" ] || [ "$BRANCH_NAME" = "$BRANCH" ]; then
    BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  fi

  if [ -n "$CUSTOM_TAG" ]; then
    VERSION_TEMPLATE="v\$1-$CUSTOM_TAG@$BRANCH_NAME[$GIT_HASH]"
  else
    VERSION_TEMPLATE="v\$1-$GIT_HASH@$BRANCH_NAME"
  fi

  awk -v body="$VERSION_TEMPLATE" '
    BEGIN {
      in_block = 0
      replaced = 0
    }
    /^[[:space:]]*define get_ksu_version_full$/ {
      print
      print body
      in_block = 1
      replaced = 1
      next
    }
    in_block && /^[[:space:]]*endef$/ {
      print
      in_block = 0
      next
    }
    !in_block {
      print
    }
    END {
      if (!replaced) {
        exit 1
      }
    }
  ' "$KBUILD_FILE" > "${KBUILD_FILE}.tmp" && mv "${KBUILD_FILE}.tmp" "$KBUILD_FILE"

  echo "已更新 get_ksu_version_full 模板: $VERSION_TEMPLATE"

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_config_sukisu_manager() {
  if [ "$KSU_MODE" != "禁用KSU" ] && { [ "$KSU_VARIANT" = "SukiSU" ] || [ "$KSU_VARIANT" = "SukiSU(40726)" ] || [ "$KSU_VARIANT" = "SukiSU(40548)" ]; }; then
    stage_config_sukisu_manager "$@"
  else
    echo "跳过阶段: config_sukisu_manager（条件不满足）"
  fi
}

stage_susfs_baseline() {
  log_stage "susfs_baseline" "记录 SUSFS 基线快照"
  local _pwd="$PWD"
  cd ${KERNEL_ROOT}/common
  # 排除 .rej/.orig 和补丁文件本身：apply.sh 会把 SUSFS 补丁拷进 common/ 并留下 .rej
  # 从真实索引复制一份再 add，只需哈希变动文件，避免对整棵内核树重新哈希
  cp "$(git rev-parse --git-path index)" /tmp/susfs-base.idx
  export GIT_INDEX_FILE=/tmp/susfs-base.idx
  git add -A -- . ':!*.rej' ':!*.orig' ':!*.patch'
  SUSFS_BASE_TREE=$(git write-tree)
  export SUSFS_BASE_TREE="$SUSFS_BASE_TREE"
  export SUSFS_PATCH_EXPORT="true"
  echo "基线树对象: $SUSFS_BASE_TREE"

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_susfs_baseline() {
  if [ "$EXPORT_SUSFS_PATCHES" = "true" ] && [ "$ENABLE_SUSFS" = "true" ] && [ "$KSU_MODE" != "禁用KSU" ] && { [ "$KSU_VARIANT" = "SukiSU" ] || [ "$KSU_VARIANT" = "ReSukiSU" ]; }; then
    stage_susfs_baseline "$@"
  else
    echo "跳过阶段: susfs_baseline（条件不满足）"
  fi
}

stage_apply_susfs() {
  log_stage "apply_susfs" "应用 SUSFS 补丁"
  local _pwd="$PWD"
  cd ${KERNEL_ROOT}
  bash "$WORKSPACE/scripts/susfs_fixes/apply.sh"
  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_apply_susfs() {
  if [ "$ENABLE_SUSFS" = "true" ]; then
    stage_apply_susfs "$@"
  else
    echo "跳过阶段: apply_susfs（条件不满足）"
  fi
}

stage_gen_susfs_patch() {
  log_stage "gen_susfs_patch" "生成 SUSFS 集成补丁"
  local _pwd="$PWD"
  # 局部作用域，避免污染 GKI 构建系统使用的 OUT_DIR
  local OUT_DIR="${WORKSPACE}/susfs-patch"
  cd ${KERNEL_ROOT}/common
  export_susfs_patch() {
    cp /tmp/susfs-base.idx /tmp/susfs-after.idx || return 1
    export GIT_INDEX_FILE=/tmp/susfs-after.idx
    git add -A -- . ':!*.rej' ':!*.orig' ':!*.patch' || return 1
    local after_tree
    after_tree=$(git write-tree) || return 1
    unset GIT_INDEX_FILE

    mkdir -p "$OUT_DIR"
    git diff --binary "$SUSFS_BASE_TREE" "$after_tree" > "$OUT_DIR/susfs.patch" || return 1
    if [ ! -s "$OUT_DIR/susfs.patch" ]; then
      echo "补丁内容为空"
      return 1
    fi
    # 反向试打，证明补丁与当前工作树完全一致
    git apply --check -R "$OUT_DIR/susfs.patch" || return 1

    local formatted_branch gki_branch gki_commit
    formatted_branch="${ANDROID_VERSION}-${KERNEL_VERSION}-${OS_PATCH_LEVEL}"
    gki_branch="$formatted_branch"
    grep -q deprecated <<< "$REMOTE_BRANCH" && gki_branch="deprecated/$formatted_branch"
    # 分支已被上游删除时，实际检出的是发布 tag
    [ -n "$TAG_FALLBACK" ] && gki_branch="refs/tags/$TAG_FALLBACK"
    gki_commit=$(git rev-parse HEAD)

    # KSU 与 SUSFS 提交都取本次构建实际克隆的仓库，不用 ls-remote 现查
    local ksu_repo ksu_commit ksu_slug ksu_setup_cmd
    ksu_repo=$(git -C "$KERNEL_ROOT/KernelSU" remote get-url origin | sed 's/\.git$//')
    ksu_commit=$(git -C "$KERNEL_ROOT/KernelSU" rev-parse HEAD)
    ksu_slug=${ksu_repo#https://github.com/}
    ksu_setup_cmd="curl -LSs https://raw.githubusercontent.com/$ksu_slug/main/kernel/setup.sh | bash -s $ksu_commit"

    local susfs_repo susfs_branch susfs_commit
    susfs_repo=$(git -C "$SUSFS4KSU" remote get-url origin | sed 's/\.git$//')
    susfs_branch="gki-${ANDROID_VERSION}-${KERNEL_VERSION}"
    susfs_commit=$(git -C "$SUSFS4KSU" rev-parse HEAD)

    local rej_count patch_sha256
    rej_count=$(find . -type f -name '*.rej' | wc -l)
    patch_sha256=$(sha256sum "$OUT_DIR/susfs.patch" | awk '{print $1}')

    jq -n \
      --arg android_version "${ANDROID_VERSION}" \
      --arg kernel_version "${KERNEL_VERSION}" \
      --arg sub_level "${SUB_LEVEL}" \
      --arg actual_sublevel "$ACTUAL_SUBLEVEL" \
      --arg os_patch_level "${OS_PATCH_LEVEL}" \
      --arg gki_branch "$gki_branch" \
      --arg gki_commit "$gki_commit" \
      --arg ksu_variant "${KSU_VARIANT}" \
      --arg ksu_repo "$ksu_repo" \
      --arg ksu_commit "$ksu_commit" \
      --arg ksu_setup_cmd "$ksu_setup_cmd" \
      --arg susfs_repo "$susfs_repo" \
      --arg susfs_branch "$susfs_branch" \
      --arg susfs_commit "$susfs_commit" \
      --argjson rej_count "$rej_count" \
      --arg patch_sha256 "$patch_sha256" \
      --arg generated_at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
      --arg run_id "$GITHUB_RUN_ID" \
      '$ARGS.named' > "$OUT_DIR/manifest.json" || return 1

    echo "补丁大小: $(du -h "$OUT_DIR/susfs.patch" | cut -f1)，.rej 数量: $rej_count"
    cat "$OUT_DIR/manifest.json"
  }

  if ! export_susfs_patch; then
    echo "::warning::SUSFS 集成补丁导出失败，本次构建不上传补丁"
    rm -rf "$OUT_DIR"
    export SUSFS_PATCH_EXPORT="false"
  fi

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_gen_susfs_patch() {
  if [ "$SUSFS_PATCH_EXPORT" = "true" ]; then
    stage_gen_susfs_patch "$@"
  else
    echo "跳过阶段: gen_susfs_patch（条件不满足）"
  fi
}

stage_clone_droidspaces() {
  log_stage "clone_droidspaces" "克隆 Droidspaces 补丁仓库"
  local _pwd="$PWD"
  git clone --depth 1 https://github.com/ravindu644/Droidspaces-OSS.git /tmp/Droidspaces-OSS
  export DROIDSPACES_PATCHES="/tmp/Droidspaces-OSS/Documentation/resources/kernel-patches/GKI"

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_clone_droidspaces() {
  if [ "$DROIDSPACES" != "不启用" ]; then
    stage_clone_droidspaces "$@"
  else
    echo "跳过阶段: clone_droidspaces（条件不满足）"
  fi
}

stage_backup_defconfig() {
  log_stage "backup_defconfig" "备份基准 defconfig"
  local _pwd="$PWD"
  cp "$DEFCONFIG" "$DEFCONFIG.orig"
  cd "$_pwd"
}

run_backup_defconfig() { stage_backup_defconfig "$@"; }

stage_integrate_droidspaces() {
  log_stage "integrate_droidspaces" "集成 Droidspaces 支持"
  local _pwd="$PWD"
  cd ${KERNEL_ROOT}/common
  KERNEL_VER="${KERNEL_VERSION}"
  SLOT="${DROIDSPACES}"

  # 678 -> 6_7_8, 123 -> 1_2_3, 345 -> 3_4_5
  SLOT_NAME=$(echo "$SLOT" | sed 's/\(.\)/\1_/g; s/_$//')
  echo "应用 Droidspaces SYSVIPC kABI 修复补丁 (槽位: $SLOT / $SLOT_NAME)..."
  case "$KERNEL_VER" in
    6.12)
      PATCH_FILE="$DROIDSPACES_PATCHES/kernel-6.12/001.GKI-6.12-or-above-fix_sysvipc_kabi.patch"
      ;;
    5.10|5.15|6.1|6.6)
      PATCH_FILE="$DROIDSPACES_PATCHES/below-kernel-6.12/001.GKI-below-6.12-fix_sysvipc_kabi_${SLOT_NAME}.patch"
      ;;
    *)
      echo "::warning::Droidspaces: 未适配的内核版本 $KERNEL_VER，跳过补丁"
      cd "$_pwd"
      return 0
      ;;
  esac
  if ! patch -p1 --forward < "$PATCH_FILE"; then
    echo "::warning::SYSVIPC kABI 补丁应用失败，可能已应用或上下文不匹配"
  fi

  # 5.10 及以下还需要 POSIX_MQUEUE 的 kABI 修复
  if [ "$KERNEL_VER" = "5.10" ]; then
    echo "应用 Droidspaces POSIX_MQUEUE kABI 修复补丁 (5.10)..."
    POSIX_PATCH="$DROIDSPACES_PATCHES/below-kernel-6.12/002.5.10_or_lower_use_android_abi_padding_for_posix_mqueue.patch"
    if ! patch -p1 --forward < "$POSIX_PATCH"; then
      echo "::warning::POSIX_MQUEUE kABI 补丁应用失败，可能已应用或上下文不匹配"
    fi
  fi

  # Android 16 / 6.12 的 rust_binder.ko 在启用 IPC_NS 后会引用
  # init_ipc_ns 与 put_ipc_ns，但当前 AOSP common 分支尚未导出这两个符号。
  # 这里补齐导出，避免 modpost 因 undefined symbol 失败。
  if [ "$KERNEL_VER" = "6.12" ]; then
    if [ -f "ipc/msgutil.c" ] && ! grep -qF 'EXPORT_SYMBOL(init_ipc_ns);' "ipc/msgutil.c"; then
      sed -i '/^struct msg_msgseg {/i EXPORT_SYMBOL(init_ipc_ns);' "ipc/msgutil.c"
      echo "已为 init_ipc_ns 补充符号导出"
    fi

    if [ -f "ipc/namespace.c" ] && ! grep -qF 'EXPORT_SYMBOL(put_ipc_ns);' "ipc/namespace.c"; then
      sed -i '/^static struct ns_common \*ipcns_get(/i EXPORT_SYMBOL(put_ipc_ns);' "ipc/namespace.c"
      echo "已为 put_ipc_ns 补充符号导出"
    fi
  fi

  echo "添加 Droidspaces 内核配置..."
  # 按文档规则逐个处理: 已启用则跳过, "# not set" 则替换, 不存在则追加
  enable_config() {
    local cfg="$1"
    if grep -q "^${cfg}=y" "$DEFCONFIG"; then
      echo "  已启用: $cfg"
    elif grep -q "^# ${cfg} is not set" "$DEFCONFIG"; then
      sed -i "s/^# ${cfg} is not set$/${cfg}=y/" "$DEFCONFIG"
      echo "  已切换: $cfg"
    else
      echo "${cfg}=y" >> "$DEFCONFIG"
      echo "  已添加: $cfg"
    fi
  }

  config_defined() {
    local name="${1#CONFIG_}"
    grep -RqsE --include='Kconfig*' "^[[:space:]]*(menuconfig|config)[[:space:]]+${name}$" .
  }

  enable_config_if_defined() {
    local cfg="$1"
    if config_defined "$cfg"; then
      enable_config "$cfg"
    else
      echo "  当前内核未定义: $cfg，跳过"
    fi
  }

  # 必要配置
  enable_config CONFIG_SYSVIPC
  enable_config CONFIG_POSIX_MQUEUE
  enable_config CONFIG_IPC_NS
  enable_config CONFIG_PID_NS
  enable_config CONFIG_DEVTMPFS

  # 用户命名空间：上游文档列为可选但推荐，用于修复 docker unsafe procfs 报错。
  # init/Kconfig 中无 depends on，且 struct cred 的 user_ns/ucounts 是无条件成员，
  # task_struct 等结构体不含 CONFIG_USER_NS 条件编译，因此不影响 kABI 布局，
  # 不需要像 SYSVIPC/IPC_NS 那样额外打 padding 补丁。与 wild_kernel 保持一致，全版本启用。
  enable_config CONFIG_USER_NS

  # 可选: 网络相关配置 (Docker/NAT 模式)
  enable_config_if_defined CONFIG_NETFILTER_XT_MATCH_ADDRTYPE
  enable_config_if_defined CONFIG_NETFILTER_XT_TARGET_LOG
  enable_config_if_defined CONFIG_NETFILTER_XT_MATCH_RECENT
  enable_config_if_defined CONFIG_IP_SET
  enable_config_if_defined CONFIG_IP_SET_HASH_IP
  enable_config_if_defined CONFIG_IP_SET_HASH_NET
  enable_config_if_defined CONFIG_NETFILTER_XT_SET

  # REJECT 目标在不同内核版本上的符号名可能不同，按实际存在的配置启用
  enable_config_if_defined CONFIG_NETFILTER_XT_TARGET_REJECT
  enable_config_if_defined CONFIG_IP_NF_TARGET_REJECT

  echo "Droidspaces 集成完成"

  echo "GKI6.6 普通用户联网专用配置 (Droidspaces)"
  # 专门处理 =n 类型的配置（安卓网络权限必须关闭）
  disable_config() {
    local cfg="$1"
    if grep -q "^${cfg}=n" "$DEFCONFIG"; then
      echo "  已禁用: $cfg"
    elif grep -q "^${cfg}=y" "$DEFCONFIG"; then
      sed -i "s/^${cfg}=y$/${cfg}=n/" "$DEFCONFIG"
      echo "  已关闭: $cfg"
    else
      echo "# ${cfg} is not set" >> "$DEFCONFIG"
      echo "  已添加并禁用: $cfg"
    fi
  }

  if [[ "${ANDROID_VERSION}" == "android15" && "${KERNEL_VERSION}" == "6.6" ]]; then
    # 关闭安卓严格网络控制，否则容器内普通用户无法联网
    disable_config CONFIG_ANDROID_PARANOID_NETWORK
  fi

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_integrate_droidspaces() {
  if [ "$DROIDSPACES" != "不启用" ]; then
    stage_integrate_droidspaces "$@"
  else
    echo "跳过阶段: integrate_droidspaces（条件不满足）"
  fi
}

stage_inject_ntsync() {
  log_stage "inject_ntsync" "注入 NTSync 内核配置"
  local _pwd="$PWD"
  cd ${KERNEL_ROOT}/common
  set -e
  echo "=== 开始注入 NTSync 内核补丁 ==="
  echo "Android 版本: ${ANDROID_VERSION}"
  echo "Kernel 版本: ${KERNEL_VERSION}"

  case "${ANDROID_VERSION}-${KERNEL_VERSION}" in
    android12-5.10)
      NTSYNC_PATCH="ntsync_compat_android12-5.10"
      ;;
    android13-5.15)
      NTSYNC_PATCH="ntsync_compat_android13-5.15"
      ;;
    android14-6.1)
      NTSYNC_PATCH="ntsync_compat_android14-6.1"
      ;;
    android15-6.6)
      NTSYNC_PATCH="ntsync_compat_android15-6.6"
      ;;
    android16-6.12)
      NTSYNC_PATCH="ntsync_compat_android16-6.12"
      ;;
    *)
      echo "::warning::NTSync: 未适配 ${ANDROID_VERSION} / ${KERNEL_VERSION}，跳过补丁"
      cd "$_pwd"
      return 0
      ;;
  esac

  echo "自动选择 NTSync 补丁: ${NTSYNC_PATCH}.patch"
  wget -q "https://raw.githubusercontent.com/Goldzxcbug/Droidspaces_Kernel_patch/refs/heads/main/NTsync/ntsync_base.patch"
  wget -q "https://raw.githubusercontent.com/Goldzxcbug/Droidspaces_Kernel_patch/refs/heads/main/NTsync/${NTSYNC_PATCH}.patch"

  patch -p1 < "ntsync_base.patch"
  patch -p1 < "${NTSYNC_PATCH}.patch"

  cd ..

  # 配置路径
  CONFIG_PATH="./common/arch/arm64/configs/gki_defconfig"
  echo "正在检查并启用 CONFIG_NTSYNC..."

  # 移除未启用标记，再追加启用项，保证重复运行时保持幂等。
  sed -i '/CONFIG_NTSYNC is not set/d' "$CONFIG_PATH"
  if ! grep -q "^CONFIG_NTSYNC=y" "$CONFIG_PATH"; then
    echo "CONFIG_NTSYNC=y" >> "$CONFIG_PATH"
    echo "✅ 已成功启用 CONFIG_NTSYNC"
  else
    echo "✅ CONFIG_NTSYNC 已处于启用状态"
  fi

  echo "=== NTSync 补丁与配置注入完成 ==="

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_inject_ntsync() {
  if [ "$DROIDSPACES" != "不启用" ] && [ "$DROIDSPACES_NTSYNC" = "true" ]; then
    stage_inject_ntsync "$@"
  else
    echo "跳过阶段: inject_ntsync（条件不满足）"
  fi
}

stage_apply_unicode_fix() {
  log_stage "apply_unicode_fix" "应用 Unicode 绕过修复"
  local _pwd="$PWD"
  cd ${KERNEL_ROOT}/common
  if [ "${KERNEL_VERSION}" = "5.10" ] || [ "${KERNEL_VERSION}" = "5.15" ]; then
    patch -p1 --forward < "$ACTION_BUILD/patches/unicode_bypass_fix_6.1-.patch" || true
  else
    patch -p1 --forward < "$ACTION_BUILD/patches/unicode_bypass_fix_6.1+.patch" || true
  fi

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_apply_unicode_fix() {
  if [ "$ENABLE_SUSFS" = "true" ]; then
    stage_apply_unicode_fix "$@"
  else
    echo "跳过阶段: apply_unicode_fix（条件不满足）"
  fi
}

stage_setup_zram_lz4() {
  log_stage "setup_zram_lz4" "配置 ZRAM LZ4 补丁栈"
  local _pwd="$PWD"
  cd ${KERNEL_ROOT}/common
  echo "升级 LZ4..."
  rm -f lib/lz4/lz4_compress.c lib/lz4/lz4_decompress.c lib/lz4/lz4defs.h lib/lz4/lz4hc_compress.c

  cp -r $ZZH_PATCHES/zram/lz4/* ./lib/lz4/
  cp -r $ZZH_PATCHES/zram/include/linux/* ./include/linux/
  bash $ZZH_PATCHES/zram/apply_lz4_neon.sh

  if [ -f "fs/f2fs/Makefile" ] && ! grep -qF "f2fs-\$(CONFIG_F2FS_IOSTAT) += iostat.o" "fs/f2fs/Makefile"; then
    echo "f2fs-\$(CONFIG_F2FS_IOSTAT) += iostat.o" >> "fs/f2fs/Makefile"
  fi

  cp -r $SUKISU_PATCHES/other/zram/lz4k/include/linux/* ./include/linux/
  cp -r $SUKISU_PATCHES/other/zram/lz4k/lib/* ./lib/
  cp -r $SUKISU_PATCHES/other/zram/lz4k/crypto/* ./crypto/
  cp -r $SUKISU_PATCHES/other/zram/lz4k_oplus ./lib/

  cp $SUKISU_PATCHES/other/zram/zram_patch/${KERNEL_VERSION}/lz4kd.patch ./
  if ! patch -p1 -F 3 < lz4kd.patch; then
    echo "::warning::lz4kd.patch 应用失败，可能已应用或上下文不匹配"
  fi

  cp $SUKISU_PATCHES/other/zram/zram_patch/${KERNEL_VERSION}/lz4k_oplus.patch ./
  if ! patch -p1 -F 3 < lz4k_oplus.patch; then
    echo "::warning::lz4k_oplus.patch 应用失败，可能已应用或上下文不匹配"
  fi

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_setup_zram_lz4() {
  if [ "$USE_ZRAM" = "true" ]; then
    stage_setup_zram_lz4 "$@"
  else
    echo "跳过阶段: setup_zram_lz4（条件不满足）"
  fi
}

stage_fix_66_wifi_bt() {
  log_stage "fix_66_wifi_bt" "修复 6.6 WiFi/蓝牙兼容性（三星 + 小米）"
  local _pwd="$PWD"
  cd ${KERNEL_ROOT}/common
  ensure_line_once() {
    local file="$1"
    local line="$2"
    if [ ! -f "$file" ]; then
      echo "::error::文件不存在: $file"
      exit 1
    fi
    if ! grep -qF "$line" "$file"; then
      echo "$line" >> "$file"
    fi
  }

  GALAXY_SYMBOL_LIST="android/abi_gki_aarch64_galaxy"
  XIAOMI_SYMBOL_LIST="android/abi_gki_aarch64_xiaomi"
  DRIVERS_MAKEFILE="drivers/Makefile"
  MIN_KDP_SRC="$KERNEL_PATCHES/samsung/min_kdp/min_kdp.c"
  MIN_KDP_PATCH="$KERNEL_PATCHES/samsung/min_kdp/add-min_kdp-symbols.patch"
  MIN_KDP_DST="drivers/min_kdp.c"

  ensure_line_once "$GALAXY_SYMBOL_LIST" "kdp_set_cred_non_rcu"
  ensure_line_once "$GALAXY_SYMBOL_LIST" "kdp_usecount_dec_and_test"
  ensure_line_once "$GALAXY_SYMBOL_LIST" "kdp_usecount_inc"

  if [ ! -f "$MIN_KDP_PATCH" ]; then
    echo "::error::补丁不存在: $MIN_KDP_PATCH"
    exit 1
  fi
  if patch -p1 --dry-run < "$MIN_KDP_PATCH" >/dev/null 2>&1; then
    patch -p1 --no-backup-if-mismatch < "$MIN_KDP_PATCH"
  else
    echo "min_kdp symbols patch 已应用或当前上下文不匹配，跳过。"
  fi

  if [ ! -f "$MIN_KDP_SRC" ]; then
    echo "::error::文件不存在: $MIN_KDP_SRC"
    exit 1
  fi
  cp "$MIN_KDP_SRC" "$MIN_KDP_DST"
  ensure_line_once "$DRIVERS_MAKEFILE" "obj-y += min_kdp.o"

  ensure_line_once "$XIAOMI_SYMBOL_LIST" "device_find_any_child"

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_fix_66_wifi_bt() {
  if [ "$KERNEL_VERSION" = "6.6" ]; then
    stage_fix_66_wifi_bt "$@"
  else
    echo "跳过阶段: fix_66_wifi_bt（条件不满足）"
  fi
}

stage_config_zram() {
  log_stage "config_zram" "配置 ZRAM 选项"
  local _pwd="$PWD"
  CONFIG_FILE="$DEFCONFIG"

  if [ "${KERNEL_VERSION}" = "5.10" ]; then
    cat >> "$CONFIG_FILE" <<'EOF'
CONFIG_ZSMALLOC=y
CONFIG_ZRAM=y
CONFIG_MODULE_SIG=n
CONFIG_CRYPTO_LZO=y
CONFIG_ZRAM_DEF_COMP_LZ4KD=y
EOF
  fi

  if [ "${KERNEL_VERSION}" != "6.6" ] && [ "${KERNEL_VERSION}" != "5.10" ]; then
    if grep -q "CONFIG_ZSMALLOC" "$CONFIG_FILE"; then
      sed -i 's/CONFIG_ZSMALLOC=m/CONFIG_ZSMALLOC=y/g' "$CONFIG_FILE"
    else
      echo "CONFIG_ZSMALLOC=y" >> "$CONFIG_FILE"
    fi
    sed -i 's/CONFIG_ZRAM=m/CONFIG_ZRAM=y/g' "$CONFIG_FILE"
  fi

  if [ "${KERNEL_VERSION}" = "6.6" ]; then
    echo "CONFIG_ZSMALLOC=y" >> "$CONFIG_FILE"
    sed -i 's/CONFIG_ZRAM=m/CONFIG_ZRAM=y/g' "$CONFIG_FILE"
  fi

  if [ "${ANDROID_VERSION}" = "android14" ] || [ "${ANDROID_VERSION}" = "android15" ]; then
    sed -i 's/"drivers\/block\/zram\/zram\.ko",//g; s/"mm\/zsmalloc\.ko",//g' "$KERNEL_ROOT/common/modules.bzl"
  fi

  if grep -q "CONFIG_ZSMALLOC=y" "$CONFIG_FILE" && grep -q "CONFIG_ZRAM=y" "$CONFIG_FILE"; then
    cat "$ZZH_PATCHES/config/zram.config" >> "$CONFIG_FILE"
  fi

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_config_zram() {
  if [ "$USE_ZRAM" = "true" ]; then
    stage_config_zram "$@"
  else
    echo "跳过阶段: config_zram（条件不满足）"
  fi
}

stage_add_bbg() {
  log_stage "add_bbg" "添加 BBG 防格机补丁"
  local _pwd="$PWD"
  cd ${KERNEL_ROOT}
  wget -O- https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash
  echo "CONFIG_BBG=y" >> common/arch/arm64/configs/gki_defconfig
  sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' common/security/Kconfig

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_add_bbg() {
  if [ "$USE_BBG" = "true" ]; then
    stage_add_bbg "$@"
  else
    echo "跳过阶段: add_bbg（条件不满足）"
  fi
}

stage_apply_rekernel() {
  log_stage "apply_rekernel" "应用 Re-Kernel"
  local _pwd="$PWD"
  cd ${KERNEL_ROOT}
  set -e
  echo "Integrating Re-Kernel..."
  TMP_REKERNEL=/tmp/rekernel
  rm -rf "$TMP_REKERNEL"
  git clone --depth 1 https://github.com/Sakion-Team/Re-Kernel.git "$TMP_REKERNEL"

  # 同步上游拆分后的完整驱动源码
  rm -rf common/drivers/rekernel
  mkdir -p common/drivers/rekernel
  cp -a "$TMP_REKERNEL/LKM-Source/." common/drivers/rekernel/

  # 将上游外置模块配置适配为内核内置驱动
  REKERNEL_MAKEFILE="common/drivers/rekernel/Makefile"
  sed -i 's/^obj-m := rekernel\.o$/obj-$(CONFIG_REKERNEL) += rekernel.o/' "$REKERNEL_MAKEFILE"
  grep -qF 'ccflags-$(CONFIG_REKERNEL_LEGACY_NETLINK) += -DLEGACY_NETLINK' "$REKERNEL_MAKEFILE" || \
    echo 'ccflags-$(CONFIG_REKERNEL_LEGACY_NETLINK) += -DLEGACY_NETLINK' >> "$REKERNEL_MAKEFILE"
  sed -i '/^[[:space:]]*depends on MODULES[[:space:]]*$/d' common/drivers/rekernel/Kconfig

  # 挂载到驱动树
  if ! grep -qF 'source "drivers/rekernel/Kconfig"' common/drivers/Kconfig; then
    sed -i '/^endmenu$/i source "drivers/rekernel/Kconfig"' common/drivers/Kconfig
  fi
  if ! grep -qF 'obj-$(CONFIG_REKERNEL) += rekernel/' common/drivers/Makefile; then
    echo 'obj-$(CONFIG_REKERNEL) += rekernel/' >> common/drivers/Makefile
  fi

  # 修正头文件包含路径（适配 in-tree 编译）
  sed -i 's|#include <../android/binder_internal.h>|#include "../android/binder_internal.h"|g' common/drivers/rekernel/rekernel_binder.c
  # 补齐 5.10 binder_internal.h 使用 DEFINE_SHOW_ATTRIBUTE 所需的定义
  grep -qF '#include <linux/seq_file.h>' common/drivers/rekernel/rekernel_binder.c || \
    sed -i '/#include <linux\/kprobes.h>/a #include <linux/seq_file.h>' common/drivers/rekernel/rekernel_binder.c

  # 配置 defconfig（幂等）
  grep -q '^CONFIG_REKERNEL=y$' "$DEFCONFIG" || echo "CONFIG_REKERNEL=y" >> "$DEFCONFIG"
  grep -q '^CONFIG_REKERNEL_NETWORK=y$' "$DEFCONFIG" || echo "CONFIG_REKERNEL_NETWORK=y" >> "$DEFCONFIG"

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_apply_rekernel() {
  if [ "$USE_REKERNEL" = "true" ]; then
    stage_apply_rekernel "$@"
  else
    echo "跳过阶段: apply_rekernel（条件不满足）"
  fi
}

stage_config_kernel() {
  log_stage "config_kernel" "配置内核选项"
  local _pwd="$PWD"
  cd ${KERNEL_ROOT}
  cat >> "$DEFCONFIG" << 'EOF'
CONFIG_TMPFS_XATTR=y
CONFIG_TMPFS_POSIX_ACL=y
EOF

  # 禁用KSU 时源码里没有 KernelSU，CONFIG_KSU 不存在，写入会被 bazel 的 defconfig 检查拒绝
  if [ "${KSU_MODE}" != "禁用KSU" ]; then
    echo "CONFIG_KSU=y" >> "$DEFCONFIG"
  fi

  if [ "${KSU_MODE}" != "禁用KSU" ] && { [ "${KSU_VARIANT}" == "SukiSU" ] || [ "${KSU_VARIANT}" == "SukiSU(40726)" ] || [ "${KSU_VARIANT}" == "SukiSU(40548)" ] || [ "${KSU_VARIANT}" == "ReSukiSU" ] || [ "${KSU_VARIANT}" == "Next" ]; }; then
    if [[ "${USE_KPM}" == enabled* ]] || [[ "${USE_KPM}" == patched* ]]; then
      if ! grep -RqsE '^[[:space:]]*config[[:space:]]+KPM([[:space:]]|$)' common KernelSU 2>/dev/null; then
        echo "错误: 已请求启用 KPM，但当前 KernelSU 代码未声明 CONFIG_KPM" >&2
        exit 1
      fi
      echo "CONFIG_KPM=y" >> "$DEFCONFIG"
    fi
  fi

  CURRENT_SUB="${SUB_LEVEL}"
  if [[ ! "$CURRENT_SUB" =~ ^[0-9]+$ ]]; then
    CURRENT_SUB=99999
  fi
  if [[ "${KSU_VARIANT}" == "ReSukiSU" && "${ANDROID_VERSION}" == "android13" && "${KERNEL_VERSION}" == "5.15" && "$CURRENT_SUB" -ge 74 && "$CURRENT_SUB" -le 137 ]]; then
    {
      echo "CONFIG_KALLSYMS=y"
      echo "CONFIG_KALLSYMS_ALL=y"
    } >> "$DEFCONFIG"
    # 修复 5.15.74~5.15.137: kallsyms_on_each_symbol 仅在 LIVEPATCH 下编译，导致 ReSukiSU 链接失败
    KALLSYMS_C="./common/kernel/kallsyms.c"
    if [ -f "$KALLSYMS_C" ] \
      && grep -qF 'int kallsyms_on_each_symbol' "$KALLSYMS_C" \
      && grep -qF '#endif /* CONFIG_LIVEPATCH */' "$KALLSYMS_C"; then
      sed -i '/^#ifdef CONFIG_LIVEPATCH$/,/^int kallsyms_on_each_symbol/ { /^#ifdef CONFIG_LIVEPATCH$/d }' "$KALLSYMS_C"
      sed -i '/^int kallsyms_on_each_symbol/,/^#endif \/\* CONFIG_LIVEPATCH \*\// { /^#endif \/\* CONFIG_LIVEPATCH \*\//d }' "$KALLSYMS_C"
      echo "已修复 kallsyms_on_each_symbol 的 LIVEPATCH 编译限制"
    fi
  fi

  sed -i 's/check_defconfig//' ./common/build.config.gki


  # [融合] BBR 拥塞控制 —— 取自 ShirkNeko/GKI_KernelSU_SUSFS
  if [ "${USE_BBR}" = "true" ]; then
    echo "启用 BBR 拥塞控制"
    if grep -q '^CONFIG_TCP_CONG_BBR=' "$DEFCONFIG"; then
      sed -i 's/^CONFIG_TCP_CONG_BBR=.*/CONFIG_TCP_CONG_BBR=y/' "$DEFCONFIG"
    else
      echo "CONFIG_TCP_CONG_BBR=y" >> "$DEFCONFIG"
    fi
    if grep -q '^CONFIG_DEFAULT_BBR=' "$DEFCONFIG"; then
      sed -i 's/^CONFIG_DEFAULT_BBR=.*/CONFIG_DEFAULT_BBR=y/' "$DEFCONFIG"
    else
      echo "CONFIG_DEFAULT_BBR=y" >> "$DEFCONFIG"
    fi
  fi

  cd "$_pwd"
}

run_config_kernel() { stage_config_kernel "$@"; }

stage_config_susfs() {
  log_stage "config_susfs" "添加 SUSFS 配置"
  local _pwd="$PWD"
  LINES_BEFORE=$(wc -l < "$DEFCONFIG")
  cat >> "$DEFCONFIG" << 'EOF'
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_KSU_SUSFS_SUS_MAP=y
EOF

  # 把本步实际追加的行导出为配置片段，随 SUSFS 集成补丁一起分发
  if [ "$SUSFS_PATCH_EXPORT" = "true" ] && [ -d "$WORKSPACE/susfs-patch" ]; then
    tail -n +$((LINES_BEFORE + 1)) "$DEFCONFIG" > "$WORKSPACE/susfs-patch/susfs.config"
    echo "已导出 SUSFS 配置片段: $(wc -l < "$WORKSPACE/susfs-patch/susfs.config") 行"
  fi

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_config_susfs() {
  if [ "$ENABLE_SUSFS" = "true" ]; then
    stage_config_susfs "$@"
  else
    echo "跳过阶段: config_susfs（条件不满足）"
  fi
}

stage_config_kernel_name() {
  log_stage "config_kernel_name" "配置内核名称"
  local _pwd="$PWD"
  cd ${KERNEL_ROOT}
  if [ -f "build/build.sh" ]; then
    sed -i 's/-dirty//' ./common/scripts/setlocalversion
  else
    sed -i '/^[[:space:]]*"protected_exports_list"[[:space:]]*:[[:space:]]*"android\/abi_gki_protected_exports_aarch64",$/d' ./common/BUILD.bazel
    sed -i '/kmi_symbol_list_strict_mode/d' ./common/BUILD.bazel
    rm -rf ./common/android/abi_gki_protected_exports_*
    sed -i "/stable_scmversion_cmd/s/-maybe-dirty//g" ./build/kernel/kleaf/impl/stamp.bzl
  fi

  VERSION_INPUT=$(echo "${VERSION}" | tr -d '[:space:]')
  if [ -n "$VERSION_INPUT" ]; then
    CLEAN_VERSION=$(echo "$VERSION_INPUT" | sed -E 's/^[0-9]+\.[0-9]+\.[0-9]+//')
    perl -i -0777 -pe 's/(.*)echo "\$\{KERNELVERSION\}\$\{file_localversion\}\$\{config_localversion\}\$\{LOCALVERSION\}\$\{scm_version\}"/$1echo "\$\{KERNELVERSION\}'"${CLEAN_VERSION}"'"/s' ./common/scripts/setlocalversion 2>/dev/null || true
    sed -i "\$s|echo \"\$res\"|echo \"${CLEAN_VERSION}\"|" ./common/scripts/setlocalversion 2>/dev/null || true
    sed -i '/^CONFIG_LOCALVERSION=/ s/="\([^"]*\)"/="'"$CLEAN_VERSION"'"/' ./common/arch/arm64/configs/gki_defconfig
  elif [ ! -f "build/build.sh" ]; then
    cd ./common
    BID="ab$((RANDOM % 90000000 + 10000000))"
    GHASH=$(git rev-parse --verify HEAD | cut -c1-13)
    case "${ANDROID_VERSION}-${KERNEL_VERSION}" in
      "android14-6.1")  KMI_TAG="android14-11" ;;
      "android15-6.6")  KMI_TAG="android15-8" ;;
      "android16-6.12") KMI_TAG="android16-5" ;;
      *) KMI_TAG="${ANDROID_VERSION}" ;;
    esac

    if [ "${KERNEL_VERSION}" = "6.1" ]; then
      KMI_LOCAL="-${KMI_TAG}-g${GHASH}-${BID}-4k"
      sed -i "\$s|echo \"\$res\"|echo \"${KMI_LOCAL}\"|" ./scripts/setlocalversion 2>/dev/null || true
      sed -i "/^CONFIG_LOCALVERSION=/ s/=\"[^\"]*\"/=\"${KMI_LOCAL}\"/" ./arch/arm64/configs/gki_defconfig 2>/dev/null || true
    else
      SUFFIX="-${KMI_TAG}-g${GHASH}-${BID}"
      perl -i -0777 -pe 's/(.*)echo "\$\{KERNELVERSION\}\$\{file_localversion\}\$\{config_localversion\}\$\{LOCALVERSION\}\$\{scm_version\}"/$1echo "\$\{KERNELVERSION\}'"${SUFFIX}"'\$\{config_localversion\}"/s' ./scripts/setlocalversion 2>/dev/null || true
    fi
  fi

  cd "$_pwd"
}

run_config_kernel_name() { stage_config_kernel_name "$@"; }

stage_set_build_time() {
  log_stage "set_build_time" "设置自定义构建时间"
  local _pwd="$PWD"
  set -euo pipefail

  local input_time="${BUILD_TIME:-}"
  if [[ -n "$input_time" && "$input_time" != "N" && "$input_time" != "n" ]]; then
    TIME_REGEX='^(Mon|Tue|Wed|Thu|Fri|Sat|Sun) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) (0[1-9]|[12][0-9]|3[01]) ([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9] UTC [0-9]{4}$'
    if [[ ! "$input_time" =~ $TIME_REGEX ]]; then
      echo "::error title=构建时间格式错误::自定义构建时间必须形如 Sun Dec 01 08:10:00 UTC 2024，请删除多余前缀并使用两位日期。"
      return 1
    fi

    NORMALIZED_TIME="$(LC_ALL=C TZ=UTC date -u -d "$input_time" +'%a %b %d %T UTC %Y' 2>/dev/null || true)"
    if [[ "$NORMALIZED_TIME" != "$input_time" ]]; then
      echo "::error title=构建时间无效::自定义构建时间无法解析为真实 UTC 时间，或星期与日期不匹配。"
      return 1
    fi

    DATESTR="$input_time"
  else
    DATESTR="$(TZ='UTC' date +'%a %b %d %T %Z %Y')"
  fi

  echo "使用构建时间: $DATESTR"
  export KBUILD_BUILD_TIMESTAMP="$DATESTR"
  export KBUILD_BUILD_VERSION="1"

  # 统一处理 mkcompile_h 补丁
  f="$KERNEL_ROOT/common/scripts/mkcompile_h"
  if [ -f "$f" ]; then
    if [[ "${KERNEL_VERSION}" == "5.10" || "${KERNEL_VERSION}" == "5.15" ]]; then
      echo "应用 5.x 经典时间戳补丁: $f"
      perl -pi -e "s{UTS_VERSION=\"\\\$\(echo \\\$UTS_VERSION \\\$CONFIG_FLAGS \\\$TIMESTAMP \\| cut -b -\\\$UTS_LEN\)\"}{UTS_VERSION=\"#1 SMP PREEMPT $DATESTR\"}" "$f"
    else
      echo "应用 6.x mkcompile_h 补丁: $f"
      if grep -q 'UTS_VERSION=' "$f"; then
        perl -pi -e "s{UTS_VERSION=\"\\\$\\\(.*?\\\)\"}{UTS_VERSION=\"#1 SMP PREEMPT $DATESTR\"}" "$f"
      else
        perl -0777 -pi -e "s{cat <<EOF}{cat <<EOF\n#undef UTS_VERSION\n#define UTS_VERSION \"#1 SMP PREEMPT $DATESTR\" } unless /UTS_VERSION/" "$f"
    fi
  fi
fi

  cd "$_pwd"
}

run_set_build_time() { stage_set_build_time "$@"; }

compile_kernel_once() {
  local _pwd="$PWD"
  LOG_DIR="$WORKSPACE/build-logs"
  ATTEMPT_FILE="$LOG_DIR/.compile-attempt"
  mkdir -p "$LOG_DIR"

  # 为 retry 的每次执行生成独立日志
  ATTEMPT=1
  if [ -s "$ATTEMPT_FILE" ]; then
    read -r LAST_ATTEMPT < "$ATTEMPT_FILE"
    if [[ "$LAST_ATTEMPT" =~ ^[0-9]+$ ]]; then
      ATTEMPT=$((LAST_ATTEMPT + 1))
    fi
  fi
  echo "$ATTEMPT" > "$ATTEMPT_FILE"
  LOG_FILE="$LOG_DIR/compile-attempt-${ATTEMPT}.log"

  set -o pipefail
  {
    echo "编译尝试: $ATTEMPT"
    echo "开始时间: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "当前 KSU 最新提交日期: ${KSU_LATEST_COMMIT_DATE}"
    echo "当前 SUSFS 最新提交日期: ${SUSFS_LATEST_COMMIT_DATE}"
    set -ex
    cd "$KERNEL_ROOT"

    sed -i 's/BUILD_SYSTEM_DLKM=1/BUILD_SYSTEM_DLKM=0/' ./common/build.config.gki.aarch64
    sed -i '/MODULES_ORDER=android\/gki_aarch64_modules/d' ./common/build.config.gki.aarch64
    sed -i '/KMI_SYMBOL_LIST_STRICT_MODE/d' ./common/build.config.gki.aarch64

    if [ -f "build/build.sh" ]; then
      # 显式钉住输出目录：GKI 的 build/build.sh 会把 OUT_DIR / DIST_DIR 当作外部环境继承，
      # 一旦外层存在同名变量（哪怕只是补丁导出用的临时目录），产物就会落到预期之外的位置。
      OUT_DIR="$KERNEL_ROOT/out/${ANDROID_VERSION}-${KERNEL_VERSION}" \
      DIST_DIR="$KERNEL_ROOT/out/${ANDROID_VERSION}-${KERNEL_VERSION}/dist" \
      LTO=thin \
      BUILD_CONFIG=common/build.config.gki.aarch64 \
      build/build.sh CC="/usr/bin/ccache clang" || {
        echo "::error::build.sh 返回非零，列出实际产出以便定位"
        find "$KERNEL_ROOT/out" -maxdepth 3 -name Image -o -maxdepth 3 -name Image.lz4 2>/dev/null | head
        exit 1
      }
      strings "out/${ANDROID_VERSION}-${KERNEL_VERSION}/dist/Image" | grep 'Linux version'
    else
      # 提取 gki_defconfig 修改到 fragment，避免 bazel trim 检查失败
      FRAG="common/arch/arm64/configs/ksu.fragment"
      diff "$DEFCONFIG.orig" "$DEFCONFIG" | grep '^>' | sed 's/^> //; s/^[[:space:]]*//' > "$FRAG" || true
      cp "$DEFCONFIG.orig" "$DEFCONFIG"
      echo "=== KSU Fragment 内容 ==="
      cat "$FRAG"
      echo "========================="
      FRAG_FLAG=""
      if [ -s "$FRAG" ]; then
        FRAG_FLAG="--defconfig_fragment=//common:arch/arm64/configs/ksu.fragment"
      fi
      LTO_FLAG="--lto=thin"
      if [ "${KERNEL_VERSION}" = "6.12" ]; then
        LTO_FLAG="--lto=none"
      fi
      tools/bazel build --disk_cache=/home/runner/.cache/bazel --config=fast $LTO_FLAG $FRAG_FLAG //common:kernel_aarch64_dist || exit 1
      strings ./bazel-bin/common/kernel_aarch64/Image | grep 'Linux version'
    fi

    echo "当前 KSU 最新提交日期: ${KSU_LATEST_COMMIT_DATE}"
    echo "当前 SUSFS 最新提交日期: ${SUSFS_LATEST_COMMIT_DATE}"
    echo "如果日期不同或相差过远则补丁失效、编译失败"
  } 2>&1 | tee "$LOG_FILE"

  BUILD_STATUS=${PIPESTATUS[0]}
  {
    echo "结束时间: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "退出码: $BUILD_STATUS"
  } >> "$LOG_FILE"
  exit "$BUILD_STATUS"

  cd "$_pwd"
}

stage_compile_kernel() {
  log_stage "compile_kernel" "编译内核"
  local attempt=1 rc=0
  export -f compile_kernel_once
  while [ "$attempt" -le "$COMPILE_MAX_ATTEMPTS" ]; do
    echo "编译尝试 $attempt/$COMPILE_MAX_ATTEMPTS"
    if timeout -k 60 "${COMPILE_TIMEOUT_MINUTES}m" bash -c "compile_kernel_once"; then
      rc=0; break
    else
      rc=$?
      echo "编译失败（退出码 $rc）"
    fi
    attempt=$((attempt + 1))
  done
  if [ "$rc" -ne 0 ]; then export COMPILE_FAILED=1; fi
  return $rc
}

run_compile_kernel() { stage_compile_kernel "$@"; }

stage_collect_fail_log() {
  log_stage "collect_fail_log" "整理编译失败日志"
  local _pwd="$PWD"
  LOG_DIR="$WORKSPACE/build-logs"
  mkdir -p "$LOG_DIR"

  {
    echo "Android 版本: ${ANDROID_VERSION}"
    echo "内核版本: ${KERNEL_VERSION}.${SUB_LEVEL}"
    echo "安全补丁级别: ${OS_PATCH_LEVEL}"
    echo "KernelSU 变体: ${KSU_VARIANT}"
    echo "配置名称: ${CONFIG:-未知}"
    echo "Git 提交: $GITHUB_SHA"
    echo "工作流地址: $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
    echo "编译尝试次数: ${COMPILE_ATTEMPTS:-未知}"
    echo "最终退出码: ${COMPILE_EXIT_CODE:-未知}"
    echo "KSU 提交日期: ${KSU_LATEST_COMMIT_DATE:-未知}"
    echo "SUSFS 提交日期: ${SUSFS_LATEST_COMMIT_DATE:-未知}"
  } > "$LOG_DIR/summary.txt"

  printf '%s\n' "${KSU_VARIANT}_kernel-${CONFIG}-Build-Logs" > "$LOG_DIR/artifact-name.txt"

  df -h "$WORKSPACE" > "$LOG_DIR/disk-usage.txt" 2>&1 || true
  ccache -s > "$LOG_DIR/ccache-stats.txt" 2>&1 || true

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_collect_fail_log() {
  if [ "$COMPILE_FAILED" = "1" ]; then
    stage_collect_fail_log "$@"
  else
    echo "跳过阶段: collect_fail_log（条件不满足）"
  fi
}

stage_patch_kpm_image() {
  log_stage "patch_kpm_image" "修补 Image（KPM）"
  local _pwd="$PWD"

  # [融合] 移植自 ShirkNeko/GKI_KernelSU_SUSFS 的 patch_kpm_image()
  # 用 SukiSU_patch 的 kpm/patch_linux 对编译产物 Image 打补丁，使其具备加载
  # KPM 模块的能力。仅在开启 KPM 且非 6.6 内核时执行。
  case "${USE_KPM}" in
    enabled*|patched*) ;;
    *)
      echo "KPM 未开启，跳过镜像修补"
      cd "$_pwd"
      return 0
      ;;
  esac

  if [ "${KERNEL_VERSION}" = "6.6" ]; then
    echo "6.6 内核不支持 KPM 镜像修补，跳过"
    cd "$_pwd"
    return 0
  fi

  local image_dir
  if [ "${ANDROID_VERSION}" = "android12" ] || [ "${ANDROID_VERSION}" = "android13" ]; then
    image_dir="$KERNEL_ROOT/out/${ANDROID_VERSION}-${KERNEL_VERSION}/dist"
  else
    image_dir="$KERNEL_ROOT/bazel-bin/common/kernel_aarch64"
  fi

  if [ ! -d "$image_dir" ]; then
    echo "::warning::未找到镜像目录 $image_dir，跳过 KPM 修补"
    cd "$_pwd"
    return 0
  fi

  cd "$image_dir"
  echo "在 $image_dir 执行 KPM 镜像修补"

  if [ ! -s Image ]; then
    echo "::warning::Image 不存在或为空，跳过 KPM 修补"
    cd "$_pwd"
    return 0
  fi
  orig_size=$(stat -c %s Image)

  if curl -LSs "$KPM_PATCH_URL" -o patch && chmod 777 patch; then
    ./patch || echo "::warning::KPM 修补脚本返回非零，请查看上方输出"
    if [ -f oImage ]; then
      # 安全性校验：修补产物必须与原始 Image 体积相当。
      # patch 工具失败时会产出一个很小的残缺 oImage，一旦直接替换，
      # 后续打包出的 AnyKernel3 里就会是一个几百 KB 的假内核。
      new_size=$(stat -c %s oImage)
      if [ "$new_size" -lt $((orig_size * 80 / 100)) ]; then
        echo "::warning::oImage 体积异常（原始 ${orig_size} 字节 -> 修补后 ${new_size} 字节），判定为修补失败，保留原始 Image"
        rm -f oImage
      else
        mv oImage Image
        echo "已用修补产物 oImage 替换 Image（${orig_size} -> ${new_size} 字节）"
      fi
    else
      echo "::warning::未生成 oImage，KPM 修补未生效，保留原始 Image"
    fi
  else
    echo "::warning::下载 KPM 修补工具失败，跳过（不影响其余产物）"
  fi
  rm -f patch

  cd "$_pwd"
}

run_patch_kpm_image() { stage_patch_kpm_image "$@"; }

stage_prepare_boot() {
  log_stage "prepare_boot" "准备 Boot 镜像"
  local _pwd="$PWD"
  mkdir -p bootimgs

  if [ "${ANDROID_VERSION}" == "android12" ] || [ "${ANDROID_VERSION}" == "android13" ]; then
    SRC_DIR="$KERNEL_ROOT/out/${ANDROID_VERSION}-${KERNEL_VERSION}/dist"
  else
    SRC_DIR="$KERNEL_ROOT/bazel-bin/common/kernel_aarch64"
  fi

  # 兜底校验：走到这一步时 Image 必须已编译出来且体积合理。
  # 曾经因为上游阶段误用 exit 0 提前"成功"退出，编译一次都没跑却照样打包，
  # 产出一个只含 AnyKernel3 模板的空壳刷机包，因此这里做硬性体积校验。
  if [ ! -s "$SRC_DIR/Image" ]; then
    echo "::error::未找到内核镜像: $SRC_DIR/Image（编译可能并未真正执行）"
    return 1
  fi
  IMAGE_SIZE=$(stat -c %s "$SRC_DIR/Image")
  MIN_IMAGE_SIZE=$((10 * 1024 * 1024))
  if [ "$IMAGE_SIZE" -lt "$MIN_IMAGE_SIZE" ]; then
    echo "::error::内核镜像体积异常: ${IMAGE_SIZE} 字节（预期大于 10MB），拒绝打包"
    return 1
  fi
  echo "内核镜像校验通过: ${IMAGE_SIZE} 字节"

  cp "$SRC_DIR/Image" ./bootimgs/
  cp "$SRC_DIR/Image.lz4" ./bootimgs/
  cp "$SRC_DIR/Image" ./
  cp "$SRC_DIR/Image.lz4" ./
  gzip -n -k -f -9 ./Image > ./Image.gz

  cd "$_pwd"
}

run_prepare_boot() { stage_prepare_boot "$@"; }

stage_make_anykernel3() {
  log_stage "make_anykernel3" "创建 AnyKernel3 压缩包"
  local _pwd="$PWD"
  cd "$ANYKERNEL3"
  ZIP_NAME="${ANDROID_VERSION}-${KERNEL_VERSION}.${SUB_LEVEL}-${OS_PATCH_LEVEL}-AnyKernel3.zip"
  mv ../Image ./Image
  zip -r "../$ZIP_NAME" ./*

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_make_anykernel3() {
  if [ "$ARTIFACT_UPLOAD_MODE" = "上传全部" ]; then
    stage_make_anykernel3 "$@"
  else
    echo "跳过阶段: make_anykernel3（条件不满足）"
  fi
}

stage_prepare_anykernel3() {
  log_stage "prepare_anykernel3" "准备 AnyKernel3 目录"
  local _pwd="$PWD"
  mv ./Image "$ANYKERNEL3/Image"

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_prepare_anykernel3() {
  if [ "$ARTIFACT_UPLOAD_MODE" != "上传全部" ]; then
    stage_prepare_anykernel3 "$@"
  else
    echo "跳过阶段: prepare_anykernel3（条件不满足）"
  fi
}

stage_build_boot_a12() {
  log_stage "build_boot_a12" "构建 Boot 镜像 (Android 12)"
  local _pwd="$PWD"
  cd bootimgs
  GKI_URL=https://dl.google.com/android/gki/gki-certified-boot-android12-5.10-${OS_PATCH_LEVEL}_${REVISION}.zip
  FALLBACK_URL=https://dl.google.com/android/gki/gki-certified-boot-android12-5.10-2023-01_r1.zip

  status=$(curl -sL -w "%{http_code}" "$GKI_URL" -o /dev/null)
  if [ "$status" = "200" ]; then
    curl -Lo gki-kernel.zip "$GKI_URL"
  else
    curl -Lo gki-kernel.zip "$FALLBACK_URL"
  fi

  unzip gki-kernel.zip && rm gki-kernel.zip
  $UNPACK_BOOTIMG --boot_img="$(pwd)/boot-5.10.img"

  gzip -n -k -f -9 ./Image > ./Image.gz

  $MKBOOTIMG --header_version 4 --kernel Image --output boot.img --ramdisk out/ramdisk --os_version 12.0.0 --os_patch_level "${OS_PATCH_LEVEL}"
  $AVBTOOL add_hash_footer --partition_name boot --partition_size $((64 * 1024 * 1024)) --image boot.img --algorithm SHA256_RSA2048 --key $BOOT_SIGN_KEY_PATH
  cp ./boot.img ../${ANDROID_VERSION}-${KERNEL_VERSION}.${SUB_LEVEL}-${OS_PATCH_LEVEL}-boot.img

  $MKBOOTIMG --header_version 4 --kernel Image.gz --output boot-gz.img --ramdisk out/ramdisk --os_version 12.0.0 --os_patch_level "${OS_PATCH_LEVEL}"
  $AVBTOOL add_hash_footer --partition_name boot --partition_size $((64 * 1024 * 1024)) --image boot-gz.img --algorithm SHA256_RSA2048 --key $BOOT_SIGN_KEY_PATH
  cp ./boot-gz.img ../${ANDROID_VERSION}-${KERNEL_VERSION}.${SUB_LEVEL}-${OS_PATCH_LEVEL}-boot-gz.img

  $MKBOOTIMG --header_version 4 --kernel Image.lz4 --output boot-lz4.img --ramdisk out/ramdisk --os_version 12.0.0 --os_patch_level "${OS_PATCH_LEVEL}"
  $AVBTOOL add_hash_footer --partition_name boot --partition_size $((64 * 1024 * 1024)) --image boot-lz4.img --algorithm SHA256_RSA2048 --key $BOOT_SIGN_KEY_PATH
  cp ./boot-lz4.img ../${ANDROID_VERSION}-${KERNEL_VERSION}.${SUB_LEVEL}-${OS_PATCH_LEVEL}-boot-lz4.img

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_build_boot_a12() {
  if [ "$ANDROID_VERSION" = "android12" ]; then
    stage_build_boot_a12 "$@"
  else
    echo "跳过阶段: build_boot_a12（条件不满足）"
  fi
}

stage_build_boot_a13plus() {
  log_stage "build_boot_a13plus" "构建 Boot 镜像 (Android 13+)"
  local _pwd="$PWD"
  cd bootimgs
  gzip -n -k -f -9 ./Image > ./Image.gz

  $MKBOOTIMG --header_version 4 --kernel Image --output boot.img
  $AVBTOOL add_hash_footer --partition_name boot --partition_size $((64 * 1024 * 1024)) --image boot.img --algorithm SHA256_RSA2048 --key $BOOT_SIGN_KEY_PATH
  cp ./boot.img ../${ANDROID_VERSION}-${KERNEL_VERSION}.${SUB_LEVEL}-${OS_PATCH_LEVEL}-boot.img

  $MKBOOTIMG --header_version 4 --kernel Image.gz --output boot-gz.img
  $AVBTOOL add_hash_footer --partition_name boot --partition_size $((64 * 1024 * 1024)) --image boot-gz.img --algorithm SHA256_RSA2048 --key $BOOT_SIGN_KEY_PATH
  cp ./boot-gz.img ../${ANDROID_VERSION}-${KERNEL_VERSION}.${SUB_LEVEL}-${OS_PATCH_LEVEL}-boot-gz.img

  $MKBOOTIMG --header_version 4 --kernel Image.lz4 --output boot-lz4.img
  $AVBTOOL add_hash_footer --partition_name boot --partition_size $((64 * 1024 * 1024)) --image boot-lz4.img --algorithm SHA256_RSA2048 --key $BOOT_SIGN_KEY_PATH
  cp ./boot-lz4.img ../${ANDROID_VERSION}-${KERNEL_VERSION}.${SUB_LEVEL}-${OS_PATCH_LEVEL}-boot-lz4.img

  cd "$_pwd"
}

# 条件执行（等价原工作流 if:）
run_build_boot_a13plus() {
  if [ "$ANDROID_VERSION" = "android13" ] || [ "$ANDROID_VERSION" = "android14" ] || [ "$ANDROID_VERSION" = "android15" ] || [ "$ANDROID_VERSION" = "android16" ]; then
    stage_build_boot_a13plus "$@"
  else
    echo "跳过阶段: build_boot_a13plus（条件不满足）"
  fi
}

stage_collect_conflicts() {
  log_stage "collect_conflicts" "收集补丁冲突文件"
  local _pwd="$PWD"
  REJECTS_DIR="$WORKSPACE/patch-rejects"
  mkdir -p "$REJECTS_DIR"

  mapfile -t REJS < <(find "$KERNEL_ROOT" -type f -name '*.rej')
  REJ_COUNT=${#REJS[@]}
  echo "发现 $REJ_COUNT 个 .rej 文件"
  export REJ_COUNT="$REJ_COUNT"

  if [ "$REJ_COUNT" -gt 0 ]; then
    for REJ in "${REJS[@]}"; do
      REL="${REJ#"$KERNEL_ROOT"/}"
      DEST="$REJECTS_DIR/$REL"
      mkdir -p "$(dirname "$DEST")"
      cp "$REJ" "$DEST"

      ORIG="${REJ%.rej}"
      if [ -f "$ORIG" ]; then
        cp "$ORIG" "${DEST%.rej}"
      fi
      echo "$REL" >> "$REJECTS_DIR/index.txt"
    done
  fi

  cd "$_pwd"
}

run_collect_conflicts() { stage_collect_conflicts "$@"; }

# ---------------------------- 状态导出 ----------------------------
# GitHub Actions 各 step 是独立进程，产物上传步骤依赖 CONFIG / SUSFS_PATCH_EXPORT
# / REJ_COUNT 等变量，必须写回 $GITHUB_ENV 才能跨 step 传递。
# 本地构建时 GITHUB_ENV 未设置，直接跳过，不影响离线使用。
export_state() {
  [ -n "${GITHUB_ENV:-}" ] || return 0
  {
    echo "CONFIG=${CONFIG:-}"
    echo "KERNEL_ROOT=${KERNEL_ROOT:-}"
    echo "DEFCONFIG=${DEFCONFIG:-}"
    echo "SUSFS_PATCH_EXPORT=${SUSFS_PATCH_EXPORT:-false}"
    echo "REJ_COUNT=${REJ_COUNT:-0}"
    echo "COMPILE_FAILED=${COMPILE_FAILED:-0}"
  } >> "$GITHUB_ENV" 2>/dev/null || true
}
# 无论成功或失败都导出，保证 always() 的上传步骤能拿到值
trap export_state EXIT

# ---------------------------- 主流程 ----------------------------
PHASES=(
  summary
  cleanup_disk
  init_env
  show_config
  install_deps
  setup_ccache
  download_toolchain
  gen_sign_key
  setup_git
  clone_deps
  sync_kernel_source
  apply_stock_config
  extract_sublevel
  apply_cve_patch
  fix_glibc
  add_oneplus8e
  resolve_ksu_branch
  add_kernelsu
  config_sukisu_manager
  susfs_baseline
  apply_susfs
  gen_susfs_patch
  clone_droidspaces
  backup_defconfig
  integrate_droidspaces
  inject_ntsync
  apply_unicode_fix
  setup_zram_lz4
  fix_66_wifi_bt
  config_zram
  add_bbg
  apply_rekernel
  config_kernel
  config_susfs
  config_kernel_name
  set_build_time
  compile_kernel
  collect_fail_log
  patch_kpm_image
  prepare_boot
  make_anykernel3
  prepare_anykernel3
  build_boot_a12
  build_boot_a13plus
  collect_conflicts
)

list_phases() {
  local i=1
  for p in "${PHASES[@]}"; do
    printf "  %2d. %s\n" "$i" "$p"
    i=$((i + 1))
  done
}

usage() {
  cat <<'EOF'
用法: build_kernel.sh [选项]

  --all                运行全部阶段（默认）
  --only <阶段>        只运行指定阶段
  --from <阶段>        从指定阶段开始运行到结束
  --list               列出全部阶段
  --help               显示本帮助

参数通过环境变量传入，常用:
  ANDROID_VERSION KERNEL_VERSION SUB_LEVEL OS_PATCH_LEVEL
  KSU_VARIANT KSU_MODE ENABLE_SUSFS USE_ZRAM USE_BBR USE_KPM
  USE_BBG USE_REKERNEL SUPP_OP DROIDSPACES DROIDSPACES_NTSYNC
  CVE_2026_43499_PATCH EXPORT_SUSFS_PATCHES ARTIFACT_UPLOAD_MODE
EOF
}

main() {
  local mode="all" target=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --all)  mode="all" ;;
      --only) mode="only"; target="${2:-}"; shift ;;
      --from) mode="from"; target="${2:-}"; shift ;;
      --list) list_phases; exit 0 ;;
      --help|-h) usage; exit 0 ;;
      *) echo "未知参数: $1" >&2; usage; exit 1 ;;
    esac
    shift
  done

  if [ "$mode" = "only" ]; then
    if ! declare -F "run_${target}" >/dev/null; then
      echo "未知阶段: $target" >&2; exit 1
    fi
    "run_${target}"
    return
  fi

  local started=false
  for p in "${PHASES[@]}"; do
    if [ "$mode" = "from" ]; then
      if [ "$p" = "$target" ]; then started=true; fi
      if [ "$started" != true ]; then continue; fi
    fi
    "run_${p}" || {
      echo "::error::阶段 $p 执行失败"
      exit 1
    }
  done
}

main "$@"

