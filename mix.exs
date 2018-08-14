defmodule GuardianFirebase.MixProject do
  use Mix.Project

  def project do
    [
      app: :guardian_firebase,
      version: "0.2.1",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "GuardianFirebase",
      source_url: "https://github.com/hippware/guardian_firebase",
      docs: [main: "readme", extras: ["README.md"]],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.post": :test,
        vcr: :test,
        "vcr.delete": :test,
        "vcr.check": :test,
        "vcr.show": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {GuardianFirebase.Application, []},
      env: [
        issuer_prefix: "https://securetoken.google.com/",
        allowed_algos: ["RS256"],
        load_keys_on_startup: true,
        local_keys: []
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:guardian, "~> 1.0"},
      {:hackney, "~> 1.11"},
      {:dialyxir, "~> 0.5", only: :dev},
      {:credo, "~> 0.8", only: :dev},
      {:ex_doc, "~> 0.16", only: :dev},
      {:timex, "~> 3.0", only: :test},
      {:excoveralls, "~> 0.8", only: :test},
      {:exvcr, "~> 0.10", only: :test}
    ]
  end

  defp description do
    """
    Library for authenticating against Google Firebase using Guardian.
    """
  end

  defp package do
    [
      maintainers: ["Phil Toland", "Bernard Duggan"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/hippware/guardian_firebase"}
    ]
  end
end
