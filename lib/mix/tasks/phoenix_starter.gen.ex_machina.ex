defmodule Mix.Tasks.PhoenixStarter.Gen.ExMachina.Docs do
  @moduledoc false

  def short_doc, do: "Adds ExMachina + a stub Factory module wired into ConnCase/DataCase"

  def example, do: "mix phoenix_starter.gen.ex_machina"

  def long_doc do
    """
    #{short_doc()}

    Does three things:

    1. Adds `{:ex_machina, "~> 2.8", only: :test}` to `mix.exs`.
    2. Creates `test/support/factory.ex` — `<App>.Factory` — with
       `use ExMachina.Ecto, repo: <App>.Repo` and a commented example.
    3. Injects `alias <App>.Factory` into the `using do quote do ... end`
       block of `test/support/conn_case.ex` and `test/support/data_case.ex`
       (if either exists).

    Each step is idempotent. Missing case files are reported as warnings,
    not errors.

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.ExMachina do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    alias Igniter.Code.Common
    alias Igniter.Code.Function
    alias Sourceror.Zipper

    @factory_template Path.join(:code.priv_dir(:phoenix_starter), "templates/ex_machina/factory.eex")
    @external_resource @factory_template
    @factory_eex File.read!(@factory_template)

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
      app_module = app_module(igniter)
      factory_module = Module.concat(app_module, Factory)

      igniter
      |> Igniter.Project.Deps.add_dep({:ex_machina, "~> 2.8", only: :test})
      |> create_factory(factory_module, app_module)
      |> alias_factory_in_case("test/support/conn_case.ex", factory_module)
      |> alias_factory_in_case("test/support/data_case.ex", factory_module)
    end

    @doc false
    def factory_body(app_module) do
      EEx.eval_string(@factory_eex, assigns: [app_module: inspect(app_module)])
    end

    defp app_module(igniter) do
      igniter
      |> Igniter.Project.Application.app_name()
      |> to_string()
      |> Macro.camelize()
      |> List.wrap()
      |> Module.concat()
    end

    defp create_factory(igniter, factory_module, app_module) do
      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, factory_module)

      if exists? do
        igniter
      else
        Igniter.Project.Module.create_module(
          igniter,
          factory_module,
          factory_body(app_module),
          path: "test/support/factory.ex"
        )
      end
    end

    defp alias_factory_in_case(igniter, path, factory_module) do
      if Igniter.exists?(igniter, path) do
        Igniter.update_elixir_file(igniter, path, fn zipper ->
          patch_case_module(zipper, factory_module)
        end)
      else
        Igniter.add_warning(igniter, """
        phoenix_starter.gen.ex_machina: #{path} not found. Add the alias manually:

            alias #{inspect(factory_module)}
        """)
      end
    end

    # Inside the case module, navigate to `using do quote do ... end end` and
    # append `alias <Factory>` if not already present.
    defp patch_case_module(zipper, factory_module) do
      with {:ok, using_call} <- move_to_using_call(zipper),
           {:ok, using_body} <- Common.move_to_do_block(using_call),
           {:ok, quote_call} <- Function.move_to_function_call(using_body, :quote, 1),
           {:ok, quote_body} <- Common.move_to_do_block(quote_call) do
        if contains_alias_to?(quote_body, factory_module) do
          {:ok, quote_body}
        else
          {:ok, Common.add_code(quote_body, "alias #{inspect(factory_module)}", placement: :after)}
        end
      else
        :error ->
          # The case file exists but doesn't fit the `using do quote do` shape —
          # leave it alone rather than guess where the alias goes.
          {:ok, zipper}
      end
    end

    defp move_to_using_call(zipper) do
      Common.move_to(zipper, fn z ->
        case Zipper.node(z) do
          {:using, _, _} -> true
          _ -> false
        end
      end)
    end

    defp contains_alias_to?(zipper, target_module) do
      result =
        Common.move_to(zipper, fn z ->
          case Zipper.node(z) do
            {:__aliases__, _, parts} -> Module.concat(parts) == target_module
            _ -> false
          end
        end)

      match?({:ok, _}, result)
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.ExMachina do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.ex_machina' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
