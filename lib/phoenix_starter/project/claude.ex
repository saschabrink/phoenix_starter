defmodule PhoenixStarter.Project.Claude do
  @moduledoc """
  Helpers for editing `.claude/settings.json` from Igniter tasks.

  Mirrors the `Igniter.Project.*` naming convention. Idempotent: adding a
  hook with the same `:command` under the same event is a no-op.
  """

  @path ".claude/settings.json"

  @doc """
  Appends a [Claude Code hook](https://docs.claude.com/en/docs/claude-code/hooks)
  to `.claude/settings.json`.

  Creates `.claude/settings.json` if it does not exist.

  ## Options

  - `:event` (required) — `:PreToolUse` or `:PostToolUse` (atom or string)
  - `:matcher` (required) — tool-name pattern, e.g. `"Write|Edit"`
  - `:command` (required) — shell command to run
  - `:status_message` (optional) — banner shown while the hook runs

  ## Example

      Claude.add_hook(igniter,
        event: :PostToolUse,
        matcher: "Write|Edit",
        command: "bash .claude/hooks/post/run_mix_format.sh",
        status_message: "Formatting..."
      )
  """
  @spec add_hook(Igniter.t(), Keyword.t()) :: Igniter.t()
  def add_hook(igniter, opts) do
    event = opts |> Keyword.fetch!(:event) |> to_string()
    matcher = Keyword.fetch!(opts, :matcher)
    command = Keyword.fetch!(opts, :command)
    status_message = Keyword.get(opts, :status_message)

    hook_entry =
      %{"type" => "command", "command" => command}
      |> maybe_put("statusMessage", status_message)

    if Igniter.exists?(igniter, @path) do
      Igniter.update_file(igniter, @path, fn source ->
        content = Rewrite.Source.get(source, :content)
        data = Jason.decode!(content)

        if hook_present?(data, event, command) do
          source
        else
          new_data = insert_hook(data, event, matcher, hook_entry)
          Rewrite.Source.update(source, :content, encode(new_data))
        end
      end)
    else
      data = insert_hook(%{"hooks" => %{}}, event, matcher, hook_entry)
      Igniter.create_new_file(igniter, @path, encode(data))
    end
  end

  @doc "Returns `true` if a hook with `command` is already registered under `event`."
  @spec hook_present?(map(), String.t(), String.t()) :: boolean()
  def hook_present?(data, event, command) do
    data
    |> Map.get("hooks", %{})
    |> Map.get(event, [])
    |> Enum.any?(fn %{"hooks" => hooks} ->
      Enum.any?(hooks, &(&1["command"] == command))
    end)
  end

  defp insert_hook(data, event, matcher, hook_entry) do
    hooks = Map.get(data, "hooks", %{})
    matchers = Map.get(hooks, event, [])
    new_matchers = upsert_matcher(matchers, matcher, hook_entry)
    new_hooks = Map.put(hooks, event, new_matchers)
    Map.put(data, "hooks", new_hooks)
  end

  defp upsert_matcher(matchers, matcher, hook_entry) do
    case Enum.find_index(matchers, &(&1["matcher"] == matcher)) do
      nil ->
        matchers ++ [%{"matcher" => matcher, "hooks" => [hook_entry]}]

      idx ->
        List.update_at(matchers, idx, fn block ->
          Map.update!(block, "hooks", &(&1 ++ [hook_entry]))
        end)
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp encode(data), do: Jason.encode!(data, pretty: true) <> "\n"
end
