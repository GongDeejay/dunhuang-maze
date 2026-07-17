# 敦煌迷途 (Dunhuang Maze)

Godot 4.7 敦煌主题迷宫 Roguelike — Web 优先（PC + 移动浏览器），探索 procedural 迷宫、收集家人、穿越三关。

## 要求

- [Godot 4.7](https://godotengine.org/)（含 headless 用于测试）
- 终端已配置 `godot` 命令

## 运行

```bash
# 编辑器：打开 project.godot，F5 运行

./run_tests.sh          # Headless 测试
./export_web.sh         # 导出 Web → web/
./tools/optimize_sprites.sh  # 同步 32×32 角色 / 18×18 心形
```

## Web 发布（PC + 移动）

```bash
./export_web.sh   # 测试 → 导出 → MANIFEST.json + DEPLOY.md
```

产物 **`web/`** 即为完整部署包（引擎 + 资源 + 描述文件），详见 [`web/DEPLOY.md`](web/DEPLOY.md)。

| 描述文件 | 说明 |
|----------|------|
| `web/DEPLOY.md` | 部署步骤、响应头、故障排查 |
| `web/MANIFEST.json` | 文件清单 + SHA256 |
| `web/VERSION.txt` | 构建时间与 Git 版本 |
| `web/nginx.conf.example` | Nginx 配置示例 |
| `web/apache.htaccess.example` | Apache 配置示例 |
| `web/project.conf` | 域名与服务器路径 |

1. `./export_web.sh` 或 MCP 工具 `export_web`（见 [`design/beckett-mcp-setup.md`](design/beckett-mcp-setup.md)）
2. 静态部署：`rsync -avz web/ root@43.133.145.77:/www/wwwroot/maze.mplusm.site/`
3. 配置 COOP/COEP 响应头（见 `web/DEPLOY.md`）
4. PWA 使用文字标题「敦煌迷途」，无独立图标包

引擎：`gl_compatibility` + `canvas_items` stretch，Safari 兼容（无线程）。

## 研发框架

基于 GitHub 模板选型，详见 [`design/dev-framework.md`](design/dev-framework.md)：

- 玩法：[godot-roguelike-basic-set](https://github.com/alexshopov/godot-roguelike-basic-set) — Action / Handler / Entity
- 发布：[godot-project-template](https://github.com/joshuafolkken/godot-project-template) — Web CI / PWA

```
scripts/
  core/           # PlatformService, GameDirector (Autoload)
  actions/        # GameAction
  handlers/       # InputHandler
  asset_registry.gd
  main.gd         # 薄协调器
assets/sprites/   # ASSET_MANIFEST.md
web/              # 导出产物
```

## 操作

| 按键 | 功能 |
|------|------|
| WASD | 移动 |
| 1–5 | 选择背包槽 |
| E | 使用道具 |
| R | 重开本关 / 胜利后下一关 |
| Q | 返回难度选择 |

## 开发规范

- 新功能 → 独立 `.gd` 模块；输入走 `InputHandler` → `GameAction`
- 贴图路径 → `AssetRegistry`，勿硬编码
- 提交前 `./run_tests.sh`
