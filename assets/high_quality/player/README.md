# 原版角色的无损矢量图

| File | Role |
|------|------|
| `dj.svg` | 玩家（主角） |
| `le.svg` | 家人1 (`family_1`) |
| `mac.svg` | 家人2 (`family_2`) |
| `mcking.svg` | 家人3 (`family_3`) |

唯一造型来源为 `assets/sprites/player/` 中上一版的 16×16 PNG。
SVG 将每行同色像素合并成矩形路径，完整保留轮廓、色值、透明度和留白；不描平边缘、不增加细节、不重绘。
SVG 的 viewBox 保持 16×16，Godot 导入为 256×256 纹理，并以最近邻方式显示。
这增加放大时的渲染分辨率，不会凭空增加原图细节，像素风格保持不变。

游戏优先加载 SVG，缺失时回退到原版 PNG。此目录旧的 32×32 PNG 是另一套造型，保留归档但不再加载。

重新生成：`godot --headless --path . --script tools/vectorize_characters.gd`

逐像素校验：`godot --headless --path . --script tools/vectorize_characters.gd -- --check`
