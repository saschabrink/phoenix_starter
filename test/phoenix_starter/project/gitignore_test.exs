defmodule PhoenixStarter.Project.GitignoreTest do
  use ExUnit.Case
  import Igniter.Test

  describe "add_line/2" do
    test "appends the line when .gitignore exists without it" do
      test_project(files: %{".gitignore" => "/_build/\n/deps/\n"})
      |> PhoenixStarter.Project.Gitignore.add_line("/.nix/")
      |> assert_has_patch(".gitignore", """
      + |/.nix/
      """)
    end

    test "creates .gitignore when it does not exist" do
      test_project(files: %{".gitignore" => nil})
      |> PhoenixStarter.Project.Gitignore.add_line("/.nix/")
      |> assert_creates(".gitignore", "/.nix/\n")
    end

    test "is idempotent — does not duplicate an existing line" do
      test_project(files: %{".gitignore" => "/_build/\n/.nix/\n/deps/\n"})
      |> PhoenixStarter.Project.Gitignore.add_line("/.nix/")
      |> assert_unchanged(".gitignore")
    end

    test "ensures a trailing newline before appending" do
      test_project(files: %{".gitignore" => "/_build/"})
      |> PhoenixStarter.Project.Gitignore.add_line("/.nix/")
      |> assert_has_patch(".gitignore", """
      + |/.nix/
      """)
    end

    test "treats lines with different trailing slashes as distinct" do
      test_project(files: %{".gitignore" => "/.nix\n"})
      |> PhoenixStarter.Project.Gitignore.add_line("/.nix/")
      |> assert_has_patch(".gitignore", """
      + |/.nix/
      """)
    end
  end
end
