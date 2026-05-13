defmodule Mix.Tasks.PhoenixStarter.Gen.EctoTrim.Docs do
  @moduledoc false

  def short_doc, do: "Adds ecto_trim as a dependency"

  def example, do: "mix phoenix_starter.gen.ecto_trim"

  def long_doc do
    """
    #{short_doc()}

    Adds `{:ecto_trim, "~> 1.0"}` to `mix.exs`. `ecto_trim` is an Ecto
    parameterized type that trims and normalizes whitespace on cast and
    dump — used inline in schemas, no further setup required.

    Idempotent — `Igniter.Project.Deps.add_dep/2` is a no-op if the dep
    is already declared.

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.EctoTrim do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

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
      Igniter.Project.Deps.add_dep(igniter, {:ecto_trim, "~> 1.0"})
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.EctoTrim do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.ecto_trim' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
