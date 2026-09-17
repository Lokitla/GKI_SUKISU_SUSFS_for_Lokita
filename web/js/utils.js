/**
 * 通用工具函数
 */

import { RUNTIME_CACHE_KEY, SUSFS_COMPAT_MIN } from './config.js';

// HTML 转义，防止 XSS
// 注意：textContent → innerHTML 只会转义 & < >，不碰引号。而本文件 escape 出来的值
// 大量被拼进 title="..." / data-xxx="..." 这类 HTML 属性里，含双引号的数据会直接
// 截断属性、拼出 onerror= 之类的东西。所以这里补上引号转义，属性上下文才安全。
export function esc(str) {
  var el = document.createElement('span');
  el.textContent = str == null ? '' : String(str);
  return el.innerHTML
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// 复制文本到剪贴板（兼容旧浏览器）
export function copyText(text) {
  if (navigator.clipboard && navigator.clipboard.writeText) {
    return navigator.clipboard.writeText(text);
  }
  var ta = document.createElement('textarea');
  ta.value = text;
  ta.style.position = 'fixed';
  ta.style.opacity = '0';
  document.body.appendChild(ta);
  ta.select();
  document.execCommand('copy');
  document.body.removeChild(ta);
  return Promise.resolve();
}

// 给 URL 追加缓存破坏参数
export function withCacheKey(url) {
  return url + (url.indexOf('?') === -1 ? '?' : '&') + 'v=' + encodeURIComponent(RUNTIME_CACHE_KEY);
}

// 强制无缓存请求 JSON
export async function fetchJsonFresh(url) {
  var r = await fetch(withCacheKey(url), { cache: 'no-store' });
  if (!r.ok) throw new Error('HTTP ' + r.status);
  return r.json();
}

// 判断内核版本是否兼容 SUSFS
export function isSusfsCompat(kernelStr) {
  var parts = kernelStr.split('.');
  var major = parts[0] + '.' + parts[1];
  var min = SUSFS_COMPAT_MIN[major];
  if (min == null) return false;
  var sublevel = parseInt(parts[2], 10);
  return sublevel >= min;
}
