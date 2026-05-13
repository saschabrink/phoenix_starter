defmodule Mix.Tasks.PhoenixStarter.Gen.DirenvTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  test "creates .envrc with dotenv_if_exists + use flake ." do
    test_project()
    |> Igniter.compose_task("phoenix_starter.gen.direnv", [])
    |> assert_creates(".envrc", """
    dotenv_if_exists
    use flake .
    """)
  end

  test "patches .gitignore with /.direnv/ and .env" do
    test_project()
    |> Igniter.compose_task("phoenix_starter.gen.direnv", [])
    |> assert_has_patch(".gitignore", """
    + |/.direnv/
    + |.env
    """)
  end

  test "does not overwrite an existing .envrc" do
    test_project(files: %{".envrc" => "# user-edited\n"})
    |> Igniter.include_existing_file(".envrc")
    |> Igniter.compose_task("phoenix_starter.gen.direnv", [])
    |> assert_unchanged(".envrc")
  end

  test "is idempotent — re-running adds nothing" do
    first =
      test_project()
      |> Igniter.compose_task("phoenix_starter.gen.direnv", [])
      |> apply_igniter!()

    first
    |> Igniter.compose_task("phoenix_starter.gen.direnv", [])
    |> assert_unchanged()
  end
end
