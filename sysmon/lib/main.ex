defmodule Sysmon.Main do
  def main() do
    {:ok, _} = Sysmon.ContainerMonitorSupervisor.start_link()
  end
end

