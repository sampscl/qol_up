defmodule ConfigFileSpec do
  use ESpec

  def temp_config_file(contents) do
    {:ok, cfg_file} = Briefly.create(directory: false)
    :ok = File.write!(cfg_file, contents)
    cfg_file
  end

  describe "QolUp.ConfigFile" do
    it "parses empty config files" do
      # make an empty temporary config file
      cfg_file = temp_config_file("")
      # note: it always parses config files on startup
      {:ok, pid} = QolUp.ConfigFile.start_link(config_file: cfg_file, name: __ENV__.function |> then(&(elem(&1, 0))))
      assert(pid |> to(be_pid()))
    end

    it "parses valid config files" do
      cfg_file = temp_config_file("---\nfoo: bar")
      {:ok, pid} = QolUp.ConfigFile.start_link(config_file: cfg_file, name: __ENV__.function |> then(&(elem(&1, 0))))
      assert(pid |> to(be_pid()))
    end

    it "reads config parameters" do
      cfg_file = temp_config_file("---\nfoo: bar")
      name = __ENV__.function |> then(&(elem(&1, 0)))
      {:ok, pid} = QolUp.ConfigFile.start_link(config_file: cfg_file, name: name)
      assert(pid |> to(be_pid()))
      expect(QolUp.ConfigFile.get_item!(name, "foo") |> to(eq("bar")))
    end

    it "can start monitoring the filesystem" do
      cfg_file = temp_config_file("---\nfoo: bar")
      name = __ENV__.function |> then(&(elem(&1, 0)))
      {:ok, pid} = QolUp.ConfigFile.start_link(config_file: cfg_file, name: name, watch_fs: true)
      assert(pid |> to(be_pid()))
      expect(QolUp.ConfigFile.get_item!(name, "foo") |> to(eq("bar")))
    end

    it "reloads configs when monitoring" do
      cfg_file = temp_config_file("---\nfoo: bar")
      name = __ENV__.function |> then(&(elem(&1, 0)))
      {:ok, pid} = QolUp.ConfigFile.start_link(config_file: cfg_file, name: name, watch_fs: true)
      assert(pid |> to(be_pid()))
      expect(QolUp.ConfigFile.get_item!(name, "foo") |> to(eq("bar")))

      File.write!(cfg_file, "---\nfoo: baz")
      # Give a bit for change / notify system to process the change
      Process.sleep(1_000)
      expect(QolUp.ConfigFile.get_item!(name, "foo") |> to(eq("baz")))

    end
  end
end
