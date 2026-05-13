defmodule Mix.Tasks.PhoenixStarter.Gen.DaisyuiTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  @app_css """
  @import "tailwindcss" source(none);
  @source "../css";

  /* daisyUI Tailwind Plugin. */
  @plugin "../vendor/daisyui" {
    themes: false;
  }

  /* daisyUI theme — Light */
  @plugin "../vendor/daisyui-theme" {
    name: "light";
    default: true;
  }

  /* daisyUI theme — Dark */
  @plugin "../vendor/daisyui-theme" {
    name: "dark";
    default: false;
  }
  """

  defp phx_like_project(extra \\ %{}) do
    files =
      Map.merge(
        %{
          "assets/css/app.css" => @app_css,
          "assets/vendor/daisyui.js" => "// stock daisyui vendor file\n",
          "assets/vendor/daisyui-theme.js" => "// stock daisyui-theme vendor file\n"
        },
        extra
      )

    test_project(files: files)
  end

  test "adds daisyui to devDependencies" do
    igniter =
      phx_like_project()
      |> Igniter.compose_task("phoenix_starter.gen.daisyui", [])
      |> apply_igniter!()

    pkg = Jason.decode!(igniter.assigns.test_files["assets/package.json"])
    assert pkg["devDependencies"]["daisyui"] == "^5.0.50"
  end

  test "rewrites @plugin \"../vendor/daisyui\" to @plugin \"daisyui\"" do
    phx_like_project()
    |> Igniter.compose_task("phoenix_starter.gen.daisyui", [])
    |> assert_has_patch("assets/css/app.css", """
    - |@plugin "../vendor/daisyui" {
    + |@plugin "daisyui" {
    """)
  end

  test "rewrites all @plugin \"../vendor/daisyui-theme\" occurrences to @plugin \"daisyui/theme\"" do
    igniter =
      phx_like_project()
      |> Igniter.compose_task("phoenix_starter.gen.daisyui", [])
      |> apply_igniter!()

    css = igniter.assigns.test_files["assets/css/app.css"]

    refute css =~ ~s|"../vendor/daisyui-theme"|
    assert css |> String.split(~s|@plugin "daisyui/theme"|) |> length() == 3
  end

  test "removes both daisyui vendor files" do
    phx_like_project()
    |> Igniter.compose_task("phoenix_starter.gen.daisyui", [])
    |> assert_rms([
      "assets/vendor/daisyui.js",
      "assets/vendor/daisyui-theme.js"
    ])
  end

  test "is idempotent — re-running after migration adds nothing" do
    first =
      phx_like_project()
      |> Igniter.compose_task("phoenix_starter.gen.daisyui", [])
      |> apply_igniter!()

    first
    |> Igniter.compose_task("phoenix_starter.gen.daisyui", [])
    |> assert_unchanged()
  end

  test "warns when app.css exists but has no vendor daisyui directives" do
    phx_like_project(%{
      "assets/css/app.css" => "@import \"tailwindcss\";\n"
    })
    |> Igniter.compose_task("phoenix_starter.gen.daisyui", [])
    |> assert_has_warning(&String.contains?(&1, "could not find"))
  end

  test "warns when app.css is missing entirely" do
    test_project()
    |> Igniter.compose_task("phoenix_starter.gen.daisyui", [])
    |> assert_has_warning(&String.contains?(&1, "app.css not found"))
  end
end
