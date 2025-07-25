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
