defmodule Mix.Tasks.PhoenixStarter.Gen.TopbarTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  @app_js_with_vendor """
  import "phoenix_html"
  import {Socket} from "phoenix"
  import {LiveSocket} from "phoenix_live_view"
  import topbar from "../vendor/topbar"

  const liveSocket = new LiveSocket("/live", Socket, {})
  liveSocket.connect()
  """

  defp phx_like_project(extra \\ %{}) do
    files =
      Map.merge(
        %{
          "assets/js/app.js" => @app_js_with_vendor,
          "assets/vendor/topbar.js" => "// stock topbar vendor file\n"
        },
        extra
      )

    test_project(files: files)
  end

  test "adds topbar ^3.0.0 to assets/package.json devDependencies" do
    igniter =
      phx_like_project()
      |> Igniter.compose_task("phoenix_starter.gen.topbar", [])
      |> apply_igniter!()

    pkg = Jason.decode!(igniter.assigns.test_files["assets/package.json"])
    assert pkg["devDependencies"]["topbar"] == "^3.0.0"
  end

  test "rewrites the app.js import from ../vendor/topbar to topbar" do
    phx_like_project()
    |> Igniter.compose_task("phoenix_starter.gen.topbar", [])
    |> assert_has_patch("assets/js/app.js", """
    - |import topbar from "../vendor/topbar"
    + |import topbar from "topbar"
    """)
  end

  test "removes assets/vendor/topbar.js" do
    phx_like_project()
    |> Igniter.compose_task("phoenix_starter.gen.topbar", [])
    |> assert_rms(["assets/vendor/topbar.js"])
  end

  test "leaves a single-quoted import alone in its quoting style" do
    igniter =
      phx_like_project(%{
        "assets/js/app.js" => ~s|import topbar from '../vendor/topbar'\n|
      })
      |> Igniter.compose_task("phoenix_starter.gen.topbar", [])
      |> apply_igniter!()

    assert igniter.assigns.test_files["assets/js/app.js"] =~ ~s|import topbar from 'topbar'|
  end

  test "is idempotent — re-running after migration adds nothing" do
    first =
      phx_like_project()
      |> Igniter.compose_task("phoenix_starter.gen.topbar", [])
      |> apply_igniter!()

    first
    |> Igniter.compose_task("phoenix_starter.gen.topbar", [])
    |> assert_unchanged()
  end

  test "is a no-op on app.js if it's already migrated and vendor file is gone" do
    phx_like_project(%{
      "assets/js/app.js" => ~s|import topbar from "topbar"\n|
    })
    |> Map.update!(:assigns, fn assigns ->
      Map.update!(assigns, :test_files, &Map.delete(&1, "assets/vendor/topbar.js"))
    end)
    |> Igniter.compose_task("phoenix_starter.gen.topbar", [])
    |> assert_unchanged("assets/js/app.js")
  end

  test "warns when app.js exists but the vendor import is absent" do
    phx_like_project(%{
      "assets/js/app.js" => "import \"phoenix_html\"\n"
    })
    |> Igniter.compose_task("phoenix_starter.gen.topbar", [])
    |> assert_has_warning(&String.contains?(&1, "could not find"))
  end

  test "warns when app.js is missing entirely" do
    test_project()
    |> Igniter.compose_task("phoenix_starter.gen.topbar", [])
    |> assert_has_warning(&String.contains?(&1, "app.js not found"))
  end
end
