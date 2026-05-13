defmodule Mix.Tasks.PhoenixStarter.Gen.FormatHook.Docs do
  @moduledoc false

  def short_doc, do: "Installs a Claude Code post-write hook that auto-formats Elixir files"

  def example, do: "mix phoenix_starter.gen.format_hook"

  def long_doc do
    """
    #{short_doc()}

    Drops a `.claude/hooks/post/run_mix_format.sh` script that runs
    `mix format <file>` (via `nix develop`) after every Write or Edit on
    an `.ex` or `.exs` file, and registers it in `.claude/settings.json`.

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.FormatHook do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @template_path Path.join(:code.priv_dir(:phoenix_starter), "templates/format_hook.sh")
    @external_resource @template_path
    @script_body File.read!(@template_path)

    @script_path ".claude/hooks/post/run_mix_format.sh"

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :phoenix_starter,
        example: __MODULE__.Docs.example()
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> Igniter.create_new_file(@script_path, @script_body, on_exists: :skip)
      |> PhoenixStarter.Project.Claude.add_hook(
        event: :PostToolUse,
        matcher: "Write|Edit",
        command: "bash #{@script_path}",
        status_message: "Formatting..."
      )
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.FormatHook do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.format_hook' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
