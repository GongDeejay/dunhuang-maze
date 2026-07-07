# 敦煌迷途 (Dunhuang Maze)

Godot 4.7 敦煌主题迷宫 Roguelike — 探索 procedural 迷宫、收集家人、穿越三关。

## 要求

- [Godot 4.7](https://godotengine.org/)（含 headless 用于测试）

## 运行

```bash
# 在 Godot 编辑器中打开 project.godot，按 F5 运行

# Headless 自动测试
./run_tests.sh
```

## Web 导出

1. Godot 编辑器 → Project → Export → Web → Export Project
2. 输出到 `web/` 目录
3. 静态部署配置见 `deploy/project.conf`（目标：`maze.mplusm.site`）

## 项目结构

```
scripts/
  main.gd           # 游戏协调器
  game_state.gd     # 状态机
  turn_resolver.gd  # 移动后处理链
  entity_spawner.gd # 怪物/道具生成
  maze_renderer.gd  # PC 渲染
  mobile_renderer.gd# 移动端渲染
  save_manager.gd   # 存档
assets/data/        # JSON 游戏配置
tests/              # Headless 测试
design/             # GDD 与项目文档
```

## 操作

| 按键 | 功能 |
|------|------|
| WASD / 方向键 | 移动 |
| E | 使用道具 |
| R | 重新生成 / 下一关 |
| Q | 返回难度选择 |

## 开发规范

- 迷宫比特语义：`1` = 通道开放，修改 `has_wall()` / 绘制逻辑时需全项目 grep 检查
- 新功能优先独立 `.gd` 模块，保持 `main.gd` 为协调器
- 提交前运行 `./run_tests.sh`
