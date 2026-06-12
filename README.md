# phoenix_starter

Opinionated [Igniter](https://github.com/ash-project/igniter)-based starter that bootstraps Phoenix projects with the conventions used across [Sascha Brink's](https://github.com/saschabrink) projects (Nix dev shell, namespaced contexts, Kamal deploys, locale routes, etc.).

**Status:** early. Currently ships one task (`gen.flake`). See [Roadmap](#roadmap).

## Quick start

### New project

```sh
mix igniter.new my_app \
  --with phx.new \
  --with-args="--database sqlite3" \
  --install "phoenix_starter@github:saschabrink/phoenix_starter"
```

This runs `phx.new`, adds phoenix_starter as a dep, and applies `phoenix_starter.install`.

### Existing project

```sh
cd my_app
mix igniter.install "phoenix_starter@github:saschabrink/phoenix_starter"
```

### Apply a single feature

```sh
mix phoenix_starter.gen.flake
```

All tasks are idempotent — re-running them on the same project state is a no-op.

## Tasks

| Task | What it does |
|---|---|
| `phoenix_starter.install` | Aggregator. Runs every applicable `gen.*` task. |
| `phoenix_starter.gen.flake` | Creates a minimal Nix dev shell (`flake.nix` + `flake.lock`), adds `/.nix/` to `.gitignore`. |
| `phoenix_starter.gen.direnv` | Creates a universal `.envrc` (`dotenv_if_exists` + `use flake .`), adds `/.direnv/` and `.env` to `.gitignore`. |
| `phoenix_starter.gen.phx_server_alias` | Adds `s: "phx.server"` to the `aliases/0` list in `mix.exs`. |
| `phoenix_starter.gen.formatter` | Sets `line_length: 150` in `.formatter.exs`. |
| `phoenix_starter.gen.format_hook` | Drops a Claude Code post-write hook that runs `mix format` on `.ex/.exs` files. Registers in `.claude/settings.json`. |
| `phoenix_starter.gen.memex` | Sets up [memex](https://github.com/saschabrink/memex): writes `memex.toml`, creates `docs/<name>/.gitkeep`, drops blueprint-injection + test-coverage hooks and registers them. |
| `phoenix_starter.gen.npm` | Adds `pkgs.nodejs_24` to the flake + shellHook pointing npm at `.nix/npm/`, ignores `/assets/node_modules/`. Does not create `package.json` — `PhoenixStarter.Project.Npm.add_dependency/4` does that on demand from other tasks. |
| `phoenix_starter.gen.postgres` | Wires a Postgres-backed project for managed local Postgres via `pg_spawner`. Adds the dep, drops `pkgs.postgresql_18` into the flake, exports `PGPORT=15432` in the shellHook, sets the Repo port in `config/dev.exs`, ignores `/priv/db/`. Aborts with a warning if `:postgrex` is not in deps. |
| `phoenix_starter.gen.sqlite` | Moves a SQLite-backed project's dev/test databases into `priv/db/<name>_(dev\|test).db` and adds matching gitignore patterns. The DB name defaults to the project directory's basename with its file extension stripped (`lingofox.ai` → `lingofox`); override with `--db-name`. Aborts if `:ecto_sqlite3` is not in deps. |
| `phoenix_starter.gen.core_contexts` | Adds the "core contexts" combo: `ecto_context` (scoped CRUD + permissions) and `static_context` (in-memory lookup data). Wires both into `.formatter.exs`. |
| `phoenix_starter.gen.page_meta` | Adds `phoenix_page_meta` and triggers its installer: creates the project-local `<AppWeb>.PageMeta` struct, injects SEO `<MetaTags>` into `root.html.heex`, and wires LiveView callbacks. |
| `phoenix_starter.gen.home_live` | Replaces the default Phoenix page controller with `<AppWeb>.HomeLive`. Rewrites the `get "/", PageController, :home` route to `live "/", HomeLive, :index`, removes the controller, HTML module, template, and test. Installs `phoenix_page_meta` as a dep. |
| `phoenix_starter.gen.ex_machina` | Adds `ex_machina` (test-only), creates `<App>.Factory` at `test/support/factory.ex` (`use ExMachina.Ecto, repo: <App>.Repo`), and aliases `<App>.Factory` inside the `using do quote do` blocks of `conn_case.ex` and `data_case.ex`. |
| `phoenix_starter.gen.ecto_trim` | Adds `{:ecto_trim, "~> 1.0"}` — parameterized Ecto type that trims and normalizes whitespace on cast and dump. |
| `phoenix_starter.gen.bump_assets` | Bumps `config :esbuild, :version` and `config :tailwind, :version` to the latest GitHub release tag. Short timeout with a baked-in fallback on network failure. Emits a notice to run `mix assets.setup` manually for the binary download. Supports `--esbuild=X --tailwind=Y` overrides. |
| `phoenix_starter.gen.credo` | Adds `credo` and `ex_slop` (both `:dev`/`:test`, `runtime: false`) and writes a `.credo.exs` based on credo's stock template (compile-time embedded), with `strict: true`, `ModuleDoc` check disabled, and `{ExSlop, []}` registered. Skips the file if it already exists. |
| `phoenix_starter.gen.topbar` | Migrates `topbar` from `assets/vendor/topbar.js` to an npm dep (`^3.0.0`), rewrites the import in `assets/js/app.js`, and removes the vendor file. |
| `phoenix_starter.gen.daisyui` | Migrates `daisyui` from `assets/vendor/{daisyui,daisyui-theme}.js` to an npm dep (`^5.0.50`), rewrites the `@plugin` directives in `assets/css/app.css`, and removes both vendor files. |

## Architecture

Each feature is one task. A feature task owns *every* file change needed to install that feature — typically `mix.exs`, a `config/*.exs`, `flake.nix`, and `.gitignore`. Tasks are independent and can be applied in any order. Composition happens via `Igniter.compose_task/3` from `phoenix_starter.install` or from other feature tasks.

**`flake.nix` is an edit target, not a generated artifact.** The same way Igniter never regenerates `mix.exs` from scratch — it patches it — feature tasks patch `flake.nix`. `gen.flake` only creates a minimal base flake if none exists; other feature tasks (e.g. a future `gen.postgres`) append their `buildInputs` and `shellHook` blocks via the `PhoenixStarter.Project.Flake` helper.

**Format assumption:** the flake is in the canonical `pkgs.<name>` form (no `with pkgs;` shorthand). If a user rewrites the flake in a non-canonical form, our editors will not find their anchor points.

**Helpers** live under `PhoenixStarter.Project.*`, mirroring Igniter's `Igniter.Project.*` layout:

- `PhoenixStarter.Project.Gitignore.add_line/2` — idempotent line append.
- `PhoenixStarter.Project.Flake.add_build_input/2` (planned)
- `PhoenixStarter.Project.Flake.add_shell_hook/3` (planned)

## Roadmap

In rough order of priority:

- [x] `gen.flake` — base Nix dev shell.
- [x] `gen.direnv` — universal `.envrc` + `.direnv/`/`.env` gitignore.
- [x] `gen.phx_server_alias` — adds `s: "phx.server"` to mix aliases.
- [x] `gen.ex_machina` — ExMachina dep + stub Factory + ConnCase/DataCase aliasing.
- [x] `gen.ecto_trim` — adds ecto_trim dep.
- [x] `gen.bump_assets` — pins esbuild + tailwind to latest GitHub releases (with fallback) and schedules `assets.setup`.
- [x] `gen.credo` — credo + ex_slop deps + tuned `.credo.exs`.
- [x] `gen.topbar` — vendor → npm migration for topbar.
- [x] `gen.daisyui` — vendor → npm migration for daisyui + daisyui-theme.
- [x] `gen.formatter` — sets `line_length: 150`.
- [x] `gen.format_hook` — Claude Code post-write hook for `mix format`.
- [x] `gen.memex` — memex.toml + Claude blueprint-injection hooks.
- [x] `PhoenixStarter.Project.Claude` helper — `add_hook/2` for composable Claude-hook registration.
- [x] `gen.npm` — Node in the Nix shell + `.gitignore` entry.
- [x] `PhoenixStarter.Project.Npm` helper — `add_dependency/4`, `remove_dependency/2` for composable `package.json` edits.
- [x] `gen.home_live` — replaces the default Phoenix page controller with a LiveView home page.
- [x] `PhoenixStarter.Project.Flake` helper — `add_build_input/2`, `add_shell_hook/3` (regex-anchored on `pkgs.elixir_*`).
- [x] `gen.postgres` — wires existing Postgres-backed projects for managed local Postgres via `pg_spawner`.
- [x] `gen.sqlite` — moves SQLite dev/test databases into `priv/db/`.
- [x] `gen.core_contexts` — adds the ecto_context + static_context combo.
- [x] `gen.page_meta` — adds phoenix_page_meta and triggers its installer.
- [ ] `gen.kamal` — `config/deploy.yml`, Ruby in flake, gem dir in `.gitignore`.
- [ ] `gen.assets` — adds Node to flake when `assets/package.json` is present.
- [ ] `gen.context_namespace` — enforces the `Platform.<Namespace>.<Context>` convention (overrides Phoenix's default `phx.gen.context` location).
- [ ] `gen.locale_routes` — `/:locale/...` prefix scaffold.
- [ ] `gen.daisyui` — adds DaisyUI to `assets/css/app.css` and `tailwind.config.js`.

Detection inside `phoenix_starter.install` is intentionally minimal: DB adapter from `mix.exs`, Node from `assets/package.json`, Ruby from `config/deploy.yml`. Anything that can't be inferred (e.g. `--pgvector`) is a CLI flag on the relevant task.

## Development

```sh
nix develop
mix deps.get
mix test
```

Tests use `Igniter.Test` — entirely in-memory, no tmp dirs. The library code lives under `lib/phoenix_starter/`, mix tasks under `lib/mix/tasks/`, templates under `priv/templates/`.

To smoketest end-to-end:

```sh
cd /tmp
mix igniter.new test_app \
  --with phx.new \
  --install "phoenix_starter@path:/path/to/phoenix_starter"
```
