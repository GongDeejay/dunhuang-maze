#!/usr/bin/env bash
# 在广州轻量应用服务器上安装/刷新 nginx 主配置、站点定义与性能策略（幂等）。
# 通过 GitHub Actions 的既有部署 SSH 连接执行：
#   scp deploy/nginx-main-guangzhou.conf  target:/tmp/maze-gz-main-<sha>.conf
#   scp deploy/nginx-guangzhou.conf       target:/tmp/maze-gz-site-<sha>.conf
#   scp deploy/nginx-performance.conf     target:/tmp/maze-gz-perf-<sha>.inc
#   scp deploy/nginx-redirect-guangzhou.conf target:/tmp/maze-gz-redirect-<sha>.conf
#   ssh target bash -s -- <sha> < deploy/install-guangzhou.sh
set -euo pipefail

revision="${1:-}"
[[ "$revision" =~ ^[0-9a-f]{40}$ ]] || { echo "Invalid revision" >&2; exit 1; }

main_src="/tmp/maze-gz-main-${revision}.conf"
site_src="/tmp/maze-gz-site-${revision}.conf"
perf_src="/tmp/maze-gz-perf-${revision}.inc"
redirect_src="/tmp/maze-gz-redirect-${revision}.conf"
main_conf="/etc/nginx/nginx.conf"
site_conf="/etc/nginx/conf.d/maze.mplusm.site.conf"
perf_inc="/etc/nginx/dunhuang-performance.inc"
redirect_conf="/etc/nginx/conf.d/maze-redirect.conf"
web_root="/www/wwwroot/maze.mplusm.site"

test -f "$main_src"
test -f "$site_src"
test -f "$perf_src"
test -f "$redirect_src"
install -d -m 755 /etc/nginx/conf.d "$web_root"

changed=0
# 主配置：不定义监听 80/443 的 server 块，避免与 nps 抢端口。
if ! cmp -s "$main_src" "$main_conf" 2>/dev/null; then
    [[ -f "$main_conf" ]] && cp -p "$main_conf" "${main_conf}.bak-${revision}"
    install -m 644 "$main_src" "$main_conf"
    changed=1
fi
if ! cmp -s "$perf_src" "$perf_inc" 2>/dev/null; then
    install -m 644 "$perf_src" "$perf_inc"
    changed=1
fi
if ! cmp -s "$site_src" "$site_conf" 2>/dev/null; then
    [[ -f "$site_conf" ]] && cp -p "$site_conf" "${site_conf}.bak-${revision}"
    install -m 644 "$site_src" "$site_conf"
    changed=1
fi
if ! cmp -s "$redirect_src" "$redirect_conf" 2>/dev/null; then
    install -m 644 "$redirect_src" "$redirect_conf"
    changed=1
fi

# 移除发行版自带的默认站点（监听 80，与 nps 冲突）。
if [[ -f /etc/nginx/conf.d/default.conf ]]; then
    mv /etc/nginx/conf.d/default.conf "/etc/nginx/conf.d/default.conf.disabled-${revision}"
    changed=1
fi

# 证书未就位时 nginx -t 会失败：此时不下发启动指令，交由迁移流程先同步证书。
if ! nginx -t; then
    echo "nginx 配置校验失败：请先同步证书到 /etc/nginx/ssl/maze.mplusm.site/" >&2
    exit 1
fi

systemctl enable nginx >/dev/null 2>&1 || true
if systemctl is-active --quiet nginx; then
    if [[ "$changed" == 1 ]]; then
        systemctl reload nginx
        echo "配置已更新并重载 nginx（revision ${revision}）"
    else
        echo "配置无变化（revision ${revision}）"
    fi
else
    systemctl start nginx
    echo "nginx 已启动（revision ${revision}）"
fi

# 自检：80/443 应仍由 nps 持有，8443 应出现 nginx 监听。
ss -tlnp 2>/dev/null | grep -E ':(80|443|8443) ' || true
