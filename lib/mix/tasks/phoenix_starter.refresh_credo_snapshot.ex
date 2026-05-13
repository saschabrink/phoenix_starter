defmodule Mix.Tasks.PhoenixStarter.RefreshCredoSnapshot do
  @shortdoc "Re-snapshots credo's stock .credo.exs into priv/templates/credo/"

  @moduledoc """
  Internal maintainer task for phoenix_starter.

  Copies `deps/credo/.credo.exs` (the stock template embedded into the credo
  package) over to `priv/templates/credo/credo.exs.snapshot`. `gen.credo`
  reads this snapshot at consumer-compile time and applies its mods on top.

  Run after bumping the `:credo` dep in phoenix_starter's own `mix.exs`.

      mix phoenix_starter.refresh_credo_snapshot
  """

  use Mix.Task

  @source Path.join(Mix.Project.deps_path(), "credo/.credo.exs")
  @dest Path.join([__DIR__, "..", "..", "..", "priv/templates/credo/credo.exs.snapshot"])
        |> Path.expand()

  @impl Mix.Task
  def run(_argv) do
    unless File.exists?(@source) do
      Mix.raise("""
      Credo is not fetched. Run `mix deps.get` first.
      Expected: #{@source}
      """)
    end

    File.mkdir_p!(Path.dirname(@dest))
    File.cp!(@source, @dest)
    Mix.shell().info("Refreshed credo snapshot: #{Path.relative_to_cwd(@dest)}")
  end
end
