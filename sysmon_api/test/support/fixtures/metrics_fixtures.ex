defmodule SysmonApi.MetricsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `SysmonApi.Metrics` context.
  """

  @doc """
  Generate a metric.
  """
  def metric_fixture(attrs \\ %{}) do
    {:ok, metric} =
      attrs
      |> Enum.into(%{
        container_id: "some container_id",
        ingestion_time: ~D[2025-07-23],
        metric_id: "7488a646-e31f-11e4-aace-600308960662",
        metric_name: "some metric_name",
        metric_value: "120.5"
      })
      |> SysmonApi.Metrics.create_metric()

    metric
  end
end
