# Sprite 资产清单

*Web（PC + 移动浏览器）双端 | 像素风 Nearest 过滤*

## 可用资源总览

| 目录 | 文件数 | 标准尺寸 | 用途 | 状态 |
|------|--------|----------|------|------|
| `sprites/player/` | 4 | 16×16 | 角色低清回退 | ✅ 可用 |
| `high_quality/player/` | 4 | **32×32** | 角色高清（优先） | ✅ 已从 `art/` 同步 |
| `art/` | 4 | 32×32 | 角色源稿 | ✅ 主源 |
| `sprites/terrain/` | 17 | 16×16 | 五地形 + 变体 | ✅ 可用 |
| `sprites/item/` | 4 | 16×16（shield 18×18） | 道具图标 | ✅ 可用 |
| `sprites/heart/` | 2 | **18×18** | 移动端 HUD | ✅ 已放大 |

## 角色映射

| 文件 | 角色 | JSON key |
|------|------|----------|
| `dj.png` | 玩家 | — |
| `le.png` | 妈妈 | `family_1` |
| `mac.png` | 哥哥 | `family_2` |
| `mcking.png` | 弟弟 | `family_3` |

源稿：`art/1.png`→dj, `art/2.png`→le, `art/3.png`→mac, `art/4.png`→mcking

## 地形

| 键 | 文件 |
|----|------|
| sand | `terrain/sand.png` |
| desert | `terrain/desert.png` |
| grotto | `terrain/hole/line.png` + cross 变体 |
| oasis | `terrain/oasis/defult.png` + pond/tree |
| ancient_road | `terrain/road/line.png` + cross 变体 |
| l1 第一关 | `terrain/l1/wall.png` `wall_alt.png` `wall_face.png` `floor_sand.png` `floor_road.png` `floor_desert.png` `floor_grotto.png` | 只在 `theme_key=l1` 时使用。墙顶以后同名覆盖，不用改代码。绿洲仍用原来的 oasis 图 |

## 道具

| type | 文件 |
|------|------|
| container/trap | `item/pot.png` |
| heal | `item/scroll.png` |
| attack | `item/sword.png` |
| defense | `item/shield.png` |

## 第一轮关卡图（v1.2）

路径都从 `scripts/asset_registry.gd` 取。铜镜和莲花灯座在第二关用最近邻过滤的子节点绘制。

| 文件 | 尺寸 | 用途 |
|------|------|------|
| `landmark/beacon.png` / `beacon_lit.png` | 16×32 | 烽燧常态 / 登台后，底边对齐所在格 |
| `landmark/mother_silhouette.png` | 16×16 | 烽燧剪影。文件存在时优先用它，Nearest，不再压暗。缺文件时回退压暗的 `player/le.png`。格子内显示为单元格的 64%（40px 格上约 26×26） |
| `landmark/caravan.png` / `caravan_searched.png` | 32×16 | 商队遗驼 / 取走清水后；远处驼影用同一张图透明度约 0.45 |
| `landmark/stele.png` / `stele_read.png` | 16×16 | 残碑未读 / 已读 |
| `item/fragment_1.png` `fragment_2.png` `fragment_3.png` | 16×16 | 壁画残片标记，对应合图左中右 |
| `item/bell.png` | 16×16 | 妈妈的驼铃 |
| `item/waterskin.png` / `waterskin_empty.png` | 16×16 | 水囊满 / 空 |
| `lore/mother_fragments.png` | 96×64 | 通关卡合图，未收集的段压暗。非文物原图 |
| `decal/footprint_n/e/s/w.png` | 16×16 | 支路入口脚印，后缀是前进方向 |
| `mogao/mirror_ne/se/sw/nw.png` 及 `_lit` | 16×16 | 单面铜镜四朝向与受光态。正面亮金，背面深青铜，光束由代码画 |
| `mogao/lamp_halo.png` | 32×32 | 拿灯时脚下的光晕。只在鹿影和灯窟显示，Nearest |
| `mogao/lotus_stand.png` / `lotus_stand_lit.png` | 16×16 | 莲花灯座暗 / 亮 |

## 缺失 / 待补充

- 怪物独立 sprite（当前用符号+色块）
- BGM / SFX 文件（见 `assets/audio/README.md`）
- PWA 图标 512×512

## 分辨率策略

- **Web 移动**：加载 32×32 角色 + 16×16 地形，在 40–44px 格内 `image-rendering: pixelated`
- **带宽优化**：地形保持 16×16；仅角色使用 HQ 层
- 维护命令：`./tools/optimize_sprites.sh`

## 代码入口

统一路径见 `scripts/asset_registry.gd`；渲染器禁止硬编码 `res://assets/...`。
