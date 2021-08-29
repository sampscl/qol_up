defmodule QolUp.MixProject do
  use Mix.Project

  @doc """
  Get the version of the app. This will do sorta-smart things when git is not
  present on the build machine (it's possible, especially in Docker containers!)
  by using the "version" environment variable.

  ## Returns
  - version `String.t`
  """
  def version do
    "git describe"
    |> System.shell(cd: Path.dirname(__ENV__.file))
    |> then(fn
      {version, 0} -> Regex.replace(~r/^[[:alpha:]]*/, String.trim(version), "")
      {_barf, _exit_code} -> System.get_env("version", "1.0.2")
    end)
    |> tap(&IO.puts("Version: #{&1}"))
  end

  def project do
    [
      app: :qol_up,
      version: version(),
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      preferred_cli_env: [espec: :test],
      deps: deps(),
      aliases: aliases(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def aliases do
    [
      espec: &espec/1
    ]
  end

  def espec(args) do
    Mix.Task.run("espec", args ++ ["--no-start"])
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ex_doc, "~> 0.25", only: :dev, runtime: false},
      {:espec, "~> 1.8", only: :test},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:briefly, "~> 0.3", only: :test},
      {:shorter_maps, "~> 2.2"},
      {:yaml_elixir, "~> 2.7"},
      {:file_system, "~> 0.2"}
    ]
  end

  defp package do
    [
      description: "Utilities for quality of life upgrades",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/sampscl/qol_up"},
      homepage_url: "https://github.com/sampscl/qol_up",
      source_url: "https://github.com/sampscl/qol_up"
    ]
  end
end
