#!/usr/bin/env bash
# maze-deploy — 拉取式部署器（在目标服务器上以 root 执行）
#
# 设计要点：
#   1. CI 只下发"一条命令 + 一个校验和"，构建产物由本机自己拉取，数据不经过 CI 的出网链路；
#   2. 下载支持国内镜像回退（GitHub 直连在境内只有 60KB/s，镜像可达 8MB/s）；
#   3. 校验和不匹配立即中止（fail closed），不做"部分成功"；
#   4. 先同步资源、最后才落 index.html，切换失败自动回滚到部署前快照；
#   5. 快照用硬链接（rsync --link-dest），几乎不占额外磁盘。
#
# 用法：
#   maze-deploy --version <rev> --sha256 <sha256> --url <artifact-url>
set -Eeuo pipefail

SITE_NAME="${SITE_NAME:-maze.mplusm.site}"
SITE_PORT="${SITE_PORT:-8443}"
ROOT="${MAZE_ROOT:-/www/wwwroot/maze.mplusm.site}"
STATE_DIR="${MAZE_STATE_DIR:-/var/lib/maze}"
SNAPSHOTS="$STATE_DIR/snapshots"
KEEP="${MAZE_KEEP:-5}"
MIRRORS="${MAZE_MIRRORS:-https://ghfast.top https://gh-proxy.com}"

VERSION=""
SHA256=""
URL=""

log() { printf '[maze-deploy] %s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="${2:?--version needs a value}"; shift 2 ;;
    --sha256)  SHA256="${2:?--sha256 needs a value}";  shift 2 ;;
    --url)     URL="${2:?--url needs a value}";        shift 2 ;;
    --root)    ROOT="${2:?--root needs a value}";      shift 2 ;;
    --keep)    KEEP="${2:?--keep needs a value}";      shift 2 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$VERSION" && -n "$SHA256" && -n "$URL" ]] || die "--version/--sha256/--url are required"
[[ "$VERSION" =~ ^[0-9a-f]{7,40}$ ]] || die "version must be a git revision (hex)"
[[ "$SHA256" =~ ^[0-9a-f]{64}$ ]] || die "sha256 must be 64 hex chars"
[[ "$KEEP" =~ ^[0-9]+$ ]] || die "keep must be numeric"

for bin in curl rsync tar sha256sum flock python3; do
  command -v "$bin" >/dev/null 2>&1 || die "required command not found: $bin"
done

mkdir -p "$STATE_DIR" "$SNAPSHOTS"
exec 9>"$STATE_DIR/.lock"
flock -n 9 || die "another maze-deploy is already running"

WORK="$STATE_DIR/work"
rm -rf "$WORK"
mkdir -p "$WORK"

snapshot=""
success=0

cleanup() {
  local rc=$?
  if [[ "$success" -ne 1 && -n "$snapshot" ]]; then
    log "deployment did not finish cleanly (rc=$rc) — rolling back to previous release"
    if rsync -a --delete "$snapshot/" "$ROOT/" 2>/dev/null; then
      log "rollback completed"
    else
      log "ROLLBACK FAILED — manual action required (snapshot: $snapshot)"
    fi
  fi
  rm -rf "$WORK"
  exit "$rc"
}
trap cleanup EXIT

# ---------------------------------------------------------------- 1. 下载
tarball="$WORK/dist-$VERSION.tar.gz"
candidates=("$URL")
case "$URL" in
  https://github.com/*|https://objects.githubusercontent.com/*|https://release-assets.githubusercontent.com/*)
    for mirror in $MIRRORS; do
      candidates+=("$mirror/$URL")
    done
    ;;
esac

verified=0
for candidate in "${candidates[@]}"; do
  log "download: $candidate"
  rm -f "$tarball"
  if curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 3600 \
       --speed-limit 1024 --speed-time 60 --continue-at - -o "$tarball" "$candidate"; then
    actual="$(sha256sum "$tarball" | awk '{print $1}')"
    if [[ "$actual" == "$SHA256" ]]; then
      log "checksum ok ($actual)"
      verified=1
      break
    fi
    log "checksum mismatch from this source (got $actual) — trying next"
  else
    log "download failed from this source"
  fi
done
[[ "$verified" -eq 1 ]] || die "no artifact source produced a matching checksum"

# ---------------------------------------------------------------- 2. 解包与自检
stage="$WORK/stage"
mkdir -p "$stage"
tar -xzf "$tarball" -C "$stage"

[[ -f "$stage/index.html" ]] || die "artifact is missing index.html"
[[ -f "$stage/MANIFEST.json" ]] || die "artifact is missing MANIFEST.json"

artifact_rev="$(python3 - "$stage/MANIFEST.json" <<'PY'
import json, sys
try:
    print(json.load(open(sys.argv[1])).get("git_revision", ""))
except Exception:
    print("")
PY
)"
if [[ -n "$artifact_rev" && "$artifact_rev" != "$VERSION"* ]]; then
  die "artifact revision ${artifact_rev} does not match requested ${VERSION}"
fi

engine="$(find "$stage" -maxdepth 1 -name 'engine-*.wasm' -printf '%f\n' | head -1)"
pck="$(find "$stage" -maxdepth 1 -name 'game-*.pck' -printf '%f\n' | head -1)"
[[ -n "$engine" && -n "$pck" ]] || die "artifact is missing engine wasm or game pck"
log "artifact contains: $engine / $pck"

# ---------------------------------------------------------------- 3. 部署前快照
mkdir -p "$ROOT"
if [[ -n "$(ls -A "$ROOT" 2>/dev/null)" ]]; then
  snapshot="$SNAPSHOTS/$(date -u +%Y%m%dT%H%M%SZ)-pre-${VERSION}"
  mkdir -p "$snapshot"
  rsync -a --link-dest="$ROOT/" "$ROOT/" "$snapshot/" || die "failed to create pre-deploy snapshot"
  log "pre-deploy snapshot: $snapshot"
fi

# ---------------------------------------------------------------- 4. 切换（资源先行，入口页最后）
log "syncing assets"
rsync -a --checksum --delete --exclude 'index.html' --exclude '.well-known/' "$stage/" "$ROOT/"
log "publishing entry page"
install -m 644 "$stage/index.html" "$ROOT/index.html"

# ---------------------------------------------------------------- 5. 健康检查
sleep 1
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 \
  --resolve "$SITE_NAME:$SITE_PORT:127.0.0.1" "https://$SITE_NAME:$SITE_PORT/" || true)"
coop="$(curl -sI --max-time 15 --resolve "$SITE_NAME:$SITE_PORT:127.0.0.1" \
  "https://$SITE_NAME:$SITE_PORT/" | tr -d '\r' \
  | awk 'tolower($1)=="cross-origin-opener-policy:"{print $2}' || true)"
log "health check: http=$code coop=${coop:-none}"

[[ "$code" == "200" ]] || die "health check failed: HTTP $code"
[[ "$coop" == "same-origin" ]] || die "health check failed: COOP header is '${coop:-missing}'"

served_rev="$(python3 - "$ROOT/MANIFEST.json" <<'PY'
import json, sys
try:
    print(json.load(open(sys.argv[1])).get("git_revision", ""))
except Exception:
    print("")
PY
)"
[[ -z "$served_rev" || "$served_rev" == "$VERSION"* ]] || die "served revision $served_rev != $VERSION"

success=1

# ---------------------------------------------------------------- 6. 收尾
printf '{"version":"%s","sha256":"%s","deployed_at":"%s","source":"%s"}\n' \
  "$VERSION" "$SHA256" "$(date -u +%FT%TZ)" "$URL" > "$STATE_DIR/state.json"

# 只保留最近 N 份快照
ls -1dt "$SNAPSHOTS"/*/ 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r old; do
  rm -rf "$old"
done

log "deployment succeeded: $VERSION -> $ROOT"
