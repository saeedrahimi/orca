# FORK.md — Personal fork maintenance guide

This is a **personal fork** of Orca (upstream: `stablyai/orca`). It hides most
features and focuses on **local parallel git worktrees + agents** on **Windows
(+ WSL)**. This file is the contract for any agent working on the fork. Read it
before touching fork behavior or syncing with upstream.

> `docs/**` is gitignored in this repo, so durable fork docs live at the repo
> root (this file) or inside `src/shared/fork-config.ts`. The local-only audit
> lives at `docs/fork-plan.md` (not committed).

---

## 1. Remotes & branch

| Name | URL | Role |
|---|---|---|
| `origin` | `stablyai/orca` | **Upstream source.** Pull updates from here. |
| `fork` | `saeedrahimi/orca` | The personal fork. Push here. |
| Branch | `personal-fork` | Long-lived fork branch, rebased onto `origin/main`. |

There is **no `upstream` remote** — `origin` is the upstream source. Do not add
one; scripts and this guide assume `origin` = stablyai.

---

## 2. The one rule: divergence lives in `src/shared/fork-config.ts`

All fork intent is declared in **`src/shared/fork-config.ts`** — a file upstream
never touches. Every other fork change is a **one-line "chokepoint read"** that
imports from it. This keeps the rebase conflict surface tiny.

**When changing what the fork keeps/hides, edit `fork-config.ts` first.** Only
touch a chokepoint file if you are adding a *new* kind of gate.

`fork-config.ts` exports:

- `KEPT_AGENTS` — the only TUI agents surfaced (`claude`, `claude-agent-teams`, `copilot`).
- `KEPT_FORGES` / `KEPT_TASK_PROVIDERS` — `['github']` only.
- `DISABLE_UPDATER`, `DISABLE_STAR_NAG`, `DISABLE_TELEMETRY`.
- `HIDE_EMULATOR`, `HIDE_MOBILE_COMPANION`, `HIDE_AUTOMATIONS_BUTTON`, `HIDE_COMPUTER_USE`.
- Predicates `isForkKeptAgent` / `isForkKeptForge` / `isForkKeptTaskProvider`
  (they take `string`, avoiding the `readonly [...] .includes()` narrowing trap —
  use these, not `.includes()`, when filtering).

### Chokepoint files (each reads fork-config)
| File | What it gates |
|---|---|
| `src/shared/tui-agent-selection.ts` | derives `DEFAULT_DISABLED_TUI_AGENTS` from `KEPT_AGENTS` |
| `src/renderer/src/lib/agent-catalog.tsx` | filters `getAgentCatalog()` to kept agents (the guaranteed, non-persisted hide) |
| `src/main/source-control/forge-provider.ts` | filters `FORGE_PROVIDERS` |
| `src/shared/task-providers.ts` | filters `TASK_PROVIDERS` |
| `src/renderer/src/components/settings/IntegrationsPane.tsx` | renders only the GitHub card |
| `src/renderer/src/components/settings/integrations-search.ts` | only the GitHub search entry |
| `src/main/updater.ts` | early-return in `setupAutoUpdater()` |
| `src/main/index.ts` | skips star-nag, emulator bridge, mobile handlers |
| `src/main/ipc/register-core-handlers.ts` | skips computer-use + emulator IPC |
| `src/renderer/src/components/sidebar/SidebarNav.tsx` | hides automations + mobile buttons |
| `src/renderer/src/hooks/useSettingsNavigationMetadata.ts` | hides computer-use / emulator / mobile settings panes |

### Do NOT touch (load-bearing — removing these breaks the app)
- **`OrcaRuntimeRpcServer`** (`index.ts`) — shared with the web client. Keep.
- **Automations *service*** (`index.ts`, ~openMainWindow) — throws if null. Only the *button* is hidden, never the service.
- **speech (sherpa-onnx), browser (agent-browser), native-chat** — kept on purpose; user may use them.
- **All WSL code paths** (`**/wsl-*.ts`, `wsl-paths.ts`, etc.) — must remain.

---

## 3. Config edits (branding / build)

`config/electron-builder.config.cjs`:
- `signtoolOptions` **removed** — unsigned local build (no SignPath cert). SmartScreen shows "Unknown publisher" → "Run anyway" once.
- `publish: null` — no release feed; bundled `app-update.yml` no longer points at upstream.
- `appId` / `productName` **kept as upstream** → the fork *replaces* the installed Orca and shares its userData dir. (Change `appId` only if you want side-by-side installs.)

- `win.signAndEditExecutable: false` — **the reason `build:win` works without
  Windows Developer Mode / an elevated shell** (see §4). Keep this. Cost: the exe
  keeps Electron's default icon/version metadata (cosmetic; in-app branding is
  unaffected).

`config/scripts/electron-builder-native-rebuild.cjs`:
- The beforeBuild hook drops `--force` on **win32** so the rebuild script probes
  node-pty's N-API prebuilds instead of invoking node-gyp. **This is why packaging
  works without Visual Studio C++ Build Tools.** Keep this; if a rebase reintroduces
  unconditional `--force`, re-apply the win32 skip (and keep its test in sync at
  `electron-builder-native-rebuild.test.mjs`).

---

## 4. Build & deploy (Windows, personal)

Toolchain: Node 24 + pnpm 10. **No dotnet SDK / MSVC / Rust needed** — the C# CLI
launcher compiles with the built-in `csc.exe`, and node-pty uses prebuilds (§3).

| Command | Output | Use |
|---|---|---|
| `pnpm run dev` | hot reload | day-to-day |
| `pnpm run build:unpack` | `dist/win-unpacked/Orca.exe` | fast smoke test (proven to build + boot) |
| `pnpm run build:win` | `dist/orca-windows-setup.exe` (NSIS) | real installer (proven, no Developer Mode) |

**Both build commands work on a stock, non-elevated Windows shell** — no
Developer Mode required. This depends on two fork edits; if a rebase drops either,
the symptom is a hard build failure, not a warning:

- The `winCodeSign` symlink trap: the app-builder **Go binary** runs `rcedit` to
  stamp the exe icon/version, which downloads `winCodeSign-2.6.0.7z` and extracts
  its macOS dylib **symlinks** with `7za -snl`. Creating symlinks on Windows needs
  a privilege absent without Developer Mode / elevation → the build dies with
  *"Cannot create symbolic link : A required privilege is not held by the client"*.
  The fork sidesteps this with `win.signAndEditExecutable: false` (§3), which skips
  rcedit entirely. There's no signing cert anyway.
  - Dead ends (don't retry these): `toolsets: { winCodeSign }` only redirects the
    JS signing path, **not** the Go rcedit path. The Go binary ignores
    `ELECTRON_BUILDER_RCEDIT_PATH` and randomizes its cache-dir hash per run, so
    neither env-override nor pre-seeding the cache works.
- MSVC: covered by the `--force` skip (§3).

The `signing with signtool.exe` lines in `build:win` output are harmless — that
message prints *before* the no-cert check; with no cert, signing is skipped and
the installer is simply unsigned.

### Deploy script: `scripts/update-local.ps1`
```
.\scripts\update-local.ps1          # full rebuild + silent /S reinstall over the installed app
.\scripts\update-local.ps1 -Fast    # skip installer, run dist\win-unpacked directly (fastest)
.\scripts\update-local.ps1 -Sync    # git fetch origin && rebase personal-fork onto origin/main, then build
```
It kills any running `Orca` process before the silent upgrade (NSIS can't
overwrite locked files; the daemon-stop hook only runs on real uninstall).

---

## 5. Syncing with upstream (the routine)

```bash
git fetch origin
git rebase origin/main            # personal-fork onto upstream
```

Because divergence is concentrated in `fork-config.ts` + one-liners, conflicts
should be rare and small. When they happen:

1. **`fork-config.ts` — never conflicts** (upstream doesn't know it exists). If a
   rebase deletes it, restore it; the fork is broken without it.
2. **Chokepoint conflicts** are almost always "upstream rewrote the list/function
   we filter." Re-apply the one-line filter/guard on top of upstream's new code —
   don't revert upstream's change.
3. **New agents/providers upstream adds** appear automatically *hidden* (they're
   not in `KEPT_*`). To surface one, add it to the relevant `KEPT_*` list. No
   other change needed.
4. **`electron-builder-native-rebuild.cjs`** — if upstream restores unconditional
   `--force`, re-apply the win32 skip (§3), or `build:win`/`build:unpack` will
   demand MSVC again.
5. **`electron-builder.config.cjs`** — if a rebase drops `signAndEditExecutable:
   false`, `build:win` will fail again on the winCodeSign symlink trap (§4).
   Re-apply it.

### After every sync — verify before deploying
```bash
pnpm install                 # rebuild node-pty postinstall (prebuilds, no MSVC)
pnpm run typecheck           # node + cli + web
npx oxlint <changed files>   # repo requires braces on if, etc.
pnpm run build:unpack        # confirm it still packages + boots
```
Then `.\scripts\update-local.ps1` (or `-Fast`).

---

## 6. Working conventions for agents on this fork

- **Prefer editing `fork-config.ts`** over adding new chokepoints.
- Use the `isForkKept*` predicates, not raw `.includes()` on the readonly `KEPT_*` tuples.
- Keep comments short and prefix fork-specific ones with **"Personal fork:"** or **"Why: fork …"** so they're greppable and obvious during rebases.
- Don't add a `max-lines` disable (repo rule, see AGENTS.md).
- The general repo rules in `AGENTS.md` still apply in full — this file only adds fork-specific guidance.
