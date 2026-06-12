defmodule Mix.Tasks.PhoenixStarter.Gen.HomeLive.Docs do
  @moduledoc false

  def short_doc, do: "Replaces the default Phoenix page controller with a LiveView home"

  def example, do: "mix phoenix_starter.gen.home_live"

  def long_doc do
    """
    #{short_doc()}

    Creates `<AppWeb>.HomeLive`, rewrites the `get "/", PageController, :home`
    route into `live "/", HomeLive, :index`, and removes the now-unused
    `PageController`, `PageHTML`, `home.html.heex`, and its test file.

    Each step is idempotent and independent — if `HomeLive` already exists,
    creation is skipped; if the page-controller route is missing from the
    router, the rewrite is skipped with a notice.

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.HomeLive do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    alias Igniter.Code.Common
    alias Igniter.Code.Function
    alias Igniter.Libs.Phoenix, as: PhoenixIgniter

    @home_live_template Path.join(:code.priv_dir(:phoenix_starter), "templates/home_live/home_live_body.eex")
    @external_resource @home_live_template
    @home_live_eex File.read!(@home_live_template)

    @home_live_test_template Path.join(
                               :code.priv_dir(:phoenix_starter),
                               "templates/home_live/home_live_test.eex"
                             )
    @external_resource @home_live_test_template
    @home_live_test_eex File.read!(@home_live_test_template)

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :phoenix_starter,
        example: __MODULE__.Docs.example(),
        composes: ["phoenix_starter.gen.page_meta"]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      web_module = PhoenixIgniter.web_module(igniter)
      home_live = Module.concat([web_module, Live, HomeLive])
      page_controller = Module.concat(web_module, PageController)
      page_html = Module.concat(web_module, PageHTML)

      igniter
      |> create_home_live(home_live, web_module)
      |> create_home_live_test(web_module)
      |> rewrite_root_route(page_controller)
      |> remove_page_controller_files(web_module, page_controller, page_html)
    end

    defp create_home_live_test(igniter, web_module) do
      web_dir = web_module |> inspect() |> Macro.underscore()
      path = "test/#{web_dir}/live/home_live_test.exs"

      Igniter.create_new_file(igniter, path, home_live_test_body(web_module), on_exists: :skip)
    end

    @doc false
    def home_live_test_body(web_module) do
      EEx.eval_string(@home_live_test_eex, assigns: [web_module: inspect(web_module)])
    end

    defp create_home_live(igniter, home_live, web_module) do
      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, home_live)

      if exists? do
        igniter
      else
        # Module is `<AppWeb>.Live.HomeLive`, which Igniter's `move_files`
        # step lands at `lib/<app_web>/live/home_live.ex` — the Phoenix
        # `live/` convention without needing a `:path` override.
        Igniter.Project.Module.create_module(igniter, home_live, home_live_body(web_module))
      end
    end

    @doc false
    def home_live_body(web_module) do
      EEx.eval_string(@home_live_eex, assigns: [web_module: inspect(web_module)])
    end

    defp rewrite_root_route(igniter, _page_controller) do
      {igniter, router} = PhoenixIgniter.select_router(igniter)

      if router do
        update_router(igniter, router)
      else
        Igniter.add_warning(igniter, """
        phoenix_starter.gen.home_live: no Phoenix router found. Skipping route rewrite.
        """)
      end
    end

    defp update_router(igniter, router) do
      Igniter.Project.Module.find_and_update_module!(igniter, router, fn zipper ->
        case Function.move_to_function_call(zipper, :get, 3, fn call ->
               Function.argument_matches_predicate?(call, 0, &Common.nodes_equal?(&1, "/")) and
                 Function.argument_matches_predicate?(call, 2, &Common.nodes_equal?(&1, :home))
             end) do
          {:ok, zipper} ->
            {:ok, Common.replace_code(zipper, ~s|live "/", Live.HomeLive, :home|)}

          :error ->
            # Route already rewritten or never existed — idempotent no-op
            {:ok, zipper}
        end
      end)
    end

    defp remove_page_controller_files(igniter, web_module, _page_controller, _page_html) do
      web_dir = web_module |> inspect() |> Macro.underscore()

      [
        "lib/#{web_dir}/controllers/page_controller.ex",
        "lib/#{web_dir}/controllers/page_html.ex",
        "lib/#{web_dir}/controllers/page_html/home.html.heex",
        "test/#{web_dir}/controllers/page_controller_test.exs"
      ]
      |> Enum.filter(&Igniter.exists?(igniter, &1))
      |> Enum.reduce(igniter, &Igniter.rm(&2, &1))
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.HomeLive do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.home_live' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
