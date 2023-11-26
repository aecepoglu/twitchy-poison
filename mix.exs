defmodule TwitchyPoison.MixProject do
  use Mix.Project

  def project do
    [
      app: :twitchy_poison,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {TwitchyPoison.Supervisor, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:exunit_stamp_formatter, "~> 0.1.0", only: :dev},
      {:httpoison, "~> 2.0"},
      {:poison, "~> 5.0"},
      {:websockex, "~> 0.4.3"},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
