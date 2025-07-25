defmodule SysmonApiWeb.MetricController do
  use SysmonApiWeb, :controller

  alias SysmonApi.Metrics
  alias SysmonApi.Metrics.Metric

  def create(conn, %{"metric" => metric_params}) do
    with {:ok, %Metric{} = metric} <- Metrics.create_metric(metric_params) do
      conn
      |> put_status(:created)
      |> json(%{data: metric})
    end
  end

  def index(conn, _params) do
    metrics = Metrics.list_metrics()
    json(conn, %{data: metrics})
  end

  def show(conn, %{"id" => id}) do
    metric = Metrics.get_metric!(id)
    json(conn, %{data: metric})
  end

  def create_batch(conn, %{"metrics" => metrics}) when is_list(metrics) do
    {stored, _} = SysmonApi.Metrics.insert_all(metrics)

    conn
    |> put_status(:created)
    |> json(%{message: "Batch created successfully", count: stored})
  end
end
