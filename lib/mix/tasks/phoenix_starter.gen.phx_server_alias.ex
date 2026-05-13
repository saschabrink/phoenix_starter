defmodule Mix.Tasks.PhoenixStarter.Gen.PhxServerAlias.Docs do
  @moduledoc false

  def short_doc, do: "Adds `s` as a Mix alias for `phx.server`"

  def example, do: "mix phoenix_starter.gen.phx_server_alias"

  def long_doc do
    """
    #{short_doc()}

    Adds `s: "phx.server"` to the `aliases/0` keyword list in `mix.exs` so the
    dev server can be started with `mix s` instead of `mix phx.server`.

    Idempotent — re-running does nothing if `s` is already aliased.

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.PhxServerAlias do
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
      Igniter.Project.TaskAliases.add_alias(igniter, :s, "phx.server")
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.PhxServerAlias do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.phx_server_alias' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
