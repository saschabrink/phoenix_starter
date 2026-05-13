defmodule Mix.Tasks.PhoenixStarter.Gen.Postgres.Docs do
  @moduledoc false

  def short_doc, do: "Wires a Phoenix project for managed local Postgres"

  def example, do: "mix phoenix_starter.gen.postgres"

  def long_doc do
    """
    #{short_doc()}

    Adds `pg_spawner` for zero-config local Postgres, drops Postgres into the
    Nix dev shell, sets the dev Repo port to 15432, and ignores the pgdata
    directory. Aborts with a warning if `:postgrex` is not in the project's
    dependencies — this task is for Postgres-backed projects only.

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.Postgres do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @port 15432

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :phoenix_starter,
        example: __MODULE__.Docs.example()
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      if Igniter.Project.Deps.has_dep?(igniter, :postgrex) do
        apply_changes(igniter)
      else
        Igniter.add_warning(igniter, """
        phoenix_starter.gen.postgres expects a Postgres-backed project, but `:postgrex`
        is not in your dependencies. Skipping.

        For a fresh project, generate it with:

            mix phx.new my_app --database postgres
        """)
      end
    end

    defp apply_changes(igniter) do
      {igniter, repos} = Igniter.Libs.Ecto.list_repos(igniter)
      app_name = Igniter.Project.Application.app_name(igniter)

      igniter
      |> Igniter.Project.Deps.add_dep({:pg_spawner, "~> 0.1", only: [:dev, :test]})
      |> PhoenixStarter.Project.Flake.add_build_input("pkgs.postgresql_18")
      |> PhoenixStarter.Project.Flake.add_shell_hook(:postgres, "export PGPORT=#{@port}\n")
      |> PhoenixStarter.Project.Gitignore.add_line("/priv/db/")
      |> configure_repos_port(repos, app_name)
    end

    defp configure_repos_port(igniter, repos, app_name) do
      Enum.reduce(repos, igniter, fn repo, igniter ->
        Igniter.Project.Config.configure(igniter, "dev.exs", app_name, [repo, :port], @port)
      end)
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.Postgres do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.postgres' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
