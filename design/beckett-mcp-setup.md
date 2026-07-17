# Godot MCP 连接指南（Beckett + Web 导出）

## 双 MCP 架构

| 服务 | 地址 | 用途 |
|------|------|------|
| **Beckett** | `http://127.0.0.1:8770/mcp` | 编辑器内：场景/脚本/运行/日志（Lite） |
| **dunhuang-export** | stdio `tools/godot_export_mcp/server.mjs` | CLI：Web 导出、测试 |

## 1. Beckett（Godot 编辑器 MCP）

1. 用 Godot 4.7 打开 `project.godot`
2. **项目 → 项目设置 → 插件** → 启用 **Beckett**
3. 在 Beckett 面板点击 **Start**（`project.godot` 中 `beckett/autostart=false`，避免与 CLI 导出抢端口）
4. 服务监听 `http://127.0.0.1:8770/mcp`

```json
{
  "mcpServers": {
    "beckett": {
      "type": "http",
      "url": "http://127.0.0.1:8770/mcp"
    },
    "dunhuang-export": {
      "command": "node",
      "args": ["tools/godot_export_mcp/server.mjs"]
    }
  }
}
```

5. **Cursor 设置 → MCP** 刷新，应看到 `beckett` + `dunhuang-export`

### Beckett Lite 可用工具（39 个）

`play_scene`, `get_scene_tree`, `write_script`, `validate_script`, `logs_read`, `wait_until`, …

### 导出说明

- **Lite 不含** `export_project`（需 Beckett Full）
- Web 测试包请用 MCP 工具 **`export_web`** 或终端 `./export_web.sh`

## 2. Web 测试导出流程

```
Agent: export_web (dunhuang-export MCP)
  或: ./export_web.sh
→ web/index.html + index.wasm + index.pck
→ 本地: cd web && python3 -m http.server 8060
→ 部署: deploy/project.conf → maze.mplusm.site
```

## 3. PWA / 呈现

- **不添加独立 PWA 图标包** — 保持 canvas 文字绘制 UI 与 HTML 标题「敦煌迷途」
- 导出预设 `progressive_web_app/enabled=false`（避免空图标校验）；安装体验靠浏览器标签标题 + 游戏内文字

## 4. 故障排查

| 现象 | 处理 |
|------|------|
| Beckett 连接失败 | 确认 Godot 编辑器已打开且插件启用 |
| export_web 失败 | 确认 `rendering/textures/vram_compression/import_etc2_astc=true`；`BECKETT_ENABLE=0 ./export_web.sh` |
| UID duplicate | 运行 `./tools/optimize_sprites.sh` 后 `--import` |
| CI 导出失败 | 见 `.github/workflows/web-export.yml` |
