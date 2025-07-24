defmodule Sysmon.DockerUtils do
  @cgroup_dir "/sys/fs/cgroup/system.slice/"
  @docker_dir_regex ~r/^docker-([a-f0-9]{64})\.scope$/

  def cgroup_dir do
    @cgroup_dir
  end

  def filter_container_dirs(dir) when is_binary(dir) do
    Regex.match?(@docker_dir_regex, dir)
  end
end

defmodule Sysmon.ContainerMonitorSupervisor do
  alias Sysmon.DockerUtils
  use Supervisor
  require Logger

  def start_link() do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    {:ok, entries} = File.ls(DockerUtils.cgroup_dir)
    valid_entries = entries |> Enum.filter(&DockerUtils.filter_container_dirs/1)

    children = [ Sysmon.ProcessMonitor | valid_entries |> Enum.map(fn x -> get_container_monitor(x) end)]

    opts = [
      strategy: :one_for_one,
      max_restarts: 4,
      max_seconds: 20
    ]
    Supervisor.init(children, opts)
  end

  defp get_container_monitor(dir) when is_binary(dir) do
    %{
      id: {:sysmon_container_monitor, dir},
      start: {Sysmon.ContainerMonitor, :start_link, [Path.join(DockerUtils.cgroup_dir, dir)]}
    }
  end
end

defmodule Sysmon.ProcessMonitor do
  alias Sysmon.DockerUtils
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end
  
  def init(_) do
    :timer.send_interval(2000, self(), :monitor)
    {:ok, nil}
  end

  def handle_info(:monitor, _) do
    existing_dirs = Supervisor.which_children(Sysmon.ContainerMonitorSupervisor)
      |> Enum.filter(fn {id, _, _, _} -> 
        case id do
          {:sysmon_container_monitor, _} -> true
          _ -> false
        end
      end)
      |> Enum.map(fn {{:sysmon_container_monitor, dir}, _, :worker, [Sysmon.ContainerMonitor]} -> dir end)

    case File.ls(DockerUtils.cgroup_dir) do
      {:ok, entries} -> check_entries(entries |> Enum.filter(&DockerUtils.filter_container_dirs/1), existing_dirs)
      {:error, _} -> Logger.info("ERROR reading cgroup file")
    end

    {:noreply, nil}
  end

  def check_entries(entries, existing_dirs) do
    Logger.info("Start child check removal")
    entry_set = entries |> MapSet.new
    dir_set = existing_dirs |> MapSet.new
  
    existing_dirs # first, we remove from the Supervisor any child that does not appear in cgroup directory
    |> Enum.filter(fn dir -> !MapSet.member?(entry_set, dir) end)
    |> Enum.map(fn dir -> remove_terminated_container(dir) end)

    entries # second, we add any missing children that we did not track
    |> Enum.filter(fn dir -> !MapSet.member?(dir_set, dir) end)
    |> Enum.map(&add_missing_container/1)

    Logger.info("End child check removal")
  end

  def remove_terminated_container(dir) do
    Logger.info("Deleting child " <> dir)
    :ok = Supervisor.terminate_child(Sysmon.ContainerMonitorSupervisor, {:sysmon_container_monitor, dir})
    :ok = Supervisor.delete_child(Sysmon.ContainerMonitorSupervisor, {:sysmon_container_monitor, dir})
  end

  def add_missing_container(dir) do
    Logger.info("Adding new child " <> dir)
    child_spec = %{
      id: {:sysmon_container_monitor, dir},
      start: {Sysmon.ContainerMonitor, :start_link, [Path.join(DockerUtils.cgroup_dir, dir)]}
    }
    Supervisor.start_child(Sysmon.ContainerMonitorSupervisor, child_spec)
  end
end

defmodule Sysmon.ContainerMonitor do
  use GenServer
  require Logger

  def start_link(path) when is_binary(path) do
    GenServer.start_link(__MODULE__, path)
  end

  def init(path) when is_binary(path) do
    Logger.info("STARTING TO MONITOR " <> path)
    :timer.send_interval(2000, self(), :emit)
    {:ok, path} # maybe more state to come
  end

  def handle_info(:emit, container_path) do
    Logger.info("START_EMIT for dir " <> container_path)

    content = get_cpu_metrics(container_path)
      |> Enum.map(fn %{:name => n, :value => v, :source => _, :type => _} -> "Name: " <> n <> " Value #{v}" end)
      |> Enum.reduce("", fn x, acc -> x <> "\n" <> acc end)

    File.write("./data#{DateTime.utc_now() |> DateTime.to_unix(:millisecond)}.txt", content, [:write])

    Logger.info("END_EMIT for dir " <> container_path)

    {:noreply, container_path}
  end

  def get_cpu_metrics(path) do
    Path.join([path, "cpu.stat"]) 
      |> File.read! 
      |> String.split("\n")
      |> Enum.filter(fn e -> e != "" end)
      |> Enum.map(fn x -> parse_cpu_line(x) end)
  end

  defp parse_cpu_line(line) when is_binary(line) do
    parts = line |> String.split(" ")
    [metric_name, metric_value] = parts
    {parsed_value, _} = Integer.parse(metric_value)
    %{name: metric_name, value: parsed_value, source: Sysmon.ContainerMonitor, type: :cpumetric}
  end
end

defmodule Sysmon.Main do
  def main() do
    {:ok, _} = Sysmon.ContainerMonitorSupervisor.start_link()
    Process.sleep(:infinity)
  end
end

