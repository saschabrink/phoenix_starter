defmodule Mix.Tasks.PhoenixStarter.Gen.FlakeTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  @expected File.read!(Path.expand("../../../priv/templates/flake.nix", __DIR__))

  test "creates flake.nix at project root" do
    test_project()
    |> Igniter.compose_task("phoenix_starter.gen.flake", [])
    |> assert_creates("flake.nix", @expected)
  end

  test "is idempotent — does not overwrite an existing flake.nix" do
    test_project(files: %{"flake.nix" => "# user-edited\n"})
    |> Igniter.compose_task("phoenix_starter.gen.flake", [])
    |> assert_unchanged("flake.nix")
  end
end
