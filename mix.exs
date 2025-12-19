defmodule JQL.MixProject do
  use Mix.Project

  @url "https://github.com/tv-labs/jql"
  @version "0.4.0"

  def project do
    [
      app: :jql,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "JQL",
      description: "An Ecto-like DSL for writing Jira Query Language (JQL)",
      source_url: @url,
      homepage_url: @url,
      package: package(),
      docs: [
        # The main page in the docs
        main: "JQL",
        source_url: @url,
        source_ref: "v#{@version}"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      maintainers: ["davydog187"],
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      links: %{
        "GitHub" => @url
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.39.3", only: :dev, runtime: false}
    ]
  end
end
