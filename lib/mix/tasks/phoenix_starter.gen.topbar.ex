defmodule Mix.Tasks.PhoenixStarter.Gen.Topbar.Docs do
  @moduledoc false

  def short_doc, do: "Migrates topbar from `assets/vendor/` to an npm dependency"

  def example, do: "mix phoenix_starter.gen.topbar"

  def long_doc do
    """
    #{short_doc()}

    Phoenix 1.8 ships topbar as a vendored file under `assets/vendor/topbar.js`.
    This task replaces it with the npm package:

    1. Adds `topbar: "^3.0.0"` to `assets/package.json` (`devDependencies`).
    2. Rewrites `import topbar from "../vendor/topbar"` in `assets/js/app.js`
       to `import topbar from "topbar"`.
    3. Removes `assets/vendor/topbar.js`.

    Each step is idempotent and skipped (with a warning where useful) when
    the project no longer matches the stock layout.

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.Topbar do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @app_js_path "assets/js/app.js"
    @vendor_path "assets/vendor/topbar.js"

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :phoenix_starter,
        example: __MODULE__.Docs.example(),
        schema: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> PhoenixStarter.Project.Npm.add_dependency("topbar", "^3.0.0")
      |> rewrite_app_js_import()
      |> remove_vendor_file()
    end

    defp rewrite_app_js_import(igniter) do
      cond do
        not Igniter.exists?(igniter, @app_js_path) ->
          Igniter.add_warning(
            igniter,
            "phoenix_starter.gen.topbar: #{@app_js_path} not found — skipping import rewrite."
          )

        true ->
          Igniter.update_file(igniter, @app_js_path, fn source ->
            content = Rewrite.Source.get(source, :content)

            cond do
              # Already migrated
              Regex.match?(~r/from\s+["']topbar["']/, content) ->
                source

              # Match the vendored import in any quote style
              Regex.match?(~r/from\s+["']\.\.\/vendor\/topbar["']/, content) ->
                Rewrite.Source.update(
                  source,
                  :content,
                  Regex.replace(
                    ~r/from\s+(["'])\.\.\/vendor\/topbar\1/,
                    content,
                    ~S|from \1topbar\1|,
                    global: false
                  )
                )

              true ->
                {:warning, "phoenix_starter.gen.topbar: could not find `from \"../vendor/topbar\"` in #{@app_js_path}."}
            end
          end)
      end
    end

    defp remove_vendor_file(igniter) do
      if Igniter.exists?(igniter, @vendor_path) do
        Igniter.rm(igniter, @vendor_path)
      else
        igniter
      end
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.Topbar do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.topbar' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
