#!/usr/bin/env bash
# 在广州轻量应用服务器上安装/刷新站点定义与性能策略（幂等）。
# 通过 GitHub Actions 的既有部署 SSH 连接执行：
#   scp deploy/nginx-guangzhou.conf  target:/tmp/maze-gz-site-<sha>.conf
#   scp deploy/nginx-performance.conf target:/tmp/maze-gz-perf-<sha>.inc
#   ssh target bash -s -- <sha> < deploy/install-guangzhou.sh
set -euo pipefail

revision="${1:-}"
[[ "$revision" =~ ^[0-9a-f]{40}$ ]] || { echo "Invalid revision" >&2; exit 1; }

site_src="/tmp/maze-gz-site-${revision}.conf"
perf_src="/tmp/maze-gz-perf-${revision}.inc"
site_conf="/etc/nginx/conf.d/maze.mplusm.site.conf"
perf_inc="/etc/nginx/dunhuang-performance.inc"
web_root="/www/wwwroot/maze.mplusm.site"

test -f "$site_src"
test -f "$perf_src"
install -d -m 755 /etc/nginx/conf.d "$web_root"

changed=0
if ! cmp -s "$perf_src" "$perf_inc" 2>/dev/null; then
    install -m 644 "$perf_src" "$perf_inc"
    changed=1
fi
if ! cmp -s "$site_src" "$site_conf" 2>/dev/null; then
    [[ -f "$site_conf" ]] && cp -p "$site_conf" "${site_conf}.bak-${revision}"
    install -m 644 "$site_src" "$site_conf"
    changed=1
fi

# 证书未就位时 nginx -t 会失败，此时不下发启动指令，交由迁移流程先同步证书。
if ! nginx -t; then
    echo "nginx 配置校验失败：请先同步证书到 /etc/nginx/ssl/maze.mplusm.site/" >&2
    exit 1
fi

systemctl enable nginx >/dev/null 2>&1 || true
if systemctl is-active --quiet nginx; then
    if [[ "$changed" == 1 ]]; then
        systemctl reload nginx
        echo "站点定义已更新并重载 nginx（revision ${revision}）"
    else
        echo "站点定义无变化（revision ${revision}）"
    fi
else
    systemctl start nginx
    echo "nginx 已启动（revision ${revision}）"
fi
