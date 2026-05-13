defmodule Mix.Tasks.PhoenixStarter.Gen.CredoTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  test "adds credo as a dev/test, runtime: false dep" do
    test_project()
    |> Igniter.compose_task("phoenix_starter.gen.credo", [])
    |> assert_has_patch("mix.exs", """
    + |      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    """)
  end

  test "adds ex_slop as a dev/test, runtime: false dep" do
    test_project()
    |> Igniter.compose_task("phoenix_starter.gen.credo", [])
    |> assert_has_patch("mix.exs", """
    + |      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false}
    """)
  end

  test "writes a tuned .credo.exs (strict, disables, ExSlop) on a fresh project" do
    igniter =
      test_project()
      |> Igniter.compose_task("phoenix_starter.gen.credo", [])
      |> apply_igniter!()

    config = igniter.assigns.test_files[".credo.exs"]

    assert config =~ "strict: true,"
    refute config =~ "strict: false,"

    assert config =~ "{Credo.Check.Readability.ModuleDoc, false}"
    assert config =~ "{Credo.Check.Design.AliasUsage, false}"
    assert config =~ "{ExSlop, []}"

    # The file still parses.
    assert {:ok, _term} = Code.string_to_quoted(config)
  end

  test "applies the patches even when .credo.exs already exists (no skip)" do
    snapshot =
      File.read!(Path.expand("../../../priv/templates/credo/credo.exs.snapshot", __DIR__))

    igniter =
      test_project(files: %{".credo.exs" => snapshot})
      |> Igniter.include_existing_file(".credo.exs")
      |> Igniter.compose_task("phoenix_starter.gen.credo", [])
      |> apply_igniter!()

    config = igniter.assigns.test_files[".credo.exs"]

    assert config =~ "strict: true,"
    assert config =~ "{Credo.Check.Readability.ModuleDoc, false}"
    assert config =~ "{ExSlop, []}"
  end

  test "is idempotent — re-running adds nothing" do
    first =
      test_project()
      |> Igniter.compose_task("phoenix_starter.gen.credo", [])
      |> apply_igniter!()

    first
    |> Igniter.compose_task("phoenix_starter.gen.credo", [])
    |> assert_unchanged()
  end
end
