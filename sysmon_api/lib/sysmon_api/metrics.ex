defmodule SysmonApi.Metrics do
  @moduledoc """
  The Metrics context.
  """

  import Ecto.Query, warn: false
  alias SysmonApi.Repo

  alias SysmonApi.Metrics.Metric

  @doc """
  Returns the list of metrics.

  ## Examples

      iex> list_metrics()
      [%Metric{}, ...]

  """
  def list_metrics do
    Repo.all(Metric)
  end

  @doc """
  Gets a single metric.

  Raises `Ecto.NoResultsError` if the Metric does not exist.

  ## Examples

      iex> get_metric!(123)
      %Metric{}

      iex> get_metric!(456)
      ** (Ecto.NoResultsError)

  """
  def get_metric!(id), do: Repo.get!(Metric, id)

  @doc """
  Creates a metric.

  ## Examples

      iex> create_metric(%{field: value})
      {:ok, %Metric{}}

      iex> create_metric(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_metric(attrs \\ %{}) do
    %Metric{}
    |> Metric.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a metric.

  ## Examples

      iex> update_metric(metric, %{field: new_value})
      {:ok, %Metric{}}

      iex> update_metric(metric, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_metric(%Metric{} = metric, attrs) do
    metric
    |> Metric.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a metric.

  ## Examples

      iex> delete_metric(metric)
      {:ok, %Metric{}}

      iex> delete_metric(metric)
      {:error, %Ecto.Changeset{}}

  """
  def delete_metric(%Metric{} = metric) do
    Repo.delete(metric)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking metric changes.

  ## Examples

      iex> change_metric(metric)
      %Ecto.Changeset{data: %Metric{}}

  """
  def change_metric(%Metric{} = metric, attrs \\ %{}) do
    Metric.changeset(metric, attrs)
  end

  def insert_all(metrics) do
    Repo.insert_all(Metric, metrics |> Enum.map(&convert_string_keys_to_atoms/1))
  end

  defp convert_string_keys_to_atoms(metric) do
    input_time = with {:ok, time, _} = DateTime.from_iso8601(metric["ingestion_time"]) do
      time |> DateTime.truncate(:second)
    end
  
    now = DateTime.utc_now |> DateTime.truncate(:second)

    %{
      container_id: metric["container_id"],
      metric_name: metric["metric_name"], 
      metric_value: metric["metric_value"],
      metric_type: metric["metric_type"],
      ingestion_time: input_time,
      inserted_at: now,
      updated_at: now
    }
  end
end
