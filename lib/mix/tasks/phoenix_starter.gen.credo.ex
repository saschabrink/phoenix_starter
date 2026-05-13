defmodule Mix.Tasks.PhoenixStarter.Gen.Credo.Docs do
  @moduledoc false

  def short_doc, do: "Adds credo + ex_slop and tunes .credo.exs"

  def example, do: "mix phoenix_starter.gen.credo"

  def long_doc do
    """
    #{short_doc()}

    Does three things, each idempotent:

    1. Adds `{:credo, "~> 1.7", only: [:dev, :test], runtime: false}` and
       `{:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false}` to
       `mix.exs`.
    2. Ensures `.credo.exs` exists. Writes credo's stock template
       (snapshotted under `priv/templates/credo/`, refreshable via
       `mix phoenix_starter.refresh_credo_snapshot`) if missing.
    3. Applies these patches to `.credo.exs` via
       `PhoenixStarter.Project.Credo`:
       * `set_strict(true)`
       * `disable_check(Credo.Check.Readability.ModuleDoc)`
       * `disable_check(Credo.Check.Design.AliasUsage)`
       * `add_check(ExSlop)`

    Each patch leaves the file alone if the desired state already holds,
    so this task is safe to re-run on a project that already has custom
    Credo tweaks.

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.Credo do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    alias PhoenixStarter.Project.Credo, as: CredoProject

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :phoenix_starter,
        example: __MODULE__.Docs.example(),
        schema: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> Igniter.Project.Deps.add_dep({:credo, "~> 1.7", only: [:dev, :test], runtime: false})
      |> Igniter.Project.Deps.add_dep({:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false})
      |> CredoProject.ensure_config()
      |> CredoProject.set_strict(true)
      |> CredoProject.disable_check(Credo.Check.Readability.ModuleDoc)
      |> CredoProject.disable_check(Credo.Check.Design.AliasUsage)
      |> CredoProject.add_check(ExSlop)
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.Credo do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.credo' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
