#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Telegram 构建通知脚本（融合自 ShirkNeko/GKI_KernelSU_SUSFS）。

相对原始实现的改进：
  1. 恢复 TLS 证书校验（原实现关闭了证书验证，存在中间人风险）
  2. 用标准库实现 multipart 上传，去掉对 `multipart` 第三方包的依赖
  3. 构建参数统一从环境变量读取，与 build_kernel.sh 保持同一套变量名
  4. 补充 zzh 特有选项（BBR / BBG / ReKernel / Droidspaces / CVE 补丁）的展示

用法:
    python3 scripts/telegram_notify.py single
        发送单版本构建完成通知（参数取自环境变量）

    python3 scripts/telegram_notify.py release <tag> <url> [notes_file]
        发送发布通知

必填环境变量:
    TELEGRAM_BOT_TOKEN    Bot Token
    TELEGRAM_CHAT_ID      目标会话 ID
可选:
    TELEGRAM_MESSAGE_THREAD_ID   话题（ forum topic ）ID
"""
import hashlib
import json
import os
import ssl
import sys
import urllib.error
import urllib.request
from html import escape
from pathlib import Path
from uuid import uuid4

API_BASE = "https://api.telegram.org"


def env_flag(name: str) -> bool:
    return os.environ.get(name, "false").strip().lower() in ("true", "1", "yes", "on")


def env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


def _sanitize_header_value(value: str) -> str:
    """清理即将写进 multipart header 的值。

    filename 与字段名都直接来自文件名/环境变量，而 multipart 的 header 以 CRLF
    分行。一个名字里带 `\\r\\n` 的文件就能凭空插入额外的 header 或字段，改变这次
    上传的语义（例如覆盖 parse_mode、伪造第二个 part）。当前调用链上的文件名由
    构建脚本生成、chat_id 来自 secrets，属于可信输入，但这是**转义边界**：
    函数本身必须对任何输入都安全，不能指望调用方永远不传脏数据。

    处理方式：CR/LF 与 NUL 直接剥除（而不是替换，避免引入新字符），
    双引号转义为 `\\"` 以免提前闭合 header 的引号包裹；截断到 200 字符。
    """
    cleaned = str(value)
    for ch in ("\r", "\n", "\x00"):
        cleaned = cleaned.replace(ch, "")
    cleaned = cleaned.replace('"', '\\"')
    return cleaned[:200]


class TelegramNotifier:
    def __init__(self, bot_token: str = None, chat_id: str = None, thread_id: str = None):
        self.bot_token = bot_token or env("TELEGRAM_BOT_TOKEN")
        self.chat_id = chat_id or env("TELEGRAM_CHAT_ID")
        self.thread_id = thread_id or env("TELEGRAM_MESSAGE_THREAD_ID")
        # 使用默认安全上下文：校验主机名与证书链
        self.ssl_ctx = ssl.create_default_context()

    def _post_json(self, method: str, payload: dict) -> bool:
        if not self.bot_token or not self.chat_id:
            print("跳过通知：未配置 TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID")
            return False
        url = f"{API_BASE}/bot{self.bot_token}/{method}"
        if self.thread_id:
            payload["message_thread_id"] = self.thread_id
        try:
            req = urllib.request.Request(
                url,
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(req, context=self.ssl_ctx, timeout=30) as resp:
                result = json.loads(resp.read().decode("utf-8"))
                if result.get("ok"):
                    print("消息发送成功")
                    return True
                print(f"发送失败: {result.get('description')}")
                return False
        except urllib.error.HTTPError as e:
            print(f"HTTP 错误 {e.code}: {e.read().decode('utf-8', 'ignore')[:300]}")
            return False
        except Exception as e:  # noqa: BLE001
            print(f"请求失败: {e}")
            return False

    def send_message(self, message: str) -> bool:
        return self._post_json("sendMessage", {
            "chat_id": self.chat_id,
            "text": message,
            "parse_mode": "HTML",
            "disable_web_page_preview": True,
        })

    def send_document(self, file_path: str, caption: str = None) -> bool:
        """上传文件（标准库手写 multipart，无第三方依赖）。"""
        if not self.bot_token or not self.chat_id:
            print("跳过文件上传：未配置 TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID")
            return False
        if not os.path.isfile(file_path):
            print(f"文件不存在: {file_path}")
            return False

        boundary = "----GkiFormBoundary" + uuid4().hex
        fields = {"chat_id": self.chat_id}
        if self.thread_id:
            fields["message_thread_id"] = self.thread_id
        if caption:
            fields["caption"] = caption
            fields["parse_mode"] = "HTML"

        body = bytearray()
        for key, value in fields.items():
            body += f"--{boundary}\r\n".encode()
            body += f'Content-Disposition: form-data; name="{_sanitize_header_value(key)}"\r\n\r\n'.encode()
            body += f"{value}\r\n".encode()

        filename = os.path.basename(file_path)
        safe_filename = _sanitize_header_value(filename)
        with open(file_path, "rb") as f:
            content = f.read()
        body += f"--{boundary}\r\n".encode()
        body += (
            f'Content-Disposition: form-data; name="document"; filename="{safe_filename}"\r\n'
        ).encode()
        body += b"Content-Type: application/octet-stream\r\n\r\n"
        body += content + b"\r\n"
        body += f"--{boundary}--\r\n".encode()

        url = f"{API_BASE}/bot{self.bot_token}/sendDocument"
        try:
            req = urllib.request.Request(
                url, data=bytes(body),
                headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
            )
            with urllib.request.urlopen(req, context=self.ssl_ctx, timeout=120) as resp:
                result = json.loads(resp.read().decode("utf-8"))
                if result.get("ok"):
                    print(f"文件发送成功: {filename}")
                    return True
                print(f"文件发送失败: {result.get('description')}")
                return False
        except Exception as e:  # noqa: BLE001
            print(f"文件发送失败: {e}")
            return False


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def collect_artifacts(workspace: str, limit: int = 8):
    """收集构建产物（AnyKernel3 包与 boot 镜像）及其 SHA256。"""
    out = []
    root = Path(workspace)
    if not root.is_dir():
        return out
    patterns = ("*AnyKernel3.zip", "*.img")
    for pat in patterns:
        for p in sorted(root.rglob(pat)):
            if p.is_file():
                out.append((p.name, sha256_file(str(p))))
                if len(out) >= limit:
                    return out
    return out


def build_single_message(hashes_file: str = None) -> str:
    def flag(name: str) -> str:
        return "✅" if env_flag(name) else "➖"

    msg = [
        "<b>GKI 内核构建完成</b>",
        "",
        f"<b>Android:</b> {escape(env('ANDROID_VERSION'))}",
        f"<b>Kernel:</b> {escape(env('KERNEL_VERSION'))}.{escape(env('SUB_LEVEL'))}",
        f"<b>OS Patch:</b> {escape(env('OS_PATCH_LEVEL'))}",
        f"<b>KSU:</b> {escape(env('KSU_VARIANT'))}（{escape(env('KSU_MODE'))}）",
        "",
        "<b>功能开关</b>",
        f"{flag('ENABLE_SUSFS')} SUSFS    {flag('USE_KPM')} KPM    {flag('USE_ZRAM')} ZRAM",
        f"{flag('USE_BBR')} BBR      {flag('USE_BBG')} BBG     {flag('USE_REKERNEL')} ReKernel",
        f"{flag('CVE_2026_43499_PATCH')} CVE补丁  {flag('SUPP_OP')} 一加8E",
    ]
    ds = env("DROIDSPACES", "off")
    if ds != "off":
        msg.append(f"🔧 Droidspaces: {escape(ds)}" + (" + NTSync" if env_flag("DROIDSPACES_NTSYNC") else ""))

    text = "\n".join(msg)

    files = []
    if hashes_file and os.path.isfile(hashes_file):
        for line in Path(hashes_file).read_text(encoding="utf-8", errors="ignore").splitlines():
            parts = line.split()
            if len(parts) >= 2:
                files.append((parts[-1].strip(), parts[0].strip()))
    else:
        files = collect_artifacts(env("WORKSPACE", "."))

    if files:
        text += "\n\n<b>产物校验 (SHA256)</b>"
        for name, digest in files:
            text += f"\n<code>{escape(name)}</code>\n<code>{digest}</code>"
    return text


def build_release_message(tag: str, url: str, notes: str = None) -> str:
    text = f"<b>新版本发布</b>\n\n<b>版本:</b> {escape(tag)}\n<b>下载:</b> <a href=\"{escape(url)}\">{escape(url)}</a>"
    if notes:
        head = notes.strip().splitlines()[:20]
        text += "\n\n<b>更新说明</b>\n" + escape("\n".join(head))
    return text


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1

    notifier = TelegramNotifier()
    action = sys.argv[1]

    if action == "single":
        hashes_file = sys.argv[2] if len(sys.argv) > 2 and os.path.isfile(sys.argv[2]) else None
        ok = notifier.send_message(build_single_message(hashes_file))
        if ok and hashes_file:
            notifier.send_document(hashes_file, "SHA256SUMS")
        return 0 if ok else 1

    if action == "release":
        if len(sys.argv) < 4:
            print("错误: release 需要 <tag> <url> [notes_file]")
            return 1
        tag, url = sys.argv[2], sys.argv[3]
        notes = None
        if len(sys.argv) > 4 and os.path.isfile(sys.argv[4]):
            notes = Path(sys.argv[4]).read_text(encoding="utf-8", errors="ignore")
        return 0 if notifier.send_message(build_release_message(tag, url, notes)) else 1

    print(f"未知操作: {action}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
