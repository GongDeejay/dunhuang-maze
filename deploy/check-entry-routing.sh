#!/usr/bin/env bash
# Read-only diagnosis ON the Guangzhou server. Never installs rules, restarts services or reads keys.
# Run through the owner's existing verified SSH/console access: bash deploy/check-entry-routing.sh
set -u
printf 'Relevant listeners (443 / 8443 / 8180):\n'
ss -ltnp '( sport = :443 or sport = :8443 or sport = :8180 )' 2>&1 || true
printf '\nNAT restore service state:\n'
systemctl is-active maze-nat-restore.service 2>&1 || true
systemctl is-enabled maze-nat-restore.service 2>&1 || true
printf '\nRelevant IPv4 NAT ingress rules:\n'
if command -v iptables >/dev/null; then
    iptables -t nat -S PREROUTING 2>&1 | grep -E -- '(^-P|--dport (80|443|8180|8443)( |$)|denied|Permission)' || true
fi
printf '\nLocal canonical HTTPS site (does NOT test external NAT):\n'
curl --noproxy '*' -sSI --connect-timeout 5 --max-time 10 --resolve maze.mplusm.site:8443:127.0.0.1 https://maze.mplusm.site:8443/ || true
printf '\nLocal HTTP redirect listener:\n'
curl --noproxy '*' -sSI --connect-timeout 5 --max-time 10 -H 'Host: maze.mplusm.site' http://127.0.0.1:8180/ || true
printf '\nNo changes made. Do not replace nps or change forwarding without reviewing these results.\n'
