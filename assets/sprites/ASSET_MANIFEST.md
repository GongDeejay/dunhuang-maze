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
| `le.png` | 乐僔 | `family_1` |
| `mac.png` | 马可 | `family_2` |
| `mcking.png` | 麦克金 | `family_3` |

源稿：`art/1.png`→dj, `art/2.png`→le, `art/3.png`→mac, `art/4.png`→mcking

## 地形

| 键 | 文件 |
|----|------|
| sand | `terrain/sand.png` |
| desert | `terrain/desert.png` |
| grotto | `terrain/hole/line.png` + cross 变体 |
| oasis | `terrain/oasis/defult.png` + pond/tree |
| ancient_road | `terrain/road/line.png` + cross 变体 |

## 道具

| type | 文件 |
|------|------|
| container/trap | `item/pot.png` |
| heal | `item/scroll.png` |
| attack | `item/sword.png` |
| defense | `item/shield.png` |

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
