# Combat System Design Document: 敦煌迷途

*Created: 2026-06-24*
*Status: Draft*
*Version: 1.0*

---

## 1. Overview — 战斗系统概述

敦煌迷途采用**碰撞战斗（Bump-to-Attack）**机制：玩家向怪物所在格子移动时，自动触发战斗。战斗在同一回合内结算——玩家先攻击，怪物若存活则反击。

核心设计理念：

| 原则 | 说明 |
| ---- | ---- |
| **简洁** | 无主动技能选择，决策集中在"打还是绕" |
| **可预测** | 伤害公式透明，玩家能算出风险 |
| **地形驱动** | 战斗数值受地形影响，与探索决策耦合 |
| **单回合制** | 一次碰撞 = 一次攻击交换，无多回合战斗 |

当前实现中，战斗在 `main.gd:70` 的 `_combat()` 函数中执行。未来可将此逻辑迁移至独立的 `CombatResolver` 节点以解耦。

---

## 2. Player Fantasy — 玩家在战斗中的感受

**目标感受**：每一场遭遇都是"硬碰硬"——你不是在施展华丽技能，而是在用蛮力和判断穿越荒野。

**具体体验**：

- **紧张**：血量有限，怪物伤害可预测但不可忽视
- **权衡**：强怪守着好位置，绕路消耗步数，硬拼消耗血量
- **成长感**：通过数值提升（防御、暴击）而非技能解锁来变强
- **孤独**：没有队友，没有复活，倒下就是倒下

**反面设计**（不应该是什么）：

- ❌ 不是动作游戏——没有闪避、连招
- ❌ 不是 RPG——没有技能树、装备选择
- ❌ 不是割草——玩家始终处于资源紧张状态

---

## 3. Detailed Rules — 完整战斗规则

### 3.1 触发机制

```
玩家按下移动键 → 检查目标格是否有怪物
  → 有怪物：触发 _combat()，本回合不计入步数
  → 无怪物：正常移动，步数 +1
```

**关键规则**：

- 战斗在同一帧内结算（玩家攻击 → 怪物反击）
- 玩家始终先手
- 击败怪物后玩家停留在怪物原位置
- 怪物被击败后从场景中移除，无法复活

### 3.2 伤害计算

#### 玩家攻击怪物

```
base_damage = player.atk + randi_range(-1, 2)
final_damage = maxi(base_damage, 1)
```

- 基础攻击力：5（来自 `player_stats.json`）
- 随机波动：-1 ~ +2
- 最低伤害：1（保证不会完全无效）

#### 怪物攻击玩家

```
base_damage = monster.atk + randi_range(-1, 1)
final_damage = maxi(base_damage, 0)
```

- 攻击力取决于怪物类型（2-4）
- 随机波动：-1 ~ +1
- 最低伤害：0（可能完全不受伤）

### 3.3 防御机制（建议添加）

当前实现中没有防御属性。建议在 `player_stats.json` 和 `monster_data.json` 中添加 `def` 字段：

```
final_damage_to_player = maxi(monster.atk + randi_range(-1, 1) - player.def, 0)
final_damage_to_monster = maxi(player.atk + randi_range(-1, 2) - monster.def, 0)
```

**防御值建议**：

| 实体 | def | 说明 |
| ---- | ---- | ---- |
| 玩家 | 1 | 旅人有基本防护 |
| 沙蝎 | 0 | 甲壳脆弱 |
| 沙虫 | 1 | 厚皮减伤 |
| 石魔 | 2 | 岩石之躯 |
| 水妖 | 0 | 灵体无防御 |
| 盗匪 | 1 | 有基本护具 |

### 3.4 暴击系统（建议添加）

暴击提供伤害爆发，增加战斗的紧张感和策略性。

```
if randf() < crit_rate:
    final_damage *= crit_multiplier
```

**参数建议**：

| 参数 | 玩家 | 怪物 | 说明 |
| ---- | ---- | ---- | ---- |
| crit_rate | 10% | 5% | 玩家暴击率更高，提供正反馈 |
| crit_multiplier | 1.5x | 1.5x | 暴击伤害倍率 |

**实现方式**：在 `player_stats.json` 和 `monster_data.json` 中添加 `crit_rate` 和 `crit_multiplier` 字段。

### 3.5 地形对战斗的影响

地形不仅决定怪物种类，还提供战斗加成。这与 game-concept.md 中"地形即玩法"的核心支柱一致。

| 地形 | 战斗效果 | 设计理由 |
| ---- | ---- | ---- |
| **汉唐古道** (ancient_road) | 玩家 +1 攻击 | 铺石路利于发挥，旅人更有信心 |
| **沙漠** (desert) | 怪物 +1 攻击 | 沙虫熟悉主场，玩家行动受限 |
| **石窟** (grotto) | 石魔 +1 攻击 | 石魔从石壁汲取力量 |
| **绿洲** (oasis) | 玩家每战恢复 1 HP | 绿洲灵气治愈旅人 |
| **沙地** (sand) | 无特殊效果 | 中性地形 |

**实现方式**：在 `_combat()` 函数中检查当前地形，应用加成。地形加成应记录在 `terrain_data.json` 的 `combat_bonus` 字段中。

### 3.6 地形移动成本（建议扩展）

不同地形消耗不同步数（或行动点），增加路径规划深度：

| 地形 | 移动成本 | 说明 |
| ---- | ---- | ---- |
| 古道 | 1 | 平坦铺石路 |
| 沙地 | 1 | 普通沙地 |
| 沙漠 | 2 | 松软沙丘，移动困难 |
| 绿洲 | 1 | 湿润地面 |
| 石窟 | 2 | 需要攀爬栈道 |

---

## 4. Formulas — 所有数学公式

### 4.1 当前公式

```gdscript
# 玩家攻击怪物
player_damage_to_monster = maxi(player.atk + randi_range(-1, 2), 1)

# 怪物攻击玩家
monster_damage_to_player = maxi(target.atk + randi_range(-1, 1), 0)
```

### 4.2 建议完整公式

```gdscript
# ===== 玩家攻击怪物 =====
func calc_player_attack(monster: MonsterEntity, terrain: String) -> int:
    var raw = player.atk + randi_range(-1, 2)

    # 地形加成
    var terrain_bonus = get_terrain_attack_bonus(terrain, "player")
    raw += terrain_bonus

    # 减去怪物防御
    var def = monster.def if monster.has_method("get") else 0
    raw -= def

    # 暴击判定
    var crit_rate = DataLoader.player_stats.get("crit_rate", 0.1)
    var crit_mult = DataLoader.player_stats.get("crit_multiplier", 1.5)
    if randf() < crit_rate:
        raw = int(raw * crit_mult)
        # 记录暴击状态用于显示

    return maxi(raw, 1)

# ===== 怪物攻击玩家 =====
func calc_monster_attack(monster: MonsterEntity, terrain: String) -> int:
    var raw = monster.atk + randi_range(-1, 1)

    # 地形加成
    var terrain_bonus = get_terrain_attack_bonus(terrain, "monster")
    raw += terrain_bonus

    # 减去玩家防御
    var player_def = DataLoader.player_stats.get("def", 1)
    raw -= player_def

    # 怪物暴击判定
    var crit_rate = monster.crit_rate if monster.has_method("get") else 0.05
    var crit_mult = monster.crit_multiplier if monster.has_method("get") else 1.5
    if randf() < crit_rate:
        raw = int(raw * crit_mult)

    return maxi(raw, 0)

# ===== 绿洲回血 =====
func calc_oasis_heal(terrain: String) -> int:
    if terrain == "oasis":
        return 1
    return 0
```

### 4.3 期望伤害计算（用于平衡）

期望伤害 = (base_damage_min + base_damage_max) / 2

**玩家期望伤害（无地形加成）**：

| 怪物 | 基础攻击力 | 随机范围 | 期望伤害 |
| ---- | ---- | ---- | ---- |
| 沙蝎 | 5 | 4-7 | 5.5 |
| 沙虫 | 5 | 4-7 | 5.5 |
| 石魔 | 5 | 4-7 | 5.5 |
| 水妖 | 5 | 4-7 | 5.5 |
| 盗匪 | 5 | 4-7 | 5.5 |

**怪物期望伤害（无地形加成）**：

| 怪物 | 攻击力 | 随机范围 | 期望伤害 |
| ---- | ---- | ---- | ---- |
| 沙蝎 | 2 | 1-3 | 2.0 |
| 沙虫 | 3 | 2-4 | 3.0 |
| 石魔 | 4 | 3-5 | 4.0 |
| 水妖 | 3 | 2-4 | 3.0 |
| 盗匪 | 4 | 3-5 | 4.0 |

**击杀回合数**（玩家期望伤害 ÷ 怪物 HP）：

| 怪物 | HP | 期望伤害 | 击杀回合 |
| ---- | ---- | ---- | ---- |
| 沙蝎 | 6 | 5.5 | ~2 |
| 沙虫 | 10 | 5.5 | ~2 |
| 石魔 | 15 | 5.5 | ~3 |
| 水妖 | 8 | 5.5 | ~2 |
| 盗匪 | 12 | 5.5 | ~3 |

**玩家可承受攻击次数**（HP=20）：

| 怪物 | 期望伤害 | 可承受次数 | 说明 |
| ---- | ---- | ---- | ---- |
| 沙蝎 | 2.0 | 10 | 安全 |
| 沙虫 | 3.0 | 6 | 需注意 |
| 石魔 | 4.0 | 5 | 危险 |
| 水妖 | 3.0 | 6 | 需注意 |
| 盗匪 | 4.0 | 5 | 危险 |

---

## 5. Edge Cases — 边界情况

### 5.1 0 HP

| 场景 | 当前行为 | 建议行为 |
| ---- | ---- | ---- |
| 玩家 HP=0 | 触发 `died` 信号，游戏结束 | 保持不变 |
| 怪物 HP=0 | 触发 `defeated` 信号，怪物移除 | 保持不变 |
| 玩家攻击后怪物 HP=0 | 怪物不反击（已移除） | 保持不变 |
| 怪物攻击后玩家 HP=0 | 游戏结束，不再处理后续 | 保持不变 |

### 5.2 同归于尽

当前实现：玩家先手攻击，怪物死亡后不反击。若怪物在玩家攻击前就 HP=0，不会出现同归于尽。

**建议**：如果玩家 HP=1 且怪物攻击力最低为 0，仍可能存活。保持当前先手机制即可。

### 5.3 逃跑

当前实现：无逃跑机制。玩家只能绕路。

**建议**：不添加逃跑机制。理由：
- 与"孤独旅人"的 Fantasy 一致——你无处可逃
- 简化战斗决策——只有"打"和"绕"
- 保持紧张感——遭遇就是生死

### 5.4 多怪物同格

当前实现：`_spawn_monsters()` 中使用 `occupied` 字典防止重叠。理论上不会出现多怪物同格。

**防御性代码**：`_get_monster_at()` 返回第一个找到的怪物。若出现重叠，只处理一个。

### 5.5 怪物在出口格

当前实现：出口格不会生成怪物（`occupied` 字典包含 `exit_pos`）。

**建议**：保持此规则。若需增加难度，可在困难关卡中允许出口格有怪物。

### 5.6 战斗中玩家死亡

当前实现：`_combat()` 中怪物攻击玩家后，若 HP=0，`died` 信号触发，`game_over` 设为 true。下一帧输入被拦截。

**注意**：当前代码在 `_combat()` 中没有检查玩家是否在怪物攻击前已死亡。建议在怪物攻击前添加 `if player.is_alive()` 检查。

---

## 6. Dependencies — 依赖的其他系统

| 依赖系统 | 依赖方式 | 说明 |
| ---- | ---- | ---- |
| **地形系统** | 读取当前地形 | 决定怪物类型和战斗加成 |
| **迷宫系统** | 提供格子信息 | 判断移动是否合法 |
| **数据加载器** | 读取配置 | 获取玩家/怪物属性 |
| **战争迷雾** | 间接依赖 | 影响玩家是否能看到怪物 |

**未来依赖**（扩展时需考虑）：

| 系统 | 依赖方式 |
| ---- | ---- |
| **道具系统** | 消耗品影响战斗数值 |
| **状态效果** | 中毒、虚弱等 Debuff |
| **音效系统** | 战斗音效触发 |
| **粒子系统** | 暴击、击杀特效 |

---

## 7. Tuning Knobs — 可调参数列表

### 7.1 玩家属性（`player_stats.json`）

| 参数 | 当前值 | 建议范围 | 影响 |
| ---- | ---- | ---- | ---- |
| max_hp | 20 | 15-30 | 玩家生存能力 |
| base_atk | 5 | 4-7 | 击杀速度 |
| def | (无) | 0-3 | 减伤能力 |
| crit_rate | (无) | 0.05-0.15 | 暴击频率 |
| crit_multiplier | (无) | 1.3-2.0 | 暴击伤害 |
| reveal_radius | 3 | 2-5 | 视野范围 |

### 7.2 怪物属性（`monster_data.json`）

| 参数 | 当前值 | 建议范围 | 影响 |
| ---- | ---- | ---- | ---- |
| hp | 6-15 | 4-20 | 击杀难度 |
| atk | 2-4 | 1-6 | 威胁程度 |
| def | (无) | 0-4 | 减伤能力 |
| crit_rate | (无) | 0.03-0.1 | 怪物暴击率 |
| crit_multiplier | (无) | 1.2-1.8 | 怪物暴击伤害 |

### 7.3 伤害公式参数

| 参数 | 当前值 | 建议范围 | 影响 |
| ---- | ---- | ---- | ---- |
| player_roll_min | -1 | -2 ~ 0 | 玩家伤害下限 |
| player_roll_max | 2 | 1 ~ 4 | 玩家伤害上限 |
| monster_roll_min | -1 | -2 ~ 0 | 怪物伤害下限 |
| monster_roll_max | 1 | 0 ~ 3 | 怪物伤害上限 |
| player_min_damage | 1 | 1 ~ 2 | 保证最低伤害 |
| monster_min_damage | 0 | 0 ~ 1 | 怪物最低伤害 |

### 7.4 地形加成参数（建议添加到 `terrain_data.json`）

| 地形 | player_atk_bonus | monster_atk_bonus | heal_per_battle | 移动成本 |
| ---- | ---- | ---- | ---- | ---- |
| ancient_road | +1 | 0 | 0 | 1 |
| sand | 0 | 0 | 0 | 1 |
| desert | 0 | +1 | 0 | 2 |
| grotto | 0 | +1 | 0 | 2 |
| oasis | 0 | 0 | +1 | 1 |

### 7.5 系统参数

| 参数 | 当前值 | 建议范围 | 影响 |
| ---- | ---- | ---- | ---- |
| monster_density | 0.12 | 0.08-0.20 | 每格怪物概率 |
| combat_log_length | 4 | 3-6 | 战斗日志显示条数 |
| log_display_time | 3.0 | 2.0-5.0 | 日志显示时长（秒） |

---

## 8. Acceptance Criteria — 验收标准

### 8.1 核心功能

- [ ] 玩家向怪物格子移动时触发战斗，不消耗额外步数
- [ ] 玩家始终先手攻击
- [ ] 伤害公式正确执行：`base = atk + randi_range(roll_min, roll_max)`
- [ ] 最终伤害不低于 `min_damage`
- [ ] 暴击判定正确执行，伤害乘以 `crit_multiplier`
- [ ] 怪物被击败后从场景移除
- [ ] 玩家 HP 降至 0 时游戏结束

### 8.2 地形系统

- [ ] 不同地形提供不同的战斗加成
- [ ] 地形加成正确应用到伤害计算
- [ ] 绿洲每战恢复 1 HP
- [ ] 战斗日志显示地形效果

### 8.3 边界情况

- [ ] 0 HP 时不执行后续伤害
- [ ] 玩家先手击杀怪物时不承受反击
- [ ] 多怪物不会出现在同一格
- [ ] 出口格不生成怪物

### 8.4 UI/UX

- [ ] 战斗日志正确显示攻击和伤害信息
- [ ] 暴击时显示特殊提示（如"暴击！"）
- [ ] 怪物 HP 条实时更新
- [ ] 玩家 HP 条实时更新
- [ ] 地形效果在 HUD 中显示

### 8.5 数值平衡

- [ ] 玩家可在 2-3 回合内击杀最弱怪物（沙蝎）
- [ ] 玩家可在 3-4 回合内击杀最强怪物（石魔）
- [ ] 玩家在不使用绿洲的情况下，可承受约 5 次石魔攻击
- [ ] 地形加成使战斗结果产生可观测差异

### 8.6 代码质量

- [ ] 伤害计算逻辑可独立测试
- [ ] 地形加成配置化，无需修改代码
- [ ] 暴击参数可从配置文件读取
- [ ] 战斗逻辑与渲染逻辑分离

---

## Appendix A: 实现优先级

| 优先级 | 功能 | 工作量 | 理由 |
| ---- | ---- | ---- | ---- |
| **P0** | 防御属性 | 小 | 增加战斗深度，配置化改动 |
| **P0** | 地形战斗加成 | 小 | 核心支柱"地形即玩法"的延伸 |
| **P1** | 暴击系统 | 中 | 增加战斗紧张感 |
| **P1** | 怪物防御属性 | 小 | 使不同怪物有差异化防御 |
| **P2** | 地形移动成本 | 中 | 增加路径规划深度 |
| **P2** | 战斗音效 | 小 | 提升打击感 |
| **P3** | 战斗动画 | 大 | 视觉反馈，但 MVP 可选 |

---

## Appendix B: 数据结构变更

### player_stats.json（新增字段）

```json
{
  "max_hp": 20,
  "base_atk": 5,
  "def": 1,
  "crit_rate": 0.1,
  "crit_multiplier": 1.5,
  "move_speed": 1.0,
  "reveal_radius": 3
}
```

### monster_data.json（新增字段）

```json
{
  "sand": {
    "name": "沙蝎",
    "symbol": "蝎",
    "hp": 6,
    "atk": 2,
    "def": 0,
    "crit_rate": 0.05,
    "crit_multiplier": 1.5,
    "color": [0.7, 0.5, 0.2]
  }
}
```

### terrain_data.json（新增字段）

```json
{
  "grotto": {
    "name": "石窟",
    "floor_color": [0.55, 0.5, 0.45],
    "wall_color": [0.3, 0.28, 0.25],
    "combat_bonus": {
      "player_atk": 0,
      "monster_atk": 1,
      "heal": 0
    },
    "move_cost": 2
  }
}
```
