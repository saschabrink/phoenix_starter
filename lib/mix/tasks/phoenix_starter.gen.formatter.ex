defmodule Mix.Tasks.PhoenixStarter.Gen.Formatter.Docs do
  @moduledoc false

  def short_doc, do: "Applies phoenix_starter formatter conventions"

  def example, do: "mix phoenix_starter.gen.formatter"

  def long_doc do
    """
    #{short_doc()}

    Currently sets `line_length: 150` in `.formatter.exs`. Future revisions may
    add more conventions (e.g. `subdirectories`, `inputs`).

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixStarter.Gen.Formatter do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @line_length 150

    @default_formatter """
    # Used by "mix format"
    [
      inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
    ]
    """

    alias Igniter.Code.Common
    alias Sourceror.Zipper

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :phoenix_starter,
        example: __MODULE__.Docs.example()
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> Igniter.include_or_create_file(".formatter.exs", @default_formatter)
      |> Igniter.update_elixir_file(".formatter.exs", fn zipper ->
        zipper
        |> Zipper.down()
        |> case do
          nil ->
            code =
              quote do
                [line_length: unquote(@line_length)]
              end

            {:ok, Common.add_code(zipper, code)}

          zipper ->
            zipper
            |> Zipper.rightmost()
            |> Igniter.Code.Keyword.put_in_keyword(
              [:line_length],
              @line_length,
              fn nested ->
                {:ok, Common.replace_code(nested, to_string(@line_length))}
              end
            )
            |> case do
              {:ok, zipper} ->
                {:ok, zipper}

              _ ->
                {:warning,
                 """
                 phoenix_starter.gen.formatter: could not set `line_length: #{@line_length}` in `.formatter.exs`.

                 Please add it manually.
                 """}
            end
        end
      end)
    end
  end
else
  defmodule Mix.Tasks.PhoenixStarter.Gen.Formatter do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_starter.gen.formatter' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
