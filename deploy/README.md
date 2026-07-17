# 部署配置目录

| 文件 | 用途 |
|------|------|
| `project.conf` | 域名、服务器 IP、WEB_ROOT 等变量 |
| `DEPLOY.md` | 完整部署说明（导出时复制到 `web/DEPLOY.md`） |
| `nginx.conf.example` | Nginx 站点配置（含 COOP/COEP） |
| `apache.htaccess.example` | Apache 重写与响应头 |

## 一键导出部署包

```bash
./export_web.sh
```

产物目录 `web/` 即为可上传的完整静态站点，包含：

- Godot 引擎与资源（`index.html` / `.wasm` / `.pck` / `.js` …）
- `DEPLOY.md` — 部署文档
- `MANIFEST.json` — 文件清单与 SHA256
- `VERSION.txt` — 构建版本摘要
- `nginx.conf.example` / `apache.htaccess.example` / `project.conf`

## 同步至生产

```bash
rsync -avz --delete web/ root@43.133.145.77:/www/wwwroot/maze.mplusm.site/
```

详见 `DEPLOY.md`。
