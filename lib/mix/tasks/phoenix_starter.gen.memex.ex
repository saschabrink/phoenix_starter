defmodule Mix.Tasks.PhoenixStarter.Gen.Memex.Docs do
  @moduledoc false

  def short_doc, do: "Sets up memex for the project + Claude Code hooks for blueprint injection"

  def example, do: "mix phoenix_starter.gen.memex"

  def long_doc do
    """
    #{short_doc()}

    Configures [memex](https://github.com/exfoundry/memex) for blueprint-driven
    development:

    - Writes `memex.toml` with the detected project name, the shared
      `phoenix-framework` blueprint remote, and the `deps/` usage-rules index.
    - Creates `docs/<name>/.gitkeep` so the project's blueprint dir is tracked.
    - Drops `.claude/hooks/{pre,post}/` scripts that delegate to
      `memex hook-advice` for blueprint injection and test-coverage hints.
    - Registers those hooks in `.claude/settings.json`.

    The project name defaults to the project directory's basename with its
    file extension stripped (`lingofox.ai` → `lingofox`); override with `--name`.

    ## Example

    ```sh
    #{example()}
    ```

    ## Options

    * `--name` — project name used in `memex.toml` and `docs/<name>/`.
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.Memex do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @templates_dir Path.join(:code.priv_dir(:phoenix_starter), "templates/memex")

    @memex_toml_template Path.join(@templates_dir, "memex.toml")
    @external_resource @memex_toml_template
    @memex_toml_body File.read!(@memex_toml_template)

    @pre_hook_template Path.join(@templates_dir, "hooks/pre/inject_blueprint_for_filetype.sh")
    @external_resource @pre_hook_template
    @pre_hook_body File.read!(@pre_hook_template)

    @post_hook_template Path.join(@templates_dir, "hooks/post/check_for_corresponding_test.sh")
    @external_resource @post_hook_template
    @post_hook_body File.read!(@post_hook_template)

    @pre_hook_path ".claude/hooks/pre/inject_blueprint_for_filetype.sh"
    @post_hook_path ".claude/hooks/post/check_for_corresponding_test.sh"

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :phoenix_starter,
        example: __MODULE__.Docs.example(),
        schema: [name: :string]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      name = igniter.args.options[:name] || default_name()

      igniter
      |> Igniter.create_new_file("memex.toml", render_memex_toml(name), on_exists: :skip)
      |> Igniter.create_new_file("docs/#{name}/.gitkeep", "\n")
      |> Igniter.create_new_file(@pre_hook_path, @pre_hook_body, on_exists: :skip)
      |> Igniter.create_new_file(@post_hook_path, @post_hook_body, on_exists: :skip)
      |> PhoenixStarter.Project.Claude.add_hook(
        event: :PreToolUse,
        matcher: "Write|Edit",
        command: "bash #{@pre_hook_path}",
        status_message: "Checking blueprints..."
      )
      |> PhoenixStarter.Project.Claude.add_hook(
        event: :PostToolUse,
        matcher: "Write|Edit",
        command: "bash #{@post_hook_path}",
        status_message: "Checking for tests..."
      )
    end

    defp render_memex_toml(name) do
      String.replace(@memex_toml_body, "{{project_name}}", name)
    end

    defp default_name do
      File.cwd!() |> Path.basename() |> Path.rootname()
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.Memex do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.memex' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
