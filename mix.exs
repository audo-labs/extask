defmodule Extask.Mixfile do
  use Mix.Project

  def project do
    [app: :extask,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [mod: {Extask, []},
     extra_applications: [:logger]]
  end

  defp deps do
    []
  end
end
