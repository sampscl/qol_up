defmodule YamlConfigFileSpec do
  use ESpec

  def temp_config_file(contents) do
    {:ok, cfg_file} = Briefly.create(directory: false)
    :ok = File.write!(cfg_file, contents)
    cfg_file
  end

  describe "QolUp.YamlConfigFile" do
    it "parses empty config files" do
      # make an empty temporary config file
      cfg_file = temp_config_file("")
      # note: it always parses config files on startup
      name = __ENV__.function |> then(&(elem(&1, 0)))
      {:ok, pid} = QolUp.YamlConfigFile.start_link(config_file: cfg_file, name: name)
      assert(pid |> to(be_pid()))
      GenServer.stop(name)
    end

    it "parses valid config files" do
      cfg_file = temp_config_file("---\nfoo: bar")
      name = __ENV__.function |> then(&(elem(&1, 0)))
      {:ok, pid} = QolUp.YamlConfigFile.start_link(config_file: cfg_file, name: name)
      assert(pid |> to(be_pid()))
      GenServer.stop(name)
    end

    it "reads config parameters" do
      cfg_file = temp_config_file("---\nfoo: bar")
      name = __ENV__.function |> then(&(elem(&1, 0)))
      {:ok, pid} = QolUp.YamlConfigFile.start_link(config_file: cfg_file, name: name)
      assert(pid |> to(be_pid()))
      expect(QolUp.YamlConfigFile.get_item!(name, "foo") |> to(eq("bar")))
      GenServer.stop(name)
    end

    it "can start monitoring the filesystem" do
      cfg_file = temp_config_file("---\nfoo: bar")
      name = __ENV__.function |> then(&(elem(&1, 0)))
      {:ok, pid} = QolUp.YamlConfigFile.start_link(config_file: cfg_file, name: name, watch_fs: true)
      assert(pid |> to(be_pid()))
      expect(QolUp.YamlConfigFile.get_item!(name, "foo") |> to(eq("bar")))
      GenServer.stop(name)
    end

    it "reloads configs when monitoring" do
      cfg_file = temp_config_file("---\nfoo: bar")
      name = __ENV__.function |> then(&(elem(&1, 0)))
      {:ok, pid} = QolUp.YamlConfigFile.start_link(config_file: cfg_file, name: name, watch_fs: true)
      assert(pid |> to(be_pid()))
      expect(QolUp.YamlConfigFile.get_item!(name, "foo") |> to(eq("bar")))

      File.write!(cfg_file, "---\nfoo: baz")
      # Give a bit for change / notify system to process the change
      Process.sleep(1_500)
      expect(QolUp.YamlConfigFile.get_item!(name, "foo") |> to(eq("baz")))
      GenServer.stop(name)
    end
  end
end
