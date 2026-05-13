defmodule Mix.Tasks.PhoenixStarter.InstallTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  test "composes the gen.flake task" do
    test_project()
    |> Igniter.compose_task("phoenix_starter.install", [])
    |> assert_creates("flake.nix")
  end
end
