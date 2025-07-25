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

    children = 
      [
        Sysmon.Emit.EventEmitter |
          [ 
            Sysmon.ProcessMonitor | 
              valid_entries |> Enum.map(&get_container_monitor/1)
          ]
      ]

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
