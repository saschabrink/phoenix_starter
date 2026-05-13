defmodule Mix.Tasks.PhoenixStarter.Gen.FormatterTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  describe "phoenix_starter.gen.formatter" do
    test "sets line_length: 150 in .formatter.exs" do
      test_project()
      |> Igniter.compose_task("phoenix_starter.gen.formatter", [])
      |> assert_has_patch(".formatter.exs", """
      + |  line_length: 150
      """)
    end

    test "is idempotent — re-running does not duplicate the key" do
      first =
        test_project()
        |> Igniter.compose_task("phoenix_starter.gen.formatter", [])
        |> apply_igniter!()

      first
      |> Igniter.compose_task("phoenix_starter.gen.formatter", [])
      |> assert_unchanged()
    end

    test "overwrites an existing line_length value" do
      test_project(
        files: %{
          ".formatter.exs" => """
          [
            inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
            line_length: 98
          ]
          """
        }
      )
      |> Igniter.compose_task("phoenix_starter.gen.formatter", [])
      |> assert_has_patch(".formatter.exs", """
      - |  line_length: 98
      + |  line_length: 150
      """)
    end
  end
end
