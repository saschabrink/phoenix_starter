defmodule Mix.Tasks.PhoenixStarter.Gen.HomeLiveTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  @router_src """
  defmodule TestWeb.Router do
    use Phoenix.Router

    pipeline :browser do
      plug :accepts, ["html"]
    end

    scope "/", TestWeb do
      pipe_through :browser

      get "/", PageController, :home
    end
  end
  """

  @page_controller_src """
  defmodule TestWeb.PageController do
    use TestWeb, :controller

    def home(conn, _params), do: render(conn, :home)
  end
  """

  @page_html_src """
  defmodule TestWeb.PageHTML do
    use TestWeb, :html

    embed_templates "page_html/*"
  end
  """

  @page_meta_src """
  defmodule TestWeb.PageMeta do
    use PhoenixPageMeta

    @enforce_keys [:title, :path]
    defstruct [:title, :path, :parent]
  end
  """

  @formatter_src """
  [
    inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
    locals_without_parens: [
      plug: 1,
      plug: 2,
      pipe_through: 1,
      scope: 2,
      scope: 3,
      scope: 4,
      get: 3,
      get: 4,
      live: 2,
      live: 3,
      live: 4
    ]
  ]
  """

  defp phx_like_project(extra \\ %{}) do
    files =
      Map.merge(
        %{
          ".formatter.exs" => @formatter_src,
          "lib/test_web/router.ex" => @router_src,
          "lib/test_web/controllers/page_controller.ex" => @page_controller_src,
          "lib/test_web/controllers/page_html.ex" => @page_html_src,
          "lib/test_web/controllers/page_html/home.html.heex" => "<h1>Old home</h1>\n",
          "test/test_web/controllers/page_controller_test.exs" => "# ...",
          "lib/test_web/page_meta.ex" => @page_meta_src
        },
        extra
      )

    test_project(files: files)
  end

  describe "phoenix_starter.gen.home_live" do
    test "creates TestWeb.Live.HomeLive at the conventional path" do
      phx_like_project()
      |> Igniter.compose_task("phoenix_starter.gen.home_live", [])
      |> assert_creates("lib/test_web/live/home_live.ex", """
      defmodule TestWeb.Live.HomeLive do
        use TestWeb, :live_view

        @impl true
        def page_meta(_socket, :home),
          do: %PageMeta{
            title: "Welcome",
            path: "/"
          }

        @impl true
        def render(assigns) do
          ~H\"\"\"
          <h1>Welcome</h1>
          \"\"\"
        end

        @impl true
        def mount(_params, _session, socket) do
          {:ok, socket |> assign_page_meta()}
        end
      end
      """)
    end

    test "rewrites the page-controller route as a live route" do
      phx_like_project()
      |> Igniter.compose_task("phoenix_starter.gen.home_live", [])
      |> assert_has_patch("lib/test_web/router.ex", """
      - |      get "/", PageController, :home
      + |      live "/", Live.HomeLive, :home
      """)
    end

    test "removes the page controller, html module, template, and its test" do
      phx_like_project()
      |> Igniter.compose_task("phoenix_starter.gen.home_live", [])
      |> assert_rms([
        "lib/test_web/controllers/page_controller.ex",
        "lib/test_web/controllers/page_html.ex",
        "lib/test_web/controllers/page_html/home.html.heex",
        "test/test_web/controllers/page_controller_test.exs"
      ])
    end

    test "creates a LiveView test at the conventional path" do
      phx_like_project()
      |> Igniter.compose_task("phoenix_starter.gen.home_live", [])
      |> assert_creates("test/test_web/live/home_live_test.exs", """
      defmodule TestWeb.Live.HomeLiveTest do
        use TestWeb.ConnCase, async: true

        import Phoenix.LiveViewTest

        describe ":home" do
          test "renders the welcome heading", %{conn: conn} do
            {:ok, _live, html} = live(conn, ~p"/")

            assert html =~ "Welcome"
          end
        end
      end
      """)
    end

    test "home_live_test_body/1 renders the test template with the given web module" do
      body = Mix.Tasks.PhoenixStarter.Gen.HomeLive.home_live_test_body(MyAppWeb)

      assert body =~ "defmodule MyAppWeb.Live.HomeLiveTest do"
      assert body =~ "use MyAppWeb.ConnCase"
      assert body =~ ~s|live(conn, ~p"/")|
      refute body =~ "<%="
    end

    test "home_live_body/1 renders the template with the given web module" do
      body = Mix.Tasks.PhoenixStarter.Gen.HomeLive.home_live_body(MyAppWeb)

      assert body =~ "use MyAppWeb, :live_view"
      assert body =~ "%PageMeta{"
      assert body =~ ~s|title: "Welcome"|
      assert body =~ ~s|path: "/"|
      assert body =~ "socket |> assign_page_meta()"
      refute body =~ "<%="
    end

    test "is idempotent — re-running on an already-migrated project does nothing" do
      first =
        phx_like_project()
        |> Igniter.compose_task("phoenix_starter.gen.home_live", [])
        |> apply_igniter!()

      first
      |> Igniter.compose_task("phoenix_starter.gen.home_live", [])
      |> assert_unchanged()
    end
  end
end
