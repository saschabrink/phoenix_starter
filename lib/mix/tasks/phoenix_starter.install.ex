defmodule Mix.Tasks.PhoenixStarter.Install.Docs do
  @moduledoc false

  def short_doc, do: "Applies all phoenix_starter generators to the project"

  def example, do: "mix phoenix_starter.install"

  def long_doc do
    """
    #{short_doc()}

    Runs every `phoenix_starter.gen.*` task in sequence. Invoked
    automatically when phoenix_starter is added via `mix igniter.new --install`.

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :phoenix_starter,
        example: __MODULE__.Docs.example(),
        composes: ["phoenix_starter.gen.flake", "phoenix_starter.gen.postgres"]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> Igniter.compose_task("phoenix_starter.gen.flake", [])
      |> Igniter.compose_task("phoenix_starter.gen.postgres", [])
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.install' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
