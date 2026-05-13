defmodule Mix.Tasks.PhoenixStarter.Gen.CoreContextsTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  describe "phoenix_starter.gen.core_contexts" do
    test "adds ecto_context and static_context to mix.exs" do
      test_project()
      |> Igniter.compose_task("phoenix_starter.gen.core_contexts", [])
      |> assert_has_patch("mix.exs", """
      + |      {:ecto_context, "~> 0.3"},
      """)
      |> assert_has_patch("mix.exs", """
      + |      {:static_context, "~> 0.2"}
      """)
    end

    test "imports both deps into .formatter.exs" do
      test_project()
      |> Igniter.compose_task("phoenix_starter.gen.core_contexts", [])
      |> assert_has_patch(".formatter.exs", """
      + |  import_deps: [:ecto_context, :static_context]
      """)
    end

    test "is idempotent — re-running adds nothing" do
      first =
        test_project()
        |> Igniter.compose_task("phoenix_starter.gen.core_contexts", [])
        |> apply_igniter!()

      first
      |> Igniter.compose_task("phoenix_starter.gen.core_contexts", [])
      |> assert_unchanged()
    end
  end
end
