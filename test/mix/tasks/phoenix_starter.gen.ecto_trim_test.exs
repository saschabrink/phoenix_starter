defmodule Mix.Tasks.PhoenixStarter.Gen.EctoTrimTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  test "adds {:ecto_trim, \"~> 1.0\"} to deps" do
    test_project()
    |> Igniter.compose_task("phoenix_starter.gen.ecto_trim", [])
    |> assert_has_patch("mix.exs", """
    + |      {:ecto_trim, "~> 1.0"}
    """)
  end

  test "is idempotent — re-running adds nothing" do
    first =
      test_project()
      |> Igniter.compose_task("phoenix_starter.gen.ecto_trim", [])
      |> apply_igniter!()

    first
    |> Igniter.compose_task("phoenix_starter.gen.ecto_trim", [])
    |> assert_unchanged()
  end
end
