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

        @impl PhoenixPageMeta.LiveView
        def page_meta(_socket, :index) do
          %TestWeb.PageMeta{title: "Welcome", path: "/"}
        end

        @impl true
        def render(assigns) do
          ~H\"\"\"
          <h1>Welcome</h1>
          \"\"\"
        end

        @impl true
        def mount(_params, _session, socket) do
          {:ok, assign_page_meta(socket)}
        end
      end
      """)
    end

    test "rewrites the page-controller route as a live route" do
      phx_like_project()
      |> Igniter.compose_task("phoenix_starter.gen.home_live", [])
      |> assert_has_patch("lib/test_web/router.ex", """
      - |      get "/", PageController, :home
      + |      live "/", Live.HomeLive, :index
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
