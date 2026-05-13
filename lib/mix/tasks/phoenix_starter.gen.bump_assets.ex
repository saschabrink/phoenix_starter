defmodule Mix.Tasks.PhoenixStarter.Gen.BumpAssets.Docs do
  @moduledoc false

  def short_doc, do: "Pins esbuild and tailwind to their latest published versions"

  def example, do: "mix phoenix_starter.gen.bump_assets"

  def long_doc do
    """
    #{short_doc()}

    Queries the GitHub Releases API for the latest tag of
    [`evanw/esbuild`](https://github.com/evanw/esbuild) and
    [`tailwindlabs/tailwindcss`](https://github.com/tailwindlabs/tailwindcss),
    then updates the `version` value of `config :esbuild` and
    `config :tailwind` in `config/config.exs`.

    Re-run this task whenever you want to pull in upstream releases.

    Resilient: each API call has a short timeout. On network errors,
    timeouts, rate-limits, or non-200 responses the task emits a warning
    and falls back to a hardcoded "last known good" version so the
    install pipeline never blocks.

    Only the config values are touched — run `mix assets.setup` manually
    afterwards to download the binaries for the new versions.

    ## Example

    ```sh
    #{example()}
    ```

    ## Options

    * `--esbuild` — pin esbuild to a specific version, skipping the network fetch.
    * `--tailwind` — pin tailwind to a specific version, skipping the network fetch.
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.BumpAssets do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    # Last-known-good versions. Used when --<flag> is omitted AND the GitHub
    # fetch fails (timeout, rate limit, network down, etc.). Bumped manually
    # whenever phoenix_starter cuts a release.
    @esbuild_fallback "0.28.0"
    @tailwind_fallback "4.3.0"

    # Keep the network call short — better to fall back than to hang an
    # install pipeline.
    @http_timeout_ms 3_000

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :phoenix_starter,
        example: __MODULE__.Docs.example(),
        schema: [esbuild: :string, tailwind: :string]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      {igniter, esbuild_version} =
        resolve_version(igniter, :esbuild, "evanw/esbuild", @esbuild_fallback)

      {igniter, tailwind_version} =
        resolve_version(igniter, :tailwind, "tailwindlabs/tailwindcss", @tailwind_fallback)

      igniter
      |> Igniter.Project.Config.configure(
        "config.exs",
        :esbuild,
        [:version],
        esbuild_version
      )
      |> Igniter.Project.Config.configure(
        "config.exs",
        :tailwind,
        [:version],
        tailwind_version
      )
      |> Igniter.add_notice("""
      Asset versions pinned (esbuild #{esbuild_version}, tailwind #{tailwind_version}).
      Run `mix assets.setup` to download the matching binaries.
      """)
    end

    # Returns `{igniter, version}`. Sources, in order:
    # 1. `--<key>` CLI override.
    # 2. GitHub Releases API (with short timeout).
    # 3. Hardcoded fallback (with a warning appended to the igniter).
    defp resolve_version(igniter, key, repo, fallback) do
      case igniter.args.options[key] do
        nil ->
          case fetch_latest(repo) do
            {:ok, version} ->
              {igniter, version}

            {:error, reason} ->
              warning = """
              phoenix_starter.gen.bump_assets: could not fetch latest #{key} version (#{inspect(reason)}).
              Falling back to #{fallback}.
              """

              {Igniter.add_warning(igniter, warning), fallback}
          end

        version ->
          {igniter, version}
      end
    end

    @doc false
    # Fetches the latest release tag for `owner/repo`, returns it stripped
    # of any leading `v`. Uses `Req` (Phoenix 1.8 default dep) when available,
    # otherwise returns `{:error, :req_unavailable}` so the caller can fall back.
    def fetch_latest(repo) do
      cond do
        not Code.ensure_loaded?(Req) ->
          {:error, :req_unavailable}

        true ->
          url = "https://api.github.com/repos/#{repo}/releases/latest"

          headers = [
            {"user-agent", "phoenix_starter"},
            {"accept", "application/vnd.github+json"}
          ]

          try do
            Req.get(url,
              headers: headers,
              receive_timeout: @http_timeout_ms,
              connect_options: [timeout: @http_timeout_ms],
              retry: false
            )
          catch
            kind, reason -> {:error, {kind, reason}}
          end
          |> case do
            {:ok, %{status: 200, body: %{"tag_name" => tag}}} ->
              {:ok, String.trim_leading(tag, "v")}

            {:ok, %{status: status}} ->
              {:error, {:http_status, status}}

            {:error, _} = err ->
              err
          end
      end
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.BumpAssets do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.bump_assets' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
