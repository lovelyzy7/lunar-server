# 维护与同步指南（lunar-base ⇄ lunar-server）

本文说明本项目的上游关系与日常维护流程。命令中的占位符（**通用写法，按你的实际目录替换**）：

- `<base-checkout>`：lunar-base 仓库的**本地克隆根目录**（源仓库）。特征：该目录下有 `setup.sh`、`start.sh`、`web/app.py`、`scripts/`；
- `<server-repo>`：本项目 lunar-server 仓库的**根目录**。特征：该目录下有 `panel/`、`server/`、`panel-start.sh`。

> 命令注释只是说明，粘贴时 `#` 之后会被 shell 忽略（建议删掉）。
> Windows 与 Linux/macOS 均适用；rsync 在 Windows 上用 WSL 或 Git Bash。

---

## 1. 先理解角色（现在是单分支模型）

| 仓库 / 位置 | 内容 | 说明 |
|---|---|---|
| lunar-base `main` | 完整源码 = 原版 + 面板全部功能（/patch、/settings、Docker 模式等） | **唯一编辑入口** |
| `<server-repo>/panel/` | `main` 的同步副本 | 只接收同步，不单独发展功能 |
| `<server-repo>` 根目录 | 入口脚本、README、docs、Docker、`server/` 上游代码 | 只属于本项目，直接改这里 |

> 历史上曾有一个 `panel` 分支用于集成；它已经**快进合并进 `main`** 并删除。现在 `main` 就是唯一的源。

**核心规则：会同步进 `panel/` 的东西，改在 lunar-base `main`；只属于本项目的，直接改 `<server-repo>`。**

---

## 2. 建立 / 重建同步副本

新环境或需要重建 `panel/` 时，把 lunar-base 的 `main` 同步过去：

```bash
# 路径替换：<base-checkout> = lunar-base 克隆根；<server-repo> = 本项目仓库根
rsync -a --delete \
  --exclude=.git --exclude=.venv --exclude=data --exclude=__pycache__ \
  --exclude=tools/grant/grant --exclude=tools/grant/grant.exe --exclude=tools/apktool \
  <base-checkout>/ <server-repo>/panel/   # 源：源仓库根；目标：本项目 panel 目录
```

`--delete` 会让 `panel/` 与 `main` 完全一致（被排除的运行时目录不受影响）。
不要手工在 `panel/` 里留“只改这边”的文件——它们会在下次同步时被删除。

---

## 3. 日常改文件：改哪里？

| 要改的内容 | 改在 | 之后 |
|---|---|---|
| 面板功能代码（`web/routes`、`web/services`、`web/templates`、`web/static`、`scripts/`、`tools/`） | lunar-base 的 **`main`** | 同步到 `panel/`（第 4 节） |
| 通用脚本（`setup.sh/bat`、`start.sh/bat`） | lunar-base 的 **`main`**（布局自适应，独立/集成两种部署都适用） | 同步到 `panel/` |
| 根入口脚本、README、docs、`docker-compose.yml`、`.env.example`、`docker/`、`server/` 代码 | **`<server-repo>` 直接改** | 正常提交推送，不进 lunar-base |

判断方法：**“这个改动会不会出现在 `panel/` 里？”** 会 → 改 lunar-base；不会 → 改本项目。

> 如果 lunar-base 自己还跟踪另一个上游（例如原始的 lunar-base-chinese），先把上游合并进 `main`，再走第 4 节同步。

---

## 4. 更新后的主流程

```bash
# 路径替换同第 2 节：<base-checkout> = 源仓库根；<server-repo> = 本项目仓库根。

# ① 更新源仓库（在 lunar-base 里操作）
cd <base-checkout>                     # 进入：lunar-base 克隆根
git checkout main && git pull          # 拉取最新提交（含上游合并结果）
# 有本地改动就先 commit；冲突只在这里解决

# ② 同步到本项目
rsync -a --delete \
  --exclude=.git --exclude=.venv --exclude=data --exclude=__pycache__ \
  --exclude=tools/grant/grant --exclude=tools/grant/grant.exe --exclude=tools/apktool \
  <base-checkout>/ <server-repo>/panel/   # 源：源仓库根；目标：本项目 panel 目录

# ③ 验证（在本项目仓库里操作）
cd <server-repo>                       # 进入：本项目仓库根
git diff --stat -- panel               # 只应看到预期变化
bash panel/setup.sh --print-paths      # 路径自检：应指向本仓库的 server/
./panel-start.sh                       # 启动检查 /、/patch、/settings
# 如 grant shim 或依赖有更新：bash panel/setup.sh 会自动重建/安装

# ④ 提交（仍在本项目仓库根）
git add panel
git commit -m "chore(panel): sync from lunar-base main"
git push
```

Windows：手工覆盖时同样排除 `.git`、`.venv`、`data`、`__pycache__`、`tools/apktool`、`tools/grant/grant(.exe)`。

---

## 5. 脚本说明（统一后）

| 脚本 | 作用 |
|---|---|
| `panel/setup.sh`（`setup.bat`） | 完整安装：venv、依赖、master data、名称、grant shim、补丁依赖 |
| `panel/setup.sh patch-deps` | 只安装 /patch 依赖（protobuf、apktool、Java/build-tools） |
| `panel/setup.sh --print-paths` | 打印识别到的 PANEL / TEAR_DIR / SERVER，排查路径问题 |
| `panel/start.sh`（`start.bat`） | 启动面板；缺 venv/masterdata/shim 时自动先跑 setup |
| `<server-repo>/panel-start.sh(.bat)` | 本项目根入口，转发到 `panel/start.*` |
| `<server-repo>/server-start.sh(.bat)` | 启动游戏服务端（原 wizard，参数透传） |

服务端检出**自动识别顺序**：
`../server`（集成布局）→ `../lunar-server`（同级独立布局）→ `../lunar-tear`（旧名）→ 环境变量 `LUNAR_SERVER_DIR`。

---

## 6. 冲突与常见问题

如果 lunar-base 需要并入另一个上游，冲突通常出现在这些文件：
`.gitignore`、`README.md`、`web/static/js/i18n.js`、`web/static/css/automata.css`、`web/templates/base.html`、`web/config.py`、`web/app.py`。
处理原则：以本项目功能为准，上游修复合并进来；逐个 `git diff` 确认后 `git add` + `git commit`。

| 问题 | 处理 |
|---|---|
| `git pull` 报本地有改动 | 先 `git status` 提交或暂存（`git stash -u`）再拉取 |
| 同步后 grant 工具报错 | 运行 `bash panel/setup.sh` 重建 shim（源码更新后必须重建） |
| Windows 上文件"整篇被修改" | `.gitattributes` 已统一行尾：仓库内 LF、`.bat` 检出 CRLF |
| 忘了把改动放进 lunar-base | 在 `<server-repo>` 用 `git diff` 找出差异，改到 lunar-base `main` 后再同步 |
| 想确保两侧完全一致 | `diff -rq --exclude=.git --exclude=.venv --exclude=data --exclude=__pycache__ --exclude=tools/grant/grant --exclude=tools/grant/grant.exe --exclude=tools/apktool <base-checkout> <server-repo>/panel` |

**绝对不要**：
- 在 `panel/` 里直接改功能代码然后不回填 lunar-base；
- 把 `data/`、`.venv/`、`tools/apktool/`、`tools/grant/grant(.exe)` 提交或同步；
- 手工维护“panel 专用”的分支/文件（模型已统一为单 `main`）。
