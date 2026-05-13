defmodule Mix.Tasks.PhoenixStarter.Gen.Daisyui.Docs do
  @moduledoc false

  def short_doc, do: "Migrates daisyUI from `assets/vendor/` to an npm dependency"

  def example, do: "mix phoenix_starter.gen.daisyui"

  def long_doc do
    """
    #{short_doc()}

    Phoenix 1.8 ships daisyUI vendored as `assets/vendor/daisyui.js` and
    `assets/vendor/daisyui-theme.js`. This task replaces them with the npm
    package:

    1. Adds `daisyui: "^5.0.50"` to `assets/package.json` (`devDependencies`).
    2. Rewrites the Tailwind `@plugin` directives in `assets/css/app.css`:
       * `@plugin "../vendor/daisyui"` → `@plugin "daisyui"`
       * `@plugin "../vendor/daisyui-theme"` → `@plugin "daisyui/theme"`
         (Tailwind 4 resolves both via node_modules.)
    3. Removes `assets/vendor/daisyui.js` and `assets/vendor/daisyui-theme.js`.
    4. Extracts every daisyUI `@plugin` block (the main `@plugin "daisyui"
       activation and each `@plugin "daisyui/theme"` block) out of `app.css`
       into a new `assets/css/daisyui-themes.css`, replacing them with a
       single `@import "./daisyui-themes.css";`. The obsolete "fetch the
       latest version" comments preceding them are dropped along the way.

    Each step is idempotent. Missing or heavily-edited files emit warnings
    rather than aborting.

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.Daisyui do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @app_css_path "assets/css/app.css"
    @themes_css_path "assets/css/daisyui-themes.css"
    @themes_import ~s|@import "./daisyui-themes.css";|

    @vendor_files [
      "assets/vendor/daisyui.js",
      "assets/vendor/daisyui-theme.js"
    ]

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
      |> PhoenixStarter.Project.Npm.add_dependency("daisyui", "^5.0.50")
      |> rewrite_app_css()
      |> remove_vendor_files()
      |> split_themes()
    end

    defp rewrite_app_css(igniter) do
      cond do
        not Igniter.exists?(igniter, @app_css_path) ->
          Igniter.add_warning(
            igniter,
            "phoenix_starter.gen.daisyui: #{@app_css_path} not found — skipping plugin rewrite."
          )

        true ->
          Igniter.update_file(igniter, @app_css_path, fn source ->
            content = Rewrite.Source.get(source, :content)
            updated = patch_plugin_lines(content)

            cond do
              updated == content and already_migrated?(content) ->
                source

              updated == content ->
                {:warning, "phoenix_starter.gen.daisyui: could not find any `@plugin \"../vendor/daisyui...\"` directives in #{@app_css_path}."}

              true ->
                Rewrite.Source.update(source, :content, updated)
            end
          end)
      end
    end

    # Order matters: the more specific `daisyui-theme` pattern must be rewritten
    # before the bare `daisyui` pattern, otherwise the latter would match the
    # theme prefix and produce `"daisyui-theme"` instead of `"daisyui/theme"`.
    defp patch_plugin_lines(content) do
      content
      |> String.replace(
        ~s|@plugin "../vendor/daisyui-theme"|,
        ~s|@plugin "daisyui/theme"|
      )
      |> String.replace(
        ~s|@plugin "../vendor/daisyui"|,
        ~s|@plugin "daisyui"|
      )
    end

    defp already_migrated?(content) do
      String.contains?(content, ~s|@plugin "daisyui"|) or
        String.contains?(content, ~s|@plugin "daisyui/theme"|)
    end

    defp remove_vendor_files(igniter) do
      Enum.reduce(@vendor_files, igniter, fn path, igniter ->
        if Igniter.exists?(igniter, path) do
          Igniter.rm(igniter, path)
        else
          igniter
        end
      end)
    end

    # Matches a daisyUI `@plugin` block (the main `daisyui` activation OR a
    # `daisyui/theme` block), optionally preceded by a `/* ... */` comment.
    # `(?:[^*]|\*(?!\/))*` is the classic "match a C-style comment body
    # without straying past the next `*/`" idiom — avoids runaway
    # backtracking where a non-greedy `[\s\S]*?` would span multiple
    # comments. CSS variable values never contain `{` or `}`, so `[^}]*` is
    # enough for the plugin body.
    @daisyui_block_regex ~r/(?:[ \t]*\/\*(?:[^*]|\*(?!\/))*\*\/\s*\n)?[ \t]*@plugin\s+"daisyui(?:\/theme)?"\s*\{[^}]*\}\n?/

    defp split_themes(igniter) do
      cond do
        Igniter.exists?(igniter, @themes_css_path) ->
          igniter

        not Igniter.exists?(igniter, @app_css_path) ->
          igniter

        true ->
          igniter = Igniter.include_existing_file(igniter, @app_css_path)
          content = Rewrite.Source.get(Rewrite.source!(igniter.rewrite, @app_css_path), :content)

          case extract_theme_blocks(content) do
            :no_blocks ->
              igniter

            {themes_css, new_app_css} ->
              igniter
              |> Igniter.create_new_file(@themes_css_path, themes_css, on_exists: :skip)
              |> Igniter.update_file(@app_css_path, fn source ->
                Rewrite.Source.update(source, :content, new_app_css)
              end)
          end
      end
    end

    defp extract_theme_blocks(content) do
      blocks = Regex.scan(@daisyui_block_regex, content) |> List.flatten()

      if blocks == [] do
        :no_blocks
      else
        # Strip leading comments (the "fetch the latest version" docs are
        # obsolete once we're on npm) and trailing newlines so each block
        # is just the @plugin {...} body.
        cleaned =
          blocks
          |> Enum.map(fn block ->
            block
            |> String.replace(~r/^\s*\/\*[\s\S]*?\*\/\s*\n/, "")
            |> String.trim_trailing()
          end)

        themes_css = Enum.join(cleaned, "\n\n") <> "\n"

        # Replace the FIRST daisyUI block with the @import line; remove the
        # rest. This keeps the @import sitting where the daisyUI stanza used
        # to start, preserving the visual order of app.css.
        new_app_css =
          content
          |> String.replace(@daisyui_block_regex, @themes_import <> "\n", global: false)
          |> String.replace(@daisyui_block_regex, "")
          |> collapse_blank_runs()

        {themes_css, new_app_css}
      end
    end

    # Cosmetic: when blocks are excised we can end up with runs of 3+ blank
    # lines. Collapse to at most 2 (i.e. one blank between top-level stanzas).
    defp collapse_blank_runs(content) do
      Regex.replace(~r/\n{3,}/, content, "\n\n")
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.Daisyui do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.daisyui' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
