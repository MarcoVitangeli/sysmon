defmodule Sysmon.DockerUtils do
  @cgroup_dir "/sys/fs/cgroup/system.slice/"
  @docker_dir_regex ~r/^docker-([a-f0-9]{64})\.scope$/

  def cgroup_dir do
    @cgroup_dir
  end

  def filter_container_dirs(dir) when is_binary(dir) do
    Regex.match?(@docker_dir_regex, dir)
  end

  def get_id_from_path(path) when is_binary(path) do
    path
    |> Path.basename()
    |> String.replace_prefix("docker-", "")
    |> String.replace_suffix(".scope", "")
  end
end
