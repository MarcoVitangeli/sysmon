defmodule Sysmon.ContainerMonitor do
  alias Sysmon.DockerUtils
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

    metrics = get_cpu_metrics(container_path)
    
    GenServer.cast(Sysmon.Emit.EventEmitter, {:store, metrics})
    Logger.info("END_EMIT for dir " <> container_path)

    {:noreply, container_path}
  end

  def get_cpu_metrics(path) do
    Logger.info(path)
    Path.join([path, "cpu.stat"]) 
      |> File.read! 
      |> String.split("\n")
      |> Enum.filter(fn e -> e != "" end)
      |> Enum.map(fn x -> parse_cpu_line(x, DockerUtils.get_id_from_path(path)) end)
  end

  defp parse_cpu_line(line, docker_container_id) when is_binary(line) when is_binary(docker_container_id) do
    parts = line |> String.split(" ")
    [metric_name, metric_value] = parts
    {parsed_value, _} = Integer.parse(metric_value)
    %{container_id: docker_container_id, metric_name: metric_name, metric_value: parsed_value, metric_type: :cpumetric, ingestion_time: DateTime.utc_now |> DateTime.truncate(:second)}
  end
end
