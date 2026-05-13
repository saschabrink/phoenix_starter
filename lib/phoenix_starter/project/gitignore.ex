defmodule PhoenixStarter.Project.Gitignore do
  @moduledoc """
  Helpers for editing `.gitignore` from Igniter tasks.

  Mirrors the `Igniter.Project.*` naming convention.
  Idempotent: adding a line that's already present is a no-op.
  """

  @path ".gitignore"

  @doc """
  Appends `line` to `.gitignore` unless it's already present.

  Creates `.gitignore` if it doesn't exist. The line is matched exactly
  (ignoring trailing whitespace), so `/.nix/` and `/.nix` are distinct entries.
  """
  @spec add_line(Igniter.t(), String.t()) :: Igniter.t()
  def add_line(igniter, line) do
    Igniter.create_or_update_file(igniter, @path, line <> "\n", fn source ->
      content = Rewrite.Source.get(source, :content)

      if has_line?(content, line) do
        source
      else
        Rewrite.Source.update(source, :content, ensure_newline(content) <> line <> "\n")
      end
    end)
  end

  @doc "Returns `true` if `line` exists in the current `.gitignore` content."
  @spec has_line?(String.t(), String.t()) :: boolean()
  def has_line?(content, line) do
    content
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.member?(line)
  end

  defp ensure_newline(""), do: ""

  defp ensure_newline(content) do
    if String.ends_with?(content, "\n"), do: content, else: content <> "\n"
  end
end
