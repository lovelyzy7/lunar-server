# Lunar Server

> An integrated private-server kit: the **lunar-tear game server** + the
> **Lunar Base management panel** + the **lunar-scripts patch tools**.
> Built for self-hosting on a single machine or LAN. Unofficial, for
> preservation and research only.

Upstream: [lunar-tear](https://github.com/Walter-Sparrow/lunar-tear) ·
panel fork: [lunar-base-chinese](https://github.com/lovelyzy7/lunar-base-chinese)

---

## Layout

```
lunar-server/
├── server/              # game server: code, assets, db, wizard kept
├── panel/               # Lunar Base panel (FastAPI); owns setup / start
├── scripts/             # lunar-scripts (master data, APK/IPA/list.bin patchers)
├── docker/              # panel image for Docker scheme D
├── docs/                # documentation (see DOCKER.md)
├── panel-start.sh(.bat) # one-click panel start (auto-initializes on first run)
└── server-start.sh(.bat)# one-click game-server start (original wizard, flags pass through)
```

In the standard layout `server/assets` and `server/db` ship with the
repository and the panel/CDN pick them up automatically. Server code, the
wizard and the Makefile targets follow upstream; see `server/` and the
upstream README for those details.

---

## Quick start (native)

Requirements: Python 3.10+, Go 1.25+ (to build the shim); the game assets
(`server/assets/release/*.bin.e`) ship with `server/`.

```bash
# Linux / macOS
./panel-start.sh          # first run auto-initializes: venv, deps, master data, shim, patch tools
./server-start.sh         # game server (original wizard)
```

```bat
rem Windows
panel-start.bat
server-start.bat
```

Both accept pass-through flags, e.g. `panel-start.sh --auth` (require login)
and `server-start.sh --prefer-saved` (reuse the saved wizard config).

| Service | Port |
|---|---|
| Panel | 8888 |
| gRPC game server | 8003 |
| Asset CDN | 8080 |
| Auth server | 3000 |
| Admin webhook (loopback) | 8082 |

> The panel and the game server use the repository's `server/` by default;
> `LUNAR_SERVER_DIR` is only needed for non-standard layouts (usually not set).

`panel/setup.sh` (Windows: `panel\setup.bat`) can be run manually: full install, or
`panel/setup.sh patch-deps` for the patch dependencies only. `panel/start.sh`
(`panel\start.bat`) is layout-agnostic and auto-initializes on first run.

> The maintenance / upstream-sync workflow is documented in **[docs/SYNC.md](docs/SYNC.md)** (Chinese).
Everything setup does is also available in the web UI under
**/settings → Initialization** (auto-detected; finished steps are disabled).

---

## Panel features

| Page | What it does |
|---|---|
| Save Data | Back up / restore `game.db`, custom backup directory, 50 kept |
| Users / Profile | Player list, currencies & inventory; per-user page for account info, level/exp calculator, gems, bulk grants/upgrades, missions/quests, user deletion |
| Item / Costume / Weapon | Grants and batch grants (karma, skills, stories) |
| Upgrade Manager | Exalt, slabs, companions/remnants/debris, skip cutscenes |
| Memoir / Mission / Quest | Sets, mission completion, multi-level quest tree complete/restore |
| Admin → Events | bin.e output path, event/banner toggling (live reload) |
| **Patch (/patch)** | Local port of the Colab patchers: APK (full apktool pipeline), IPA, master data, list.bin — background jobs, live run console, download/apply |
| **Settings (/settings)** | Listen address/port (save → auto restart + redirect), login toggle, admin account, game-server mode/status/start/stop, initialization (native mode) |

The panel is **open mode by default** (no login). Exposing it to the public
internet is the deployer's decision and risk. Once login control is enabled,
`/login` becomes reachable, game accounts see only their own record, and the
admin account sees everything.

---

## Game server

- `server-start.sh` is the upstream wizard: validates assets, migrates the
  database, builds and launches auth + CDN + game server; settings are saved
  in `server/.wizard.json`;
- common flags: `--prefer-saved`, `--grpc-port/--cdn-port/--auth-port`,
  `--setup-only`;
- migrations, snapshot import and account tools (claim/register) stay in the
  upstream `server/Makefile` and `cmd/` tooling.

---

## Docker (scheme D)

Multi-container: `lunar-tear` + `octo-cdn` + `auth-server` + `panel`, plus a
restricted `docker-socket-proxy`.

```bash
cp .env.example .env       # adjust ports, public address, ADMIN_TOKEN
docker compose up -d --build
# Panel: http://<host>:8888
```

Key points:

- All containers run as **root (`user: "0:0"`)** so bind-mounted files never
  hit mixed-UID permission problems;
- The panel controls the three game containers through the **socket-proxy
  allowlist** (inspect/start/stop/restart only) — it never touches the raw
  Docker socket;
- Server logs are read through the **Docker API**; the probe host is the
  compose service `server`;
- `panel/`'s venv and tools live in named volumes so runtime installs survive
  container recreation;
- In Docker mode `/settings` hides the native initialization steps (the image
  bakes in the dependencies).

Full design, mount list, security model and troubleshooting:
**[docs/DOCKER.md](docs/DOCKER.md)**.

---

## License & disclaimer

[MIT](LICENSE). A fan-made, non-commercial preservation project; not
affiliated with the original publisher. All game IP belongs to its owners;
no copyrighted game assets are distributed here. Use at your own risk.
