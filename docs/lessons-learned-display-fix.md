# 游戏地图底部行显示问题 - 解决过程与经验教训

## 问题描述

在Godot 4.7开发的敦煌迷宫游戏中，地图最底部的2行格子始终不可见，玩家无法看到完整的迷宫区域。

## 解决历程

### 尝试1：修改GameCamera的Y轴钳制

**方案**：在 `game_camera.gd` 中增加20px偏移量

```gdscript
# 旧代码
target_pos.y = clampf(target_pos.y, half_view.y, maze_pixel_h - half_view.y)

# 新代码
target_pos.y = clampf(target_pos.y, half_view.y, maze_pixel_h - half_view.y + 20)
```

**结果**：❌ 无效。问题不在相机钳制，而在更根本的坐标计算。

### 尝试2：修复非滚动模式的缩放计算

**方案**：在 `main.gd` 中修复缩放因子计算，添加居中逻辑

```gdscript
# 修复前：scale_f计算但未使用
# 修复后：正确应用缩放并居中
var scale_f = mini(int((game_w - 8) / maze_pixel_w), int((vp.y - 8) / maze_pixel_h))
scale_f = maxi(scale_f, 1)
offset = Vector2((game_w - scaled_w) / 2, (vp.y - scaled_h) / 2)
```

**结果**：❌ 无效。根本原因是视口尺寸计算错误。

### 尝试3：添加底部边距

**方案**：为Godot编辑器底部工具栏预留40px空间

```gdscript
var game_h: float = vp.y - 40  # 预留工具栏空间
```

**结果**：❌ 无效。问题不在编辑器工具栏遮挡。

### 尝试4：全局缩放0.9

**方案**：将整个地图缩小10%

```gdscript
var render_scale: float = 0.9
var maze_pixel_w: float = maze_width * cell_size * render_scale
```

**结果**：❌ 无效。缩小后底部行仍然被裁剪。

### 尝试5：相对坐标自适应缩放（最终方案）

**方案**：从窗口四角计算相对坐标，自动缩放确保完整显示

```gdscript
var game_w: float = vp.x - panel_w
var game_h: float = vp.y - 40

var scale_x: float = game_w / maze_pixel_w
var scale_y: float = game_h / maze_pixel_h
var draw_scale: float = minf(scale_x, scale_y)
draw_scale = minf(draw_scale, 1.0)

var scaled_w: float = maze_pixel_w * draw_scale
var scaled_h: float = maze_pixel_h * draw_scale
var offset: Vector2 = Vector2((game_w - scaled_w) / 2, (game_h - scaled_h) / 2)
```

**结果**：✅ 成功！整个迷宫完整显示，四边都有边距。

## 根本原因分析

1. **视口尺寸误解**：`get_viewport_rect().size` 返回的是完整视口大小，但实际可用游戏区域更小
2. **坐标系混淆**：使用绝对坐标而非相对坐标，导致边界计算错误
3. **过度复杂化**：引入GameCamera滚动机制增加了复杂度，但没有解决核心问题

## 关键教训

### 1. 优先使用相对坐标

```gdscript
# ❌ 错误：绝对坐标
var offset = Vector2.ZERO

# ✅ 正确：从窗口角落计算相对坐标
var offset = Vector2((game_w - scaled_w) / 2, (game_h - scaled_h) / 2)
```

### 2. 先计算可用区域再绘制

```gdscript
# ✅ 正确流程
var game_w = vp.x - panel_w      # 1. 计算可用宽度
var game_h = vp.y - margin        # 2. 计算可用高度
var scale = minf(game_w / maze_w, game_h / maze_h)  # 3. 计算缩放
var offset = Vector2(...)         # 4. 计算居中偏移
```

### 3. 避免过早优化

- 不要一开始就引入复杂机制（如Camera滚动）
- 先用最简单的方法验证可行性
- 只有在简单方法不够时才增加复杂度

### 4. 测试时关注边界情况

- 始终测试地图的最大尺寸
- 检查四角和边缘是否完整显示
- 使用不同分辨率的窗口测试

## 代码变更记录

| 文件 | 变更 | 效果 |
|------|------|------|
| `game_camera.gd` | 添加Y轴+20px偏移 | ❌ 无效 |
| `main.gd` | 修复缩放计算+居中 | ❌ 无效 |
| `main.gd` | 添加game_h=vp.y-40 | ❌ 无效 |
| `main.gd` | 全局缩放0.9 | ❌ 无效 |
| `main.gd` | 相对坐标自适应缩放 | ✅ 成功 |

## 最终方案优势

1. **简单**：不需要Camera滚动机制
2. **可靠**：从窗口角落计算，确保完整显示
3. **自适应**：自动计算最佳缩放比例
4. **可维护**：代码清晰，易于理解和修改

## 适用场景

此方案适用于：
- 需要完整显示整个地图的游戏
- 地图尺寸可能变化的场景
- 需要自适应不同分辨率的情况

不适用于：
- 需要无缝滚动的大世界地图
- 需要精确控制相机行为的场景

---

*创建日期：2026-06-26*
*项目：敦煌迷宫游戏 (Dunhuang Maze Game)*
*Godot版本：4.7*
