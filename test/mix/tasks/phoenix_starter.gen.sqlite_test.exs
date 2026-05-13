defmodule Mix.Tasks.PhoenixStarter.Gen.SqliteTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  defp sqlite_project do
    test_project()
    |> Igniter.Project.Deps.add_dep({:ecto_sqlite3, ">= 0.0.0"})
    |> Igniter.Project.Module.create_module(Test.Repo, """
    use Ecto.Repo, otp_app: :test, adapter: Ecto.Adapters.SQLite3
    """)
  end

  describe "without :ecto_sqlite3" do
    test "emits a warning and makes no changes" do
      test_project()
      |> Igniter.compose_task("phoenix_starter.gen.sqlite", [])
      |> assert_has_warning(&String.contains?(&1, ":ecto_sqlite3"))
      |> assert_unchanged()
    end
  end

  describe "with :ecto_sqlite3" do
    test "writes the dev DB path to config/dev.exs" do
      sqlite_project()
      |> Igniter.compose_task("phoenix_starter.gen.sqlite", ["--db-name", "myapp"])
      |> assert_creates("config/dev.exs", """
      import Config

      config :test, Test.Repo,
        database: Path.expand("../priv/db/myapp_dev.db", Path.dirname(__ENV__.file))
      """)
    end

    test "writes the test DB path to config/test.exs" do
      sqlite_project()
      |> Igniter.compose_task("phoenix_starter.gen.sqlite", ["--db-name", "myapp"])
      |> assert_creates("config/test.exs", """
      import Config

      config :test, Test.Repo,
        database: Path.expand("../priv/db/myapp_test.db", Path.dirname(__ENV__.file))
      """)
    end

    test "adds SQLite gitignore patterns" do
      sqlite_project()
      |> Igniter.compose_task("phoenix_starter.gen.sqlite", ["--db-name", "myapp"])
      |> assert_has_patch(".gitignore", """
      + |*.db
      + |*.db-*
      """)
    end

    test "is idempotent — re-running adds nothing" do
      first =
        sqlite_project()
        |> Igniter.compose_task("phoenix_starter.gen.sqlite", ["--db-name", "myapp"])
        |> apply_igniter!()

      first
      |> Igniter.compose_task("phoenix_starter.gen.sqlite", ["--db-name", "myapp"])
      |> assert_unchanged()
    end

    test "defaults db-name to project dir basename with extension stripped" do
      # Tests run from the phoenix_starter dir → default db name is "phoenix_starter"
      sqlite_project()
      |> Igniter.compose_task("phoenix_starter.gen.sqlite", [])
      |> assert_creates("config/dev.exs", """
      import Config

      config :test, Test.Repo,
        database: Path.expand("../priv/db/phoenix_starter_dev.db", Path.dirname(__ENV__.file))
      """)
    end
  end
end
