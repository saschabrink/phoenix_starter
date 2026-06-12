defmodule Mix.Tasks.PhoenixStarter.Gen.PageMeta.Docs do
  @moduledoc false

  def short_doc, do: "Installs phoenix_page_meta for per-page metadata in Phoenix LiveView"

  def example, do: "mix phoenix_starter.gen.page_meta"

  def long_doc do
    """
    #{short_doc()}

    Adds `phoenix_page_meta` and triggers its installer, which creates the
    project-local `<AppWeb>.PageMeta` struct module, injects SEO `<MetaTags>`
    into `root.html.heex`, and wires the LiveView callbacks in
    `<AppWeb>.live_view/0`.

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.PageMeta do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :phoenix_starter,
        example: __MODULE__.Docs.example(),
        installs: [{:phoenix_page_meta, "~> 0.1"}]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      if Code.ensure_loaded?(Mix.Tasks.PhoenixPageMeta.Install) do
        Igniter.compose_task(igniter, "phoenix_page_meta.install", [])
      else
        igniter
      end
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.PageMeta do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.page_meta' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
