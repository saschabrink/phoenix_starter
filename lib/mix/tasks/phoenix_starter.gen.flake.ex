defmodule Mix.Tasks.PhoenixStarter.Gen.Flake.Docs do
  @moduledoc false

  @spec short_doc() :: String.t()
  def short_doc do
    "Generates a flake.nix for an Elixir development environment"
  end

  @spec example() :: String.t()
  def example do
    "mix phoenix_starter.gen.flake"
  end

  @spec long_doc() :: String.t()
  def long_doc do
    """
    #{short_doc()}

    Creates a `flake.nix` at the project root providing a minimal Nix dev
    shell with Elixir. The flake is universal — it contains no project-specific
    values.

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.Flake do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @flake_nix_path Path.join(:code.priv_dir(:phoenix_starter), "templates/flake.nix")
    @flake_lock_path Path.join(:code.priv_dir(:phoenix_starter), "templates/flake.lock")
    @external_resource @flake_nix_path
    @external_resource @flake_lock_path
    @flake_nix File.read!(@flake_nix_path)
    @flake_lock File.read!(@flake_lock_path)

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :phoenix_starter,
        example: __MODULE__.Docs.example(),
        positional: [],
        schema: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> Igniter.create_new_file("flake.nix", @flake_nix, on_exists: :skip)
      |> Igniter.create_new_file("flake.lock", @flake_lock, on_exists: :skip)
      |> PhoenixStarter.Project.Gitignore.add_line("/.nix/")
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.Flake do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.flake' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
