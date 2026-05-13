defmodule Mix.Tasks.PhoenixStarter.Gen.PhxServerAliasTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  @mix_exs """
  defmodule Test.MixProject do
    use Mix.Project

    def project do
      [
        app: :test,
        version: "0.1.0",
        deps: deps(),
        aliases: aliases()
      ]
    end

    defp deps, do: []
    defp aliases, do: []
  end
  """

  defp project_with_mix_exs(extra_aliases \\ "") do
    test_project(files: %{"mix.exs" => String.replace(@mix_exs, "defp aliases, do: []", "defp aliases, do: [#{extra_aliases}]")})
  end

  test "adds s: \"phx.server\" to the aliases list" do
    project_with_mix_exs()
    |> Igniter.compose_task("phoenix_starter.gen.phx_server_alias", [])
    |> assert_has_patch("mix.exs", """
    + |  defp aliases, do: [s: "phx.server"]
    """)
  end

  test "is idempotent — re-running adds nothing" do
    first =
      project_with_mix_exs()
      |> Igniter.compose_task("phoenix_starter.gen.phx_server_alias", [])
      |> apply_igniter!()

    first
    |> Igniter.compose_task("phoenix_starter.gen.phx_server_alias", [])
    |> assert_unchanged()
  end

  test "leaves an existing s alias untouched" do
    project_with_mix_exs(~s|s: "run --no-halt"|)
    |> Igniter.compose_task("phoenix_starter.gen.phx_server_alias", [])
    |> assert_unchanged("mix.exs")
  end
end
