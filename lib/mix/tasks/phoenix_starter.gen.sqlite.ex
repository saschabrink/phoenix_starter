defmodule Mix.Tasks.PhoenixStarter.Gen.Sqlite.Docs do
  @moduledoc false

  def short_doc, do: "Moves the SQLite dev/test database into priv/db/"

  def example, do: "mix phoenix_starter.gen.sqlite"

  def long_doc do
    """
    #{short_doc()}

    Rewrites `:database` in `config/dev.exs` and `config/test.exs` to point at
    `priv/db/<name>_dev.db` and `priv/db/<name>_test.db`, and adds matching
    SQLite patterns to `.gitignore`. Aborts with a warning if `:ecto_sqlite3`
    is not in the project's dependencies — this task is for SQLite-backed
    projects only.

    The database name defaults to the project directory's name with any
    file extension stripped: `lingofox.ai` → `lingofox_dev.db`. Override with
    `--db-name`.

    ## Example

    ```sh
    #{example()}
    ```

    ## Options

    * `--db-name` — base name for the database files. Defaults to the project
      directory name with its extension stripped.
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.Sqlite do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :phoenix_starter,
        example: __MODULE__.Docs.example(),
        schema: [db_name: :string]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      if Igniter.Project.Deps.has_dep?(igniter, :ecto_sqlite3) do
        apply_changes(igniter)
      else
        Igniter.add_warning(igniter, """
        phoenix_starter.gen.sqlite expects a SQLite-backed project, but `:ecto_sqlite3`
        is not in your dependencies. Skipping.

        For a fresh project, generate it with:

            mix phx.new my_app --database sqlite3
        """)
      end
    end

    defp apply_changes(igniter) do
      db_name = igniter.args.options[:db_name] || default_db_name()
      {igniter, repos} = Igniter.Libs.Ecto.list_repos(igniter)
      app_name = Igniter.Project.Application.app_name(igniter)

      igniter
      |> configure_repos_database(repos, app_name, db_name, "dev")
      |> configure_repos_database(repos, app_name, db_name, "test")
      |> PhoenixStarter.Project.Gitignore.add_line("*.db")
      |> PhoenixStarter.Project.Gitignore.add_line("*.db-*")
    end

    defp configure_repos_database(igniter, repos, app_name, db_name, env) do
      path = "../priv/db/#{db_name}_#{env}.db"

      db_ast =
        Sourceror.parse_string!(~s|Path.expand("#{path}", Path.dirname(__ENV__.file))|)

      Enum.reduce(repos, igniter, fn repo, igniter ->
        Igniter.Project.Config.configure(
          igniter,
          "#{env}.exs",
          app_name,
          [repo, :database],
          {:code, db_ast}
        )
      end)
    end

    defp default_db_name do
      File.cwd!() |> Path.basename() |> Path.rootname()
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.Sqlite do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.sqlite' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
