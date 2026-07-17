# 敦煌迷途 — 研发框架与工程规范

*基于 GitHub 开源模板选型，适配 Web（PC + 移动浏览器）双端发布*

---

## 1. 框架选型（Git 调研结论）

| 仓库 | 匹配度 | 采纳内容 |
|------|--------|----------|
| [alexshopov/godot-roguelike-basic-set](https://github.com/alexshopov/godot-roguelike-basic-set) | **玩法最接近** — 传统 Roguelike、回合制、实体/地图分离 | `actions/` 输入→动作、`handlers/event_handler`、`entities/`、`globals/`、`data/` Resources |
| [joshuafolkken/godot-project-template](https://github.com/joshuafolkken/godot-project-template) | **Web/CI 最接近** — PWA、GitHub Pages、多平台 | Web 导出预设、CI 版本对齐、`deploy-web` 工作流思路 |
| [brettchalupa/godot_skeleton](https://github.com/brettchalupa/godot_skeleton) | 场景/菜单结构 | Compatibility 渲染器、预配置 Web 导出 |
| [fourgames/template](https://github.com/fourgames/template) | 架构参考 | Feature 文件夹、Global Signals、Run-Any-Scene |

**结论：不更换引擎，继续 Godot 4.7 + GLES3 Compatibility（Web 兼容性最佳）。**

玩法层对齐 **Godot Roguelike Basic Set**；发布层对齐 **godot-project-template** 的 Web-first 流程。

---

## 2. 目标目录结构（渐进迁移）

```
scripts/
  core/                 # 全局管理（Autoload）
    platform_service.gd # Web / 移动 / 桌面检测
    game_director.gd    # 会话：难度、存档、续关
  actions/              # 输入 → 游戏动作（Roguelike Basic Set 模式）
    game_action.gd
  handlers/
    input_handler.gd    # 统一键盘/鼠标路由
  entities/             # 已有 entity 脚本（逐步迁入）
    player_controller.gd, monster_entity.gd, item_entity.gd
  systems/              # 纯逻辑模块
    turn_resolver.gd, entity_spawner.gd, path_guide.gd, save_manager.gd
  presentation/         # 渲染与 UI（逐步迁入）
    maze_renderer.gd, mobile_renderer.gd, ui_panel.gd, mobile_controls.gd
  world/
    maze_generator.gd
  main.gd               # 薄协调器：装配模块、转发信号
assets/
  data/                 # JSON 配置（DataLoader）
  sprites/              # 16×16 标准贴图（Web 友好）
  high_quality/         # 32×32 角色（PC / 大屏 Web）
  art/                  # 32×32 源稿
tests/
web/                    # Web 导出产物（部署目录）
deploy/project.conf     # 静态站点配置
```

> 当前迭代：**新增 `core/`、`actions/`、`handlers/`、`asset_registry.gd`**，旧路径保持兼容，避免大规模移动破坏 Git 历史。

---

## 3. 核心管理逻辑

### PlatformService（Autoload）

- 检测 `OS.has_feature("web")` / `mobile`
- Web 窄屏或触屏 → 启用移动 UI（`MobileControls`）
- 提供 `get_target_cell_size()`：Web 移动略大触控区域

### GameDirector（Autoload）

- 难度选择与存档冲突确认
- 续关摘要 `_get_continue_hint()`
- 统一 `begin_session(force_new)` 入口

### InputHandler + GameAction

- 输入事件 → 枚举动作（MOVE / USE_ITEM / REGENERATE / …）
- `main.gd` 只执行动作，不解析原始 `InputEvent`

### AssetRegistry

- 集中 sprite 路径、期望分辨率、Web 加载优先级
- 渲染器通过 Registry 取路径，避免硬编码散落

---

## 4. Web 双端发布策略

| 维度 | PC 浏览器 | 移动浏览器 |
|------|-----------|------------|
| 渲染 | `MazeRenderer` + 侧栏 | `MobileRenderer` + 虚拟 D-pad |
| 输入 | 键盘 WASD + 鼠标 | 触屏 + 滑动 |
| 视口 | 1280×720 stretch expand | 同视口，窄屏自动切移动布局 |
| 导出 | `export_web.sh` → `web/index.html` | 同包；PWA 可选 |
| 纹理 | VRAM 压缩 desktop + **mobile** | 减小 WASM 体积 |
| 部署 | `deploy/project.conf` → maze.mplusm.site | 同静态站点 + viewport meta |

**引擎设置：**

- `renderer/rendering_method=gl_compatibility`
- `window/stretch/mode=canvas_items`
- Export Web：`thread_support=false`（Safari 兼容）

---

## 5. 资产规范

| 类型 | 标准尺寸 | 目录 | 说明 |
|------|----------|------|------|
| 角色 | 32×32 | `high_quality/player/` | 源稿 `art/1-4.png` |
| 角色回退 | 16×16 | `sprites/player/` | 低带宽回退 |
| 地形/道具 | 16×16 | `sprites/terrain|item/` | 与 `cell_size=40` 配合 |
| UI 心形 | 18×18 | `sprites/heart/` | 移动端 HUD 2× 清晰 |

Import：像素风 → Filter **Nearest**，Compress **Lossless**（Web 小图）。

详见 `assets/sprites/ASSET_MANIFEST.md`。

---

## 6. CI / 发布命令

```bash
./run_tests.sh              # 本地测试
./export_web.sh             # 导出 Web → web/
# 部署：将 web/ 同步至 deploy/project.conf 指定目录
```

GitHub Actions：`test.yml`（Godot 4.7 headless）+ `web-export.yml`（可选导出校验）。

---

## 7. 与 GDD 的映射

| GDD 概念 | 框架模块 |
|----------|----------|
| 回合制移动 | `TurnResolver` + `InputHandler` |
| 数据驱动 | `DataLoader` + `assets/data/*.json` |
| 实体 | `EntitySpawner` + `entities/*` |
| 迷雾/地图 | `MazeGenerator` + `MazeRenderer` |
| 存档 | `SaveManager` + `GameDirector` |
