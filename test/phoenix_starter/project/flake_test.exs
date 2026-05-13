defmodule PhoenixStarter.Project.FlakeTest do
  use ExUnit.Case
  import Igniter.Test

  alias PhoenixStarter.Project.Flake

  @base_flake File.read!(Path.expand("../../../priv/templates/flake.nix", __DIR__))

  defp project(files \\ %{}) do
    test_project(files: Map.merge(%{"flake.nix" => @base_flake}, files))
  end

  describe "add_build_input/2" do
    test "inserts a package after pkgs.elixir, matching indent" do
      project()
      |> Flake.add_build_input("pkgs.ruby_4_0")
      |> assert_has_patch("flake.nix", """
        |          pkgs.elixir_1_19
      + |          pkgs.ruby_4_0
      """)
    end

    test "is idempotent — does not add a package twice" do
      project()
      |> Flake.add_build_input("pkgs.ruby_4_0")
      |> Flake.add_build_input("pkgs.ruby_4_0")
      |> assert_has_patch("flake.nix", """
        |          pkgs.elixir_1_19
      + |          pkgs.ruby_4_0
      """)
    end

    test "supports complex package expressions" do
      project()
      |> Flake.add_build_input("pkgs.postgresql_18.withPackages (ps: [ ps.pgvector ])")
      |> assert_has_patch("flake.nix", """
      + |          pkgs.postgresql_18.withPackages (ps: [ ps.pgvector ])
      """)
    end

    test "raises when flake.nix is not in canonical form" do
      assert_raise RuntimeError, ~r/cannot find a `pkgs\.elixir_\*` line/, fn ->
        project(%{"flake.nix" => "{ outputs = ..."})
        |> Flake.add_build_input("pkgs.ruby_4_0")
        |> Igniter.Test.apply_igniter!()
      end
    end
  end

  describe "add_shell_hook/3" do
    test "appends a labeled block before the closing ''" do
      project()
      |> Flake.add_shell_hook(:postgres, """
      export PGDATA=$PWD/priv/db/data
      export PGPORT=15432
      """)
      |> assert_has_patch("flake.nix", """
      + |            # >>> postgres
      + |            export PGDATA=$PWD/priv/db/data
      + |            export PGPORT=15432
      + |            # <<< postgres
      """)
    end

    test "accepts string label" do
      project()
      |> Flake.add_shell_hook("ruby", "export GEM_HOME=$PWD/.nix/gems\n")
      |> assert_has_patch("flake.nix", """
      + |            # >>> ruby
      + |            export GEM_HOME=$PWD/.nix/gems
      + |            # <<< ruby
      """)
    end

    test "is idempotent — same label twice is a no-op" do
      igniter =
        project()
        |> Flake.add_shell_hook(:postgres, "export PGDATA=foo\n")

      igniter
      |> Flake.add_shell_hook(:postgres, "export PGDATA=bar\n")
      |> assert_has_patch("flake.nix", """
      + |            # >>> postgres
      + |            export PGDATA=foo
      + |            # <<< postgres
      """)
    end

    test "different labels coexist" do
      project()
      |> Flake.add_shell_hook(:postgres, "export PGDATA=foo\n")
      |> Flake.add_shell_hook(:ruby, "export GEM_HOME=foo\n")
      |> assert_has_patch("flake.nix", """
      + |            # >>> postgres
      + |            export PGDATA=foo
      + |            # <<< postgres
      + |            # >>> ruby
      + |            export GEM_HOME=foo
      + |            # <<< ruby
      """)
    end
  end
end
