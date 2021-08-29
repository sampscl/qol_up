defmodule QolUp.ConfigFile do
  @moduledoc """
  GenServer that reads from a config file.
  """

  use GenServer
  use QolUp.LoggerUtils
  import ShorterMaps

  ##############################
  # API
  ##############################

  @typedoc """
  The name of a configuration item, the list variation is
  for nesting of items.
  """
  @type item_name :: String.t() | list(String.t())

  @spec parse_config_file(atom()) :: :ok | {:error, any()}
  @doc """
  Parse the config file. This is automatically called when the
  genserver starts. Call it again if the config file changes and
  need to be reloaded. If `watch_file_system: true` is passed to
  `start_link/1`, then the GenServer will automatically watch
  the config file and will automatically reload it when it
  changes.

  ## Parameters
  - `name` The name of the GenServer
  ## Returns
  - `:ok` All is well
  - `{:error, reason}` Failed for reason
  """
  def parse_config_file(name \\ __MODULE__), do: GenServer.call(name, :parse_config_files)

  @spec get_item(atom(), item_name()) :: {:ok, any()} | {:error, any()}
  @doc """
  Get a config item by name or path through config file
  ## Parameters
  - `name` The name of the GenServer
  - `item` [String.t] or String.t An item or path to an item to retrieve
    As in "foo", or ["foo"], or ["foo", "bar"]
  ## Returns
  - `{:ok, value}` All is well
  - `{:error, :not_found}` Item was not found in the config
  """
  def get_item(name \\ __MODULE__, item), do: GenServer.call(name, {:get_item, item})

  @spec get_item!(atom(), item_name()) :: any()
  @doc """
  Get an item, raising if not found. See `get_item/1`

  ## Parameters
  - `name` The name of the GenServer
    - `item` [String.t] or String.t An item or path to an item to retrieve
    As in "foo", or ["foo"], or ["foo", "bar"]

  ## Returns
  - value
  """
  def get_item!(name \\ __MODULE__, item) do
    {:ok, item} = get_item(name, item)
    item
  end

  @spec put_item(atom(), item_name(), any()) :: :ok
  @doc """
  Put a config item by name or path. This does **not** update an underlying
  config file; it is only an in-memory ephemeral change.

  ## Parameters
  - `name` The name of the GenServer
    - `item` [String.t] or String.t An item or path to an item to retrieve
    As in "foo", or ["foo"], or ["foo", "bar"]
  - `value` String.t value to assign to `item`

  ## Returns
  - `:ok` All is well
  """
  def put_item(name \\ __MODULE__, item, value),
    do: GenServer.call(name, {:put_item, item, value})

  @typedoc """
  Available options for the GenServer
  """
  @type opts_t ::
          {:config_file, String.t()} | {:watch_fs, boolean()} | {:name, atom()}

  @typedoc """
  List of options
  """
  @type opts_list :: list(opts_t)

  @spec start_link(opts_list()) :: GenServer.on_start()
  @doc """
  Start the genserver

  ## Parameters
  - `opts`, an `opts_list()`:
    * name Name to give the GenServer; if not specified, then `QolUp.ConfigFile` is used.
    * config_file Path to the config file to load, required
    * watch_fs Whether (true) or not to watch the config file and automatically reload it when it changes, defaults to false

  ## Returns
  - See `GenServer.start_link/3`
  """
  def start_link(opts),
    do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))

  defmodule State do
    @moduledoc """
    State structure for the GenServer.
    """
    defstruct [
      # the config
      cfg: %{},

      # path to the config
      config_file: nil,

      # whether or not to watch the config file and reload on change
      watch_fs: false,

      # pid of filesystem watcher (or nil if disabled)
      fs_pid: nil
    ]

    @typedoc """
    Type spec for this structure
    """
    @type t :: %__MODULE__{
            cfg: map(),
            config_file: String.t(),
            watch_fs: boolean(),
            fs_pid: pid() | nil
          }
  end

  ##############################
  # GenServer Callbacks
  ##############################

  @impl GenServer
  def init(opts) do
    L.info("Starting: #{inspect(opts, pretty: true)}")
    config_file = Keyword.get(opts, :config_file)
    watch_fs = Keyword.get(opts, :watch_fs, false)
    state = do_init(~M{%State config_file, watch_fs})
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:parse_config_files, _from, state) do
    {updated_state, result} = do_parse_config_file(state)
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

  @impl GenServer
  def handle_info({:file_event, _watcher_pid, {path, events}}, state) do
    {:noreply, do_handle_file_events(state, path, events)}
  end

  ##############################
  # Internal Calls
  ##############################

  @spec do_init(State.t()) :: State.t()
  @doc false
  def do_init(~M{config_file, watch_fs} = state) do
    {cfg_state, result} = do_parse_config_file(state)
    L.debug("Initial config parse result: #{inspect(result, pretty: true)}")

    if watch_fs do
      L.debug("Watching #{config_file}")
      {:ok, fs_pid} = FileSystem.start_link(dirs: [config_file])
      FileSystem.subscribe(fs_pid)
      ~M{cfg_state| fs_pid}
    else
      cfg_state
    end
  end

  @doc false
  def do_parse_config_file(~M{config_file} = state) do
    case YamlElixir.read_from_file(config_file) do
      {:ok, cfg} ->
        {~M{state| cfg}, :ok}

      err ->
        L.error("Failed to parse config: #{inspect(err, pretty: true)}")
        {state, {:error, err}}
    end
  end

  @doc false
  def do_get_item(state, item) when not is_list(item), do: do_get_item(state, List.wrap(item))

  @doc false
  def do_get_item(~M{cfg} = state, item) do
    case get_in(cfg, item) do
      nil -> {state, {:error, :not_found}}
      value -> {state, {:ok, value}}
    end
  end

  @doc false
  def do_put_item(state, item, value) when not is_list(item),
    do: do_put_item(state, List.wrap(item), value)

  @doc false
  def do_put_item(~M{cfg} = state, item, value) do
    updated_cfg = put_in(cfg, item, value)
    {~M{state| cfg: updated_cfg}, :ok}
  end

  @spec do_handle_file_events(State.t(), String.t(), list(atom())) :: State.t()
  @doc false
  def do_handle_file_events(~M{config_file} = state, path, events) do
    L.locals()

    Enum.reduce(events, state, fn event, intermediate_state ->
      case event do
        :modified ->
          L.debug("")
          {updated_state, :ok} = do_parse_config_file(intermediate_state)
          updated_state

        _ ->
          intermediate_state
      end
    end)
    |> L.leave()
  end
end
