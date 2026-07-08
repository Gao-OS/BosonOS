defmodule Boson.MixProject do
  use Mix.Project

  def project do
    [
      app: :boson,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  def application do
    [
      mod: {Boson.Application, []},
      extra_applications: [:logger]
    ]
  end
end
