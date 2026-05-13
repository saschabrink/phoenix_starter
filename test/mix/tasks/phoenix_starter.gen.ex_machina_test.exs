defmodule Mix.Tasks.PhoenixStarter.Gen.ExMachinaTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  @conn_case_src """
  defmodule TestWeb.ConnCase do
    use ExUnit.CaseTemplate

    using do
      quote do
        @endpoint TestWeb.Endpoint

        use TestWeb, :verified_routes

        import Plug.Conn
        import Phoenix.ConnTest
        import TestWeb.ConnCase
      end
    end

    setup _tags do
      {:ok, conn: Phoenix.ConnTest.build_conn()}
    end
  end
  """

  @data_case_src """
  defmodule Test.DataCase do
    use ExUnit.CaseTemplate

    using do
      quote do
        alias Test.Repo

        import Ecto
        import Ecto.Changeset
        import Ecto.Query
        import Test.DataCase
      end
    end
  end
  """

  defp phx_like_project(extra \\ %{}) do
    files =
      Map.merge(
        %{
          "test/support/conn_case.ex" => @conn_case_src,
          "test/support/data_case.ex" => @data_case_src
        },
        extra
      )

    test_project(files: files)
  end

  test "adds ex_machina to deps" do
    phx_like_project()
    |> Igniter.compose_task("phoenix_starter.gen.ex_machina", [])
    |> assert_has_patch("mix.exs", """
    + |      {:ex_machina, "~> 2.8", only: :test}
    """)
  end

  test "creates Test.Factory at test/support/factory.ex" do
    phx_like_project()
    |> Igniter.compose_task("phoenix_starter.gen.ex_machina", [])
    |> assert_creates("test/support/factory.ex")
  end

  test "factory body uses ExMachina.Ecto with the project repo" do
    igniter =
      phx_like_project()
      |> Igniter.compose_task("phoenix_starter.gen.ex_machina", [])
      |> apply_igniter!()

    body = igniter.assigns.test_files["test/support/factory.ex"]

    assert body =~ "defmodule Test.Factory do"
    assert body =~ "use ExMachina.Ecto, repo: Test.Repo"
    assert body =~ "Test.Accounts.User"
  end

  test "adds `alias Test.Factory` inside ConnCase's using do quote do" do
    phx_like_project()
    |> Igniter.compose_task("phoenix_starter.gen.ex_machina", [])
    |> assert_has_patch("test/support/conn_case.ex", """
    + |      alias Test.Factory
    """)
  end

  test "adds `alias Test.Factory` inside DataCase's using do quote do" do
    phx_like_project()
    |> Igniter.compose_task("phoenix_starter.gen.ex_machina", [])
    |> assert_has_patch("test/support/data_case.ex", """
    + |      alias Test.Factory
    """)
  end

  test "warns when a case file is missing" do
    test_project()
    |> Igniter.compose_task("phoenix_starter.gen.ex_machina", [])
    |> assert_has_warning(&String.contains?(&1, "test/support/conn_case.ex not found"))
  end

  test "is idempotent — re-running adds nothing" do
    first =
      phx_like_project()
      |> Igniter.compose_task("phoenix_starter.gen.ex_machina", [])
      |> apply_igniter!()

    first
    |> Igniter.compose_task("phoenix_starter.gen.ex_machina", [])
    |> assert_unchanged()
  end
end
