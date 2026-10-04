# Lunar Server

> 整合版私有服务器套件：**lunar-tear 游戏服务端** + **Lunar Base 管理面板** + **lunar-scripts 补丁工具**。
> 面向单机/局域网自建，非官方项目，仅供学习与存档研究。

上游项目：[lunar-tear](https://github.com/Walter-Sparrow/lunar-tear) · Lua 面板源自 [lunar-base](https://github.com/lovelyzy7/lunar-base)

---

## 目录结构

```
lunar-server/
├── server/              # 游戏服务端：代码、assets、db、wizard
├── panel/               # Lunar Base 管理面板（FastAPI），自持 setup / start
├── scripts/             # lunar-scripts 工具（master data、APK/IPA/list.bin 补丁）
├── docker/              # Docker 方案 D 的 panel 镜像
├── docs/                # 文档（含 DOCKER.md）
├── panel-start.sh(.bat) # 一键启动面板（首次自动初始化）
└── server-start.sh(.bat)# 一键启动游戏服务端（原 wizard，参数透传）
```

标准布局中 `server/assets`、`server/db` 随仓库就位，面板与 CDN 自动使用它们；
游戏服务端相关代码、wizard、Makefile 目标等沿用上游，详情见 `server/` 与上游 README。

---

## 快速开始（本机运行）

依赖：Python 3.10+、Go 1.25+（编译 shim 用）；`server/assets/release/*.bin.e` 等游戏资源随 `server/` 一并提供。

```bash
# Linux / macOS
./panel-start.sh          # 首次自动初始化：venv、依赖、master data、shim、补丁工具
./server-start.sh         # 游戏服务端（原 wizard）
```

```bat
rem Windows
panel-start.bat
server-start.bat
```

两者均支持透传参数，例如 `panel-start.sh --auth`（开启登录控制）、
`server-start.sh --prefer-saved`（复用向导配置）。

| 服务 | 端口 |
|---|---|
| 管理面板 | 8888 |
| gRPC 游戏服 | 8003 |
| 资源 CDN | 8080 |
| Auth 账号服 | 3000 |
| 管理 webhook（仅本机） | 8082 |

> 面板与游戏服务端默认使用仓库内的 `server/`；只在非标准布局下才需要设置
> `LUNAR_SERVER_DIR` 指向实际的检出目录（一般无需设置）。

`panel/setup.sh`（Windows：`panel\setup.bat`）可单独手动运行：完整安装，或 `panel/setup.sh patch-deps` 只装补丁依赖；
`panel/start.sh`（`panel\start.bat`）布局自适应、首次会自动安装。所有 setup 功能同样在网页 **/settings → 初始化** 中提供（自动检测，已完成即禁用）。

> 维护与上游同步流程见 **[docs/SYNC.md](docs/SYNC.md)**。

---

## 管理面板功能

| 页面 | 功能 |
|---|---|
| 存档管理 | 备份 / 恢复 `game.db`，可自定义备份目录，保留 50 份 |
| 用户 / 档案 | 玩家列表、货币与库存；单页完成账户信息、等级/经验计算、宝石、批量发放/升级、任务/关卡、删除用户 |
| 物品 / 服装 / 武器 | 发放与批量发放，卡玛、技能、剧情联动 |
| 强化管理 | 角色突破、石板、伙伴/残响/碎片补全、跳过过场 |
| 回忆 / 任务 / 关卡 | 构建套装、勾选完成任务、多级关卡树完成/还原 |
| 管理 → 活动 | bin.e 输出路径、启用活动/横幅（含热重载） |
| **补丁 /patch** | 本地化 Colab 补丁：APK（apktool 全流程）、IPA、master data、list.bin；后台任务 + 实时运行窗口 + 下载/应用 |
| **设置 /settings** | 监听地址/端口（保存自动重启并跳转）、登录开关、管理员账户、游戏服务器模式/状态/启停、初始化（本机模式） |

面板默认**开放模式**（无登录）。开放模式暴露到公网由部署者自行决定并承担风险；开启登录控制后，`/login` 才可访问，游戏账号只能看自己的记录，管理员可看全部。

---

## 游戏服务端

- `server-start.sh` 与上游 `go run ./cmd/wizard` 一致：检测/迁移数据库、构建并同时启动 auth + CDN + 游戏服，配置保存在 `server/.wizard.json`；
- 常用参数：`--prefer-saved`（复用配置）、`--grpc-port/--cdn-port/--auth-port`（端口）、`--setup-only`（仅显示打补丁说明）；
- 数据库迁移、快照导入、账号工具（claim/register）等沿用上游 `server/Makefile` 与 `cmd/` 文档。

---

## Docker（方案 D）

多容器：`lunar-tear` + `octo-cdn` + `auth-server` + `panel`，外加受限 `docker-socket-proxy`。

```bash
cp .env.example .env       # 按需改端口、公网地址、ADMIN_TOKEN
docker compose up -d --build
# 面板: http://<宿主机>:8888
```

要点：

- 所有容器统一以 **root（user: "0:0"）** 运行，避免挂载目录出现混合 UID 的写权限问题；
- 面板通过 **docker-socket-proxy 白名单**（仅查看/启停/重启）控制三个游戏容器，绝不接触原始 docker.sock；
- 服务器日志经 **Docker API** 读取；探测地址为 compose 服务名 `server`；
- `panel/` 的 venv 与 tools 使用命名卷（放卷），运行期安装可跨容器重建保留；
- Docker 模式下 `/settings` 隐藏本机初始化步骤（依赖已烘焙进镜像）。

详细设计、挂载清单、安全模型与排障见 **[docs/DOCKER.md](docs/DOCKER.md)**。

---

## 许可与免责

[MIT](LICENSE)。非商业同人存档/研究项目，与原厂商无关联；游戏 IP 归其所有者，本仓库不含受版权保护的游戏资源，使用风险自负。
