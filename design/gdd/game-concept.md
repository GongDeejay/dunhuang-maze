# 敦煌迷途 — 游戏概念文档

*Created: 2026-06-24*
*Status: Draft*

---

## Elevator Pitch

> 一款敦煌主题的迷宫探索Roguelike，玩家穿越汉唐古道、无人区、三危山三大地形区域，在随机生成的迷宫中与地形怪物战斗、解开谜题，最终抵达绿洲。

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Roguelike 迷宫探索 |
| **Platform** | PC (Godot 4) |
| **Target Audience** | 喜欢探索与策略战斗的独立游戏玩家 |
| **Player Count** | Single-player |
| **Session Length** | 15-30 分钟 |
| **Monetization** | None (prototype) |
| **Estimated Scope** | Small (2-4 weeks prototype) |
| **Comparable Titles** | Crown Trick, 神之亵渎 (地图探索部分), Into the Breach |

---

## Core Fantasy

你是一名穿越敦煌古道的旅人，眼前是无尽的迷宫与未知的危险。你必须凭借智慧和勇气，在沙暴与迷雾中找到通往绿洲的路。

核心幻想：**在荒凉与神秘并存的敦煌古道中，凭一己之力穿越迷宫抵达终点。**

---

## Unique Hook

> "敦煌文化主题 × 随机迷宫探索 × 地形驱动的战斗系统"

每次游玩都是不同的迷宫布局，但三大地域（汉唐古道→无人区→三危山）的文化氛围和怪物类型始终保持。地形不只是视觉背景——它决定了你会遇到什么敌人、走哪条路。

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Challenge** (obstacle course, mastery) | 1 | 迷宫路线规划 + 战斗策略选择 |
| **Discovery** (exploration, secrets) | 2 | 三大地形区域各有独特怪物和视觉风格 |
| **Fantasy** (make-believe, role-playing) | 3 | 敦煌古道、石窟、绿洲的文化沉浸感 |
| **Sensation** (sensory pleasure) | 4 | 地形色彩变化 + 战斗反馈 + HUD信息层次 |
| **Narrative** (drama, story arc) | N/A | Prototype阶段暂不涉及 |
| **Fellowship** (social connection) | N/A | 单人游戏 |

### Key Dynamics (Emergent player behaviors)

- 玩家会在不同地形区域调整策略（古道安全但无收益，石窟危险但有宝物）
- 玩家会记录已探索区域以规划最优路径
- 玩家会在遭遇强敌时选择绕行或正面迎战

### Core Mechanics (Systems we build)

1. **随机迷宫生成** — 递归回溯算法 + BFS验证，每次不同但保证可通达
2. **地形系统** — 5种地形（沙地/荒漠/石窟/绿洲/古道），双噪声+聚类生成
3. **碰撞战斗** — 进入怪物格子触发回合制战斗，地形决定怪物类型和强度
4. **战争迷雾** — 只有视野范围内可见，已探索区域永久显示
5. **数据驱动配置** — 所有数值外部化到JSON，可独立调整

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | 自由选择探索路线、战斗/回避决策 | Core |
| **Competence** (mastery, skill growth) | 迷宫导航能力提升 + 战斗策略优化 | Core |
| **Relatedness** (connection, belonging) | 单人游戏，暂不涉及 | Minimal |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Explorers** (discovery, understanding systems) — 三大地形各有特色，迷宫每次不同
- [x] **Achievers** (goal completion, collection) — 从起点到终点的通关目标
- [ ] **Socializers** (relationships, cooperation) — 不适用
- [ ] **Killers/Competitors** (domination, PvP) — 不适用

### Flow State Design

- **Onboarding curve**: 第一关（古道）怪物弱、地形简单，教玩家基本操作
- **Difficulty scaling**: 随区域推进怪物增强（古道→沙地→荒漠→石窟→绿洲）
- **Feedback clarity**: HP条实时显示 + 战斗日志记录每次攻防
- **Recovery from failure**: 死亡后按R重新开始，无永久惩罚

---

## Core Loop

### Moment-to-Moment (30 seconds)
移动 → 探索迷宫 → 遭遇怪物 → 战斗 → 继续前进。每一步都是决策：往哪走、打还是绕。

### Short-Term (5-15 minutes)
完成一个地形区域的探索，从一种地形过渡到下一种。比如从古道穿越到荒漠区。

### Session-Level (30-120 minutes)
一次完整的游戏：从起点出发，穿越三大地形区域，抵达绿洲出口。通关或死亡后重新开始。

### Long-Term Progression
Prototype阶段无持久进度。未来可加入：角色升级、解锁新能力、收集敦煌文物。

### Retention Hooks
- **Curiosity**: 下一区域会遇到什么新怪物？绿洲里有什么？
- **Investment**: 已探索区域的路径记忆，不想从头再来
- **Mastery**: 优化通关步数，减少战斗损耗

---

## Game Pillars

### Pillar 1: 地形即玩法
地形不仅是背景——它决定怪物类型、视觉风格、策略选择。

*Design test*: 如果一个功能不与地形产生关联（比如不同地形有不同效果），就不做。

### Pillar 2: 迷宫探索的紧张感
战争迷雾 + 随机生成 = 每一步都有未知。

*Design test*: 如果一个功能让探索变得无聊（比如全图可见），就不做。

### Pillar 3: 数据驱动可调
所有数值外部化到配置文件，不硬编码。

*Design test*: 如果一个数值写死在代码里而不是JSON里，就重构它。

### Anti-Pillars (What This Game Is NOT)

- **NOT 大世界开放探索**: 这是迷宫游戏，不是开放世界RPG
- **NOT 多人对战**: 单人体验，专注个人探索
- **NOT 复杂剧情**: Prototype阶段聚焦核心玩法，不加叙事

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Crown Trick | 回合制迷宫战斗 + 地形交互 | 敦煌文化主题 | 验证了地形驱动战斗的可行性 |
| Into the Breach | 战术决策 + 信息透明 | 非网格战术，而是迷宫探索 | 每步决策的重要性 |
| shan-shui-inf | 中国山水美学 | 敦煌风格而非通用山水 | 文化沉浸感参考 |

**Non-game inspirations**: 敦煌莫高窟壁画、丝绸之路历史、河西走廊地理地貌

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 18-35 |
| **Gaming experience** | Mid-core |
| **Time availability** | 15-30分钟单局 |
| **Platform preference** | PC |
| **Current games they play** | Into the Breach, Crown Trick, 王杀尖塔 |
| **What they're looking for** | 有文化深度的策略迷宫游戏 |
| **What would turn them away** | 操作太复杂、没有策略深度、纯视觉无玩法 |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4 (GDScript, 无需外部依赖) |
| **Key Technical Challenges** | 迷宫生成算法稳定性、地形过渡自然性、战斗数值平衡 |
| **Art Style** | 2D 俯视角, 像素/简约风格 |
| **Art Pipeline Complexity** | Low (原型阶段用draw API, 无外部资源) |
| **Audio Needs** | Minimal (原型阶段无音频) |
| **Networking** | None |
| **Content Volume** | Prototype: 1关, 5种地形, 5种怪物 |
| **Procedural Systems** | 迷宫随机生成 + 地形噪声生成 |

---

## Risks and Open Questions

### Design Risks
- 核心循环可能在30分钟后缺乏新鲜感（原型阶段怪物种类有限）
- 战斗系统过于简单（互相攻击，无策略深度）

### Technical Risks
- 迷宫生成偶有死路（已通过BFS验证解决）
- draw API性能在大地图时可能不足（已通过视野裁剪缓解）

### Market Risks
- Prototype阶段暂不考虑

### Scope Risks
- 地形噪声阈值硬编码，调参不便（可外置到JSON）
- 战斗公式硬编码，平衡困难（可外置到JSON）

### Open Questions
- 战斗系统是否需要更多策略元素（如技能、装备）？→ 待原型验证核心循环后决定
- 是否需要多关卡系统？→ 待原型验证后决定

---

## MVP Definition

**Core hypothesis**: 玩家觉得"在随机迷宫中穿越不同地形、与怪物战斗"这个核心循环有趣。

**Required for MVP**:
1. 随机迷宫生成 + BFS验证
2. 5种地形 + 视觉区分
3. 地形绑定怪物 + 碰撞战斗
4. 战争迷雾 + 视野系统
5. 死亡/通关判定

**Explicitly NOT in MVP**:
- 多关卡系统
- 角色升级/装备系统
- 音频/音乐
- 存档系统
- 复杂剧情

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1迷宫, 5地形, 5怪物 | 核心循环完整 | 1周 |
| **Vertical Slice** | 3关卡, 5地形, 8怪物 | +道具系统 | 2周 |
| **Alpha** | 10关卡, 5地形, 15怪物 | +升级系统+存档 | 4周 |
| **Full Vision** | 无限关卡, 5地形, 20+怪物 | +剧情+成就+排行榜 | 8周 |

---

## Next Steps

- [x] 安装 CCGS 参考框架
- [x] 完成核心原型（迷宫+地形+怪物+战斗+迷雾）
- [x] 数据驱动重构（JSON配置+DataLoader autoload）
- [ ] 验证重构代码在 Godot 中正常运行
- [ ] 外置剩余硬编码值（战斗公式、地形噪声阈值）
- [ ] 添加关卡切换系统
- [ ] 添加道具系统
- [ ] 添加怪物AI（主动追击/巡逻）
