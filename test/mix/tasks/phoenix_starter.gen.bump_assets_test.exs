defmodule Mix.Tasks.PhoenixStarter.Gen.BumpAssetsTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  @config_src """
  import Config

  config :esbuild,
    version: "0.25.4",
    platform: [
      args: ~w(js/app.js --bundle),
      cd: Path.expand("../assets", __DIR__)
    ]

  config :tailwind,
    version: "4.1.12",
    platform: [
      args: ~w(--input=assets/css/app.css --output=priv/static/assets/css/app.css),
      cd: Path.expand("..", __DIR__)
    ]
  """

  defp project_with_asset_config do
    test_project(files: %{"config/config.exs" => @config_src})
  end

  test "updates :esbuild version to the value passed via --esbuild" do
    project_with_asset_config()
    |> Igniter.compose_task("phoenix_starter.gen.bump_assets", [
      "--esbuild",
      "0.28.0",
      "--tailwind",
      "4.3.0"
    ])
    |> assert_has_patch("config/config.exs", """
    - |  version: "0.25.4",
    + |  version: "0.28.0",
    """)
  end

  test "updates :tailwind version to the value passed via --tailwind" do
    project_with_asset_config()
    |> Igniter.compose_task("phoenix_starter.gen.bump_assets", [
      "--esbuild",
      "0.28.0",
      "--tailwind",
      "4.3.0"
    ])
    |> assert_has_patch("config/config.exs", """
    - |  version: "4.1.12",
    + |  version: "4.3.0",
    """)
  end

  test "is idempotent — re-running with the same versions adds nothing" do
    first =
      project_with_asset_config()
      |> Igniter.compose_task("phoenix_starter.gen.bump_assets", [
        "--esbuild",
        "0.28.0",
        "--tailwind",
        "4.3.0"
      ])
      |> apply_igniter!()

    first
    |> Igniter.compose_task("phoenix_starter.gen.bump_assets", [
      "--esbuild",
      "0.28.0",
      "--tailwind",
      "4.3.0"
    ])
    |> assert_unchanged()
  end

  test "leaves other config keys (platform, args) untouched" do
    igniter =
      project_with_asset_config()
      |> Igniter.compose_task("phoenix_starter.gen.bump_assets", [
        "--esbuild",
        "0.28.0",
        "--tailwind",
        "4.3.0"
      ])
      |> apply_igniter!()

    updated = igniter.assigns.test_files["config/config.exs"]

    assert updated =~ ~s|args: ~w(js/app.js --bundle)|
    assert updated =~ ~s|cd: Path.expand("../assets", __DIR__)|
    assert updated =~ ~s|args: ~w(--input=assets/css/app.css|
  end

  describe "fetch_latest/1 (live network)" do
    @describetag :network

    test "returns the latest esbuild release tag (without leading v)" do
      assert {:ok, version} = Mix.Tasks.PhoenixStarter.Gen.BumpAssets.fetch_latest("evanw/esbuild")
      assert version =~ ~r/^\d+\.\d+\.\d+/
    end

    test "returns the latest tailwind release tag (without leading v)" do
      assert {:ok, version} =
               Mix.Tasks.PhoenixStarter.Gen.BumpAssets.fetch_latest("tailwindlabs/tailwindcss")

      assert version =~ ~r/^\d+\.\d+\.\d+/
    end
  end

  test "falls back to a baked-in version + warning when the repo cannot be reached" do
    project_with_asset_config()
    |> Igniter.compose_task("phoenix_starter.gen.bump_assets", [
      # An unresolvable owner forces fetch_latest/1 down the error path.
      "--tailwind",
      "4.3.0"
    ])
    # esbuild has no override and no Req-fetch is reachable in the sandboxed
    # test env — task should still patch config.exs to the fallback constant
    # rather than crashing.
    |> assert_has_patch("config/config.exs", """
    - |  version: "0.25.4",
    + |  version: "0.28.0",
    """)
    |> assert_has_warning(&String.contains?(&1, "could not fetch latest"))
  end
end
