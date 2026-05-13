# phoenix_starter

Opinionated [Igniter](https://github.com/ash-project/igniter)-based starter that bootstraps Phoenix projects with the conventions used in [exfoundry](https://github.com/exfoundry) projects (Nix dev shell, namespaced contexts, Kamal deploys, locale routes, etc.).

**Status:** early. Currently ships one task (`gen.flake`). See [Roadmap](#roadmap).

## Quick start

### New project

```sh
mix igniter.new my_app \
  --with phx.new \
  --with-args="--database sqlite3" \
  --install "phoenix_starter@github:exfoundry/phoenix_starter"
```

This runs `phx.new`, adds phoenix_starter as a dep, and applies `phoenix_starter.install`.

### Existing project

```sh
cd my_app
mix igniter.install "phoenix_starter@github:exfoundry/phoenix_starter"
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
| `phoenix_starter.gen.formatter` | Sets `line_length: 150` in `.formatter.exs`. |
| `phoenix_starter.gen.postgres` | Wires a Postgres-backed project for managed local Postgres via `pg_spawner`. Adds the dep, drops `pkgs.postgresql_18` into the flake, exports `PGPORT=15432` in the shellHook, sets the Repo port in `config/dev.exs`, ignores `/priv/db/`. Aborts with a warning if `:postgrex` is not in deps. |
| `phoenix_starter.gen.sqlite` | Moves a SQLite-backed project's dev/test databases into `priv/db/<name>_(dev\|test).db` and adds matching gitignore patterns. The DB name defaults to the project directory's basename with its file extension stripped (`lingofox.ai` → `lingofox`); override with `--db-name`. Aborts if `:ecto_sqlite3` is not in deps. |
| `phoenix_starter.gen.core_contexts` | Adds the exfoundry "core contexts" combo: `ecto_context` (scoped CRUD + permissions) and `static_context` (in-memory lookup data). Wires both into `.formatter.exs`. |
| `phoenix_starter.gen.page_meta` | Adds `phoenix_page_meta` and triggers its installer: creates the project-local `<AppWeb>.PageMeta` struct, injects SEO `<MetaTags>` into `root.html.heex`, and wires LiveView callbacks. |

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
- [x] `gen.formatter` — sets `line_length: 150`.
- [x] `PhoenixStarter.Project.Flake` helper — `add_build_input/2`, `add_shell_hook/3` (regex-anchored on `pkgs.elixir_*`).
- [x] `gen.postgres` — wires existing Postgres-backed projects for managed local Postgres via `pg_spawner`.
- [x] `gen.sqlite` — moves SQLite dev/test databases into `priv/db/`.
- [x] `gen.core_contexts` — adds the exfoundry ecto_context + static_context combo.
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
