defmodule Mix.Tasks.PhoenixStarter.Gen.Npm.Docs do
  @moduledoc false

  def short_doc, do: "Adds Node.js to the Nix dev shell"

  def example, do: "mix phoenix_starter.gen.npm"

  def long_doc do
    """
    #{short_doc()}

    Drops `pkgs.nodejs_24` into `flake.nix` `buildInputs` and a shellHook
    block that points `npm`'s prefix at `.nix/npm/` (so globally-installed
    binaries stay project-local). Also adds `/assets/node_modules/` to
    `.gitignore`.

    Does not create `assets/package.json` — that happens on-demand when
    another task adds its first npm dependency via
    `PhoenixStarter.Project.Npm.add_dependency/4`.

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.Npm do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @shell_hook """
    export NPM_HOME=$PWD/.nix/npm
    export PATH=$NPM_HOME/bin:$PATH
    npm set prefix $NPM_HOME
    """

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
      |> PhoenixStarter.Project.Flake.add_build_input("pkgs.nodejs_24")
      |> PhoenixStarter.Project.Flake.add_shell_hook(:node, @shell_hook)
      |> PhoenixStarter.Project.Gitignore.add_line("/assets/node_modules/")
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.Npm do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.npm' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
