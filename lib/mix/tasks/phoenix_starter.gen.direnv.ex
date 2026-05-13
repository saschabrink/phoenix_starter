defmodule Mix.Tasks.PhoenixStarter.Gen.Direnv.Docs do
  @moduledoc false

  def short_doc, do: "Generates a universal .envrc for direnv + an optional .env"

  def example, do: "mix phoenix_starter.gen.direnv"

  def long_doc do
    """
    #{short_doc()}

    Creates a project-agnostic `.envrc` that:

    - Loads `.env` if present (`dotenv_if_exists` — does nothing when absent).
    - Activates the project's Nix dev shell (`use flake .`).

    Adds `/.direnv/` and `.env` to `.gitignore` so the cache dir and any
    local secrets stay out of version control.

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.Direnv do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @envrc """
    dotenv_if_exists
    use flake .
    """

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
      |> Igniter.create_new_file(".envrc", @envrc, on_exists: :skip)
      |> PhoenixStarter.Project.Gitignore.add_line("/.direnv/")
      |> PhoenixStarter.Project.Gitignore.add_line(".env")
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.Direnv do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.direnv' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
