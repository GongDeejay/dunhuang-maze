# 敦煌迷途 — Web 部署说明

Godot 4.7 静态 Web 包，单目录部署，支持 **PC + 移动浏览器**（竖屏顶栏 HUD + Follow 地图）。

## 入口

| 项目 | 值 |
|------|-----|
| 入口文件 | `index.html` |
| 域名（生产） | `maze.mplusm.site` |
| 服务器路径 | `/www/wwwroot/maze.mplusm.site` |
| 构建目录 | 本目录全部文件 |

## 文件清单

| 文件 | 说明 |
|------|------|
| `index.html` | 页面壳，加载引擎与配置 |
| `index.js` | Godot Web 引导脚本 |
| `index.wasm` | Emscripten 引擎（约 38MB，gzip 后约 9–10MB） |
| `index.pck` | 游戏资源包（场景、脚本、贴图、音频） |
| `index.png` | 启动页 / 图标 |
| `index.icon.png` | Favicon |
| `index.apple-touch-icon.png` | iOS 主屏图标 |
| `index.audio.worklet.js` | 音频 Worklet |
| `index.audio.position.worklet.js` | 3D 音频 Worklet |
| `MANIFEST.json` | 自动生成：文件大小与 SHA256 |
| `VERSION.txt` | 自动生成：构建时间与 Git 版本 |

> 完整校验信息见 `MANIFEST.json`（由 `./export_web.sh` 导出后生成）。

## 服务器要求

### 必须：跨域隔离头（SharedArrayBuffer）

Godot 4 Web 导出启用了 `ensure_cross_origin_isolation_headers`。静态服务器**必须**返回：

```http
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

缺少上述头可能导致游戏无法启动或线程池降级。

### 推荐

- **HTTPS**（生产环境）
- **gzip / brotli** 压缩 `.wasm`、`.pck`、`.js`；仓库导出脚本会生成 `.gz`
- `Cache-Control`：`index.html` 不缓存；自动部署使用 `game-{git-sha}` 文件名并设置一年 immutable 缓存

## Nginx 示例

见同仓库 `deploy/nginx.conf.example`。核心片段：

```nginx
location / {
    try_files $uri $uri/ /index.html;
    add_header Cross-Origin-Opener-Policy same-origin;
    add_header Cross-Origin-Embedder-Policy require-corp;
}
```

## Apache 示例

见 `deploy/apache.htaccess.example`，部署时复制为站点根目录 `.htaccess`。

## 本地冒烟测试

```bash
# 导出（项目根目录）
./export_web.sh

# 带 COOP/COEP 的本地服务（推荐）
python3 tools/serve_web.py --port 8060

# 浏览器打开
open http://127.0.0.1:8060/index.html
```

DevTools 竖屏：设备尺寸 **390×844** 验证顶栏 HUD；**1280×720** 验证桌面侧栏。

## 增量部署（推荐日常更新）

本地增量导出仍使用 `index.*`。GitHub Actions 自动部署会使用带 Git SHA 的文件名，避免发布后旧缓存污染。

### 1. 导出并生成增量清单

```bash
# 首次部署前，可先复制一份基线（可选）
cp web/MANIFEST.json web/.last_deploy_manifest.json

# 增量导出：完整构建 + 对比上次 MANIFEST
./export_web_incremental.sh
```

生成文件：

| 文件 | 说明 |
|------|------|
| `INCREMENTAL.json` | 变更摘要（added/changed/removed） |
| `rsync_files.txt` | 仅需上传的文件列表 |

### 2. 仅上传变更文件

```bash
rsync -avz \
  --files-from=web/rsync_files.txt \
  web/ root@43.133.145.77:/www/wwwroot/maze.mplusm.site/
```

### 3. 更新部署基线

```bash
cp web/MANIFEST.json web/.last_deploy_manifest.json
```

下次运行 `export_web_incremental.sh` 将与此基线对比。

### 典型变更范围

| 改动类型 | 通常需上传 |
|----------|------------|
| 游戏脚本 / 贴图 / 关卡 | `index.pck`，`MANIFEST.json`，`VERSION.txt`，`INCREMENTAL.json` |
| 导出预设 / 引擎 | `index.wasm`，`index.js`，`index.html` |
| 仅文档 | `DEPLOY.md` 等 |

> 若 `index.wasm` 的 SHA256 未变，**切勿**重复上传 38MB wasm，可节省大量时间。

## 生产部署步骤（全量）

1. 在项目根目录执行 `./export_web.sh`（含测试 + 资源导入 + 导出 + 清单生成）
2. 将 **`web/` 目录下全部文件**同步至服务器 `WEB_ROOT`（见 `deploy/project.conf`）
3. 配置 Nginx/Apache 响应头（见上文）
4. 确认 HTTPS 证书有效
5. 访问 `https://maze.mplusm.site/index.html` 冒烟

### rsync 示例

```bash
rsync -avz --delete \
  --exclude '*.import' \
  --exclude 'cert.pem' \
  --exclude 'key.pem' \
  web/ root@43.133.145.77:/www/wwwroot/maze.mplusm.site/
```

> 勿上传 `*.import`（Godot 编辑器元数据）、本地 `cert.pem` / `key.pem`（应在服务器配置 SSL）。

## 体积说明

| 资源 | 原始 | gzip 约 |
|------|------|---------|
| index.wasm | ~38 MB | ~9–10 MB |
| index.pck（优化后） | ~0.55 MB | ~0.50 MB |
| index.js | ~280 KB | ~80 KB |

首屏需下载 wasm + pck。项目使用约 200KB 的运行时中文子集字体替代 7.9MB 全量字库，并为 WASM/PCK 生成预压缩文件；新增游戏文案后请运行 `./tools/subset_font.sh`。

## GitHub Actions 自动部署

`.github/workflows/deploy.yml` 在 `main` 分支的游戏文件变化后自动测试、导出、压缩并发布。仓库需配置 Actions Secret：

- `TENCENT_CVM_SSH_KEY`：仅允许部署该站点目录的 SSH 私钥，优先使用专用 deploy 用户/密钥。
- 可选 Actions Variable `TENCENT_DEPLOY_USER`：SSH 用户名，未设置时沿用现有 `root` 部署用户。

工作流先同步带版本号的资源，最后更新 `index.html`，并保留旧资源，避免打断仍在加载旧版本的玩家。若 Secret 尚未配置，工作流仍会完成构建并保存 14 天 artifact，但会跳过生产发布。

服务器需一次性将本站 Nginx 配置合并 `nginx.conf.example` 中的 `gzip_static` 和缓存规则，然后执行 `nginx -t` 并重载；上传示例文件不会自动修改 Nginx。旧版本资源可在确认没有在途加载后定期清理。

## 引擎与兼容性

- Godot **4.7**，`gl_compatibility` 渲染器
- **无线程** Web 导出（`thread_support=false`），Safari / 移动端兼容
- PWA manifest 未启用（`progressive_web_app/enabled=false`）；标题为「敦煌迷途」

## 故障排查

| 现象 | 处理 |
|------|------|
| 黑屏 / 无法加载 | 检查 COOP/COEP 响应头 |
| 404 on .wasm / .pck | 确认 MIME：`application/wasm`，静态文件已上传 |
| 旧版本缓存 | 硬刷新或更新 `index.html` 缓存策略 |
| 导出失败 | `BECKETT_ENABLE=0 ./export_web.sh`；确认 `import_etc2_astc=true` |

## 相关文档

- 研发框架：`design/dev-framework.md`
- 导出 / MCP：`design/beckett-mcp-setup.md`
- 部署配置：`deploy/project.conf`
