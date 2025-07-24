"""
What we want to do is to create a supervision tree of the following
structure:
{
  Root: {
    Container Monitor: [ContainerMonitor]
  }
}

we need to find the files to monitor in:
/sys/fs/cgroup/system.slice/docker-{guid}.scope
"""

defmodule Sysmon.ContainerMonitorSupervisor do
  use Supervisor
  require Logger

  @cgroup_dir "/sys/fs/cgroup/system.slice/"
  @docker_dir_regex ~r/^docker-([a-f0-9]{64})\.scope$/

  def start_link() do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    {:ok, entries} = File.ls(@cgroup_dir)
    valid_entries = entries |> Enum.filter(fn dir -> Regex.match?(@docker_dir_regex, dir) end)

    children = [ {Sysmon.ProcessMonitor, @cgroup_dir} | valid_entries |> Enum.map(fn x -> get_cpu_monitor(x) end)]

    opts = [
      strategy: :one_for_one,
      max_restarts: 4,
      max_seconds: 20
    ]
    Supervisor.init(children, opts)
  end

  def start_metric_emit() do
    handles = Supervisor.which_children(Sysmon.ContainerMonitorSupervisor)
    |> Enum.filter(fn {id, _, _, _} ->
        case id do
          {:sysmon_cpu_worker, _} -> true
          _ -> false
        end
    end)
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.map(fn pid -> :timer.send_interval(2000, pid, :emit) end)
    |> Enum.map(fn {:ok, handle} -> handle end)

    {:ok, handles}
  end

  def cancel_metric_emit(handles) do
    handles |> Enum.map(fn e -> :timer.cancel(e) end)
  end
  
  defp get_cpu_monitor(dir) when is_binary(dir) do
    %{
      id: {:sysmon_cpu_worker, dir},
      start: {Sysmon.ContainerMonitor, :start_link, [Path.join(@cgroup_dir, dir)]}
    }
  end
end

defmodule Sysmon.ProcessMonitor do
  use GenServer
  require Logger

  def start_link(cgroup_dir) when is_binary(cgroup_dir) do
    GenServer.start_link(__MODULE__, cgroup_dir, name: __MODULE__)
  end
  
  def init(init_arg) do
    Process.send_after(self(), :monitor, 1000)
    {:ok, init_arg}
  end

  def handle_info(:monitor, cgroup_dir) do
    existing_dirs = Supervisor.which_children(Sysmon.ContainerMonitorSupervisor)
      |> Enum.filter(fn {id, _, _, _} -> 
        case id do
          {:sysmon_cpu_worker, _} -> true
          _ -> false
        end
      end)
      |> Enum.map(fn {{:sysmon_cpu_worker, dir}, _, :worker, [Sysmon.ContainerMonitor]} -> dir end)

    case File.ls(cgroup_dir) do
      {:ok, entries} -> check_entries(cgroup_dir, entries, existing_dirs)
      {:error, _} -> Logger.info("ERROR reading cgroup file")
    end

    Process.send_after(self(), :monitor, 1500)
    {:noreply, cgroup_dir}
  end

  def check_entries(cgroup_dir, entries, existing_dirs) do
    Logger.info("Start child check removal")
    entry_set = entries |> MapSet.new

    existing_dirs 
    |> Enum.filter(fn dir -> !MapSet.member?(entry_set, dir) end)
    |> Enum.map(fn dir -> remove_non_existent(dir) end)
    Logger.info("End child check removal")
  end

  def remove_non_existent(dir) do
    Logger.info("Deleting child " <> dir)
    :ok = Supervisor.terminate_child(Sysmon.ContainerMonitorSupervisor, {:sysmon_cpu_worker, dir})
    :ok = Supervisor.delete_child(Sysmon.ContainerMonitorSupervisor, {:sysmon_cpu_worker, dir})
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
    {:ok, handles} = Sysmon.ContainerMonitorSupervisor.start_metric_emit()

    Process.sleep(:infinity)
  end
end

