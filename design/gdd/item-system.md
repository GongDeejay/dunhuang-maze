# Item System Design Document

*Created: 2026-06-24*
*Status: Draft*
*Depends on: game-concept.md, monster_data.json, player_stats.json, terrain_data.json*

---

## 1. Overview

道具系统为敦煌迷途的探索层增加资源管理维度。玩家在迷宫中拾取散落的敦煌遗物，
用于回复生命、增强战斗能力或获取地图信息。

**设计目标**：
- 增加路径选择的策略深度（绕路捡道具 vs 直接前进）
- 强化"孤独旅人"的核心幻想（有限资源，精打细算）
- 不增加操作复杂度（自动拾取，一键使用）

**不在范围内**：
- 装备系统（武器/护甲）
- 道具合成/制作
- 商店/交易系统

---

## 2. Player Fantasy

> 你在石窟中发现一卷古老的疗伤秘方，展开泛黄的纸卷，
> 依稀可辨的墨迹记载着千年前的智慧。你将它贴在伤口上，
> 沙漠的灼痛渐渐消退。

**拾取感受**：
- 发现阶段：迷雾中隐约可见的光点 → 走近发现道具
- 拾取阶段：自动拾取，播放简短的拾取动画（卷轴展开/符文闪烁）
- 使用阶段：即时效果，屏幕边缘短暂反馈（绿光回复/红光攻击）

**核心情感**：发现的惊喜 + 资源积累的安全感

---

## 3. Detailed Rules

### 3.1 道具类型

| Type | 效果类别 | 持续时间 | 使用方式 |
| ---- | ---- | ---- | ---- |
| `heal` | 回复HP | 即时 | 自动使用或按键使用 |
| `attack` | 临时提升攻击力 | 限时（回合数） | 自动使用 |
| `defense` | 临时减少伤害 | 限时（回合数） | 自动使用 |
| `reveal` | 揭示迷雾 | 即时/限时 | 自动使用 |

### 3.2 道具品质

| Rarity Tier | rarity 范围 | 含义 |
| ---- | ---- | ---- |
| Common | 0.10 - 0.20 | 常见，沙地/古道大量出现 |
| Uncommon | 0.05 - 0.10 | 较少，荒漠/绿洲出现 |
| Rare | 0.02 - 0.05 | 稀有，石窟深处或隐藏路径 |
| Legendary | 0.01 - 0.02 | 传说级，仅特定事件触发 |

### 3.3 获取方式

1. **地图拾取**：道具直接出现在迷宫地板上，玩家移动到该格自动拾取
2. **怪物掉落**：击败怪物后有 30% 概率掉落一个道具（按怪物所在地形的掉落表）
3. **地形宝箱**：石窟地形有 15% 概率生成宝箱，包含 Rare+ 道具

### 3.4 使用规则

- **自动使用**：heal 类道具在 HP < 50% 时自动使用
- **手动使用**：attack/defense/reveal 类道具通过快捷键使用
- **背包上限**：最多携带 3 个道具，超过时自动使用最低品质的同类道具
- **地形限制**：所有道具在任何地形均可使用

### 3.5 效果叠加

- 同类 buff 不叠加，取持续时间更长的那个
- heal 效果可叠加（但 HP 不超过 max_hp）
- 不同类 buff 可同时存在（attack + defense + reveal）

---

## 4. Formulas

### 4.1 道具掉落概率

```
drop_chance = base_drop_rate * terrain_modifier

base_drop_rate = 0.30
terrain_modifier:
  sand         = 0.8
  desert       = 1.0
  grotto       = 1.5
  oasis        = 1.2
  ancient_road = 1.0
```

### 4.2 道具稀有度权重

```
spawn_weight = rarity * terrain_affinity

terrain_affinity（地形对稀有道具的亲和度）:
  sand         = { common: 1.2, uncommon: 0.8, rare: 0.5, legendary: 0.2 }
  desert       = { common: 1.0, uncommon: 1.0, rare: 0.8, legendary: 0.5 }
  grotto       = { common: 0.6, uncommon: 1.2, rare: 1.5, legendary: 1.0 }
  oasis        = { common: 1.0, uncommon: 1.0, rare: 1.0, legendary: 0.8 }
  ancient_road = { common: 1.2, uncommon: 0.8, rare: 0.6, legendary: 0.3 }
```

### 4.3 Buff 持续时间衰减

```
effective_duration = base_duration * (1 + 0.1 * level_modifier)

level_modifier:
  汉唐古道 = 0
  无人区   = 1
  三危山   = 2
```

### 4.4 回复量公式

```
actual_heal = min(value, max_hp - current_hp)
```

### 4.5 攻击加成伤害

```
final_atk = base_atk + attack_buff
damage = max(1, final_atk - monster_def)
```

### 4.6 防御减伤

```
actual_damage = max(1, incoming_damage - defense_buff)
```

---

## 5. Edge Cases

### 5.1 HP 满时拾取回复道具
- 道具进入背包，不自动使用
- 如果背包已满，丢弃该道具

### 5.2 同时拾取多个同类 buff
- 保留持续时间更长的那个
- 丢弃较弱的

### 5.3 死亡时背包清空
- 死亡后所有携带道具消失
- 地图上未拾取的道具保留

### 5.4 道具与地形交互
- 沙地：attack buff 持续时间 -1（沙尘干扰）
- 石窟：reveal buff 效果 +2 格（石壁反射）
- 绿洲：heal 效果 +50%（水源加持）

### 5.5 三关卡切换
- 关卡切换时背包保留
- 地图上的未拾取道具消失

### 5.6 暂停/恢复
- buff 计时器在暂停时冻结
- 恢复后继续倒计时

---

## 6. Dependencies

### 6.1 输入系统
- 使用键：`E` 键或 `Space` 键使用背包中的道具
- 切换键：`Q` 键循环切换背包中的道具

### 6.2 战斗系统
- 读取 `attack_buff` 和 `defense_buff` 计算伤害
- 战斗结束后清除一次性 buff

### 6.3 迷雾系统
- `reveal` 类道具调用 `fog.reveal_area(center, radius)`
- `path_mark` 类道具调用 `fog.mark_path(start, end)`

### 6.4 怪物系统
- 怪物死亡时触发掉落逻辑
- 掉落表从 `monster_data.json` 的 terrain 字段索引

### 6.5 UI 系统
- 背包栏显示在屏幕右下角
- buff 状态显示在 HP 条下方
- 道具拾取时显示浮动文字提示

---

## 7. Tuning Knobs

| 参数 | 默认值 | 说明 | 调整方向 |
| ---- | ---- | ---- | ---- |
| `base_drop_rate` | 0.30 | 怪物掉落基础概率 | ↑ 增加道具获取感 |
| `max_backpack_size` | 3 | 背包上限 | ↑ 降低资源管理压力 |
| `heal_auto_threshold` | 0.5 | 自动使用回复道具的HP阈值 | ↓ 更保守的自动使用 |
| `buff_base_duration` | 5 | buff 基础持续回合数 | ↑ 延长增益效果 |
| `rarity_spawn_weight` | 1.0 | 稀有道具生成权重乘数 | ↑ 增加稀有道具出现率 |
| `terrain_heal_bonus` | 0.5 | 绿洲地形回复加成 | ↑ 绿洲的战略价值 |
| `grotto_chest_rate` | 0.15 | 石窟宝箱生成率 | ↑ 石窟的探索奖励 |

---

## 8. Acceptance Criteria

### 8.1 基础功能
- [ ] 玩家移动到道具格子时自动拾取
- [ ] 背包 UI 正确显示已拾取道具（最多3个）
- [ ] 使用回复道具后 HP 正确增加（不超过 max_hp）
- [ ] 使用攻击/防御 buff 后对应属性正确变化
- [ ] buff 持续时间结束后效果正确消失

### 8.2 掉落系统
- [ ] 击败怪物后有概率掉落道具
- [ ] 掉落道具的稀有度符合地形亲和度表
- [ ] 石窟地形能生成宝箱

### 8.3 边界情况
- [ ] HP 满时拾取回复道具，道具进入背包
- [ ] 背包满时拾取新道具，自动使用最弱的同类道具
- [ ] 死亡后背包清空，地图道具保留
- [ ] 暂停时 buff 计时器冻结

### 8.4 体验质量
- [ ] 道具拾取有视觉反馈（浮动文字）
- [ ] buff 激活时有状态指示（HP 条下方图标）
- [ ] 道具使用音效播放正确
- [ ] 不同地形的道具亲和度差异可感知

### 8.5 性能
- [ ] 100 个道具同时存在时帧率 > 30fps
- [ ] 道具拾取/使用无明显卡顿

---

## Appendix: 快捷键映射

| Key | Action |
| ---- | ---- |
| `E` / `Space` | 使用当前选中的道具 |
| `Q` | 切换到下一个道具 |
| `1-3` | 直接使用对应背包格的道具 |
