defmodule PhoenixStarter.Project.Npm do
  @moduledoc """
  Helpers for editing `assets/package.json` from Igniter tasks.

  Mirrors the `Igniter.Project.*` naming convention. All operations are
  idempotent. The file is created on demand with sensible defaults when
  a helper is called and it does not yet exist.
  """

  @path "assets/package.json"

  @doc """
  Adds (or updates) a package in `assets/package.json`.

  ## Options

  - `:type` — `:dev` (default, writes to `devDependencies`) or `:runtime`
    (writes to `dependencies`). Phoenix's bundled esbuild handles the build,
    so dev is almost always correct.

  ## Example

      Npm.add_dependency(igniter, "topbar", "^3.0.0")
      Npm.add_dependency(igniter, "daisyui", "^5.0.50", type: :dev)
  """
  @spec add_dependency(Igniter.t(), String.t(), String.t(), Keyword.t()) :: Igniter.t()
  def add_dependency(igniter, name, version, opts \\ []) do
    field = field_for(opts)

    update_package_json(igniter, fn data ->
      if get_in(data, [field, name]) == version do
        :unchanged
      else
        {:updated, put_in_field(data, field, name, version)}
      end
    end)
  end

  @doc "Removes a package from both `dependencies` and `devDependencies`."
  @spec remove_dependency(Igniter.t(), String.t()) :: Igniter.t()
  def remove_dependency(igniter, name) do
    update_package_json(igniter, fn data ->
      data
      |> drop_dep(name, "dependencies")
      |> drop_dep(name, "devDependencies")
      |> case do
        ^data -> :unchanged
        new_data -> {:updated, new_data}
      end
    end)
  end

  @doc "Returns `true` if `name` is present in either dependency map."
  @spec has_dependency?(map(), String.t()) :: boolean()
  def has_dependency?(data, name) do
    Map.has_key?(data["dependencies"] || %{}, name) or
      Map.has_key?(data["devDependencies"] || %{}, name)
  end

  defp field_for(opts) do
    case Keyword.get(opts, :type, :dev) do
      :dev -> "devDependencies"
      :runtime -> "dependencies"
    end
  end

  defp put_in_field(data, field, name, version) do
    Map.update(data, field, %{name => version}, &Map.put(&1, name, version))
  end

  defp drop_dep(data, name, field) do
    case data[field] do
      nil ->
        data

      deps ->
        case Map.pop(deps, name) do
          {nil, _} -> data
          {_, new_deps} -> Map.put(data, field, new_deps)
        end
    end
  end

  defp update_package_json(igniter, updater) do
    if Igniter.exists?(igniter, @path) do
      Igniter.update_file(igniter, @path, fn source ->
        content = Rewrite.Source.get(source, :content)
        data = Jason.decode!(content)

        case updater.(data) do
          :unchanged -> source
          {:updated, new_data} -> Rewrite.Source.update(source, :content, encode(new_data))
        end
      end)
    else
      data = default_package_json(igniter)

      case updater.(data) do
        :unchanged -> Igniter.create_new_file(igniter, @path, encode(data))
        {:updated, new_data} -> Igniter.create_new_file(igniter, @path, encode(new_data))
      end
    end
  end

  defp default_package_json(_igniter) do
    %{
      "name" => default_name(),
      "version" => "1.0.0",
      "license" => "ISC",
      "devDependencies" => %{}
    }
  end

  defp default_name do
    File.cwd!() |> Path.basename() |> Path.rootname()
  end

  defp encode(data), do: Jason.encode!(data, pretty: true) <> "\n"
end
