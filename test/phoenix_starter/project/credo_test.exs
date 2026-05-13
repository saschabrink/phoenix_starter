defmodule PhoenixStarter.Project.CredoTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  alias PhoenixStarter.Project.Credo, as: CredoProject

  @snapshot File.read!(
              Path.expand(
                "../../../priv/templates/credo/credo.exs.snapshot",
                __DIR__
              )
            )

  defp project_with_credo_config(content \\ @snapshot) do
    test_project(files: %{".credo.exs" => content})
    |> Igniter.include_existing_file(".credo.exs")
  end

  describe "ensure_config/1" do
    test "creates .credo.exs from the stock snapshot when missing" do
      test_project()
      |> CredoProject.ensure_config()
      |> assert_creates(".credo.exs", @snapshot)
    end

    test "leaves an existing .credo.exs untouched" do
      project_with_credo_config("%{configs: []}\n")
      |> CredoProject.ensure_config()
      |> assert_unchanged(".credo.exs")
    end

    test "warns if .credo.exs is missing for downstream patch helpers" do
      test_project()
      |> CredoProject.set_strict(true)
      |> assert_has_warning(&String.contains?(&1, ".credo.exs not found"))
    end
  end

  describe "set_strict/2" do
    test "flips strict: false to strict: true" do
      project_with_credo_config()
      |> CredoProject.set_strict(true)
      |> assert_has_patch(".credo.exs", """
      - |      strict: false,
      + |      strict: true,
      """)
    end

    test "is idempotent when already set" do
      project_with_credo_config()
      |> CredoProject.set_strict(false)
      |> assert_unchanged(".credo.exs")
    end

    test "warns when no strict: line exists" do
      project_with_credo_config("%{configs: []}\n")
      |> CredoProject.set_strict(true)
      |> assert_has_warning(&String.contains?(&1, "set_strict"))
    end
  end

  describe "disable_check/2" do
    test "replaces a default-opts check with {Module, false}" do
      project_with_credo_config()
      |> CredoProject.disable_check(Credo.Check.Readability.ModuleDoc)
      |> assert_has_patch(".credo.exs", """
      - |          {Credo.Check.Readability.ModuleDoc, []},
      + |          {Credo.Check.Readability.ModuleDoc, false},
      """)
    end

    test "replaces a multi-line check entry (e.g. AliasUsage)" do
      igniter =
        project_with_credo_config()
        |> CredoProject.disable_check(Credo.Check.Design.AliasUsage)
        |> apply_igniter!()

      updated = igniter.assigns.test_files[".credo.exs"]

      assert updated =~ "{Credo.Check.Design.AliasUsage, false}"
      refute updated =~ "if_called_more_often_than: 0]}"
    end

    test "is idempotent when already disabled" do
      already_disabled =
        String.replace(
          @snapshot,
          "{Credo.Check.Readability.ModuleDoc, []}",
          "{Credo.Check.Readability.ModuleDoc, false}"
        )

      project_with_credo_config(already_disabled)
      |> CredoProject.disable_check(Credo.Check.Readability.ModuleDoc)
      |> assert_unchanged(".credo.exs")
    end

    test "warns when the check is not in the file" do
      project_with_credo_config("%{configs: []}\n")
      |> CredoProject.disable_check(Credo.Check.Readability.ModuleDoc)
      |> assert_has_warning(&String.contains?(&1, "disable_check"))
    end
  end

  describe "add_check/3" do
    test "appends the new check as the last enabled entry" do
      igniter =
        project_with_credo_config()
        |> CredoProject.add_check(ExSlop)
        |> apply_igniter!()

      updated = igniter.assigns.test_files[".credo.exs"]

      # Comma added to previous last entry; ExSlop sits before the closing.
      assert updated =~ "{Credo.Check.Warning.WrongTestFilename, []},\n          {ExSlop, []}"
    end

    test "is idempotent when the check is already present (any opts)" do
      with_exslop =
        String.replace(
          @snapshot,
          "{Credo.Check.Warning.WrongTestFilename, []}\n",
          "{Credo.Check.Warning.WrongTestFilename, []},\n          {ExSlop, []}\n"
        )

      project_with_credo_config(with_exslop)
      |> CredoProject.add_check(ExSlop)
      |> assert_unchanged(".credo.exs")
    end

    test "produces a file that still parses as a valid Elixir term" do
      igniter =
        project_with_credo_config()
        |> CredoProject.add_check(ExSlop)
        |> apply_igniter!()

      updated = igniter.assigns.test_files[".credo.exs"]

      assert {:ok, term} = Code.string_to_quoted(updated)
      assert {:%{}, _, _} = term
    end
  end
end
