defmodule Mix.Tasks.PhoenixStarter.Gen.CoreContexts.Docs do
  @moduledoc false

  def short_doc, do: "Installs ecto_context + static_context, the core contexts combo"

  def example, do: "mix phoenix_starter.gen.core_contexts"

  def long_doc do
    """
    #{short_doc()}

    Adds two exfoundry packages to the project's dependencies and wires them
    into `.formatter.exs`:

    - `ecto_context` — scoped CRUD with a permission layer via macro DSL
    - `static_context` — in-memory lookup data with a uniform query API

    Both ship a `.formatter.exs` that needs to be imported via `import_deps`
    so their macro DSL formats correctly.

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.CoreContexts do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :phoenix_starter,
        example: __MODULE__.Docs.example()
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      # Both helpers prepend, so call the ones we want last first.
      igniter
      |> Igniter.Project.Deps.add_dep({:static_context, "~> 0.2"})
      |> Igniter.Project.Deps.add_dep({:ecto_context, "~> 0.3"})
      |> Igniter.Project.Formatter.import_dep(:static_context)
      |> Igniter.Project.Formatter.import_dep(:ecto_context)
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.CoreContexts do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.core_contexts' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
