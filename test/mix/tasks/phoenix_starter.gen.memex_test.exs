defmodule Mix.Tasks.PhoenixStarter.Gen.MemexTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  describe "phoenix_starter.gen.memex" do
    test "creates memex.toml with the given project name" do
      igniter =
        test_project()
        |> Igniter.compose_task("phoenix_starter.gen.memex", ["--name", "myapp"])
        |> apply_igniter!()

      toml = igniter.assigns.test_files["memex.toml"]
      assert toml =~ ~s|project_name = "myapp"|
      assert toml =~ "[myapp]"
      assert toml =~ ~s|mount = "docs/myapp"|
    end

    test "creates docs/<name>/.gitkeep so the dir is tracked" do
      test_project()
      |> Igniter.compose_task("phoenix_starter.gen.memex", ["--name", "myapp"])
      |> assert_creates("docs/myapp/.gitkeep", "")
    end

    test "drops the two memex hook scripts" do
      test_project()
      |> Igniter.compose_task("phoenix_starter.gen.memex", ["--name", "myapp"])
      |> assert_creates(".claude/hooks/pre/inject_blueprint_for_filetype.sh")
      |> assert_creates(".claude/hooks/post/check_for_corresponding_test.sh")
    end

    test "registers both hooks in .claude/settings.json" do
      igniter =
        test_project()
        |> Igniter.compose_task("phoenix_starter.gen.memex", ["--name", "myapp"])
        |> apply_igniter!()

      data =
        igniter.assigns.test_files[".claude/settings.json"]
        |> Jason.decode!()

      pre_commands =
        data
        |> get_in(["hooks", "PreToolUse"])
        |> hd()
        |> Map.fetch!("hooks")
        |> Enum.map(& &1["command"])

      post_commands =
        data
        |> get_in(["hooks", "PostToolUse"])
        |> hd()
        |> Map.fetch!("hooks")
        |> Enum.map(& &1["command"])

      assert pre_commands == ["bash .claude/hooks/pre/inject_blueprint_for_filetype.sh"]
      assert post_commands == ["bash .claude/hooks/post/check_for_corresponding_test.sh"]
    end

    test "defaults name to project dir basename with extension stripped" do
      # Tests run from phoenix_starter — default name is "phoenix_starter"
      igniter =
        test_project()
        |> Igniter.compose_task("phoenix_starter.gen.memex", [])
        |> apply_igniter!()

      assert igniter.assigns.test_files["memex.toml"] =~ ~s|project_name = "phoenix_starter"|
    end

    test "is idempotent — re-running adds nothing" do
      first =
        test_project()
        |> Igniter.compose_task("phoenix_starter.gen.memex", ["--name", "myapp"])
        |> apply_igniter!()

      first
      |> Igniter.compose_task("phoenix_starter.gen.memex", ["--name", "myapp"])
      |> assert_unchanged()
    end
  end
end
