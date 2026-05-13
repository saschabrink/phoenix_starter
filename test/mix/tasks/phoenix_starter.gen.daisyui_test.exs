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

  test "rewrites @plugin \"../vendor/daisyui\" to @plugin \"daisyui\" (now in daisyui-themes.css)" do
    igniter =
      phx_like_project()
      |> Igniter.compose_task("phoenix_starter.gen.daisyui", [])
      |> apply_igniter!()

    themes = igniter.assigns.test_files["assets/css/daisyui-themes.css"]
    app_css = igniter.assigns.test_files["assets/css/app.css"]

    # Main daisyUI plugin activation moved out of app.css and onto the npm path.
    refute app_css =~ ~s|@plugin "daisyui"|
    refute themes =~ ~s|"../vendor/daisyui"|
    assert themes =~ ~s|@plugin "daisyui" {|
  end

  test "rewrites all @plugin \"../vendor/daisyui-theme\" occurrences to @plugin \"daisyui/theme\"" do
    igniter =
      phx_like_project()
      |> Igniter.compose_task("phoenix_starter.gen.daisyui", [])
      |> apply_igniter!()

    # The vendor path is gone from app.css; the theme blocks have been moved
    # into `daisyui-themes.css` — both should land on the npm import path.
    refute igniter.assigns.test_files["assets/css/app.css"] =~ ~s|"../vendor/daisyui-theme"|

    themes = igniter.assigns.test_files["assets/css/daisyui-themes.css"]
    assert themes |> String.split(~s|@plugin "daisyui/theme"|) |> length() == 3
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

  describe "theme split" do
    test "extracts both @plugin \"daisyui/theme\" blocks into daisyui-themes.css" do
      igniter =
        phx_like_project()
        |> Igniter.compose_task("phoenix_starter.gen.daisyui", [])
        |> apply_igniter!()

      themes = igniter.assigns.test_files["assets/css/daisyui-themes.css"]

      assert themes =~ ~s|@plugin "daisyui/theme" {|
      assert themes =~ ~s|name: "light"|
      assert themes =~ ~s|name: "dark"|
      # The obsolete "fetch the latest version" comment should not be carried
      # into the extracted file.
      refute themes =~ "fetch the latest version"
    end

    test "replaces theme blocks in app.css with a single @import" do
      igniter =
        phx_like_project()
        |> Igniter.compose_task("phoenix_starter.gen.daisyui", [])
        |> apply_igniter!()

      app_css = igniter.assigns.test_files["assets/css/app.css"]

      refute app_css =~ ~s|@plugin "daisyui/theme"|
      refute app_css =~ "fetch the latest version"
      assert app_css =~ ~s|@import "./daisyui-themes.css";|
    end

    test "@import sits where the first daisyUI block used to be (after @source)" do
      igniter =
        phx_like_project()
        |> Igniter.compose_task("phoenix_starter.gen.daisyui", [])
        |> apply_igniter!()

      app_css = igniter.assigns.test_files["assets/css/app.css"]

      source_idx = :binary.match(app_css, ~s|@source "../css";|) |> elem(0)
      import_idx = :binary.match(app_css, ~s|@import "./daisyui-themes.css";|) |> elem(0)
      assert import_idx > source_idx
    end

    test "themes file begins with the main daisyUI plugin activation" do
      igniter =
        phx_like_project()
        |> Igniter.compose_task("phoenix_starter.gen.daisyui", [])
        |> apply_igniter!()

      themes = igniter.assigns.test_files["assets/css/daisyui-themes.css"]

      # @plugin "daisyui" comes first, followed by the theme blocks.
      idx_main = :binary.match(themes, ~s|@plugin "daisyui" {|) |> elem(0)
      idx_theme = :binary.match(themes, ~s|@plugin "daisyui/theme"|) |> elem(0)
      assert idx_main < idx_theme
    end

    test "is idempotent — re-running leaves the split files alone" do
      first =
        phx_like_project()
        |> Igniter.compose_task("phoenix_starter.gen.daisyui", [])
        |> apply_igniter!()

      first
      |> Igniter.compose_task("phoenix_starter.gen.daisyui", [])
      |> assert_unchanged()
    end

    test "skips the split when daisyui-themes.css already exists" do
      phx_like_project(%{
        "assets/css/daisyui-themes.css" => "/* user-customized themes */\n"
      })
      |> Igniter.compose_task("phoenix_starter.gen.daisyui", [])
      |> assert_unchanged("assets/css/daisyui-themes.css")
    end
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
