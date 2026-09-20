#!/usr/bin/env bash
# Run over the existing deployment SSH connection. Only migrate the known site include.
set -euo pipefail
revision="${1:-}"
[[ "$revision" =~ ^[0-9a-f]{40}$ ]] || { echo "Invalid revision" >&2; exit 1; }
target=/www/server/panel/vhost/nginx/dunhuang-performance.inc
site=/www/server/panel/vhost/nginx/maze.mplusm.site.conf
candidate="/tmp/dunhuang-performance-${revision}.inc"
backup="${target}.before-intro-cache-${revision}"
nginx=/www/server/nginx/sbin/nginx
test -x "$nginx"
test -f "$target"
test -f "$candidate"
grep -Fq 'dunhuang-performance.inc' "$site"
if cmp -s "$candidate" "$target"; then
    "$nginx" -t
    exit 0
fi
# Stop instead of overwriting an administrator's unrelated edits.
baseline=56af7463ef317aa754e7419b6a42256035882a76510dabf7f3e547c528994ebd
actual="$(sha256sum "$target" | cut -d ' ' -f 1)"
if [[ "$actual" != "$baseline" ]]; then
    echo "Performance include differs from the reviewed baseline ($actual); inspect before updating." >&2
    exit 1
fi
cp -p "$target" "$backup"
changed=0
committed=0
rollback() {
    if [[ "$changed" == 1 && "$committed" == 0 ]]; then
        cp -p "$backup" "$target"
        "$nginx" -t && "$nginx" -s reload
        echo "Restored $backup" >&2
    fi
}
trap rollback EXIT
cp "$candidate" "${target}.next-${revision}"
changed=1
mv "${target}.next-${revision}" "$target"
"$nginx" -t
"$nginx" -s reload
committed=1
echo "Installed story-image cache policy; backup: $backup"
