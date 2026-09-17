# Web 加载与字号修复（2026-09-17）

## 诊断证据

- 引擎 WASM 原始大小 39,509,339 字节，预压缩 gzip 10,052,173 字节；游戏 PCK 约 0.55 MB，角色 SVG 并非这次慢加载的主要来源。
- 旧工作流将引擎命名为 `game-<commit>.wasm`，每次 UI 发布都会改变网址，造成未修改的引擎也必须重新下载。
- 线上配置实际只有 `max-age=3600` 和动态 gzip；仓库示例中的 `gzip_static` 未应用。
- 本机直连生产站点一次 45 秒测试仅收到约 1.31 MB（29 KB/s）；启用预压缩后另一次 30 秒测试收到约 1.41 MB（47 KB/s）。两次均未完成，不是完整启动耗时，也不能据此断言线路带宽稳定或证明压缩优化的速度收益。
- 服务器检查时负载约 0.04。现有证据更支持传输链路慢，不支持“角色图片变大”或服务器 CPU 饱和；不能据一次客户端测量定位到云带宽限额或具体运营商。

## 已实施

1. 引擎 JS/WASM/worklet 作为整体计算内容哈希，生成稳定 `engine-<hash>` 名称。游戏包独立内容哈希，通过 Godot `mainPack` 载入。引擎升级、脚本或 worklet 内容变化才刷新引擎缓存。
2. 线上 HTTPS server 在通用静态资源正则前引入 `/www/server/panel/vhost/nginx/dunhuang-performance.inc`，内容对应 `deploy/nginx-performance.conf`。提供预压缩 gzip，哈希资源缓存一年；入口 HTML 必须重新验证。
3. 修改前备份：`/www/server/panel/vhost/nginx/maze.mplusm.site.conf.before-perf-20260917`。经过 `nginx -t` 后平滑 reload，未改证书、其他站点或删除旧版本资源。
4. CI 检查入口 no-cache、WASM MIME、gzip、immutable 和压缩 Content-Length，避免只检查 HTTP 200 而遗漏配置回退。此 include 是服务器配置，不会被网站 rsync 覆盖；调整它时须显式同步、备份并执行 nginx 配置检查。

## 字号

游戏使用 Godot 画布，不是 HTML 文本。PlatformService 读取浏览器根字号和 devicePixelRatio，把逻辑坐标统一为随默认字号缩放的 CSS 像素；保留高分辨率画布，并由 Godot 同步变换点击坐标。每 0.5 秒检查缩放，不在每帧反复测量网页。

默认网页字号为 100%；支持的 Apple 浏览器使用 `-apple-system-body`。游戏仍保留现有中文子集字体，不新增网络字体请求，也不把“字号跟随浏览器”误称为“可读取任意操作系统字体设置”。操作系统设置必须由浏览器暴露才能跟随。验证涵盖默认字号、20px 根字号以及 DPR 1/2/3。

## 验证与后续

```sh
python3 -m unittest discover -s tests -p 'test_web_export.py'
BECKETT_ENABLE=0 ./run_tests.sh
NODE_PATH=/Users/gongdj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules node tools/verify_responsive_web.mjs
```

首次冷启动仍需约 10 MB 引擎。在约 30–50 KB/s 链路上，即使缓存配置正确，冷启动仍可能以分钟计。后续若首次访问仍慢，应从多个地区/运营商实测并核对 CVM 出口带宽，再评估 CDN 或裁剪 Godot Web 模板；涉及新增云服务和费用时另行确认。不要通过强制刷新测试正常回访缓存。
