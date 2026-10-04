# 维护与同步指南（lunar-base ⇄ lunar-server）

本文说明本项目的上游关系与日常维护流程。命令中的占位符（**通用写法，按你的实际目录替换**）：

- `<base-checkout>`：lunar-base 仓库的**本地克隆根目录**（源仓库）。特征：该目录下有 `setup.sh`、`web/app.py`、`tools/`；
- `<server-repo>`：本项目 lunar-server 仓库的**根目录**。特征：该目录下有 `panel/`、`server/`、`panel-start.sh`。

> 下文命令中凡出现这两个占位符的行都加了注释说明“这是哪个目录”；命令里的注释**只是说明，不要原样粘贴**（`#` 之后的内容会被 shell 忽略，粘贴进去也无害，但建议删掉）。
> Windows 与 Linux/macOS 均适用；仅 shell 写法不同（bash / cmd），rsync 在 Windows 上用 WSL 或 Git Bash。

---

## 1. 先理解角色

| 仓库 / 分支 | 内容 | 说明 |
|---|---|---|
| lunar-base `main` | 干净原版面板 | 独立布局；上游/原版更新进这里 |
| lunar-base `panel` | 原版 + 本项目集成功能 | `panel/` 的唯一来源 |
| `<server-repo>/panel/` | `panel` 分支的同步副本 | 不要单独发展功能，避免分叉 |
| `<server-repo>` 根目录 | 入口脚本、README、docs、Docker、server 上游代码 | 只属于本项目，不进 lunar-base |

**核心规则：会同步进 `panel/` 的东西，先改在 lunar-base；只属于本项目的，直接改在 `<server-repo>`。**

---

## 2. 一次性准备（已在仓库中完成，重建时参考）

```bash
# 下面所有路径都在占位符处替换：
#   <base-checkout> = lunar-base 克隆的仓库根（当前目录应最终变成这个位置）
#   <server-repo>   = 本项目仓库根（其中有 panel/ 目录）
cd <base-checkout>                         # 进入：lunar-base 的本地克隆根
git checkout -b panel                      # 在源仓库里创建 panel 分支（已存在则 checkout）

# 把本项目的 panel/ 内容叠加进 panel 分支（排除运行时目录与统一脚本）
rsync -a \
  --exclude=.git --exclude=.venv --exclude=data --exclude=__pycache__ \
  --exclude=tools/grant/grant --exclude=tools/grant/grant.exe --exclude=tools/apktool \
  --exclude=setup.sh --exclude=setup.bat --exclude=start.sh --exclude=start.bat \
  --exclude=tools/grant/src \
  <server-repo>/panel/ ./                 # 源：本项目 panel 目录；目标 ./ ：当前 lunar-base 仓库根

git rm --ignore-unmatch run-lunar-base.sh run-lunar-base.bat   # 删除旧别名（它们已不在 panel 中）
git add -A && git commit -m "panel: integration overlay"

git merge main                       # 把原版（main）的最新提交并进来；冲突在这里解决一次
git push -u origin panel             # 推送 panel 分支（首次 -u，之后 git push 即可）
```

之后在 `<server-repo>` 里用第 4 节的同步命令把 `panel` 分支内容取回 `panel/`。

---

## 3. 日常改文件：改哪里？

| 要改的内容 | 改在 | 之后 |
|---|---|---|
| 面板功能代码（`web/routes`、`web/services`、`web/templates`、`web/static` 等集成功能） | lunar-base 的 **`panel` 分支** | 同步到 `panel/`（第 4 节 ④⑤），无需合并 |
| 通用脚本与工具（`setup.sh/bat`、`start.sh/bat`、`tools/`、`scripts/`） | lunar-base 的 **`main` 分支**（脚本布局自适应，两边共用） | 合并进 `panel` 分支后再同步 |
| 根入口脚本、README、docs、`docker-compose.yml`、`.env.example`、`docker/`、`server/` 代码 | **`<server-repo>` 直接改** | 正常提交推送，不进 lunar-base |

判断方法：**“这个改动会不会出现在 `panel/` 里？”** 会 → 改 lunar-base；不会 → 改本项目。

---

## 4. 上游更新后的主流程

```bash
# 路径替换同第 2 节：<base-checkout> = 源仓库根；<server-repo> = 本项目仓库根。

# ① 更新原版（在源仓库里操作）
cd <base-checkout>                     # 进入：lunar-base 克隆根
git checkout main && git pull          # 拉取原版最新提交

# ② 合并进 panel 分支（冲突只在这里解决一次）
git checkout panel                     # 切到集成分支
git merge main                         # main -> panel（方向不要反）
git push origin panel                  # 推送集成分支

# ③ 同步到本项目（--delete 会删除 panel 里已不存在的文件；排除运行时目录）
rsync -a --delete \
  --exclude=.git --exclude=.venv --exclude=data --exclude=__pycache__ \
  --exclude=tools/grant/grant --exclude=tools/grant/grant.exe --exclude=tools/apktool \
  <base-checkout>/ <server-repo>/panel/   # 源：源仓库根；目标：本项目 panel 目录

# ④ 验证（在本项目仓库里操作）
cd <server-repo>                       # 进入：本项目仓库根
git diff --stat -- panel               # 只应看到预期变化
bash panel/setup.sh --print-paths      # 路径自检：应指向本仓库的 server/
./panel-start.sh                       # 启动检查 /、/patch、/settings
# 如 grant shim 源码有更新：bash panel/setup.sh 会自动重建

# ⑤ 提交（仍在本项目仓库根）
git add panel
git commit -m "chore(panel): sync from lunar-base panel"
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

**可能同时被两边修改的文件**（冲突热点）：
`.gitignore`、`README.md`、`web/static/js/i18n.js`、`web/static/css/automata.css`、`web/templates/base.html`、`web/config.py`、`web/app.py`。
处理原则：集成功能以 `panel` 分支为准，原版修复合并进来；逐个 `git diff` 确认，解决后 `git add` + `git commit`。

| 问题 | 处理 |
|---|---|
| `git pull` 报本地有改动 | 先 `git status` 提交或暂存（`git stash -u`）再拉取 |
| 合并后脚本行为异常 | 确认没有把 `panel` 分支的旧 `setup.*` 带回来；统一脚本以 `main` 为准 |
| 同步后 grant 工具报错 | 运行 `bash panel/setup.sh` 重建 shim（源码更新后必须重建） |
| Windows 上文件"整篇被修改" | `.gitattributes` 已统一行尾：仓库内 LF、`.bat` 检出 CRLF；避免用会改行尾的编辑器 |
| 忘了回填集成改动 | 在 `<server-repo>` 用 `git diff` / `diff -r` 找出差异，复制回 `panel` 分支再提交 |

**绝对不要**：
- 反向执行 `panel → main`（除非有意把集成功能上移原版）；
- 把 `data/`、`.venv/`、`tools/apktool/`、`tools/grant/grant(.exe)` 提交或同步；
- 只在 `panel/` 手改而不回填 `panel` 分支。
