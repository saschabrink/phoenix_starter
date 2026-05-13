defmodule Mix.Tasks.PhoenixStarter.Gen.PostgresTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  @flake_nix File.read!(Path.expand("../../../priv/templates/flake.nix", __DIR__))

  defp postgres_project(extra_files \\ %{}) do
    files = Map.merge(%{"flake.nix" => @flake_nix}, extra_files)

    test_project(files: files)
    |> Igniter.Project.Deps.add_dep({:postgrex, ">= 0.0.0"})
    |> Igniter.Project.Module.create_module(Test.Repo, """
    use Ecto.Repo, otp_app: :test, adapter: Ecto.Adapters.Postgres
    """)
  end

  describe "without :postgrex" do
    test "emits a warning and makes no changes" do
      test_project(files: %{"flake.nix" => @flake_nix})
      |> Igniter.compose_task("phoenix_starter.gen.postgres", [])
      |> assert_has_warning(&String.contains?(&1, ":postgrex"))
      |> assert_unchanged()
    end
  end

  describe "with :postgrex" do
    test "adds pg_spawner as a dev/test dep" do
      postgres_project()
      |> Igniter.compose_task("phoenix_starter.gen.postgres", [])
      |> assert_has_patch("mix.exs", """
      + |      {:pg_spawner, "~> 0.1", only: [:dev, :test]},
      """)
    end

    test "adds postgresql_18 to flake.nix buildInputs" do
      postgres_project()
      |> Igniter.compose_task("phoenix_starter.gen.postgres", [])
      |> assert_has_patch("flake.nix", """
        |          pkgs.elixir_1_19
      + |          pkgs.postgresql_18
      """)
    end

    test "adds a labeled postgres shell-hook block exporting PGPORT" do
      postgres_project()
      |> Igniter.compose_task("phoenix_starter.gen.postgres", [])
      |> assert_has_patch("flake.nix", """
      + |            # >>> postgres
      + |            export PGPORT=15432
      + |            # <<< postgres
      """)
    end

    test "adds /priv/db/ to .gitignore" do
      postgres_project()
      |> Igniter.compose_task("phoenix_starter.gen.postgres", [])
      |> assert_has_patch(".gitignore", """
      + |/priv/db/
      """)
    end

    test "sets the Repo port to 15432 in dev.exs" do
      postgres_project()
      |> Igniter.compose_task("phoenix_starter.gen.postgres", [])
      |> assert_creates("config/dev.exs", """
      import Config
      config :test, Test.Repo, port: 15432
      """)
    end

    test "is idempotent — re-running adds nothing" do
      first =
        postgres_project()
        |> Igniter.compose_task("phoenix_starter.gen.postgres", [])
        |> apply_igniter!()

      first
      |> Igniter.compose_task("phoenix_starter.gen.postgres", [])
      |> assert_unchanged()
    end
  end
end
