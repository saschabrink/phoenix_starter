defmodule PhoenixStarter.Project.Credo do
  @moduledoc """
  Idempotent edits to `.credo.exs`.

  Each function leaves the file alone if the desired state already holds, and
  emits an Igniter warning if the file cannot be patched (e.g. heavily edited
  layout that no longer matches the stock anchors).

  ## Compose pattern

      igniter
      |> PhoenixStarter.Project.Credo.ensure_config()
      |> PhoenixStarter.Project.Credo.set_strict(true)
      |> PhoenixStarter.Project.Credo.disable_check(Credo.Check.Readability.ModuleDoc)
      |> PhoenixStarter.Project.Credo.add_check(ExSlop)
  """

  @snapshot Path.join(:code.priv_dir(:phoenix_starter), "templates/credo/credo.exs.snapshot")
  @external_resource @snapshot
  @stock_template File.read!(@snapshot)

  @path ".credo.exs"

  @doc """
  Creates `.credo.exs` from credo's stock template (snapshotted under
  `priv/templates/credo/`) if it doesn't exist. Existing files are left
  untouched.
  """
  @spec ensure_config(Igniter.t()) :: Igniter.t()
  def ensure_config(igniter) do
    Igniter.create_new_file(igniter, @path, @stock_template, on_exists: :skip)
  end

  @doc """
  Sets the `strict:` flag in the default config. Idempotent.
  """
  @spec set_strict(Igniter.t(), boolean()) :: Igniter.t()
  def set_strict(igniter, bool) when is_boolean(bool) do
    desired = "strict: #{bool},"

    patch(igniter, fn content ->
      cond do
        String.contains?(content, desired) ->
          {:ok, content}

        Regex.match?(~r/strict:\s*(?:true|false)\s*,/, content) ->
          {:ok, Regex.replace(~r/strict:\s*(?:true|false)\s*,/, content, desired, global: false)}

        true ->
          {:warning, "PhoenixStarter.Project.Credo.set_strict: could not find `strict:` line in .credo.exs"}
      end
    end)
  end

  @doc """
  Sets the check `{module, false}` regardless of where it currently sits or
  what options it has. Matches `{Module, []}`, `{Module, [opts: ...]}`, and
  multi-line entries. Idempotent.
  """
  @spec disable_check(Igniter.t(), module()) :: Igniter.t()
  def disable_check(igniter, check_module) when is_atom(check_module) do
    name = inspect(check_module)
    target = "{#{name}, false}"
    entry_regex = ~r/\{#{Regex.escape(name)},[^}]*\}/

    patch(igniter, fn content ->
      cond do
        Regex.match?(~r/\{#{Regex.escape(name)},\s*false\s*\}/, content) ->
          {:ok, content}

        match = first_match(content, entry_regex) ->
          {:ok, String.replace(content, match, target, global: false)}

        true ->
          {:warning, "PhoenixStarter.Project.Credo.disable_check: could not find #{name} in .credo.exs"}
      end
    end)
  end

  @doc """
  Appends `{module, opts}` to the enabled checks list if not already present
  anywhere in the file (under any options). Idempotent.

  Assumes the stock-template layout where `enabled: [...]` is followed by
  `disabled: [...]` at the same indentation. Custom-formatted files emit a
  warning instead.
  """
  @spec add_check(Igniter.t(), module(), keyword()) :: Igniter.t()
  def add_check(igniter, check_module, opts \\ []) when is_atom(check_module) do
    name = inspect(check_module)
    new_entry = "{#{name}, #{inspect(opts)}}"
    anchor = "}\n        ],\n        disabled:"
    replacement = "},\n          #{new_entry}\n        ],\n        disabled:"

    patch(igniter, fn content ->
      cond do
        Regex.match?(~r/\{#{Regex.escape(name)},/, content) ->
          {:ok, content}

        String.contains?(content, anchor) ->
          {:ok, String.replace(content, anchor, replacement, global: false)}

        true ->
          {:warning, "PhoenixStarter.Project.Credo.add_check: could not locate the end of enabled checks in .credo.exs (custom layout?)"}
      end
    end)
  end

  # -------------------------------------------------------------------------

  defp patch(igniter, fun) do
    if Igniter.exists?(igniter, @path) do
      Igniter.update_file(igniter, @path, fn source ->
        content = Rewrite.Source.get(source, :content)

        case fun.(content) do
          {:ok, ^content} -> source
          {:ok, new} -> Rewrite.Source.update(source, :content, new)
          {:warning, msg} -> {:warning, msg}
        end
      end)
    else
      Igniter.add_warning(
        igniter,
        "PhoenixStarter.Project.Credo: .credo.exs not found. Run `mix phoenix_starter.gen.credo` first."
      )
    end
  end

  defp first_match(content, regex) do
    case Regex.run(regex, content) do
      [match | _] -> match
      nil -> nil
    end
  end
end
