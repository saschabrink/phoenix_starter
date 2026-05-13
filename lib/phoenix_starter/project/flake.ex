defmodule PhoenixStarter.Project.Flake do
  @moduledoc """
  Helpers for editing `flake.nix` from Igniter tasks.

  These helpers expect the canonical `pkgs.<name>` form produced by
  `mix phoenix_starter.gen.flake`. They do not handle Nix shorthands
  like `with pkgs;` — if a project rewrites the flake into a different
  shape, the anchors will not be found and the call raises.

  All helpers are idempotent.
  """

  @path "flake.nix"

  @doc """
  Inserts `pkg` into `buildInputs` if not already present.

  Anchored on the `pkgs.elixir_*` line; new entries are placed after it,
  matching its indent.

  ## Example

      Flake.add_build_input(igniter, "pkgs.postgresql_18.withPackages (ps: [ ps.pgvector ])")
  """
  @spec add_build_input(Igniter.t(), String.t()) :: Igniter.t()
  def add_build_input(igniter, pkg) do
    Igniter.update_file(igniter, @path, fn source ->
      content = Rewrite.Source.get(source, :content)

      if has_build_input?(content, pkg) do
        source
      else
        Rewrite.Source.update(source, :content, insert_build_input(content, pkg))
      end
    end)
  end

  @doc """
  Appends a labeled block to the `shellHook` if a block with that label
  is not already present.

  The block is wrapped in `# >>> <label>` / `# <<< <label>` markers, both
  for idempotency and for human readability. The body is re-indented to
  match the shellHook body indent.

  ## Example

      Flake.add_shell_hook(igniter, :postgres, \"""
      export PGDATA=$PWD/priv/db/data
      export PGPORT=15432
      \""")
  """
  @spec add_shell_hook(Igniter.t(), atom | String.t(), String.t()) :: Igniter.t()
  def add_shell_hook(igniter, label, body) when is_atom(label),
    do: add_shell_hook(igniter, Atom.to_string(label), body)

  def add_shell_hook(igniter, label, body) do
    Igniter.update_file(igniter, @path, fn source ->
      content = Rewrite.Source.get(source, :content)

      if has_shell_hook?(content, label) do
        source
      else
        Rewrite.Source.update(source, :content, insert_shell_hook(content, label, body))
      end
    end)
  end

  @doc "Returns `true` if `buildInputs` already lists `pkg`."
  @spec has_build_input?(String.t(), String.t()) :: boolean()
  def has_build_input?(content, pkg) do
    content
    |> String.split("\n")
    |> Enum.any?(&(String.trim(&1) == pkg))
  end

  @doc "Returns `true` if a labeled shell-hook block is already present."
  @spec has_shell_hook?(String.t(), String.t()) :: boolean()
  def has_shell_hook?(content, label),
    do: String.contains?(content, "# >>> #{label}")

  defp insert_build_input(content, pkg) do
    case Regex.run(~r/^(\s*)pkgs\.elixir_\S+$/m, content, return: :index) do
      [{line_start, line_len}, {_indent_start, indent_len}] ->
        line_end = line_start + line_len
        indent = String.slice(content, line_start, indent_len)
        before = String.slice(content, 0, line_end)
        rest = String.slice(content, line_end, String.length(content) - line_end)
        before <> "\n" <> indent <> pkg <> rest

      nil ->
        raise """
        PhoenixStarter.Project.Flake: cannot find a `pkgs.elixir_*` line in flake.nix.

        The helpers assume the canonical form produced by `mix phoenix_starter.gen.flake`.
        If the flake has been restructured (e.g. using `with pkgs;`), add the build input
        manually.
        """
    end
  end

  defp insert_shell_hook(content, label, body) do
    indent = detect_shell_hook_indent(content)
    block = format_block(label, body, indent)

    case Regex.run(~r/^(\s*)''(?=;)/m, content, return: :index) do
      [{line_start, _}, _indent_match] ->
        before = String.slice(content, 0, line_start)
        rest = String.slice(content, line_start, String.length(content) - line_start)
        before <> block <> rest

      nil ->
        raise """
        PhoenixStarter.Project.Flake: cannot find the closing `'';` of `shellHook` in flake.nix.
        """
    end
  end

  defp detect_shell_hook_indent(content) do
    case Regex.run(~r/shellHook = ''\n(\s+)\S/, content) do
      [_full, indent] -> indent
      nil -> String.duplicate(" ", 12)
    end
  end

  defp format_block(label, body, indent) do
    body_lines =
      body
      |> String.trim()
      |> String.split("\n")
      |> Enum.map(fn
        "" -> ""
        line -> indent <> String.trim_leading(line)
      end)
      |> Enum.join("\n")

    """
    #{indent}# >>> #{label}
    #{body_lines}
    #{indent}# <<< #{label}
    """
  end
end
