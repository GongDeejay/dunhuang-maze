# 部署流程（广州轻量应用服务器）

本站点生产环境：**腾讯云轻量应用服务器 / 广州 / `lhins-afj37xpr` / `101.33.209.194`**。

## 1. 架构与端口约定

| 项目 | 值 | 说明 |
| --- | --- | --- |
| 站点根目录 | `/www/wwwroot/maze.mplusm.site` | 静态产物，rsync 覆盖式发布 |
| Web 服务 | nginx（系统包安装，systemd 管理） | `systemctl reload nginx` 生效 |
| 监听端口 | **8443（HTTPS）** | 80/443 由 nps 内网穿透服务占用（家庭 Minecraft 隧道），不得占用 |
| 证书目录 | `/etc/nginx/ssl/maze.mplusm.site/` | `fullchain.pem` / `privkey.pem`（600） |
| 访问地址 | `https://maze.mplusm.site:8443/` | 端口不可省略 |
| 站点配置 | `/etc/nginx/conf.d/maze.mplusm.site.conf` | 由仓库 `deploy/nginx-guangzhou.conf` 下发，禁止手工修改 |
| 性能策略 | `/etc/nginx/dunhuang-performance.inc` | 由仓库 `deploy/nginx-performance.conf` 下发（预压缩、缓存、COOP/COEP） |

**红线**：不要改动 nps 的任何配置与端口（`nps.conf`、`hosts.json`、`tasks.json`、80/443/8080/8024/7891）。该服务承载家庭 Minecraft 隧道。

## 2. 部署通道（GitHub Actions + SSH 部署密钥）

```
push main ──> Build & Test ──> Export Web ──> 压缩/清单校验
                                        └──> scp 配置 + rsync 产物 ──> 广州服务器
                                        └──> 线上校验（DNS 无关，按 IP 固定解析）
```

发布顺序刻意设计为「先资产、后入口页」：

1. `scp` 站点定义与性能策略到 `/tmp`，由 `deploy/install-guangzhou.sh` 幂等安装（`nginx -t` 通过才 reload）
2. `rsync` 除 `index.html` 外的全部内容（content-addressed 资源，可安全叠加）
3. 最后 `rsync` `index.html` 完成切换（入口页 `Cache-Control: no-cache`，用户端即刻生效）
4. 校验 `MANIFEST.json` 中的 `git_revision` 与本次提交一致

### 必需的仓库配置

| 类型 | 名称 | 用途 |
| --- | --- | --- |
| Secret | `LIGHTHOUSE_GZ_SSH_KEY` | 广州服务器部署私钥（ed25519，仅用于 `root@101.33.209.194`） |
| Secret | `TENCENT_CVM_SSH_KEY` | 旧雅加达服务器私钥（仅一次性迁移时使用，迁移完成后可轮换） |
| Variable（可选） | `DEPLOY_HOST` | 覆盖目标 IP，默认 `101.33.209.194` |
| Variable（可选） | `DEPLOY_USER` | 覆盖登录用户，默认 `root` |

缺失 `LIGHTHOUSE_GZ_SSH_KEY` 时流水线只构建不发布，并在运行摘要中给出 warning——这是刻意设计，避免误发布。

## 3. 首次初始化（已完成/可重跑）

`Bootstrap Guangzhou Migration`（`workflow_dispatch`）执行一次性迁移，参数默认值即当前环境：

1. 在目标机建立目录
2. 证书对 `fullchain.pem`/`privkey.pem` 从源机经 runner 内存直传（**不落盘、不进仓库、不进 artifact**）
3. 站点内容 `tar | tar` 流式同步（308MB 级）
4. 下发 nginx 站点定义并 `nginx -t` + 启动
5. 目标机本地 `curl --resolve` 校验 8443 的 TLS 与 COOP 头

可重复执行，语义是「让广州服务器与雅加达源站内容一致」。

## 4. 日常发布

```bash
git push origin main          # 触发 Build and Deploy Web
gh run watch                  # 观察执行
```

仅改文档等非 `paths` 命中项不会触发；需要强制发布时用 `workflow_dispatch`。

## 5. 回滚

| 场景 | 操作 |
| --- | --- |
| 内容回滚 | 在 GitHub 上 revert 对应提交后 push（产物按 `git_revision` 全量重建） |
| 配置回滚 | 服务器上 `/etc/nginx/conf.d/maze.mplusm.site.conf.bak-<sha>` 为最后一次变更前备份；`cp` 回后 `nginx -t && systemctl reload nginx` |
| 整站回退到雅加达 | 将 `vars.DEPLOY_HOST` 改为 `43.133.145.77`，DNS 记录指回旧 IP |

## 6. 证书

- 当前证书来源：雅加达服务器（宝塔签发的 Let's Encrypt/商业证书），有效期至 **2027-06-28**。
- 续期约束：广州服务器 80/443 被 nps 占用，HTTP-01 与 TLS-ALPN-01 均不可用；续期必须走 **DNS-01**。
- 推荐做法：在 DNSPod 为 `mplusm.site` 申请 API Token，在广州服务器用 `acme.sh --dns dns_dp` 做自动续期；或在到期前 30 天用同参数手工执行 DNS-01 验证。
- 续期后只需替换 `/etc/nginx/ssl/maze.mplusm.site/` 两个文件并 `systemctl reload nginx`。

## 7. 与「服务器安全告警」的关系（重要）

云端远程命令（TAT）对下列操作有安全审查，命中即返回 `AccessDeny`，曾被误判为「服务器告警拦截」：

- 生成 SSH 密钥（`ssh-keygen`）、写入 `authorized_keys`
- 下载并执行远程脚本（`curl ... | sh`、`wget -O script`）
- 端口探测（`nc`、`/dev/tcp`）

因此本流程的设计原则：

1. **日常发布完全不使用远程命令**，全部通过 GitHub Actions + SSH 部署密钥完成，命令内容固定、可审计、可重放
2. **密钥安装只通过控制台网页终端（OrcaTerm）由站点所有者本人执行一次**，AI 不代持服务器登录凭据
3. **不做零散手工文件传输**（长配置曾因逐字符转写产生偏差），配置一律随仓库版本化下发，服务器上只保留可校验的最终文件
4. 只在只读诊断（`cat`/`ls`/`systemctl status`）和软件包安装（`dnf install`）场景使用远程命令

## 8. 验证清单（每次发布后）

```bash
curl -fsSI https://maze.mplusm.site:8443/index.html | grep -iE 'cross-origin-opener-policy|cache-control'
curl -fsSI -H 'Accept-Encoding: br' https://maze.mplusm.site:8443/engine-*.wasm | grep -iE 'content-encoding|content-type'
curl -fsS  https://maze.mplusm.site:8443/MANIFEST.json | python3 -m json.tool | head
```
