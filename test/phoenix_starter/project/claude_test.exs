defmodule PhoenixStarter.Project.ClaudeTest do
  use ExUnit.Case
  import Igniter.Test

  alias PhoenixStarter.Project.Claude

  defp encode(data), do: Jason.encode!(data, pretty: true) <> "\n"

  defp read_settings(igniter, path \\ ".claude/settings.json") do
    igniter
    |> Map.fetch!(:assigns)
    |> Map.fetch!(:test_files)
    |> Map.fetch!(path)
    |> Jason.decode!()
  end

  describe "add_hook/2" do
    test "creates .claude/settings.json with the hook when missing" do
      test_project()
      |> Claude.add_hook(
        event: :PostToolUse,
        matcher: "Write|Edit",
        command: "bash .claude/hooks/post/run_mix_format.sh",
        status_message: "Formatting..."
      )
      |> assert_creates(".claude/settings.json", """
      {
        "hooks": {
          "PostToolUse": [
            {
              "hooks": [
                {
                  "command": "bash .claude/hooks/post/run_mix_format.sh",
                  "statusMessage": "Formatting...",
                  "type": "command"
                }
              ],
              "matcher": "Write|Edit"
            }
          ]
        }
      }
      """)
    end

    test "accepts a string event name" do
      test_project()
      |> Claude.add_hook(event: "PreToolUse", matcher: "Write|Edit", command: "echo hi")
      |> apply_igniter!()
      |> read_settings()
      |> then(fn data ->
        assert get_in(data, ["hooks", "PreToolUse"]) |> hd() |> Map.fetch!("matcher") == "Write|Edit"
      end)
    end

    test "omits statusMessage when not provided" do
      igniter =
        test_project()
        |> Claude.add_hook(event: :PreToolUse, matcher: "Write|Edit", command: "echo hi")
        |> apply_igniter!()

      hook = igniter |> read_settings() |> get_in(["hooks", "PreToolUse"]) |> hd() |> get_in(["hooks"]) |> hd()
      refute Map.has_key?(hook, "statusMessage")
    end

    test "appends to the same matcher block when present" do
      initial =
        encode(%{
          "hooks" => %{
            "PostToolUse" => [
              %{
                "matcher" => "Write|Edit",
                "hooks" => [%{"type" => "command", "command" => "first"}]
              }
            ]
          }
        })

      igniter =
        test_project(files: %{".claude/settings.json" => initial})
        |> Claude.add_hook(event: :PostToolUse, matcher: "Write|Edit", command: "second")
        |> apply_igniter!()

      commands =
        igniter
        |> read_settings()
        |> get_in(["hooks", "PostToolUse"])
        |> hd()
        |> Map.fetch!("hooks")
        |> Enum.map(& &1["command"])

      assert commands == ["first", "second"]
    end

    test "adds a new matcher block when matcher differs" do
      initial =
        encode(%{
          "hooks" => %{
            "PostToolUse" => [
              %{
                "matcher" => "Write",
                "hooks" => [%{"type" => "command", "command" => "for-write"}]
              }
            ]
          }
        })

      igniter =
        test_project(files: %{".claude/settings.json" => initial})
        |> Claude.add_hook(event: :PostToolUse, matcher: "Edit", command: "for-edit")
        |> apply_igniter!()

      matchers =
        igniter
        |> read_settings()
        |> get_in(["hooks", "PostToolUse"])
        |> Enum.map(& &1["matcher"])

      assert matchers == ["Write", "Edit"]
    end

    test "is idempotent — same command twice is a no-op" do
      initial =
        encode(%{
          "hooks" => %{
            "PreToolUse" => [
              %{
                "matcher" => "Write|Edit",
                "hooks" => [%{"type" => "command", "command" => "echo hi"}]
              }
            ]
          }
        })

      test_project(files: %{".claude/settings.json" => initial})
      |> Claude.add_hook(event: :PreToolUse, matcher: "Write|Edit", command: "echo hi")
      |> assert_unchanged(".claude/settings.json")
    end

    test "preserves other top-level keys when settings.json exists" do
      initial =
        encode(%{
          "model" => "claude-sonnet-4-5",
          "hooks" => %{}
        })

      igniter =
        test_project(files: %{".claude/settings.json" => initial})
        |> Claude.add_hook(event: :PreToolUse, matcher: "Write|Edit", command: "echo hi")
        |> apply_igniter!()

      data = read_settings(igniter)
      assert data["model"] == "claude-sonnet-4-5"
      assert get_in(data, ["hooks", "PreToolUse"]) |> length() == 1
    end
  end
end
