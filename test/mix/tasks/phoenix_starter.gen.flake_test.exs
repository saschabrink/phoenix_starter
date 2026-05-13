defmodule Mix.Tasks.PhoenixStarter.Gen.FlakeTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  @flake_nix File.read!(Path.expand("../../../priv/templates/flake.nix", __DIR__))
  @flake_lock File.read!(Path.expand("../../../priv/templates/flake.lock", __DIR__))

  test "creates flake.nix and flake.lock at project root" do
    test_project()
    |> Igniter.compose_task("phoenix_starter.gen.flake", [])
    |> assert_creates("flake.nix", @flake_nix)
    |> assert_creates("flake.lock", @flake_lock)
  end

  test "is idempotent — does not overwrite existing flake files" do
    test_project(files: %{"flake.nix" => "# user-edited\n", "flake.lock" => "{}\n"})
    |> Igniter.compose_task("phoenix_starter.gen.flake", [])
    |> assert_unchanged(["flake.nix", "flake.lock"])
  end

  test "patches .gitignore with /.nix/" do
    test_project()
    |> Igniter.compose_task("phoenix_starter.gen.flake", [])
    |> assert_has_patch(".gitignore", """
    + |/.nix/
    """)
  end
end
