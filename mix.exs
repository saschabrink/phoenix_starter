defmodule PhoenixStarter.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_starter,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:igniter, "~> 0.8", optional: true},
      # Dev/test only — used to refresh `priv/templates/credo/credo.exs.snapshot`
      # via `mix phoenix_starter.refresh_credo_snapshot`.
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
