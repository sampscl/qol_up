defmodule QolUp.LoggerUtils do
  @moduledoc """
  Macros supporting logging
  """
  require Logger

  defmodule Functions do
    @doc """
    Prettify the results from `Process.info(:current_stacktrace)`, returning a list
    if items that inspect cleanly.

    ## Returns
    - [String.t()]
    """
    def pretty_stack do
      {:current_stacktrace, [_me, _process_info | fs]} = Process.info(self(), :current_stacktrace)

      Enum.map(fs, fn info_silliness ->
        # The return from Process.info is not very pretty, so make it nicer
        {m, f, a, kwl} = info_silliness
        fl = Keyword.get(kwl, :file)
        l = Keyword.get(kwl, :line)

        "#{m}.#{f}/#{a} (#{fl}:#{l})"
      end)
    end
  end

  @doc """
  Using macro.

  ## Parameters
  - opts KWL options, currently unused
  """
  defmacro __using__(_opts \\ []) do
    quote do
      require Logger
      require QolUp.LoggerUtils
      alias QolUp.LoggerUtils, as: L
    end
  end

  @doc """
  Log a string at specified logger level
  """
  defmacro debug(string, metadata \\ []) do
    quote do
      {f, a} = __ENV__.function
      l = __ENV__.line
      file = __ENV__.file

      path =
        "./#{Path.relative_to_cwd(file)}" |> String.replace(~r/.+?\/apps\//, "", global: false)

      log_string = "#{node()} #{path}:#{l} in #{f}/#{a}: " <> unquote(string)
      Logger.debug(log_string, unquote(metadata))
    end
  end

  @doc """
  Inspect then log an object at debug level
  """
  defmacro di(o, metadata \\ []) do
    quote do
      {f, a} = __ENV__.function
      l = __ENV__.line
      file = __ENV__.file

      path =
        "./#{Path.relative_to_cwd(file)}" |> String.replace(~r/.+?\/apps\//, "", global: false)

      log_string =
        "#{node()} #{path}:#{l} in #{f}/#{a}: " <>
          inspect(unquote(o), pretty: true, limit: :infinity)

      Logger.debug(log_string, unquote(metadata))
    end
  end

  @doc """
  Print the current stack trace at debug level, use as fist statement in a function
  """
  defmacro trace_enter(metadata \\ []) do
    quote do
      if Logger.level() == :debug do
        st = inspect(QolUp.LoggerUtils.Functions.pretty_stack(), pretty: true, limit: :infinity)

        Logger.debug("==> #{st}", unquote(metadata))
      end
    end
  end

  @doc """
  Log the function result at debug level, pipe to this as last statement in a function
  """
  defmacro trace_leave(result, metadata \\ []) do
    quote do
      the_result = unquote(result)

      if Logger.level() == :debug do
        st = QolUp.LoggerUtils.Functions.pretty_stack() |> Enum.join("\n  ")

        Logger.debug("<== #{st} (#{the_result})", unquote(metadata))
      end

      the_result
    end
  end

  @doc """
  Print local bindings (all local variables)
  """
  defmacro locals(metadata \\ []) do
    quote do
      if Logger.level() == :debug do
        vars = binding()

        {f, a} = __ENV__.function
        l = __ENV__.line
        file = __ENV__.file

        path =
          "./#{Path.relative_to_cwd(file)}" |> String.replace(~r/.+?\/apps\//, "", global: false)

        log_string =
          "#{node()} #{path}:#{l} in #{f}/#{a} locals: " <>
            inspect(vars, pretty: true, limit: :infinity)

        Logger.debug(log_string, unquote(metadata))
      end
    end
  end

  @doc """
  Print current stack trace and local variables at debug level, use as first statement in a function
  """
  defmacro enter(metadata \\ []) do
    quote do
      if Logger.level() == :debug do
        vars = binding()

        st = QolUp.LoggerUtils.Functions.pretty_stack() |> Enum.join("\n  ")

        log_string =
          "==> #{st}\n" <>
            "#{node()}: " <> inspect(vars, pretty: true, limit: :infinity)

        Logger.debug(log_string, unquote(metadata))
      end
    end
  end

  @doc """
  Log the function result at debug level, pipe to this as last statement in a function
  """
  defmacro leave(result, metadata \\ []) do
    quote do
      the_result = unquote(result)

      if Logger.level() == :debug do
        {f, a} = __ENV__.function
        l = __ENV__.line
        file = __ENV__.file

        path =
          "./#{Path.relative_to_cwd(file)}" |> String.replace(~r/.+?\/apps\//, "", global: false)

        log_string =
          "<== #{node()} #{path}:#{l} in #{f}/#{a}: " <>
            inspect(the_result, pretty: true, limit: :infinity)

        Logger.debug(log_string, unquote(metadata))
      end

      the_result
    end
  end

  @doc """
  Log a string at specified logger level
  """
  defmacro info(string, metadata \\ []) do
    quote do
      {f, a} = __ENV__.function
      l = __ENV__.line
      file = __ENV__.file

      path =
        "./#{Path.relative_to_cwd(file)}" |> String.replace(~r/.+?\/apps\//, "", global: false)

      log_string = "#{node()} #{path}:#{l} in #{f}/#{a}: " <> unquote(string)
      Logger.info(log_string, unquote(metadata))
    end
  end

  @spec warn(any, any) :: {:__block__, [], [{:= | {any, any, any}, [], [...]}, ...]}
  @doc """
  Log a string at specified logger level
  """
  defmacro warn(string, metadata \\ []) do
    quote do
      {f, a} = __ENV__.function
      l = __ENV__.line
      file = __ENV__.file

      path =
        "./#{Path.relative_to_cwd(file)}" |> String.replace(~r/.+?\/apps\//, "", global: false)

      log_string = "#{node()} #{path}:#{l} in #{f}/#{a}: " <> unquote(string)
      Logger.warn(log_string, unquote(metadata))
    end
  end

  @doc """
  Log a string at specified logger level
  """
  defmacro error(string, metadata \\ []) do
    quote do
      {f, a} = __ENV__.function
      l = __ENV__.line
      file = __ENV__.file

      path =
        "./#{Path.relative_to_cwd(file)}" |> String.replace(~r/.+?\/apps\//, "", global: false)

      log_string = "#{node()} #{path}:#{l} in #{f}/#{a}: " <> unquote(string)
      Logger.error(log_string, unquote(metadata))
    end
  end

  @doc """
  Log a string at specified logger level
  """
  defmacro log(level, string) do
    quote do
      {f, a} = __ENV__.function
      l = __ENV__.line
      file = __ENV__.file

      path =
        "./#{Path.relative_to_cwd(file)}" |> String.replace(~r/.+?\/apps\//, "", global: false)

      log_string = "#{node()} #{path}:#{l} in #{f}/#{a}: " <> unquote(string)

      case unquote(level) do
        :debug -> Logger.debug(log_string)
        :info -> Logger.info(log_string)
        :warn -> Logger.warn(log_string)
        :error -> Logger.error(log_string)
      end
    end
  end
end
