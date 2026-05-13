defmodule PhoenixStarter.Project.NpmTest do
  use ExUnit.Case
  import Igniter.Test

  alias PhoenixStarter.Project.Npm

  defp encode(data), do: Jason.encode!(data, pretty: true) <> "\n"

  defp read(igniter, path \\ "assets/package.json") do
    igniter
    |> Map.fetch!(:assigns)
    |> Map.fetch!(:test_files)
    |> Map.fetch!(path)
    |> Jason.decode!()
  end

  describe "add_dependency/4" do
    test "creates assets/package.json with sensible defaults when missing" do
      igniter =
        test_project()
        |> Npm.add_dependency("topbar", "^3.0.0")
        |> apply_igniter!()

      data = read(igniter)

      assert data["devDependencies"]["topbar"] == "^3.0.0"
      assert data["name"] == "phoenix_starter"
      assert data["version"] == "1.0.0"
    end

    test "adds devDependency by default" do
      igniter =
        test_project()
        |> Npm.add_dependency("topbar", "^3.0.0")
        |> apply_igniter!()

      data = read(igniter)
      assert data["devDependencies"]["topbar"] == "^3.0.0"
      refute data["dependencies"]
    end

    test "respects :type, :runtime for production dependencies" do
      igniter =
        test_project()
        |> Npm.add_dependency("react", "^18.0.0", type: :runtime)
        |> apply_igniter!()

      data = read(igniter)
      assert data["dependencies"]["react"] == "^18.0.0"
      refute data["devDependencies"]["react"]
    end

    test "preserves other fields when package.json already exists" do
      initial =
        encode(%{
          "name" => "myapp",
          "version" => "0.5.0",
          "license" => "MIT",
          "scripts" => %{"watch" => "esbuild --watch"},
          "devDependencies" => %{"daisyui" => "^5.0.50"}
        })

      igniter =
        test_project(files: %{"assets/package.json" => initial})
        |> Npm.add_dependency("topbar", "^3.0.0")
        |> apply_igniter!()

      data = read(igniter)
      assert data["name"] == "myapp"
      assert data["version"] == "0.5.0"
      assert data["license"] == "MIT"
      assert data["scripts"]["watch"] == "esbuild --watch"
      assert data["devDependencies"]["daisyui"] == "^5.0.50"
      assert data["devDependencies"]["topbar"] == "^3.0.0"
    end

    test "is idempotent when version matches" do
      initial = encode(%{"devDependencies" => %{"topbar" => "^3.0.0"}})

      test_project(files: %{"assets/package.json" => initial})
      |> Npm.add_dependency("topbar", "^3.0.0")
      |> assert_unchanged("assets/package.json")
    end

    test "updates the version when it differs" do
      initial = encode(%{"devDependencies" => %{"topbar" => "^2.0.0"}})

      igniter =
        test_project(files: %{"assets/package.json" => initial})
        |> Npm.add_dependency("topbar", "^3.0.0")
        |> apply_igniter!()

      assert read(igniter)["devDependencies"]["topbar"] == "^3.0.0"
    end
  end

  describe "remove_dependency/2" do
    test "removes from devDependencies" do
      initial =
        encode(%{
          "devDependencies" => %{"topbar" => "^3.0.0", "daisyui" => "^5.0.50"}
        })

      igniter =
        test_project(files: %{"assets/package.json" => initial})
        |> Npm.remove_dependency("topbar")
        |> apply_igniter!()

      data = read(igniter)
      refute data["devDependencies"]["topbar"]
      assert data["devDependencies"]["daisyui"] == "^5.0.50"
    end

    test "removes from dependencies when type was :runtime" do
      initial = encode(%{"dependencies" => %{"react" => "^18.0.0"}})

      igniter =
        test_project(files: %{"assets/package.json" => initial})
        |> Npm.remove_dependency("react")
        |> apply_igniter!()

      refute read(igniter)["dependencies"]["react"]
    end

    test "is idempotent when the dep isn't present" do
      initial = encode(%{"devDependencies" => %{"daisyui" => "^5.0.50"}})

      test_project(files: %{"assets/package.json" => initial})
      |> Npm.remove_dependency("topbar")
      |> assert_unchanged("assets/package.json")
    end
  end

  describe "has_dependency?/2" do
    test "returns true for devDependencies" do
      data = %{"devDependencies" => %{"topbar" => "^3.0.0"}}
      assert Npm.has_dependency?(data, "topbar")
    end

    test "returns true for dependencies" do
      data = %{"dependencies" => %{"react" => "^18.0.0"}}
      assert Npm.has_dependency?(data, "react")
    end

    test "returns false when absent" do
      data = %{"devDependencies" => %{"topbar" => "^3.0.0"}}
      refute Npm.has_dependency?(data, "daisyui")
    end
  end
end
