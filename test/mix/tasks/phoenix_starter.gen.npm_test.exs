defmodule Mix.Tasks.PhoenixStarter.Gen.NpmTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  @flake_nix File.read!(Path.expand("../../../priv/templates/flake.nix", __DIR__))

  defp project do
    test_project(files: %{"flake.nix" => @flake_nix})
  end

  describe "phoenix_starter.gen.npm" do
    test "adds nodejs to flake buildInputs" do
      project()
      |> Igniter.compose_task("phoenix_starter.gen.npm", [])
      |> assert_has_patch("flake.nix", """
        |          pkgs.elixir_1_19
      + |          pkgs.nodejs_24
      """)
    end

    test "adds an NPM_HOME shell-hook block" do
      project()
      |> Igniter.compose_task("phoenix_starter.gen.npm", [])
      |> assert_has_patch("flake.nix", """
      + |            # >>> node
      + |            export NPM_HOME=$PWD/.nix/npm
      + |            export PATH=$NPM_HOME/bin:$PATH
      + |            npm set prefix $NPM_HOME
      + |            # <<< node
      """)
    end

    test "adds /assets/node_modules/ to .gitignore" do
      project()
      |> Igniter.compose_task("phoenix_starter.gen.npm", [])
      |> assert_has_patch(".gitignore", """
      + |/assets/node_modules/
      """)
    end

    test "is idempotent — re-running adds nothing" do
      first =
        project()
        |> Igniter.compose_task("phoenix_starter.gen.npm", [])
        |> apply_igniter!()

      first
      |> Igniter.compose_task("phoenix_starter.gen.npm", [])
      |> assert_unchanged()
    end
  end
end
