# Docker 部署（方案 D）

多容器 Compose + 受限 docker-socket-proxy。适用于长期运行、需要隔离补丁
工具、又希望面板能一键控制游戏服务的场景。

## 1. 组件与拓扑

```
宿主机
├─ network lunar-net (bridge)
│   ├─ lunar-tear   :8003 gRPC, 127.0.0.1:8082 admin webhook
│   ├─ octo-cdn     :8080
│   ├─ auth-server  :3000
│   └─ panel        :8888
├─ network proxy-net (internal)
│   ├─ dockerproxy  (仅内部 2375)
│   └─ panel
└─ 挂载/卷
    ├─ ${LUNAR_SERVER_DIR}/server/db      → server 容器与 panel
    ├─ ${LUNAR_SERVER_DIR}/server/assets  → server/cdn（cdn 只读）与 panel（读写）
    ├─ ${PANEL_DATA_DIR}           → /app/panel/data
    ├─ volume panel-venv           → /app/panel/.venv（放卷，保留运行期安装）
    └─ volume panel-tools          → /app/panel/tools（放卷，保留 apktool/shim）
```

## 2. 快速使用

```bash
cp .env.example .env
# 必改：LUNAR_PUBLIC_ADDR、LUNAR_PUBLIC_CDN、LUNAR_OCTO_URL、LUNAR_ADMIN_TOKEN
# 标准布局无需设置 LUNAR_SERVER_DIR（保持 "."）；服务端位于别处时才改为：
#   Linux/macOS: /path/to/lunar-server
#   Windows:     D:/path/to/lunar-server
docker compose up -d --build
docker compose logs -f panel
```

面板地址 `http://<宿主机>:8888`，首次进入 `/settings` 创建管理员。

## 3. 运行身份与权限

- 所有容器统一 `user: "0:0"`（root）。原因：上游 server/cdn/auth 镜像默认
  `USER 1000`，而面板默认 root，混用会让 `db` 文件在 root 与 1000 之间来回
  变属主，导致 SQLite 写失败。统一 root 后任何挂载目录都可读写。
- 代价：面板/服务写在 bind mount 里的文件在宿主机上也是 root 所有；备份、
  清理时可能需要 sudo。
- 如需降权，可在 compose 中给单个服务加 `user: "1000:1000"`，但必须保证
  `db/assets` 属主为 1000，且运行期安装类操作会受限。

## 4. docker-socket-proxy 白名单

| 变量 | 值 | 说明 |
|---|---|---|
| `CONTAINERS` | 1 | 容器列表/详情/日志（GET） |
| `ALLOW_START` / `ALLOW_STOP` / `ALLOW_RESTARTS` | 1 | 启停/重启 |
| `POST` | 0 | 关掉通用 POST |
| `EXEC/BUILD/VOLUMES/IMAGES/NETWORKS/…` | 0 | 一律禁用 |

代理只以只读方式挂 `docker.sock`，只接在 `proxy-net`，不发布端口。
面板侧还会校验容器 label（`com.lunar.role`，值 server/cdn/auth）后才执行动作。

## 5. 面板在 Docker 模式下的行为

| 功能 | 行为 |
|---|---|
| 数据库/用户/库存等管理 | 完整可用（共享 `db`） |
| /patch 全流程 | 完整可用；JDK、zipalign、apksigner、apktool、venv 全部烘焙在镜像内 |
| 服务器状态 | 探测 compose 服务名 `server` 的 8003/8080 |
| 启动/停止/重启 | 经代理对三个容器执行；启动顺序 cdn → auth → server，停止/重启反之 |
| 服务器日志 | Docker API `GET /containers/<id>/logs`（多路复用流已解包） |
| /settings → 初始化 | **隐藏**：依赖由镜像构建负责；需要更新时 `docker compose up -d --build` |
| 面板自身端口修改 | `os.execv` 内部重启（Python 为 PID 1，容器不重建） |

相关环境变量（已写进 compose）：`LUNAR_CONTROL_MODE=docker`、
`LUNAR_SERVER_HOST=server`、`LUNAR_LOG_SOURCE=docker`、
`DOCKER_HOST=tcp://dockerproxy:2375`。

## 6. 挂载清单（对照 .env）

| 宿主机变量 | 默认值 | 容器路径 | 读写 |
|---|---|---|---|
| `LUNAR_SERVER_DIR` | `.`（仓库根） | server: `/opt/lunar-tear/{db,assets}`；cdn: `/opt/octo-cdn/assets`；auth: `/opt/auth-server/db`；panel: `/app/server/{db,assets}` | db rw；assets：cdn ro、server/panel rw |
| `PANEL_DATA_DIR` | `./panel/data` | `/app/panel/data` | rw |
| （命名卷） | `panel-venv` | `/app/panel/.venv` | rw |
| （命名卷） | `panel-tools` | `/app/panel/tools` | rw |

首次创建命名卷时 Docker 会把镜像内已烘焙的 venv/apktool/shim 拷进去，因此
开箱即用；之后运行期的 pip/安装也会保留。

## 7. 安全模型

- 内核共享（容器不是 VM），root 容器仍受 capabilities/seccomp 限制，但被攻破
  的后果大于非 root；因此：代理白名单 + 不暴露 2375 + 管理 webhook 仅绑
  `127.0.0.1` + 设置 `LUNAR_ADMIN_TOKEN`。
- 建议只发布 8888/8003/8080/3000；面板开放模式若暴露公网，请自行配合防火墙/
  反向代理，或开启登录控制（届时 `/login` 才可访问，管理员在 /settings 创建）。
- 不要把 `/var/run/docker.sock` 直接挂给 panel；只通过代理。

## 8. 排障

| 现象 | 检查 |
|---|---|
| `up` 报 `error from registry: denied`（`lunar-server/*:local`） | 这是 Compose 把“仅本地构建”的镜像名拿去远端查询所致；compose 已为四个构建服务设置 `pull_policy: build`。若仍遇到，先 `docker compose build` 再 `docker compose up -d` |
| 面板显示 STOPPED 但服务在跑 | `LUNAR_SERVER_HOST` 是否为 `server`（compose 网络内才可达） |
| 启停返回 403 | 代理白名单是否允许该动作；容器是否带 `com.lunar.role` label |
| 日志为空 | `LUNAR_LOG_SOURCE=docker` 是否生效；代理 `CONTAINERS` 是否为 1 |
| 数据库无法写入 | 挂载属主/`user` 是否一致（本方案统一 root） |
| 补丁下载/应用失败 | `assets` 是否为 rw、磁盘空间、apktool 是否存在于镜像 |

## 9. 更新与备份

- 更新：`git pull && docker compose up -d --build`（面板/服务镜像重建，数据卷与
  bind mount 不受影响）。
- 备份：`${LUNAR_SERVER_DIR}/server/db`（game.db/auth.db/backups）与
  `${PANEL_DATA_DIR}`（设置、任务产物、面板备份）。
- 回滚：固定镜像 tag 或使用数据备份恢复。
