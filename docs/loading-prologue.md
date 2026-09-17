# 前置剧情与固定引擎

## 引擎锁定

`deploy/godot-runtime-lock.json` 固定 Godot 4.7 Web 非线程运行时及其完整哈希。继续使用已经上线的 `engine-0e92f6c922b2d3230a5f05c5` 地址，因此本次序章更新也不会改变引擎 URL。

普通发布只更新游戏包和网页；构建时校验引擎 JS、WASM、audio worklet 的整体内容。若导出模板或版本意外变化，发布失败，不能覆盖已缓存的引擎。上传资源使用 rsync checksum，内容相同也不因导出时间戳变化重复传输。

主动升级 Godot 时须同时更新 CI 的 `GODOT_VERSION`、锁文件版本及新运行时哈希，完整验证后使用新 URL；不能把不同引擎写进旧的 immutable URL。哈希计算规则见 `content_address_assets`。浏览器清缓存、无痕模式或缓存被系统回收后仍可能重新下载，这不能靠固定 URL 阻止。

## 前置剧情

- `deploy/loading/intro.html` / `.css` / `.js`：直接嵌入入口 HTML，在引擎脚本之前执行。没有外部 UI 库或字体下载。
- `deploy/loading/family.webp`：用户提供的一家四口敦煌旅行图的等比例网页压缩版，未重绘人物；约 93 KB，独立于 Godot PCK。
- 三幕故事：一起出发 → 风暴突至、家人走散 → 寻找家人。风沙仅由 CSS 叠加。
- 每幕配操作说明：电脑/手机移动、即时战斗及暂停、道具与关卡目标。说明与现有输入代码对应，不新增战斗按键或改变关卡家人数。
- 默认每 9 秒自动翻一幕；支持手动上一幕/下一幕、暂停、跳过。手动翻页后停止自动播放；减少动态效果偏好下不自动播放。
- 初访资源就绪后可立即“启程”，无需强制读完；读剧情时仍停留在难度选择界面。跳过不停止下载，准备好后自动进入。
- 成功进入时才写入 `dunhuang-intro-v1=seen`；下次访问简化展示，资源就绪自动进入，也可“重看序章”。localStorage 被禁用时仍可正常进入。
- 进度来自 Godot 实际加载回调，不用剧情计时伪造进度。下载失败显示重试；慢网显示继续等待提示；重试不清除存档。
- 手机图片与底部加载/进入区固定，正文可滚动，支持浏览器字号设置。

## 验证

```sh
python3 -m unittest discover -s tests -p 'test_web_export.py'
BECKETT_ENABLE=0 ./run_tests.sh
URL=http://127.0.0.1:8060/ node tools/verify_loading_intro.mjs
URL=http://127.0.0.1:8060/ node tools/verify_responsive_web.mjs
```

浏览器测试覆盖 1440×900、390×844、360×640 大字号、慢下载时的剧情交互、首次进入、回访自动进入、引擎脚本失败和本地存储禁用。截图位于 `artifacts/intro-verify`。
