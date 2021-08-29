defmodule WagonWheel.Utils.ConfigFile do
  @moduledoc """
  GenServer that reads from config files,
  knowing which settings are stored in which config files. This
  must be started after the settings genserver because it looks
  up the base directory for the config file location in Settings.

  Note that some settings can be overridden with environment
  variables, see the function docs for details.
  """

  use GenServer
  use LoggerUtils
  import ShorterMaps

  ##############################
  # API
  ##############################

  @doc """
  Parse the config file. This is automatically called when the
  genserver starts. Call it again if the config file changes and
  need to be reloaded. If `watch_file_system: true` is passed to
  `start_link/1`, then the GenServer will automatically watch
  the config file and will automatically reload it when it
  changes.

  ## Returns
  - `:ok` All is well
  - `{:error, reason}` Failed for reason
  """
  def parse_config_file, do: GenServer.call(__MODULE__, :parse_config_files)

  @doc """
  Get a config item by name or path through config file
  ## Parameters
  - `item` [String.t] or String.t An item or path to an item to retrieve
    As in "foo", or ["foo"], or ["foo", "bar"]
  ## Returns
  - `{:ok, value}` All is well
  - `{:error, :not_found}` Item was not found in the config
  """
  def get_item(item), do: GenServer.call(__MODULE__, {:get_item, item})

  @doc """
  Get an item, raising if not found. See `get_item/1`

  ## Parameters
  - `item` [String.t] or String.t An item or path to an item to retrieve
    As in "foo", or ["foo"], or ["foo", "bar"]

  ## Returns
  - value
  """
  def get_item!(item) do
    {:ok, item} = get_item(item)
    item
  end

  @doc """
  Put a config item by name or path. This does **not** update an underlying
  config file; it is only an in-memory ephemeral change

  ## Parameters
  - `item` [String.t] or String.t An item or path to an item to retrieve
    As in "foo", or ["foo"], or ["foo", "bar"]
  - `value` String.t value to assign to `item`

  ## Returns
  - `:ok` All is well
  """
  def put_item(item, value), do: GenServer.call(__MODULE__, {:put_item, item, value})

  @doc """
  Ensure that this genserver is started. NB: if it isn't, then it will be linked to the caller!
  """
  def ensure_started do
    with pid <- Process.whereis(__MODULE__),
         true <- is_pid(pid),
         true <- Process.alive?(pid) do
      :ok
    else
      err ->
        LoggerUtils.error(
          "#{__MODULE__} was not alive and had to be started (#{inspect(err, pretty: true)})"
        )

        {:ok, _} = __MODULE__.start_link(:ok)
        :ok
    end
  end

  @doc """
  Start the genserver

  ## Parameters
  - `opts`, a keyword list:
    - {:config_file, String.t} Path to the config file to load, required
    - {:watch_fs, boolean()} Whether (true) or not to watch the config file and automatically reload it when it changes, defaults to false

  ## Returns
  - See `GenServer.start_link/3`
  """
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  defmodule State do
    @moduledoc false
    defstruct [
      # the config
      cfg: %{}
    ]
  end

  ##############################
  # GenServer Callbacks
  ##############################

  @impl GenServer
  def init(opts) do
    LoggerUtils.info("Starting")
    {state, result} = do_parse_config_files(~M{%State})
    LoggerUtils.debug("Initial config parse result: #{inspect(result, pretty: true)}")
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:parse_config_files, _from, state) do
    {updated_state, result} = do_parse_config_files(state)
    {:reply, result, updated_state}
  end

  @impl GenServer
  def handle_call({:get_item, item}, _from, state) do
    {updated_state, result} = do_get_item(state, item)
    {:reply, result, updated_state}
  end

  @impl GenServer
  def handle_call({:put_item, item, value}, _from, state) do
    {updated_state, result} = do_put_item(state, item, value)
    {:reply, result, updated_state}
  end

  ##############################
  # Internal Calls
  ##############################

  def do_parse_config_files(state) do
    with cfg_path <- get_cfg_path(),
         _ <- LoggerUtils.info("Config file is: #{cfg_path}"),
         {:ok, cfg} <- YamlElixir.read_from_file(cfg_path) do
      updated_state = ~M{state| cfg}
      LoggerUtils.debug(inspect(updated_state, pretty: true, limit: :infinity))
      {updated_state, :ok}
    else
      err ->
        LoggerUtils.error("Failed to parse config: #{inspect(err, pretty: true)}")
        {state, err}
    end
  end

  def do_get_item(state, item) when not is_list(item), do: do_get_item(state, List.wrap(item))

  def do_get_item(~M{cfg} = state, item) do
    case get_in(cfg, item) do
      nil -> {state, {:error, :not_found}}
      value -> {state, {:ok, value}}
    end
  end

  def do_put_item(state, item, value) when not is_list(item),
    do: do_put_item(state, List.wrap(item), value)

  def do_put_item(~M{cfg} = state, item, value) do
    updated_cfg = put_in(cfg, item, value)
    {~M{state| cfg: updated_cfg}, :ok}
  end

  def get_cfg_path do
    want_path =
      Path.join([
        System.get_env("CONFIG_ROOT", "/opt/ww/wagon_wheel"),
        "config",
        "wagon_wheel.yml"
      ])

    LoggerUtils.debug("Want config from: #{want_path}")

    if File.exists?(want_path) do
      want_path
    else
      LoggerUtils.error("Using fallback config file from priv dir!")
      Path.join([:code.priv_dir(:wagon_wheel), "wagon_wheel.yml"])
    end
  end
end
