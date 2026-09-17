# 虚拟方向键重复移动回归 · 2026-09-17

## 原因与边界

`MobileControls.try_handle_input` 原来同时处理原生触摸与 Godot 自动生成的模拟鼠标事件。两次 pressed 都触发 `move_pressed`，一次轻触可能走两格，工具按钮也可能执行两次。

仅在虚拟控制器内过滤 `InputEvent.DEVICE_ID_EMULATION` 的指针副本；不关闭全局鼠标模拟，不改变键位、大小、速度、战斗规则，不使用会吞掉快速连点的时间防抖。

Godot 官方说明：[InputEvent.DEVICE_ID_EMULATION](https://docs.godotengine.org/en/4.7/classes/class_inputevent.html#class-inputevent-constant-device-id-emulation)。

## 验证

- 修复前新回归用例：3 次触摸累计产生 2 / 4 / 6 条移动指令，工具按钮产生 2 次动作。
- 修复后：游戏测试 219 项断言通过，包括快速连续轻触、真实鼠标、反向模拟触摸、地图滑动与工具按钮。
- 独立浏览器测试：390×844 @1x、390×844 @3x、844×390 @2x，每组 15 次手势恰好产生 15 条移动指令。测试记录同时存在 `InputEventScreenTouch:0:true` 与 `InputEventMouseButton:-1:true`，确认覆盖了实际浏览器/引擎输入链路。

## 复跑浏览器测试

1. 在 `artifacts/` 下建立独立项目副本（复制 `project.godot`、`export_presets.cfg`、`scripts/`、`assets/`、`scenes/`、`addons/`、`tests/`）。不要修改正式项目配置。
2. 仅在副本中，将 `run/main_scene` 改为 `res://tests/mobile_input_probe.tscn`，导出排除项去掉 `tests/**`。
3. 对副本运行 `godot --headless --path <副本> --import --quit`，然后 `--export-release Web <独立导出目录>/index.html`。使用原生 Godot HTML，不加序章。
4. 启动独立导出目录的 HTTP 服务；运行 `URL=http://127.0.0.1:8061/ NODE_PATH=<Playwright所在node_modules> node tools/verify_mobile_input.mjs`。

测试探针只存在于 `tests/`，正式导出仍排除 `tests/**`。不要发布探针构建，它只记录测试指令，不是游戏入口。
