defmodule Mix.Tasks.PhoenixStarter.Gen.FormatHookTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  describe "phoenix_starter.gen.format_hook" do
    test "creates the post-write format hook script" do
      test_project()
      |> Igniter.compose_task("phoenix_starter.gen.format_hook", [])
      |> assert_creates(".claude/hooks/post/run_mix_format.sh")
    end

    test "registers the hook in .claude/settings.json" do
      igniter =
        test_project()
        |> Igniter.compose_task("phoenix_starter.gen.format_hook", [])
        |> apply_igniter!()

      data = Jason.decode!(igniter.assigns.test_files[".claude/settings.json"])

      commands =
        data
        |> get_in(["hooks", "PostToolUse"])
        |> hd()
        |> Map.fetch!("hooks")
        |> Enum.map(& &1["command"])

      assert commands == ["bash .claude/hooks/post/run_mix_format.sh"]
    end

    test "is idempotent — re-running adds nothing" do
      first =
        test_project()
        |> Igniter.compose_task("phoenix_starter.gen.format_hook", [])
        |> apply_igniter!()

      first
      |> Igniter.compose_task("phoenix_starter.gen.format_hook", [])
      |> assert_unchanged()
    end
  end
end
